-- bizhawk_perf_sample.lua
-- Phase 0 perf harness: sample per-frame cycle count + wall time during the
-- T34 scripted input scenario. Output: builds/reports/perf_sample.json.
-- Pairs with tools/compare_perf.py for regression detection.
--
-- Two metrics per frame:
--   cycles_delta — emu.totalexecutedcycles() delta (if core exposes it)
--   wall_ms      — os.clock() delta * 1000 (emulator-step wall time)
--
-- Deterministic workload: T34 movement scenario (361 frames of scripted D-pad
-- input through room $77). Same capture gate as bizhawk_t34_movement_gen_capture
-- so perf samples are aligned with parity baseline.

dofile((function()
    local env_root = os.getenv("CODEX_BIZHAWK_ROOT")
    if env_root and env_root ~= "" then
        env_root = env_root:gsub("/", "\\")
        return env_root .. "\\tools\\probe_root.lua"
    end
    local source = debug.getinfo(1, "S").source
    if source:sub(1, 1) == "@" then
        source = source:sub(2)
    end
    source = source:gsub("/", "\\")
    local tools_dir = source:match("^(.*)\\[^\\]+$")
    if not tools_dir then
        error("unable to resolve tools directory from '" .. source .. "'")
    end
    return tools_dir .. "\\probe_root.lua"
end)())

local SCENARIO = dofile(repo_path("tools\\t34_input_scenario.lua"))

local OUT_TXT  = repo_path("builds\\reports\\perf_sample.txt")
local OUT_JSON = repo_path("builds\\reports\\perf_sample.json")

-- Flow states (mirrors T34 gen capture)
local FLOW_BOOT_TO_FS1     = "BOOT_TO_FS1"
local FLOW_FS1_START_GAME  = "FS1_START_GAME"
local FLOW_WAIT_GAMEPLAY   = "WAIT_GAMEPLAY"
local FLOW_T34_STABILIZE   = "T34_STABILIZE"
local FLOW_T34_SAMPLING    = "T34_SAMPLING"
local FLOW_DONE            = "DONE"

local MAX_FRAMES = 7000
local MODE0_BOOT_TIMEOUT = 1200
local LINK_STABLE_FRAMES = 60
local TARGET_ROOM_ID = 0x77

-- NES-mirror bus addresses (A4 = $FF0000)
local BUS = 0xFF0000
local A_MODE     = BUS + 0x0012
local A_OBJ_X    = BUS + 0x0070
local A_OBJ_Y    = BUS + 0x0084
local A_ROOM_ID  = BUS + 0x00EB
local A_HELD     = BUS + 0x00F8

-- Memory domain discovery
local AVAILABLE_DOMAINS = {}
do
    local ok, domains = pcall(memory.getmemorydomainlist)
    if ok and type(domains) == "table" then
        for _, n in ipairs(domains) do AVAILABLE_DOMAINS[n] = true end
    end
end

local function domain_ok(n) return AVAILABLE_DOMAINS[n] == true end

local RAM_DOMAIN = (domain_ok("68K RAM") and "68K RAM")
    or (domain_ok("Main RAM") and "Main RAM")
    or nil

local function ram_u8(bus_addr)
    local ofs = bus_addr - 0xFF0000
    if RAM_DOMAIN then
        local ok, v = pcall(function()
            memory.usememorydomain(RAM_DOMAIN)
            return memory.read_u8(ofs)
        end)
        if ok then return v end
    end
    if domain_ok("M68K BUS") then
        local even_addr = bus_addr - (bus_addr % 2)
        local ok, w = pcall(function()
            memory.usememorydomain("M68K BUS")
            return memory.read_u16_be(even_addr)
        end)
        if ok then
            if (bus_addr % 2) == 0 then return math.floor(w / 256) % 256 end
            return w % 256
        end
    end
    return 0
end

-- Cycle counter: try emu.totalexecutedcycles(), fall back to 0 if unsupported
local CYCLE_API_AVAILABLE = false
do
    local ok, _ = pcall(function() return emu.totalexecutedcycles() end)
    CYCLE_API_AVAILABLE = ok
end

