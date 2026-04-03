-- bizhawk_vdp_reg_trace_probe.lua
-- Tracks VDP register values via CRAM/VRAM domain reads every frame.
-- Flags unexpected values for R02 (Plane A), R15 (auto-inc), R16 (scroll size).
-- Also captures the PC at which the change occurs by reading the M68K BUS.
-- Runs for 400 frames.

local ROOT   = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/"
local REPORT = ROOT .. "builds/reports/bizhawk_vdp_reg_trace_probe.txt"

local lines = {}
local function log(s) lines[#lines+1] = s print(s) end

local frame_count = 0
local CAPTURE_END = 400

-- Expected register values
local EXPECTED = {
    [2]  = 0x30,  -- Plane A @ $C000
    [15] = 0x02,  -- auto-increment = 2
    [16] = 0x01,  -- scroll size 64H x 32V
}

-- Read a VDP register from the Genesis GPGX "VDP Regs" domain
local function vdp_reg(n)
    local ok, v = pcall(function()
        memory.usememorydomain("VDP Regs")
        return memory.read_u8(n)
    end)
    return ok and v or nil
end

-- Read CRAM
local function cram_u16(addr)
    local ok, v = pcall(function()
        memory.usememorydomain("CRAM")
        return memory.read_u16_be(addr)
    end)
    return ok and v or 0
end

-- Track previous reg values to detect changes
local prev_regs = {}

-- Track CRAM pal0 for palette fix verification
local prev_cram0 = nil

log("=================================================================")
log("VDP Register Trace Probe -- 400 frames")
log("  Watching R02, R15, R16 for unexpected values")
log("  Watching CRAM[0] for palette fix verification")
log("=================================================================")
log("")

local anomaly_count = 0
local cram0_changes = {}

local function on_frame()
    frame_count = frame_count + 1
    if frame_count > CAPTURE_END then
        -- Write report
        log("")
        log("=== SUMMARY ===")
        log(string.format("Total anomalies: %d", anomaly_count))
        log("")
        log("CRAM[0] history:")
        for _, entry in ipairs(cram0_changes) do
            log(entry)
        end
        log("")

        -- Final register dump
        log("Final VDP register state:")
        for r = 0, 23 do
            local v = vdp_reg(r)
            if v then
                local flag = ""
                if EXPECTED[r] and v ~= EXPECTED[r] then
                    flag = string.format("  *** UNEXPECTED (want $%02X)", EXPECTED[r])
                end
                log(string.format("  R%02d = $%02X%s", r, v, flag))
            end
        end

        -- Final CRAM
        log("")
        log("Final CRAM:")
        for pal = 0, 3 do
            local s = string.format("  pal%d:", pal)
            for c = 0, 15 do
                s = s .. string.format(" %04X", cram_u16((pal * 16 + c) * 2))
            end
            log(s)
        end

        log("")
        log("=================================================================")
        log("VDP REGISTER TRACE COMPLETE")
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

    -- Check registers of interest
    for reg, expected in pairs(EXPECTED) do
        local val = vdp_reg(reg)
        if val and val ~= expected then
            -- Only log if this is a new anomaly (different from last frame)
            if prev_regs[reg] == nil or prev_regs[reg] ~= val then
                anomaly_count = anomaly_count + 1
                log(string.format("f%03d: R%02d = $%02X (expected $%02X) *** ANOMALY",
                    frame_count, reg, val, expected))
            end
        end
        if val then prev_regs[reg] = val end
    end

    -- Track CRAM[0]
    local c0 = cram_u16(0)
    if prev_cram0 == nil or c0 ~= prev_cram0 then
        local entry = string.format("  f%03d: CRAM[0] = $%04X", frame_count, c0)
        cram0_changes[#cram0_changes + 1] = entry
        if frame_count <= 100 then
            log(entry)
        end
        prev_cram0 = c0
    end
end

event.onframeend(on_frame)
