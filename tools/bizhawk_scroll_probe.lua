-- bizhawk_scroll_probe.lua
-- Tracks scroll RAM state, triggers detailed capture when subphase hits $02

local REPORT_DIR = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\builds\\reports"
local REPORT = REPORT_DIR .. "\\scroll_probe.txt"

local lines = {}
local captured = false
local prev_subphase = 0
local frame = 0
local capture_frames = 0
local MAX_CAPTURE = 120  -- capture 120 frames after transition

local function log(s)
    lines[#lines+1] = s
end

local function read_ram()
    local curVScroll   = memory.read_u8(0xFF00FC, "M68K Bus")
    local ntToggle     = memory.read_u8(0xFF005C, "M68K Bus")
    local ppuCtrl      = memory.read_u8(0xFF00FF, "M68K Bus")
    local ppuScrlY     = memory.read_u8(0xFF0807, "M68K Bus")
    local demoNTWraps  = memory.read_u8(0xFF0415, "M68K Bus")
    local subphase     = memory.read_u8(0xFF042D, "M68K Bus")
    return curVScroll, ntToggle, ppuCtrl, ppuScrlY, demoNTWraps, subphase
end

local function fmt(f, cv, nt, ctrl, scrlY, wraps, sub)
    local ntBit = bit.band(bit.rshift(ctrl, 1), 1)
    if nt ~= 0 then ntBit = bit.bxor(ntBit, 1) end
    local vsram_simple = cv + 8 + (ntBit * 240)
    if vsram_simple >= 480 then vsram_simple = vsram_simple - 480 end
    local vsram_scrlY = scrlY + 8 + (ntBit * 240)
    if vsram_scrlY >= 480 then vsram_scrlY = vsram_scrlY - 480 end
    return string.format(
        "F%05d  sub=%02X  curV=%3d  scrlY=%3d  ntTog=%d  ctrl=%02X  ntBit=%d  wraps=%d  vsram(curV)=%3d  vsram(scrlY)=%3d",
        f, sub, cv, scrlY, nt, ctrl, ntBit, wraps, vsram_simple, vsram_scrlY)
end

log("=== Scroll Probe ===")
log("Waiting for subphase transition to $02 (item roll)...")
log("")
log(string.format("%-7s %-6s %-8s %-8s %-7s %-7s %-7s %-7s %-14s %-14s",
    "Frame", "sub", "curV", "scrlY", "ntTog", "ctrl", "ntBit", "wraps", "vsram(curV)", "vsram(scrlY)"))
log(string.rep("-", 110))

while true do
    frame = frame + 1
    local cv, nt, ctrl, scrlY, wraps, sub = read_ram()

    -- Log every frame while subphase is 0 or 2 (story/item phases)
    if sub == 0x00 or sub == 0x02 then
        -- Only log periodically during subphase 0 (every 30 frames) to avoid spam
        if sub == 0x00 and frame % 30 == 0 then
            log(fmt(frame, cv, nt, ctrl, scrlY, wraps, sub))
        end
    end

    -- Detect transition into subphase 2
    if sub == 0x02 and prev_subphase ~= 0x02 and not captured then
        log("")
        log(">>> SUBPHASE TRANSITION TO $02 at frame " .. frame .. " <<<")
        log("")
        captured = true
        capture_frames = 0
    end

    -- Capture detailed frames after transition
    if captured and capture_frames < MAX_CAPTURE then
        log(fmt(frame, cv, nt, ctrl, scrlY, wraps, sub))
        capture_frames = capture_frames + 1

        if capture_frames == MAX_CAPTURE then
            log("")
            log(">>> Capture complete (" .. MAX_CAPTURE .. " frames). <<<")
            -- Write report
            local f = io.open(REPORT, "w")
            if f then
                f:write(table.concat(lines, "\n") .. "\n")
                f:close()
            end
            print("Scroll probe saved to: " .. REPORT)
        end
    end

    -- Also catch if subphase leaves 02 after capture
    if captured and sub ~= 0x02 and capture_frames > 0 and capture_frames < MAX_CAPTURE then
        log(fmt(frame, cv, nt, ctrl, scrlY, wraps, sub))
        log("")
        log(">>> Subphase left $02 at frame " .. frame .. " <<<")
    end

    prev_subphase = sub
    emu.frameadvance()
end
