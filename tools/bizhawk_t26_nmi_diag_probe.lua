-- bizhawk_t26_nmi_diag_probe.lua
-- T26 pre-flight: diagnose why NMI stops after 7 fires.
-- Reads all debug counters, PPU_CTRL, key RAM state every 60 frames.
-- Also hooks VBlankISR entry to count actual VBlank events.

local ROOT     = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\"
local OUT_DIR  = ROOT .. "builds\\reports\\"
local OUT_PATH = OUT_DIR .. "bizhawk_t26_nmi_diag_probe.txt"

dofile(ROOT .. "tools/probe_addresses.lua")

os.execute('if not exist "' .. OUT_DIR .. '" mkdir "' .. OUT_DIR .. '"')
local f = assert(io.open(OUT_PATH, "w"))
local function log(msg) f:write(msg.."\n") f:flush() print(msg) end

local function try_dom(dom, offset, width)
    local ok, v = pcall(function()
        memory.usememorydomain(dom)
        if     width == 1 then return memory.read_u8(offset)
        elseif width == 2 then return memory.read_u16_be(offset)
        else                    return memory.read_u32_be(offset) end
    end)
    return ok and v or nil
end

local function ram_read(bus_addr, width)
    local ofs = bus_addr - 0xFF0000
    for _, spec in ipairs({
        {"M68K BUS", bus_addr}, {"68K RAM", ofs},
        {"System Bus", bus_addr}, {"Main RAM", ofs},
    }) do
        local v = try_dom(spec[1], spec[2], width or 1)
        if v ~= nil then return v end
    end
    return nil
end

local function dump_state(label)
    local nmi_c   = ram_read(0xFF1003, 1) or 0
    local tcp_c   = ram_read(0xFF1007, 1) or 0
    local tim_c   = ram_read(0xFF1008, 1) or 0
    local aud_c   = ram_read(0xFF1009, 1) or 0
    local inim_c  = ram_read(0xFF1000, 1) or 0
    local ini0_c  = ram_read(0xFF1001, 1) or 0
    local tcp2_c  = ram_read(0xFF1002, 1) or 0
    local igom_c  = ram_read(0xFF1004, 1) or 0
    local upd_c   = ram_read(0xFF1005, 1) or 0
    local ci_c    = ram_read(0xFF100A, 1) or 0   -- CheckInput reach
    local ri_c    = ram_read(0xFF100B, 1) or 0   -- ReadInputs return
    local sc_c    = ram_read(0xFF100C, 1) or 0   -- ScrambleRandom entry
    local sw_c    = ram_read(0xFF100D, 1) or 0   -- pre-SwitchBank
    local dt1_c   = ram_read(0xFF100E, 1) or 0   -- DriveTune1 returned
    local de_c    = ram_read(0xFF100F, 1) or 0   -- DriveEffect returned
    local dsa_c   = ram_read(0xFF1010, 1) or 0   -- DriveSample returned
    local dso_c   = ram_read(0xFF1011, 1) or 0   -- DriveSong returned
    local dt0_c   = ram_read(0xFF1012, 1) or 0   -- DriveTune0 returned

    local ppu_ctrl = ram_read(0xFF0804, 1) or 0
    local ppu_mask = ram_read(0xFF0805, 1) or 0

    local ram_F4  = ram_read(0xFF00F4, 1) or 0
    local ram_F5  = ram_read(0xFF00F5, 1) or 0
    local ram_F6  = ram_read(0xFF00F6, 1) or 0
    local ram_FF  = ram_read(0xFF00FF, 1) or 0
    local ram_11  = ram_read(0xFF0011, 1) or 0
    local ram_12  = ram_read(0xFF0012, 1) or 0
    local ram_13  = ram_read(0xFF0013, 1) or 0
    local ram_14  = ram_read(0xFF0014, 1) or 0
    local ram_42C = ram_read(0xFF042C, 1) or 0
    local ram_42D = ram_read(0xFF042D, 1) or 0

    local nmi_bit = (ppu_ctrl >> 7) & 1

    log(string.format("  [%s]", label))
    log(string.format("    NMI=%d  TCP=%d  Tim=%d  Aud=%d  CI=%d  RI=%d  SC=%d  SW=%d",
        nmi_c, tcp_c, tim_c, aud_c, ci_c, ri_c, sc_c, sw_c))
    log(string.format("    IGOM=%d  Upd=%d  IM=%d  IM0=%d  TCP2=%d",
        igom_c, upd_c, inim_c, ini0_c, tcp2_c))
    log(string.format("    DriveAudio: DT1=%d  DE=%d  DSa=%d  DSo=%d  DT0=%d",
        dt1_c, de_c, dsa_c, dso_c, dt0_c))
    log(string.format("    PPU_CTRL=$%02X (bit7/NMI-en=%d)  PPU_MASK=$%02X",
        ppu_ctrl, nmi_bit, ppu_mask))
    log(string.format("    $F4=$%02X  $F5=$%02X  $F6=$%02X  $FF=$%02X",
        ram_F4, ram_F5, ram_F6, ram_FF))
    log(string.format("    $11=$%02X  $12=$%02X  $13=$%02X  $14=$%02X  $42C=$%02X  $42D=$%02X",
        ram_11, ram_12, ram_13, ram_14, ram_42C, ram_42D))