local function read_cycles()
    if not CYCLE_API_AVAILABLE then return 0 end
    local ok, v = pcall(function() return emu.totalexecutedcycles() end)
    if ok and type(v) == "number" then return v end
    return 0
end

local function safe_set(pad)
    local ok = pcall(function() joypad.set(pad or {}, 1) end)
    if not ok then joypad.set(pad or {}) end
end

-- Wipe SRAM so no saved game auto-boots
do
    local needs_reboot = false
    for _, dn in ipairs({"SRAM", "Cart (Save) RAM", "Save RAM"}) do
        if domain_ok(dn) then
            pcall(function()
                memory.usememorydomain(dn)
                for i = 0, 0x1FFF do
                    if memory.read_u8(i) ~= 0 then
                        needs_reboot = true
                        break
                    end
                end
                if needs_reboot then
                    for i = 0, 0x1FFF do
                        memory.write_u8(i, 0)
                    end
                end
            end)
        end
    end
    if needs_reboot then client.reboot_core() end
end

-- State machine: boot → filesel → gameplay → stabilize → sample
local flow = FLOW_BOOT_TO_FS1
local frame = 0
local boot_mode_ok_frame = nil
local stable_frames = 0
local prev_link_x = nil
local prev_link_y = nil
local sampling_t = 0
local phase_name = "bootup"

-- Sample buffer
local samples = {}
local prev_cycles = read_cycles()
local prev_wall = os.clock()

-- Boot flow: press Start at filesel, pick register, skip name entry if possible
local input_plan_hold = 0
local input_plan_button = nil
local input_plan_release = 0

local function plan_input(button, hold, release)
    input_plan_button = button
    input_plan_hold = hold or 1
    input_plan_release = release or 8
end

local function build_pad()
    local pad = {}
    if input_plan_hold > 0 and input_plan_button then
        pad["P1 " .. input_plan_button] = true
        input_plan_hold = input_plan_hold - 1
    elseif input_plan_release > 0 then
        input_plan_release = input_plan_release - 1
    end
    return pad
end

-- Main loop
while frame < MAX_FRAMES and flow ~= FLOW_DONE do
    local mode = ram_u8(A_MODE)
    local room = ram_u8(A_ROOM_ID)
    local link_x = ram_u8(A_OBJ_X)
    local link_y = ram_u8(A_OBJ_Y)

    local pad

    if flow == FLOW_BOOT_TO_FS1 then
        -- Wait for Mode != 0 (past boot), then advance by pressing Start
        if mode ~= 0 then
            boot_mode_ok_frame = frame
            flow = FLOW_FS1_START_GAME
            plan_input("Start", 4, 20)
        elseif frame > MODE0_BOOT_TIMEOUT then
            -- Force Start to break past title
            plan_input("Start", 4, 20)
        end
        pad = build_pad()
    elseif flow == FLOW_FS1_START_GAME then
        -- Press Start multiple times to accept defaults
        if input_plan_hold == 0 and input_plan_release == 0 then
            if mode == 5 then
                flow = FLOW_WAIT_GAMEPLAY
            else
                plan_input("Start", 4, 30)
            end
        end
        pad = build_pad()
    elseif flow == FLOW_WAIT_GAMEPLAY then
        if mode == 5 and room == TARGET_ROOM_ID then
            flow = FLOW_T34_STABILIZE
            stable_frames = 0
        end
        pad = {}
    elseif flow == FLOW_T34_STABILIZE then
        if prev_link_x == link_x and prev_link_y == link_y then
            stable_frames = stable_frames + 1
        else
            stable_frames = 0
        end
        prev_link_x = link_x
        prev_link_y = link_y
        if stable_frames >= LINK_STABLE_FRAMES then
            flow = FLOW_T34_SAMPLING
            sampling_t = 0
            prev_cycles = read_cycles()
            prev_wall = os.clock()
        end
        pad = {}
    elseif flow == FLOW_T34_SAMPLING then
        pad = SCENARIO.get_input_for_relative_frame(sampling_t)
        local p = SCENARIO.phase_for_relative_frame(sampling_t)
        phase_name = p and p.name or "?"
    end

    safe_set(pad)
    emu.frameadvance()
    frame = frame + 1

    if flow == FLOW_T34_SAMPLING then
        local cur_cycles = read_cycles()
        local cur_wall = os.clock()
        samples[#samples + 1] = {
            t = sampling_t,
            phase = phase_name,
            cycles_delta = cur_cycles - prev_cycles,
            wall_ms = (cur_wall - prev_wall) * 1000.0,
        }
        prev_cycles = cur_cycles
        prev_wall = cur_wall
        sampling_t = sampling_t + 1
        if sampling_t >= SCENARIO.SCENARIO_LENGTH then
            flow = FLOW_DONE
        end
    end
