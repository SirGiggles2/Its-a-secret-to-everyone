-- Boomerang sprite visual probe.
-- Captures screenshot + SAT dump + VRAM tile dump while the boomerang
-- is mid-flight in RoomRom (Debug.md). Compare visual output to NES Z1
-- ground truth for tile 0x36/0x38/0x3A 8x8 spinning boomerang.
--
-- Output dir is created at C:\tmp\bm_probe\.

local OUT_DIR = "C:\\tmp\\bm_probe"
os.execute('mkdir "' .. OUT_DIR .. '" 2>nul')

-- Phase counters
local frame = 0
local FRAME_BOOT      = 60      -- wait for boot
local FRAME_PRESS_START = 120
local FRAME_PRESS_B   = 240
local FRAME_CAPTURE_1 = 250     -- 10 frames after B press
local FRAME_CAPTURE_2 = 256     -- mid-flight phase 2
local FRAME_CAPTURE_3 = 262     -- mid-flight phase 3
local FRAME_DONE      = 280

-- Capture state
local captured = {}

local function inject_pad(start_pressed, b_pressed)
    joypad.set({
        ["P1 Up"] = false,    ["P1 Down"] = false,
        ["P1 Left"] = false,  ["P1 Right"] = false,
        ["P1 A"] = false,     ["P1 B"] = b_pressed,
        ["P1 C"] = false,     ["P1 X"] = false,
        ["P1 Y"] = false,     ["P1 Z"] = false,
        ["P1 Start"] = start_pressed,
        ["P1 Mode"] = false,
    }, 1)
end

local function dump_sat(label)
    -- Genesis SAT: read from VDP RAM via memory.read, but easier to use
    -- sprite domain. Genesis SAT lives in VRAM at $A800 (or wherever
    -- VDP_set_sprite_table_base put it). RoomRom default SAT base via
    -- SGDK SPR_setBank. Just read first 16 sprites from VRAM.
    local out = io.open(OUT_DIR .. "\\sat_" .. label .. ".txt", "w")
    out:write("=== SAT dump @ " .. label .. " (frame=" .. emu.framecount() .. ") ===\n")
    -- Genesis SAT entry: 8 bytes per sprite
    -- byte 0-1: y
    -- byte 2: size (HHWW)
    -- byte 3: link
    -- byte 4-5: tile (priority, palette, vflip, hflip, tile_low11)
    -- byte 6-7: x
    --
    -- We don't know exact SAT base. SGDK uses VDP_setSpriteListAddress.
    -- Try common locations: $A800 (default after Phase 5).
    -- Actually use VDP regs to find it.
    -- VDP reg 5 = sprite table address (high 7 bits at 9-15 of $C00000).
    -- Easier: just dump VRAM at common bases.
    for base_label, base_addr in pairs({A800=0xA800, B800=0xB800, F000=0xF000, F400=0xF400}) do
        out:write(string.format("\nSAT@%s:\n", base_label))
        for i = 0, 15 do
            local off = base_addr + i * 8
            local b0 = memory.read_u8(off + 0, "VRAM")
            local b1 = memory.read_u8(off + 1, "VRAM")
            local b2 = memory.read_u8(off + 2, "VRAM")
            local b3 = memory.read_u8(off + 3, "VRAM")
            local b4 = memory.read_u8(off + 4, "VRAM")
            local b5 = memory.read_u8(off + 5, "VRAM")
            local b6 = memory.read_u8(off + 6, "VRAM")
            local b7 = memory.read_u8(off + 7, "VRAM")
            local y  = (b0 * 256 + b1) & 0x3FF
            local sz = b2
            local link = b3
            local attr = b4 * 256 + b5
            local tile = attr & 0x07FF
            local prio = (attr >> 15) & 1
            local pal  = (attr >> 13) & 3
            local vfl  = (attr >> 12) & 1
            local hfl  = (attr >> 11) & 1
            local x = (b6 * 256 + b7) & 0x3FF
            out:write(string.format("  [%2d] y=%4d x=%4d sz=%02X link=%02X tile=%03X "
                                    .. "prio=%d pal=%d vfl=%d hfl=%d\n",
                                    i, y, x, sz, link, tile, prio, pal, vfl, hfl))
        end
    end
    out:close()
end

local function dump_vram_tile_range(start_tile, count, label)
    local out = io.open(OUT_DIR .. "\\vram_tile_" .. label .. ".txt", "w")
    out:write("=== VRAM tiles " .. start_tile .. ".." .. (start_tile + count - 1) ..
              " @ " .. label .. " (frame=" .. emu.framecount() .. ") ===\n")
    for t = start_tile, start_tile + count - 1 do
        out:write(string.format("\nTile $%03X (offset $%05X):\n", t, t * 32))
        for row = 0, 7 do
            out:write("  ")
            for col = 0, 3 do
                local b = memory.read_u8(t * 32 + row * 4 + col, "VRAM")
                out:write(string.format("%02X", b))
            end
            -- ASCII art: each Genesis 4bpp byte = 2 pixels
            out:write("  |")
            for col = 0, 3 do
                local b = memory.read_u8(t * 32 + row * 4 + col, "VRAM")
                local hi = (b >> 4) & 0xF
                local lo = b & 0xF
                out:write(hi == 0 and "." or string.format("%X", hi))
                out:write(lo == 0 and "." or string.format("%X", lo))
            end
            out:write("|\n")
        end
    end
    out:close()
end

local function snap(label)
    client.screenshot(OUT_DIR .. "\\screen_" .. label .. ".png")
    dump_sat(label)
end

event.onframeend(function()
    frame = emu.framecount()

    -- Phase machine driving inputs
    if frame == FRAME_PRESS_START then
        inject_pad(true, false)
    elseif frame == FRAME_PRESS_START + 4 then
        inject_pad(false, false)
    elseif frame == FRAME_PRESS_B then
        inject_pad(false, true)
    elseif frame == FRAME_PRESS_B + 2 then
        inject_pad(false, false)
    end

    -- Captures
    if frame == FRAME_CAPTURE_1 then
        snap("01_post_throw")
        dump_vram_tile_range(0x500, 16, "01_post_throw")  -- ~items range
    elseif frame == FRAME_CAPTURE_2 then
        snap("02_mid_flight")
    elseif frame == FRAME_CAPTURE_3 then
        snap("03_late_flight")
    elseif frame == FRAME_DONE then
        gui.text(10, 10, "PROBE DONE — see " .. OUT_DIR)
        client.screenshot(OUT_DIR .. "\\screen_99_done.png")
    end
end)

gui.text(10, 10, "BM probe armed — frame counter")
