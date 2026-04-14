-- bizhawk_t28_title_input_probe.lua
-- T28 story-soak profile (no forced mode writes, no "input faster" workaround).
--
-- Goal for this phase: stress the title/story scroll path with no Start presses
-- and detect crash/hang behavior with rich telemetry.
--
-- Captures:
--   GameMode/GameSubmode
--   DemoPhase/DemoSubphase
--   DemoTimer/TileBufSelector
--   Scroll state (CurVScroll/CurHScroll/VScrollStartFrame/ScrolledLineCount)
--   Exception PC/vector hits

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

dofile(repo_path("tools\\probe_addresses.lua"))

local OUT_DIR = repo_path("builds\\reports")
local OUT_TXT = repo_path("builds\\reports\\bizhawk_t28_title_input_probe.txt")

os.execute('if not exist "' .. OUT_DIR .. '" mkdir "' .. OUT_DIR .. '"')

local function try_read(domain, addr, width)
    local ok, value = pcall(function()
        memory.usememorydomain(domain)
        if width == 1 then
            return memory.read_u8(addr)
        end
        if width == 2 then
            return memory.read_u16_be(addr)
        end
        return memory.read_u32_be(addr)
    end)
    if ok then
        return value
    end
    return nil
end

local function ram_u8(bus_addr)
    local ofs = bus_addr - 0xFF0000
    local domains = {
        {"68K RAM", ofs},
        {"M68K BUS", bus_addr},
        {"System Bus", bus_addr},
        {"Main RAM", ofs},
    }
    for _, spec in ipairs(domains) do
        local v = try_read(spec[1], spec[2], 1)
        if v ~= nil then
            return v
        end
    end
    return 0
end

