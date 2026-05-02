-- probe_atlas_chr_live.lua
-- RoomRom atlas Phase 1c: dump live CHR RAM to a binary file.
--
-- Boots Zelda 1 (orig) to overworld, settles 30 frames, then dumps
-- the entire CHR RAM (4096 bytes, PPU $0000..$0FFF) to disk so
-- verify_chr_live.py can byte-match it against PRG-extracted blocks.
--
-- Output: C:\tmp\atlas_chr_live_orig.bin  (configurable via env var)
--
-- Usage (via bizhawkScript skill or manually):
--   EmuHawk.exe --lua="probe_atlas_chr_live.lua" --rom="...Zelda.nes"
--
-- Environment variables (optional overrides):
--   ATLAS_CHR_OUT   - output path for the 4096-byte CHR dump
--   ATLAS_CHR_ROM_ID - variant label written into a companion status file
--
-- The probe boots using the same boot-to-overworld sequence as
-- probe_nes_item_chr_manifest.lua. The CHR dump uses whichever
-- NesHawk memory domain exposes CHR RAM.

local OUT_CHR = os.getenv("ATLAS_CHR_OUT") or "C:\\tmp\\atlas_chr_live_orig.bin"
local ROM_ID  = os.getenv("ATLAS_CHR_ROM_ID") or "orig"
local OUT_STATUS = OUT_CHR:gsub("%.bin$", "") .. "_status.json"

-- -------------------------------------------------------------------------
-- Helpers
-- -------------------------------------------------------------------------

local function safe_set(pad)
    local ok = pcall(function() joypad.set(pad or {}, 1) end)
    if not ok then joypad.set(pad or {}) end
end

local function settle(frames)
    for _ = 1, frames do safe_set({}); emu.frameadvance() end
end

local function u8(addr)
    memory.usememorydomain("System Bus")
    return memory.read_u8(addr & 0xFFFF)
end

-- NES RAM addresses
local GAME_MODE = 0x0012
local GAME_SUB  = 0x0013
local CUR_LEVEL = 0x0010

-- -------------------------------------------------------------------------
-- CHR domain selection
-- -------------------------------------------------------------------------

local function find_chr_domain()
    local ok, list = pcall(function() return memory.getmemorydomainlist() end)
    if not ok or not list then return nil end
    local n = list.Count or #list
    local candidates = {"CHR RAM", "CHR", "CHR VRAM", "CHR ROM", "CHR VROM", "VRAM"}
    for _, want in ipairs(candidates) do
        for i = 0, n - 1 do
            if tostring(list[i]) == want then return want end
        end
    end
    return nil
end

local function dump_chr(domain, count)
    memory.usememorydomain(domain)
    local t = {}
    for i = 0, count - 1 do
        t[i + 1] = memory.read_u8(i)
    end
    return t
end

-- -------------------------------------------------------------------------
-- Boot sequence (matches probe_nes_item_chr_manifest.lua structure)
-- -------------------------------------------------------------------------

local booted = false
local BOOT_TO_FS1, SELECT_REGISTER, ENTER_REGISTER, TYPE_NAME,
      FINISH_NAME, WAIT_GAMEPLAY, START_GAME = 1,2,3,4,5,6,7
local flow = BOOT_TO_FS1
local flow_timer = 0

