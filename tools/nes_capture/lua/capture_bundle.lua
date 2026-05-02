-- tools/nes_capture/lua/capture_bundle.lua
-- Master plan Phase 1.5 — Task 1.5.2
--
-- Bundled NES reference capture script.
-- Reads all parameters from environment variables (set by run_capture.py):
--   NES_CAPTURE_SCENARIO  scenario id string
--   NES_CAPTURE_FRAME     target frame (decimal int string)
--   NES_CAPTURE_SEED      RNG seed (hex string like "0xABCD") or "" for none
--   NES_CAPTURE_MOVIE     path to .bk2 input movie or "" for none
--   NES_CAPTURE_ROM       path to ROM (informational)
--   NES_CAPTURE_OUT_DIR   output directory (absolute path)
--   NES_CAPTURE_ROM_HASH  SHA-256 of the ROM
--
-- Artifacts written (all to NES_CAPTURE_OUT_DIR):
--   screenshot.png     BizHawk screencapture at target frame
--   ppu.bin            PPU registers $2000-$2007 (8 bytes)
--   oam.bin            OAM buffer (256 bytes, via OAM domain or CPU bus)
--   palram.bin         PALRAM $3F00-$3F1F (32 bytes via PPU bus)
--   ciram.bin          CIRAM / Name Tables $2000-$2FFF (4096 bytes via PPU bus)
--   ram.bin            CPU RAM $0000-$07FF (2048 bytes)
--   frame.txt          Decimal target frame number
--   input_log.txt      Per-frame joypad bitmasks (one line per frame, hex)
--   rng_seed.txt       Injected RNG seed or "observed:<value>"
--
-- Memory rule feedback_one_big_probe: ALL artifacts in a single BizHawk launch.
-- Memory rule feedback_check_dont_guess: NES ROM is ground truth; no guessing.
-- Memory rule feedback_bizhawk_lua_env: BIZHAWK_ROOT must be set externally.

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local function get_env(name, default)
    local v = os.getenv(name)
    if v == nil or v == "" then return default end
    return v
end

local function write_bytes_to_file(path, bytes_array)
    local f = io.open(path, "wb")
    if not f then
        print("[capture_bundle] ERROR: cannot open for write: " .. path)
        return false
    end
    for _, b in ipairs(bytes_array) do
        f:write(string.char(b))
    end
    f:close()
    return true
end

local function write_text_to_file(path, text)
    local f = io.open(path, "w")
    if not f then
        print("[capture_bundle] ERROR: cannot open for write: " .. path)
        return false
    end
    f:write(text)
    f:close()
    return true
end

-- ---------------------------------------------------------------------------
-- Read parameters
-- ---------------------------------------------------------------------------

local scenario_id  = get_env("NES_CAPTURE_SCENARIO", "unknown")
local target_frame = tonumber(get_env("NES_CAPTURE_FRAME", "60"))
local seed_str     = get_env("NES_CAPTURE_SEED", "")
local movie_path   = get_env("NES_CAPTURE_MOVIE", "")
local out_dir      = get_env("NES_CAPTURE_OUT_DIR", ".")
local rom_hash     = get_env("NES_CAPTURE_ROM_HASH", "unknown")

print("[capture_bundle] scenario   = " .. scenario_id)
print("[capture_bundle] target_frame = " .. tostring(target_frame))
print("[capture_bundle] out_dir    = " .. out_dir)
print("[capture_bundle] rom_hash   = " .. rom_hash)

-- Parse RNG seed.
local rng_seed = nil
if seed_str ~= "" then
    rng_seed = tonumber(seed_str)  -- handles "0xABCD" and decimal
    if rng_seed then
        print("[capture_bundle] rng_seed   = " .. string.format("0x%04X", rng_seed))
    else
        print("[capture_bundle] WARNING: could not parse seed: " .. seed_str)
    end
end

-- ---------------------------------------------------------------------------
-- Input movie
-- ---------------------------------------------------------------------------

if movie_path ~= "" then
    print("[capture_bundle] Loading input movie: " .. movie_path)
    local ok, err = pcall(function()
        movie.load(movie_path)
    end)
    if not ok then
        print("[capture_bundle] WARNING: movie.load failed: " .. tostring(err))
    end
end

-- ---------------------------------------------------------------------------
-- Input log accumulator
-- ---------------------------------------------------------------------------

local input_log_lines = {}  -- one entry per frame, hex bitmask

-- ---------------------------------------------------------------------------
-- Per-frame callback registered on framestart
-- ---------------------------------------------------------------------------

local frame_reached = false