local function record(lines, text)
    lines[#lines + 1] = text
    print(text)
end

local lines = {}
local mode_changes = {}
local phase_changes = {}

local MAX_FRAMES = 3200
local LOG_PERIOD = 60
local STALL_LIMIT = 180

local exception_hit = false
local exception_name = ""
local exception_frame = -1

local saw_demo_phase1 = false
local saw_story_scroll = false
local max_vscroll = 0
local max_scrolled_lines = 0

local nmi_start = 0
local nmi_end = 0
local ci_start = 0
local ci_end = 0
local nmi_stall_hit = false
local ci_stall_hit = false
local nmi_stall_frame = -1
local ci_stall_frame = -1

local last_mode = nil
local last_sub = nil
local last_demo_phase = nil
local last_demo_sub = nil
local last_nmi = nil
local last_ci = nil
local nmi_stall_len = 0
local ci_stall_len = 0

record(lines, "=================================================================")
record(lines, "T28 story-soak probe (no Start press)")
record(lines, "=================================================================")
record(lines, string.format("LoopForever=$%06X  IsrNmi=$%06X", LOOPFOREVER, ISRNMI))
record(lines, string.format("frames=%d  log_period=%d  stall_limit=%d", MAX_FRAMES, LOG_PERIOD, STALL_LIMIT))
record(lines, "")

for frame = 1, MAX_FRAMES do
    emu.frameadvance()

    local mode = ram_u8(0xFF0012)
    local sub = ram_u8(0xFF0013)
    local tile_sel = ram_u8(0xFF0014)
    local demo_phase = ram_u8(0xFF042C)
    local demo_sub = ram_u8(0xFF042D)
    local demo_timer = ram_u8(0xFF041A)
    local cur_vscroll = ram_u8(0xFF00FC)
    local cur_hscroll = ram_u8(0xFF00FD)
    local vscroll_start = ram_u8(0xFF00E6)
    local scrolled_lines = ram_u8(0xFF041B)
    local nmi = ram_u8(0xFF1003)
    local ci = ram_u8(0xFF100A)
    local pc = emu.getregister("M68K PC") or 0

    if frame == 1 then
        nmi_start = nmi
        ci_start = ci
        last_nmi = nmi
        last_ci = ci
    end

    if mode ~= last_mode or sub ~= last_sub then
        mode_changes[#mode_changes + 1] = {frame = frame, mode = mode, sub = sub}
        record(lines, string.format(
            "f%04d mode=$%02X sub=$%02X tileSel=$%02X vscroll=%3d hscroll=%3d vStart=%3d lines=%3d",
            frame, mode, sub, tile_sel, cur_vscroll, cur_hscroll, vscroll_start, scrolled_lines
        ))
        last_mode = mode
        last_sub = sub
    end

    if demo_phase ~= last_demo_phase or demo_sub ~= last_demo_sub then
        phase_changes[#phase_changes + 1] = {
            frame = frame,
            phase = demo_phase,
            sub = demo_sub,
            timer = demo_timer,
            tile_sel = tile_sel,
        }
        record(lines, string.format(
            "f%04d demoPhase=$%02X demoSub=$%02X demoTimer=$%02X tileSel=$%02X",
            frame, demo_phase, demo_sub, demo_timer, tile_sel
        ))
        last_demo_phase = demo_phase
        last_demo_sub = demo_sub
    end

    if demo_phase >= 0x01 then
        saw_demo_phase1 = true
    end

    if cur_vscroll > max_vscroll then
        max_vscroll = cur_vscroll
    end
    if scrolled_lines > max_scrolled_lines then
        max_scrolled_lines = scrolled_lines
    end
    if cur_vscroll ~= 0 or scrolled_lines ~= 0 then
        saw_story_scroll = true
    end

    if nmi == last_nmi then
        nmi_stall_len = nmi_stall_len + 1
        if not nmi_stall_hit and nmi_stall_len >= STALL_LIMIT then
            nmi_stall_hit = true
            nmi_stall_frame = frame
            record(lines, string.format("f%04d NMI stall detected (%d frames unchanged)", frame, nmi_stall_len))
        end
    else
        nmi_stall_len = 0
    end
    last_nmi = nmi

    if ci == last_ci then
        ci_stall_len = ci_stall_len + 1
        if not ci_stall_hit and ci_stall_len >= STALL_LIMIT then
            ci_stall_hit = true
            ci_stall_frame = frame
            record(lines, string.format("f%04d CheckInput stall detected (%d frames unchanged)", frame, ci_stall_len))
        end
    else
        ci_stall_len = 0
    end
    last_ci = ci

    if not exception_hit and (pc == EXC_BUS or pc == EXC_ADDR or pc == EXC_DEF) then
        exception_hit = true
        exception_frame = frame
        if pc == EXC_BUS then
            exception_name = "ExcBusError"
        elseif pc == EXC_ADDR then
            exception_name = "ExcAddrError"
        else
            exception_name = "DefaultException"
        end
        record(lines, string.format("f%04d EXCEPTION %s PC=$%06X", frame, exception_name, pc))
        break
    end

    if frame % LOG_PERIOD == 0 then
        record(lines, string.format(
            "f%04d telemetry mode=$%02X/$%02X demo=$%02X/$%02X timer=$%02X tileSel=$%02X v=%3d h=%3d lines=%3d nmi=%3d ci=%3d",
            frame, mode, sub, demo_phase, demo_sub, demo_timer, tile_sel, cur_vscroll, cur_hscroll, scrolled_lines, nmi, ci
        ))
    end
end

nmi_end = ram_u8(0xFF1003)
ci_end = ram_u8(0xFF100A)

local function verdict(name, ok, detail)
    record(lines, string.format("[%s] %-30s %s", ok and "PASS" or "FAIL", name, detail))
    return ok and 1 or 0
end

record(lines, "")
record(lines, "Mode changes (first 24):")
for i = 1, math.min(#mode_changes, 24) do
    local m = mode_changes[i]
    record(lines, string.format("  f%04d mode=$%02X sub=$%02X", m.frame, m.mode, m.sub))
end

record(lines, "")
record(lines, "Demo phase changes (first 24):")
for i = 1, math.min(#phase_changes, 24) do
    local p = phase_changes[i]
    record(lines, string.format("  f%04d phase=$%02X sub=$%02X timer=$%02X tileSel=$%02X", p.frame, p.phase, p.sub, p.timer, p.tile_sel))
end

record(lines, "")
record(lines, string.format("NMI delta: %d", (nmi_end - nmi_start) % 0x100))
record(lines, string.format("CheckInput delta: %d", (ci_end - ci_start) % 0x100))
record(lines, string.format("max_vscroll: %d  max_scrolled_lines: %d", max_vscroll, max_scrolled_lines))
record(lines, "")

local pass = 0
local total = 0

total = total + 1
pass = pass + verdict("T28_NO_EXCEPTION", not exception_hit,
    exception_hit and (exception_name .. " at frame " .. tostring(exception_frame)) or "no exception")

total = total + 1
pass = pass + verdict("T28_NMI_CONTINUOUS", not nmi_stall_hit,
    nmi_stall_hit and ("stalled at frame " .. tostring(nmi_stall_frame)) or "no long NMI stall")

total = total + 1
pass = pass + verdict("T28_CHECKINPUT_CONTINUOUS", not ci_stall_hit,
    ci_stall_hit and ("stalled at frame " .. tostring(ci_stall_frame)) or "no long CheckInput stall")

total = total + 1
pass = pass + verdict("T28_DEMOPHASE_ADVANCE", saw_demo_phase1,
    saw_demo_phase1 and "reached demo phase >= 1" or "never reached demo phase 1")

total = total + 1
pass = pass + verdict("T28_STORY_SCROLL_ACTIVITY", saw_story_scroll,
    saw_story_scroll and "vscroll/scrolled-line activity observed" or "no story-scroll activity observed")

record(lines, "")
record(lines, string.format("T28 STORY-SOAK SUMMARY: %d PASS / %d FAIL", pass, total - pass))
record(lines, (pass == total) and "T28 STORY-SOAK: ALL PASS" or "T28 STORY-SOAK: FAIL")

local out = assert(io.open(OUT_TXT, "w"))
out:write(table.concat(lines, "\n"))
out:write("\n")
out:close()
client.exit()
