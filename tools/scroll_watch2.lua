-- scroll_watch2.lua — BizHawk Genesis Plus GX scroll state monitor v2
-- Logs every frame where scroll values change during item roll (phase 1 sub 2).
-- Also captures subphase transitions.
--
-- Usage: Tools → Lua Console → Open Script → select this file

local function rb(offset)
    return mainmemory.read_u8(offset)
end

local prev_subphase = 0
local prev_curV = -1
local prev_scrlY = -1
local prev_nt = -1
local prev_ctrl = -1
local frame_in_sub2 = 0
local logging_active = false

while true do
    local curVScroll   = rb(0x00FC)
    local ntToggle     = rb(0x005C)
    local ppuCtrl      = rb(0x00FF)
    local ppuScrlY     = rb(0x0807)
    local demoWraps    = rb(0x0415)
    local subphase     = rb(0x042D)
    local phase        = rb(0x042C)
    local gameMode     = rb(0x0012)
    local frameCount   = rb(0x0015)
    local fc           = emu.framecount()

    -- Detect subphase transitions
    if subphase ~= prev_subphase then
        console.log(string.format(
            "F%d: sub %d->%d  Ph:%02X Mode:%02X CurV:%02X ScrlY:%02X NT:%02X CTRL:%02X Wraps:%02X",
            fc, prev_subphase, subphase, phase, gameMode,
            curVScroll, ppuScrlY, ntToggle, ppuCtrl, demoWraps))

        if subphase == 2 and phase == 1 and gameMode == 0 then
            logging_active = true
            frame_in_sub2 = 0
            prev_curV = -1
            prev_scrlY = -1
            prev_nt = -1
            prev_ctrl = -1
            console.log("  >>> ITEM ROLL START — logging every scroll change <<<")
        end
    end

    -- During item roll: log when anything scroll-related changes
    if logging_active and subphase == 2 and phase == 1 and gameMode == 0 then
        frame_in_sub2 = frame_in_sub2 + 1

        local changed = (curVScroll ~= prev_curV) or
                        (ppuScrlY ~= prev_scrlY) or
                        (ntToggle ~= prev_nt) or
                        (ppuCtrl ~= prev_ctrl)

        if changed then
            -- Compute VSRAM the way acs_check_sub2 does: PPU_SCRL_Y + 8 + NT
            local vsram = ppuScrlY + 8
            local ctrl = ppuCtrl
            if ntToggle ~= 0 then
                ctrl = ctrl ~ 0x02
            end
            if (ctrl & 0x02) ~= 0 then
                vsram = vsram + 240
            end
            if vsram >= 480 then
                vsram = vsram - 480
            end

            -- Also compute what CurVScroll would give
            local vsram_curv = curVScroll + 8
            if ntToggle ~= 0 then
                local c2 = ppuCtrl ~ 0x02
                if (c2 & 0x02) ~= 0 then
                    vsram_curv = vsram_curv + 240
                end
            else
                if (ppuCtrl & 0x02) ~= 0 then
                    vsram_curv = vsram_curv + 240
                end
            end
            if vsram_curv >= 480 then
                vsram_curv = vsram_curv - 480
            end

            console.log(string.format(
                "  F%d [+%d] NESfc:%02X CurV:%02X ScrlY:%02X NT:%02X CTRL:%02X Wraps:%02X  VSRAM(scrl)=%d VSRAM(curv)=%d %s",
                fc, frame_in_sub2, frameCount,
                curVScroll, ppuScrlY, ntToggle, ppuCtrl, demoWraps,
                vsram, vsram_curv,
                (curVScroll ~= ppuScrlY) and "<<DIVERGE>>" or ""))

            prev_curV = curVScroll
            prev_scrlY = ppuScrlY
            prev_nt = ntToggle
            prev_ctrl = ppuCtrl
        end

        -- Stop logging after the item roll ends (subphase changes)
    elseif logging_active and subphase ~= 2 then
        logging_active = false
        console.log(string.format("  >>> ITEM ROLL END at F%d <<<", fc))
    end

    prev_subphase = subphase

    -- HUD overlay
    local y = 10
    gui.text(10, y, string.format("Mode:%02X Ph:%02X Sub:%02X F:%d",
        gameMode, phase, subphase, fc), "white", "black")
    y = y + 16
    gui.text(10, y, string.format("CurV:%02X  ScrlY:%02X  NESfc:%02X",
        curVScroll, ppuScrlY, frameCount), "yellow", "black")
    y = y + 16
    gui.text(10, y, string.format("NT:%02X  CTRL:%02X  Wraps:%02X",
        ntToggle, ppuCtrl, demoWraps), "cyan", "black")

    if logging_active then
        y = y + 16
        gui.text(10, y, string.format("ITEM ROLL +%d frames", frame_in_sub2),
            "lime", "black")
    end

    emu.frameadvance()
end