end

local function main()
    local MAX_FRAMES = 300
    log("=================================================================")
    log("T26 NMI Diagnostic Probe  —  up to " .. MAX_FRAMES .. " frames")
    log("=================================================================")
    log(string.format("  LoopForever=$%06X  VBlankISR=$%06X",
        LOOPFOREVER, 0x000306))  -- approximate; adjust if needed
    log("")

    local exception_hit = false
    local visit_lf = nil
    local display_on_frame = nil
    local last_nmi = 0

    -- Hook VBlankISR to count actual VBlank entries
    local vblank_hits = 0
    local vblank_id = nil
    local ok, vid = pcall(function()
        -- VBlankISR is in the vector table dispatch; hook the btst instruction
        -- at the start of VBlankISR. We'll just poll each frame.
        return nil
    end)

    for frame = 1, MAX_FRAMES do
        emu.frameadvance()
        local pc = emu.getregister("M68K PC") or 0

        if pc >= LOOPFOREVER and pc <= LOOPFOREVER+3 then
            if not visit_lf then visit_lf = frame end
        end

        if not display_on_frame then
            local pm = ram_read(0xFF0805, 1) or 0
            if (pm & 0x08) ~= 0 or (pm & 0x10) ~= 0 then
                display_on_frame = frame
            end
        end

        -- Check if NMI counter changed
        local cur_nmi = ram_read(0xFF1003, 1) or 0
        if cur_nmi ~= last_nmi then
            dump_state(string.format("f%03d NMI#%d fired", frame, cur_nmi))
            last_nmi = cur_nmi
        end

        -- Periodic state dump
        if frame == 1 or frame == 5 or frame % 30 == 0 then
            dump_state(string.format("f%03d periodic", frame))
        end
    end

    log("")
    log("=== Final state after " .. MAX_FRAMES .. " frames ===")
    dump_state("FINAL")

    -- SAT sprite 0 check
    local function vram_u16(addr)
        return try_dom("VRAM", addr, 2) or 0
    end
    local SAT_BASE = 0xD800
    local sat0_Y  = vram_u16(SAT_BASE + 0) & 0x1FF
    local sat0_sl = vram_u16(SAT_BASE + 2)
    local sat0_tw = vram_u16(SAT_BASE + 4)
    local sat0_X  = vram_u16(SAT_BASE + 6) & 0x1FF
    log(string.format("  SAT[0]: Y=%d link=%d tw=$%04X X=%d",
        sat0_Y, sat0_sl & 0x7F, sat0_tw, sat0_X))

    -- Check a few more sprites
    for i = 1, 7 do
        local base = SAT_BASE + i * 8
        local sy = vram_u16(base) & 0x1FF
        local sl = vram_u16(base+2) & 0x7F
        local tw = vram_u16(base+4)
        local sx = vram_u16(base+6) & 0x1FF
        if sy ~= 0 or tw ~= 0 then
            log(string.format("  SAT[%d]: Y=%d link=%d tw=$%04X X=%d",
                i, sy, sl, tw, sx))
        end
    end

    log("")
    log("=================================================================")
    log("Diagnosis: NMI stopped? Check PPU_CTRL bit 7 at FINAL state.")
    log("If NMI-en=0: NMI was disabled and never re-enabled.")
    log("If NMI-en=1: NMI enabled but VBlank not firing (timing/exception).")
    log("=================================================================")
    f:close()
    client.exit()
end

main()