local function on_frame_start()
    local cf = emu.framecount()

    -- Frame 0: inject RNG seed before first display.
    if cf == 0 and rng_seed then
        local lo = rng_seed & 0xFF
        local hi = (rng_seed >> 8) & 0xFF
        -- NES Zelda 1 PRNG seed locations: $00FE and $00FF in CPU RAM.
        -- These are the random number table pointers / seeds used by Z_Rand.
        memory.write_byte(0x00FE, lo)
        memory.write_byte(0x00FF, hi)
        print(string.format(
            "[capture_bundle] Injected RNG seed lo=0x%02X hi=0x%02X at $00FE/$00FF",
            lo, hi
        ))
    end

    -- Log joypad bitmask for every frame up to target.
    if cf <= target_frame then
        local joy = joypad.get(1)
        -- Build an NES-style 8-bit bitmask: A B Sel Start Up Down Left Right
        local bitmask = 0
        if joy["A"]      then bitmask = bitmask | 0x01 end
        if joy["B"]      then bitmask = bitmask | 0x02 end
        if joy["Select"] then bitmask = bitmask | 0x04 end
        if joy["Start"]  then bitmask = bitmask | 0x08 end
        if joy["Up"]     then bitmask = bitmask | 0x10 end
        if joy["Down"]   then bitmask = bitmask | 0x20 end
        if joy["Left"]   then bitmask = bitmask | 0x40 end
        if joy["Right"]  then bitmask = bitmask | 0x80 end
        table.insert(input_log_lines, string.format("%d:0x%02X", cf, bitmask))
    end

    -- At target frame: capture everything.
    if cf == target_frame and not frame_reached then
        frame_reached = true
        capture_all()
    end
end

-- ---------------------------------------------------------------------------
-- Master capture function (called once at target frame)
-- ---------------------------------------------------------------------------