local function boot_step()
    local mode = u8(GAME_MODE)
    local sub  = u8(GAME_SUB)
    if flow == BOOT_TO_FS1 then
        -- Wait for File Select (mode 0x05)
        if mode == 0x05 then
            settle(10)
            flow = SELECT_REGISTER
        else
            -- Need Start press in mode 0x00
            if mode == 0x00 then
                safe_set({ ["Start"] = true, ["P1 Start"] = true })
                emu.frameadvance()
                safe_set({})
                settle(5)
            else
                settle(2)
            end
        end
    elseif flow == SELECT_REGISTER then
        -- Navigate to first empty slot and press A to register
        flow_timer = flow_timer + 1
        if flow_timer < 30 then
            settle(1)
        else
            flow = ENTER_REGISTER
            flow_timer = 0
        end
    elseif flow == ENTER_REGISTER then
        -- Press Start to enter register mode
        safe_set({ ["Start"] = true, ["P1 Start"] = true })
        emu.frameadvance()
        safe_set({})
        settle(10)
        flow = TYPE_NAME
    elseif flow == TYPE_NAME then
        -- Skip naming: just press A repeatedly to accept default
        for _ = 1, 10 do
            safe_set({ ["A"] = true, ["P1 A"] = true })
            emu.frameadvance()
            safe_set({})
            settle(2)
        end
        flow = FINISH_NAME
    elseif flow == FINISH_NAME then
        -- Press Start to confirm name entry
        safe_set({ ["Start"] = true, ["P1 Start"] = true })
        emu.frameadvance()
        safe_set({})
        settle(15)
        flow = WAIT_GAMEPLAY
    elseif flow == WAIT_GAMEPLAY then
        -- Wait until we are in overworld gameplay (mode >= 0x04)
        flow_timer = flow_timer + 1
        if mode == 0x07 or mode == 0x04 then
            flow = START_GAME
        elseif flow_timer > 600 then
            -- Timeout: take the CHR dump anyway at whatever state we're in
            flow = START_GAME
        else
            settle(1)
        end
    elseif flow == START_GAME then
        booted = true
    end
end

-- -------------------------------------------------------------------------
-- JSON writer (minimal)
-- -------------------------------------------------------------------------

local function jstr(s)
    return '"' .. tostring(s):gsub('\\', '\\\\'):gsub('"', '\\"') .. '"'
end

local function write_status(path, ok, msg, chr_sha)
    local f = io.open(path, "w")
    if not f then return end
    f:write("{\n")
    f:write('  "rom_id": ' .. jstr(ROM_ID) .. ",\n")
    f:write('  "ok": ' .. (ok and "true" or "false") .. ",\n")
    f:write('  "message": ' .. jstr(msg) .. ",\n")
    f:write('  "chr_sha256_prefix": ' .. jstr(chr_sha or "") .. "\n")
    f:write("}\n")
    f:close()
end

-- -------------------------------------------------------------------------
-- Main frame loop
-- -------------------------------------------------------------------------

local SETTLE_FRAMES = 30
local settle_count  = 0
local done          = false

event.onframeend(function()
    if done then return end

    if not booted then
        boot_step()
        return
    end

    -- Settled enough?
    settle_count = settle_count + 1
    if settle_count < SETTLE_FRAMES then return end

    -- One-shot: dump CHR RAM
    done = true

    local domain = find_chr_domain()
    if not domain then
        local msg = "ERROR: no CHR memory domain found"
        print("[atlas_chr_live] " .. msg)
        write_status(OUT_STATUS, false, msg, "")
        return
    end

    local chr_bytes = dump_chr(domain, 4096)

    -- Write binary
    local f = io.open(OUT_CHR, "wb")
    if not f then
        local msg = "ERROR: could not open output: " .. OUT_CHR
        print("[atlas_chr_live] " .. msg)
        write_status(OUT_STATUS, false, msg, "")
        return
    end
    for _, b in ipairs(chr_bytes) do
        f:write(string.char(b))
    end
    f:close()

    -- Quick SHA-like: just report first 16 bytes as hex prefix for status
    local hex_prefix = ""
    for i = 1, 16 do
        hex_prefix = hex_prefix .. string.format("%02x", chr_bytes[i])
    end

    local msg = "CHR dump written: " .. OUT_CHR .. " (4096 bytes, domain=" .. domain .. ")"
    print("[atlas_chr_live] " .. msg)
    write_status(OUT_STATUS, true, msg, hex_prefix)
end)

print("[atlas_chr_live] probe loaded. ROM_ID=" .. ROM_ID .. "  OUT=" .. OUT_CHR)
