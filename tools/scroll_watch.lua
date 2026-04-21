-- scroll_watch.lua — BizHawk Genesis Plus GX scroll state monitor
-- Watches NES RAM scroll variables and flags the subphase 1→2 transition.
--
-- Usage: Tools → Lua Console → Open Script → select this file

local function rb(offset)
    return mainmemory.read_u8(offset)
end

local prev_subphase = 0
local snap_frame = -1
local snap = {}

while true do
    local curVScroll   = rb(0x00FC)
    local ntToggle     = rb(0x005C)
    local ppuCtrl      = rb(0x00FF)
    local ppuScrlY     = rb(0x0807)   -- PPU_SCRL_Y at $FF0807
    local demoWraps    = rb(0x0415)
    local subphase     = rb(0x042D)
    local phase        = rb(0x042C)
    local gameMode     = rb(0x0012)

    -- Detect subphase transition to 2 (item roll start)
    if subphase == 2 and prev_subphase ~= 2 then
        snap_frame = emu.framecount()
        snap = {
            curV = curVScroll,
            nt   = ntToggle,
            ctrl = ppuCtrl,
            scrlY = ppuScrlY,
            wraps = demoWraps,
            phase = phase,
            mode  = gameMode,
        }
        console.log(string.format(
            "=== SUBPHASE -> 2 at frame %d ===", snap_frame))
        console.log(string.format(
            "  CurVScroll=$%02X  NTtoggle=$%02X  PPU_CTRL=$%02X",
            snap.curV, snap.nt, snap.ctrl))
        console.log(string.format(
            "  PPU_SCRL_Y=$%02X  DemoWraps=$%02X  Phase=$%02X  Mode=$%02X",
            snap.scrlY, snap.wraps, snap.phase, snap.mode))

        -- Compute what VSRAM would be with current formula
        local vsram = snap.scrlY + 8
        local ctrl = snap.ctrl
        if snap.nt ~= 0 then
            ctrl = bit.bxor(ctrl, 0x02)
        end
        if bit.band(ctrl, 0x02) ~= 0 then
            vsram = vsram + 240
        end
        if vsram >= 480 then
            vsram = vsram - 480
        end
        console.log(string.format(
            "  Computed VSRAM=%d ($%04X)", vsram, vsram))
    end
    prev_subphase = subphase

    -- HUD overlay every frame
    local y = 10
    gui.text(10, y, string.format("Mode:%02X Ph:%02X Sub:%02X",
        gameMode, phase, subphase), "white", "black")
    y = y + 16
    gui.text(10, y, string.format("CurV:%02X  ScrlY:%02X",
        curVScroll, ppuScrlY), "yellow", "black")
    y = y + 16
    gui.text(10, y, string.format("NT:%02X  CTRL:%02X  Wraps:%02X",
        ntToggle, ppuCtrl, demoWraps), "cyan", "black")

    -- Show snapshot if captured
    if snap_frame > 0 then
        y = y + 20
        gui.text(10, y, string.format("SNAP @%d: VSRAM=%d",
            snap_frame,
            snap.scrlY and (snap.scrlY + 8) or 0),
            "lime", "black")
    end

    emu.frameadvance()
end
