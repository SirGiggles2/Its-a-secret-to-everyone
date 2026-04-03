-- bizhawk_subphase_timing_probe.lua
-- Reads TileBufSelector ($FF0014), subphase ($FF042D), DynTileBuf[0] ($FF0302)
-- at each frame to verify one subphase advance per NMI and correct palette timing.
-- Runs for 200 frames.

local ROOT   = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/"
local REPORT = ROOT .. "builds/reports/bizhawk_subphase_timing_probe.txt"

local lines = {}
local function log(s) lines[#lines+1] = s print(s) end

local frame_count = 0
local CAPTURE_END = 200

local function bus_read(addr)
    local ok, v = pcall(function()
        memory.usememorydomain("M68K BUS")
        return memory.read_u8(addr)
    end)
    return ok and v or 0
end

log("=================================================================")
log("Subphase Timing Probe -- 200 frames")
log("  TileBufSelector=$FF0014  Subphase=$FF042D  DynBuf[0]=$FF0302")
log("=================================================================")
log("")

local prev_subphase = nil
local prev_selector = nil
local prev_dynbuf0  = nil
local subphase_changes = 0
local double_advances = 0

local function on_frame()
    frame_count = frame_count + 1
    if frame_count > CAPTURE_END then
        log("")
        log("=== SUMMARY ===")
        log(string.format("Subphase changes: %d in %d frames", subphase_changes, CAPTURE_END))
        log(string.format("Double-advance frames (>1 subphase step): %d", double_advances))
        log("")
        log("=================================================================")
        log("SUBPHASE TIMING PROBE COMPLETE")
        log("=================================================================")

        local f = io.open(REPORT, "w")
        if f then
            f:write(table.concat(lines, "\n") .. "\n")
            f:close()
            print("Report written to: " .. REPORT)
        end
        client.pause()
        return
    end

    local selector = bus_read(0xFF0014)
    local subphase = bus_read(0xFF042D)
    local dynbuf0  = bus_read(0xFF0302)

    -- Detect changes
    local changed = false
    if selector ~= prev_selector or subphase ~= prev_subphase or dynbuf0 ~= prev_dynbuf0 then
        changed = true
    end

    -- Log every frame for first 50 frames, then only changes
    if frame_count <= 50 or changed then
        local flag = ""
        if dynbuf0 == 0x3F then
            flag = " *** PALETTE PENDING"
        end
        if prev_subphase and subphase ~= prev_subphase then
            local delta = subphase - prev_subphase
            if delta < 0 then delta = delta + 256 end
            if delta > 1 and delta < 128 then
                double_advances = double_advances + 1
                flag = flag .. string.format(" *** DOUBLE-ADVANCE (+%d)", delta)
            end
            subphase_changes = subphase_changes + 1
        end

        log(string.format("f%03d: sel=$%02X sub=$%02X dyn[0]=$%02X%s",
            frame_count, selector, subphase, dynbuf0, flag))
    end

    prev_selector = selector
    prev_subphase = subphase
    prev_dynbuf0  = dynbuf0
end

event.onframeend(on_frame)