function capture_all()
    print("[capture_bundle] Capturing at frame " .. tostring(emu.framecount()))

    -- 1. Screenshot
    local screenshot_path = out_dir .. "/screenshot.png"
    local ok_ss, err_ss = pcall(function()
        client.screenshot(screenshot_path)
    end)
    if not ok_ss then
        print("[capture_bundle] screenshot failed: " .. tostring(err_ss))
    else
        print("[capture_bundle] screenshot -> " .. screenshot_path)
    end

    -- 2. PPU registers $2000-$2007 (8 bytes via "PPU Bus" or "System Bus")
    local ppu_bytes = {}
    local ok_ppu, err_ppu = pcall(function()
        -- BizHawk NES: memory domain names vary by core.
        -- Try "PPU Bus" first (CycleAccurate core), then "System Bus".
        local domain = "PPU Bus"
        local domains = memory.getmemorydomainlist()
        local found_ppu = false
        for _, d in ipairs(domains) do
            if d == "PPU Bus" then found_ppu = true; break end
        end
        if not found_ppu then domain = "System Bus" end

        -- PPU registers are mapped to CPU bus $2000-$2007.
        for addr = 0x2000, 0x2007 do
            table.insert(ppu_bytes, memory.read_byte(addr))
        end
    end)
    if not ok_ppu then
        print("[capture_bundle] PPU register read failed: " .. tostring(err_ppu))
        ppu_bytes = {0, 0, 0, 0, 0, 0, 0, 0}
    end
    write_bytes_to_file(out_dir .. "/ppu.bin", ppu_bytes)
    print("[capture_bundle] ppu.bin -> " .. #ppu_bytes .. " bytes")

    -- 3. OAM (256 bytes) — via "OAM" domain if available, else CPU RAM $0200.
    local oam_bytes = {}
    local ok_oam, err_oam = pcall(function()
        local domains = memory.getmemorydomainlist()
        local has_oam = false
        for _, d in ipairs(domains) do
            if d == "OAM" then has_oam = true; break end
        end
        if has_oam then
            for i = 0, 255 do
                table.insert(oam_bytes, memory.read_byte_as_of("OAM", i))
            end
        else
            -- Fallback: OAM mirror at CPU $0200-$02FF (standard Zelda 1 DMA target).
            for addr = 0x0200, 0x02FF do
                table.insert(oam_bytes, memory.read_byte(addr))
            end
        end
    end)
    if not ok_oam then
        print("[capture_bundle] OAM read failed: " .. tostring(err_oam))
        for i = 1, 256 do oam_bytes[i] = 0 end
    end
    write_bytes_to_file(out_dir .. "/oam.bin", oam_bytes)
    print("[capture_bundle] oam.bin -> " .. #oam_bytes .. " bytes")

    -- 4. PALRAM $3F00-$3F1F (32 bytes via PPU bus)
    local palram_bytes = {}
    local ok_pal, err_pal = pcall(function()
        local domains = memory.getmemorydomainlist()
        local ppu_domain = nil
        for _, d in ipairs(domains) do
            if d == "PPU Bus" then ppu_domain = "PPU Bus"; break end
        end
        -- PALRAM is at PPU bus $3F00-$3F1F.
        if ppu_domain then
            for addr = 0x3F00, 0x3F1F do
                table.insert(palram_bytes, memory.read_byte_as_of(ppu_domain, addr))
            end
        else
            -- Fallback via default domain + offset (less reliable).
            for addr = 0x3F00, 0x3F1F do
                table.insert(palram_bytes, 0)
            end
            print("[capture_bundle] WARNING: PPU Bus domain not found; palram.bin will be zeroes")
        end
    end)
    if not ok_pal then
        print("[capture_bundle] PALRAM read failed: " .. tostring(err_pal))
        for i = 1, 32 do palram_bytes[i] = 0 end
    end
    write_bytes_to_file(out_dir .. "/palram.bin", palram_bytes)
    print("[capture_bundle] palram.bin -> " .. #palram_bytes .. " bytes")

    -- 5. CIRAM / Name Tables $2000-$2FFF (4096 bytes via PPU bus)
    local ciram_bytes = {}
    local ok_ci, err_ci = pcall(function()
        local domains = memory.getmemorydomainlist()
        local ppu_domain = nil
        for _, d in ipairs(domains) do
            if d == "PPU Bus" then ppu_domain = "PPU Bus"; break end
        end
        if ppu_domain then
            for addr = 0x2000, 0x2FFF do
                table.insert(ciram_bytes, memory.read_byte_as_of(ppu_domain, addr))
            end
        else
            for i = 1, 4096 do ciram_bytes[i] = 0 end
            print("[capture_bundle] WARNING: PPU Bus domain not found; ciram.bin will be zeroes")
        end
    end)
    if not ok_ci then
        print("[capture_bundle] CIRAM read failed: " .. tostring(err_ci))
        for i = 1, 4096 do ciram_bytes[i] = 0 end
    end
    write_bytes_to_file(out_dir .. "/ciram.bin", ciram_bytes)
    print("[capture_bundle] ciram.bin -> " .. #ciram_bytes .. " bytes")

    -- 6. CPU RAM $0000-$07FF (2048 bytes)
    local ram_bytes = {}
    local ok_ram, err_ram = pcall(function()
        for addr = 0x0000, 0x07FF do
            table.insert(ram_bytes, memory.read_byte(addr))
        end
    end)
    if not ok_ram then
        print("[capture_bundle] RAM read failed: " .. tostring(err_ram))
        for i = 1, 2048 do ram_bytes[i] = 0 end
    end
    write_bytes_to_file(out_dir .. "/ram.bin", ram_bytes)
    print("[capture_bundle] ram.bin -> " .. #ram_bytes .. " bytes")

    -- 7. frame.txt
    write_text_to_file(out_dir .. "/frame.txt", tostring(emu.framecount()) .. "\n")
    print("[capture_bundle] frame.txt")

    -- 8. input_log.txt
    write_text_to_file(out_dir .. "/input_log.txt", table.concat(input_log_lines, "\n") .. "\n")
    print("[capture_bundle] input_log.txt -> " .. #input_log_lines .. " lines")

    -- 9. rng_seed.txt
    local seed_content
    if rng_seed then
        seed_content = string.format("injected:0x%04X\n", rng_seed)
    else
        -- Read observed seed from RAM for reference.
        local obs_lo = memory.read_byte(0x00FE)
        local obs_hi = memory.read_byte(0x00FF)
        seed_content = string.format("observed:0x%04X\n", (obs_hi << 8) | obs_lo)
    end
    write_text_to_file(out_dir .. "/rng_seed.txt", seed_content)
    print("[capture_bundle] rng_seed.txt -> " .. seed_content:gsub("\n", ""))

    print("[capture_bundle] All artifacts written.")
    print("[capture_bundle] Closing emulator.")

    -- Close BizHawk after capture (CLI automation).
    client.exit()
end

-- ---------------------------------------------------------------------------
-- Register frame callback and run
-- ---------------------------------------------------------------------------

event.onframestart(on_frame_start)

-- If BizHawk is in play mode the callback will fire automatically.
-- If we are already past target_frame (e.g. loaded a save state), capture now.
if emu.framecount() >= target_frame then
    frame_reached = true
    capture_all()
end

print("[capture_bundle] Registered. Waiting for frame " .. tostring(target_frame) .. "...")
