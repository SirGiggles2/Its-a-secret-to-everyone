-- bizhawk_t29_file_select_probe.lua
-- T29: title -> file-select transition + frontend readiness (natural flow).
--
-- This probe does not force GameMode/Submode values.
-- It injects Start with hold/release cadence and validates:
--   - no exception
--   - continuous NMI/input loop
--   - transition away from title mode
--   - file-select operational mode observed (Mode $01 or Mode $0E/$0F)
--   - frontend visual readiness (Plane A + CRAM non-zero)

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
local OUT_TXT = repo_path("builds\\reports\\bizhawk_t29_file_select_probe.txt")

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

local function vram_u16(addr)
    local ok, v = pcall(function()
        memory.usememorydomain("VRAM")
        return memory.read_u16_be(addr)
    end)
    return ok and v or 0
end

local function cram_u16(addr)
    local ok, v = pcall(function()
        memory.usememorydomain("CRAM")
        return memory.read_u16_be(addr)
    end)
    return ok and v or 0
end

local function safe_set(pad)
    local ok = pcall(function()
        joypad.set(pad or {}, 1)
    end)
    if not ok then
        joypad.set(pad or {})
    end
end

local function record(lines, text)
    lines[#lines + 1] = text
    print(text)
end

local function build_start_pad()
    return {
        ["Start"] = true,
        ["P1 Start"] = true,
    }
end

local lines = {}
local mode_changes = {}

local MAX_FRAMES = 1200
local START_FROM = 90
local START_TO = 260
local START_HOLD = 2
local START_RELEASE = 4

local hold_left = 0
local release_left = 0
local start_pulses = 0

local exception_hit = false
local exception_name = ""
local exception_frame = -1

local nmi_start = 0
local nmi_end = 0
local ci_start = 0
local ci_end = 0

local saw_mode1 = false
local saw_mode0e_or_0f = false
local first_mode_nonzero = nil

local last_mode = nil
local last_sub = nil

record(lines, "=================================================================")
record(lines, "T29 file-select probe (natural title->frontend flow)")
record(lines, "=================================================================")
record(lines, string.format("LoopForever=$%06X  IsrNmi=$%06X", LOOPFOREVER, ISRNMI))
record(lines, string.format("Start pulse window: f%04d..f%04d  hold=%d release=%d", START_FROM, START_TO, START_HOLD, START_RELEASE))
record(lines, "")

for frame = 1, MAX_FRAMES do
    local mode = ram_u8(0xFF0012)
    local sub = ram_u8(0xFF0013)
    local nmi = ram_u8(0xFF1003)
    local ci = ram_u8(0xFF100A)

    if frame == 1 then
        nmi_start = nmi
        ci_start = ci
    end

    if mode ~= last_mode or sub ~= last_sub then
        mode_changes[#mode_changes + 1] = {frame = frame, mode = mode, sub = sub}
        record(lines, string.format("f%04d mode=$%02X sub=$%02X", frame, mode, sub))
        last_mode = mode
        last_sub = sub
    end

    if mode == 0x01 then
        saw_mode1 = true
    end
    if mode == 0x0E or mode == 0x0F then
        saw_mode0e_or_0f = true
    end
    if mode ~= 0x00 and not first_mode_nonzero then
        first_mode_nonzero = mode
    end

    if frame >= START_FROM and frame <= START_TO then
        if hold_left == 0 and release_left == 0 then
            hold_left = START_HOLD
            release_left = START_RELEASE
            start_pulses = start_pulses + 1
            record(lines, string.format("f%04d input Start pulse #%d", frame, start_pulses))
        end
    end

    local pad = {}
    if hold_left > 0 then
        pad = build_start_pad()
        hold_left = hold_left - 1
    elseif release_left > 0 then
        release_left = release_left - 1
    end
    safe_set(pad)

    emu.frameadvance()

    local pc = emu.getregister("M68K PC") or 0
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
end

nmi_end = ram_u8(0xFF1003)
ci_end = ram_u8(0xFF100A)

local final_mode = ram_u8(0xFF0012)

local nt_nonzero = 0
for i = 0, 63 do
    local word = vram_u16(0xC000 + i * 2)
    if word ~= 0 then
        nt_nonzero = nt_nonzero + 1
    end
end

local cram_nonzero = 0
for i = 0, 63 do
    if cram_u16(i * 2) ~= 0 then
        cram_nonzero = cram_nonzero + 1
    end
end

local function verdict(name, ok, detail)
    record(lines, string.format("[%s] %-30s %s", ok and "PASS" or "FAIL", name, detail))
    return ok and 1 or 0
end

record(lines, "")
record(lines, "Mode transitions (first 24):")
for i = 1, math.min(#mode_changes, 24) do
    local m = mode_changes[i]
    record(lines, string.format("  f%04d mode=$%02X sub=$%02X", m.frame, m.mode, m.sub))
end

record(lines, "")
record(lines, string.format("final_mode=$%02X first_nonzero_mode=%s", final_mode, first_mode_nonzero and string.format("$%02X", first_mode_nonzero) or "none"))
record(lines, string.format("start_pulses=%d  nmi_delta=%d  checkinput_delta=%d", start_pulses, (nmi_end - nmi_start) % 0x100, (ci_end - ci_start) % 0x100))
record(lines, string.format("nt_nonzero(first64)=%d  cram_nonzero(64)=%d", nt_nonzero, cram_nonzero))
record(lines, "")

local pass = 0
local total = 0

total = total + 1
pass = pass + verdict("T29_NO_EXCEPTION", not exception_hit,
    exception_hit and (exception_name .. " at frame " .. tostring(exception_frame)) or "no exception")

total = total + 1
pass = pass + verdict("T29_NMI_CONTINUOUS", ((nmi_end - nmi_start) % 0x100) >= 100,
    string.format("delta=%d", (nmi_end - nmi_start) % 0x100))

total = total + 1
pass = pass + verdict("T29_CHECKINPUT_CONTINUOUS", ((ci_end - ci_start) % 0x100) >= 100,
    string.format("delta=%d", (ci_end - ci_start) % 0x100))

total = total + 1
pass = pass + verdict("T29_MODE_TRANSITION", first_mode_nonzero ~= nil,
    first_mode_nonzero and ("left title mode, first non-zero mode " .. string.format("$%02X", first_mode_nonzero)) or "mode remained $00")

total = total + 1
pass = pass + verdict("T29_FILESELECT_MODE_OBSERVED", saw_mode1 or saw_mode0e_or_0f,
    (saw_mode1 and "Mode $01 observed") or (saw_mode0e_or_0f and "Mode $0E/$0F observed") or "no file-select mode observed")

total = total + 1
pass = pass + verdict("T29_NT_POPULATED", nt_nonzero >= 4,
    string.format("%d/64 non-zero tile words", nt_nonzero))

total = total + 1
pass = pass + verdict("T29_CRAM_POPULATED", cram_nonzero >= 4,
    string.format("%d/64 non-zero CRAM words", cram_nonzero))

record(lines, "")
record(lines, string.format("T29 FILE-SELECT SUMMARY: %d PASS / %d FAIL", pass, total - pass))
record(lines, (pass == total) and "T29 FILE-SELECT: ALL PASS" or "T29 FILE-SELECT: FAIL")

local out = assert(io.open(OUT_TXT, "w"))
out:write(table.concat(lines, "\n"))
out:write("\n")
out:close()
client.exit()
