-- bizhawk_nes_title_ram_capture.lua
-- T22 helper: run NES Zelda to title screen, then dump $0000-$07FF
--
-- Output: builds/reports/nes_title_ram.txt  (2048 hex bytes, one per line)
--         builds/reports/nes_title_ram_meta.txt (frame info)
--
-- Capture trigger: PPU $2001 write with BG-enable (bit 3) or SPR-enable (bit 4) set,
-- then wait 10 frames for the screen to stabilize.

local ROOT    = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\"
local OUT_DIR = ROOT .. "builds\\reports\\"
local OUT_RAM = OUT_DIR .. "nes_title_ram.txt"
local OUT_META= OUT_DIR .. "nes_title_ram_meta.txt"

os.execute('if not exist "' .. OUT_DIR .. '" mkdir "' .. OUT_DIR .. '"')

local fmeta = assert(io.open(OUT_META, "w"))
local function mlog(msg) fmeta:write(msg.."\n") fmeta:flush() print(msg) end

mlog("NES title RAM capture starting...")

local MAX_FRAMES    = 400
local display_frame = nil
local cur_frame     = 0

-- Monitor writes to $2001 (PPUMASK) for display enable
local watch_id = event.onmemorywrite(function()
    if display_frame then return end
    -- Read what was written — we can't get the value directly in write callback
    -- but the write already occurred, so we check the current memory bus value
    -- Actually in BizHawk NES, $2001 isn't readable from CPU RAM domain.
    -- Instead, check NES RAM $0012 (GameMode) — once non-zero the game is past init.
    -- We'll use a polling approach in the main loop instead.
end, 0x2001, "ppu_mask_watch")

-- Main loop
for frame = 1, MAX_FRAMES do
    cur_frame = frame
    emu.frameadvance()

    -- Poll NES work RAM for display enable
    -- Zelda writes PPUMASK=$1E (bits 3,4 set) when turning display on.
    -- BizHawk NES: use System Bus domain to read PPU register state is not trivial.
    -- Better: watch for the NES game mode $0012 to reach a stable title-screen value.
    -- In NES Zelda, $0012 holds the subscreen/area index; once display is on it stays put.
    -- More reliable: watch for NES RAM $001F (frame counter) to be non-zero after mode=stable.

    -- Check for PPUMASK shadow — NES Zelda stores a copy of $2001 write at NES RAM $0007
    -- (varies by version; let's check multiple candidate locations).
    -- Safest: read System Bus at $2001 if supported.
    local ppu_mask_val = nil
    local ok, v = pcall(function()
        memory.usememorydomain("System Bus")
        return memory.read_u8(0x2001)
    end)
    if ok and v ~= nil then ppu_mask_val = v end

    if not ppu_mask_val then
        -- Try NES RAM domain, known PPUMASK shadow locations
        local ok2, v2 = pcall(function()
            memory.usememorydomain("RAM")
            return memory.read_u8(0x00FE)  -- our Genesis port stores it at $00FE
        end)
        if ok2 and v2 ~= nil then ppu_mask_val = v2 end
    end

    if not display_frame and ppu_mask_val and ((ppu_mask_val & 0x08) ~= 0 or (ppu_mask_val & 0x10) ~= 0) then
        display_frame = frame
        mlog(string.format("  Display enable detected at frame %d (PPUMASK=$%02X)", frame, ppu_mask_val))
    end

    if frame <= 5 or frame % 60 == 0 then
        local mode12 = 0
        local ok3, v3 = pcall(function()
            memory.usememorydomain("RAM")
            return memory.read_u8(0x0012)
        end)
        if ok3 and v3 ~= nil then mode12 = v3 end
        mlog(string.format("  f%03d  $0012=$%02X  disp_frame=%s",
            frame, mode12, tostring(display_frame or "-")))
    end

    if display_frame and frame >= display_frame + 10 then
        mlog(string.format("  10-frame settle complete at frame %d — capturing RAM", frame))
        break
    end
end

if watch_id then pcall(function() event.unregisterbyid(watch_id) end) end

if not display_frame then
    mlog("  WARNING: display never enabled in " .. MAX_FRAMES .. " frames — capturing anyway")
end

-- Dump NES RAM $0000-$07FF
local ok_ram, err_ram = pcall(function()
    memory.usememorydomain("RAM")
end)
if not ok_ram then
    -- Try alternate domain name
    pcall(function() memory.usememorydomain("System Bus") end)
end

local fout = assert(io.open(OUT_RAM, "w"))
for i = 0, 0x07FF do
    local ok4, bval = pcall(function()
        memory.usememorydomain("RAM")
        return memory.read_u8(i)
    end)
    local b = (ok4 and bval) or 0
    fout:write(string.format("%02X\n", b))
end
fout:close()

mlog("RAM dump written to: " .. OUT_RAM)
mlog(string.format("Capture frame: %s", tostring(display_frame and (display_frame + 10) or "MAX")))
fmeta:close()
client.exit()