end

-- JSON escape
local function json_escape(s)
    s = s:gsub("\\", "\\\\")
    s = s:gsub('"', '\\"')
    return s
end

-- Compute summary stats
local function stats_of(field)
    local total = 0
    local n = #samples
    if n == 0 then return 0, 0, 0 end
    local sorted = {}
    for i = 1, n do
        sorted[i] = samples[i][field]
        total = total + samples[i][field]
    end
    table.sort(sorted)
    local p99_idx = math.max(1, math.floor(n * 0.99))
    return total / n, sorted[p99_idx], total
end

local c_mean, c_p99, c_total = stats_of("cycles_delta")
local w_mean, w_p99, w_total = stats_of("wall_ms")

-- Write text summary
do
    local fh = assert(io.open(OUT_TXT, "w"))
    fh:write("perf_sample_version=1\n")
    fh:write("scenario=T34_movement\n")
    fh:write(string.format("scenario_length=%d\n", SCENARIO.SCENARIO_LENGTH))
    fh:write(string.format("samples_collected=%d\n", #samples))
    fh:write(string.format("cycle_api_available=%s\n", tostring(CYCLE_API_AVAILABLE)))
    fh:write(string.format("cycles_delta_mean=%.2f\n", c_mean))
    fh:write(string.format("cycles_delta_p99=%d\n", c_p99 or 0))
    fh:write(string.format("cycles_delta_total=%d\n", c_total or 0))
    fh:write(string.format("wall_ms_mean=%.4f\n", w_mean))
    fh:write(string.format("wall_ms_p99=%.4f\n", w_p99 or 0))
    fh:write(string.format("wall_ms_total=%.4f\n", w_total or 0))
    fh:write(string.format("final_flow=%s\n", flow))
    fh:write(string.format("final_frame=%d\n", frame))
    fh:close()
end

-- Write JSON
do
    local fh = assert(io.open(OUT_JSON, "w"))
    fh:write("{\n")
    fh:write('  "perf_sample_version": 1,\n')
    fh:write('  "scenario": "T34_movement",\n')
    fh:write(string.format('  "scenario_length": %d,\n', SCENARIO.SCENARIO_LENGTH))
    fh:write(string.format('  "samples_collected": %d,\n', #samples))
    fh:write(string.format('  "cycle_api_available": %s,\n', tostring(CYCLE_API_AVAILABLE)))
    fh:write(string.format('  "cycles_delta_mean": %.4f,\n', c_mean))
    fh:write(string.format('  "cycles_delta_p99": %d,\n', c_p99 or 0))
    fh:write(string.format('  "cycles_delta_total": %d,\n', c_total or 0))
    fh:write(string.format('  "wall_ms_mean": %.6f,\n', w_mean))
    fh:write(string.format('  "wall_ms_p99": %.6f,\n', w_p99 or 0))
    fh:write(string.format('  "wall_ms_total": %.6f,\n', w_total or 0))
    fh:write(string.format('  "final_flow": "%s",\n', json_escape(flow)))
    fh:write(string.format('  "final_frame": %d,\n', frame))
    fh:write('  "samples": [\n')
    for i, s in ipairs(samples) do
        local sep = (i < #samples) and "," or ""
        fh:write(string.format(
            '    {"t":%d,"phase":"%s","cycles_delta":%d,"wall_ms":%.4f}%s\n',
            s.t, json_escape(s.phase), s.cycles_delta, s.wall_ms, sep
        ))
    end
    fh:write("  ]\n")
    fh:write("}\n")
    fh:close()
end

print(string.format("perf_sample: wrote %d samples, final_flow=%s", #samples, flow))
client.exit()
