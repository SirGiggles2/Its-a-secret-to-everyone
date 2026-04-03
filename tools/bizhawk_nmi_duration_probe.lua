-- bizhawk_nmi_duration_probe.lua
-- Measures per-NMI duration in frames and logs PC samples

local ROOT = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/"
local REPORT = ROOT .. "builds/reports/bizhawk_nmi_duration_probe.txt"
local M68K = "M68K BUS"
local FRAMES_TO_RUN = 300

-- Auto-discover IsrNmi from probe_addresses.lua
dofile(ROOT .. "tools/probe_addresses.lua")
local ADDR_ISR_NMI = ISRNMI

local lines = {}
local function log(s) lines[#lines+1] = s end

log("=================================================================")
log("NMI Duration Probe — " .. FRAMES_TO_RUN .. " frames")
log(string.format("  IsrNmi=$%06X", ADDR_ISR_NMI))
log("=================================================================")

local nmi_count = 0
local frame_count = 0
local nmi_start_frame = 0
local nmi_pc_samples = {}

-- Hook IsrNmi entry
local function on_isrnmi()
    -- Close previous NMI
    if nmi_count > 0 then
        local duration = frame_count - nmi_start_frame
        local pcs = {}
        for _, s in ipairs(nmi_pc_samples) do pcs[#pcs+1] = s end
        log(string.format("  NMI #%d: frame %d-%d (%d frames)  PCs: %s",
            nmi_count, nmi_start_frame, frame_count - 1, duration,
            table.concat(pcs, ", ")))
    end
    nmi_count = nmi_count + 1
    nmi_start_frame = frame_count
    nmi_pc_samples = {}
end

event.onmemoryexecute(on_isrnmi, ADDR_ISR_NMI, "nmi_hook", M68K)

-- Sample PC every frame
local function on_frame()
    frame_count = frame_count + 1

    -- Sample PC at each frame
    if nmi_count > 0 and #nmi_pc_samples < 20 then
        local pc = emu.getregister("M68K PC")
        nmi_pc_samples[#nmi_pc_samples+1] = string.format("$%06X@f%d", pc, frame_count)
    end

    if frame_count >= FRAMES_TO_RUN then
        -- Close last NMI
        if nmi_count > 0 then
            local duration = frame_count - nmi_start_frame
            local pcs = {}
            for _, s in ipairs(nmi_pc_samples) do pcs[#pcs+1] = s end
            log(string.format("  NMI #%d: frame %d-%d (%d frames)  PCs: %s",
                nmi_count, nmi_start_frame, frame_count, duration,
                table.concat(pcs, ", ")))
        end

        log("")
        log(string.format("Total NMIs: %d in %d frames", nmi_count, frame_count))

        local fh = io.open(REPORT, "w")
        for _, line in ipairs(lines) do fh:write(line .. "\n") end
        fh:close()
        print("NMI duration probe written to: " .. REPORT)
        client.exit()
    end
end

event.onframeend(on_frame)

while true do emu.frameadvance() end
