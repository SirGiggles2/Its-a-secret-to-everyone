-- bizhawk_t36_statewrite_bp.lua
-- Watch writes to $FF0098 (facedir), $FF00AC (objstate), $FF000F (movedir)
-- during mode $0B (cave interior). Runs Gen bootflow + T36 scenario
-- (walk_left/align/walk_up/settle/walk_down). Logs PC + value + mode.

dofile((function()
    local env_root = os.getenv("CODEX_BIZHAWK_ROOT")
    if env_root and env_root ~= "" then
        env_root = env_root:gsub("/", "\\")
        return env_root .. "\\tools\\probe_root.lua"
    end
    local source = debug.getinfo(1, "S").source
    if source:sub(1, 1) == "@" then source = source:sub(2) end
    source = source:gsub("/", "\\")
    return (source:match("^(.*)\\[^\\]+$")) .. "\\probe_root.lua"
end)())

local SCENARIO = dofile(repo_path("tools\\t36_input_scenario.lua"))
local replay_mod = dofile(repo_path("tools\\bootflow_replay.lua"))
local REPLAY = replay_mod.load(repo_path("tools\\bootflow_gen.txt"), "GEN")
if not REPLAY then error("bootflow_gen.txt missing") end

local OUT = repo_path("builds\\reports\\t36_statewrite_bp.txt")
local BUS = 0xFF0000
local TARGET_ROOM = 0x77
local LINK_STABLE = 60

local AVAILABLE = {}
do
    local ok, lst = pcall(memory.getmemorydomainlist)
    if ok and type(lst) == "table" then for _, n in ipairs(lst) do AVAILABLE[n] = true end end
end

local function ram_u8(bus_addr)
    local ofs = bus_addr - 0xFF0000
    for _, dn in ipairs({"68K RAM", "Main RAM"}) do
        if AVAILABLE[dn] then
            local ok, v = pcall(function() memory.usememorydomain(dn); return memory.read_u8(ofs) end)
            if ok then return v end
        end
    end
    return 0
end

local function safe_set(pad)
    local e = {}
    for k, v in pairs(pad or {}) do e[k] = v; if k:sub(1,3) ~= "P1 " then e["P1 "..k]=v end end
    pcall(function() joypad.set(e, 1) end)
end

-- wipe SRAM
for _, dn in ipairs({"SRAM","Cart (Save) RAM","Save RAM","Battery RAM","CartRAM"}) do
    if AVAILABLE[dn] then
        pcall(function()
            memory.usememorydomain(dn)
            local sz = memory.getmemorydomainsize(dn)
            for a=0,sz-1 do memory.writebyte(a, 0) end
        end)
    end
end

local lines = {}
local function log(s)
    lines[#lines+1] = s
    print(s)
    local f = io.open(OUT, "w")
    if f then f:write(table.concat(lines, "\n").."\n"); f:close() end
end

log("T36 state-write watcher — $FF0098 facedir, $FF00AC objstate, $FF000F movedir")

local current_frame = 0
local t0_frame = -1
local stable_prev_x, stable_prev_y = nil, nil
local stable_count = 0
local in_capture = false

local function tnow()
    if t0_frame < 0 then return -1 end
    return current_frame - t0_frame
end

-- Only log during/near cave interior to trim noise: mode in {$10,$0B,$0A}
-- OR t in walk_down window.
local function interesting()
    local m = ram_u8(BUS + 0x12)
    if m == 0x0B or m == 0x10 or m == 0x0A then return true end
    return false
end

local function make_cb(label)
    return function(a, v, flags)
        if not interesting() then return end
        local pc = 0
        local ok, regs = pcall(function() return emu.getregisters() end)
        if ok and regs then pc = regs["M68K PC"] or regs["PC"] or 0 end
        local m = ram_u8(BUS+0x12)
        local sub = ram_u8(BUS+0x13)
        local oy = ram_u8(BUS+0x84)
        log(string.format("WR f=%d t=%d %s addr=%06X val=%02X PC=%08X mode=%02X sub=%02X y=%02X",
            current_frame, tnow(), label, a or 0, v or -1, pc, m, sub, oy))
    end
end

local cb_handles = {}
for _, dn in ipairs({"System Bus", "68K BUS", "M68K BUS"}) do
    if AVAILABLE[dn] then
        local ok = pcall(function()
            cb_handles[#cb_handles+1] = event.on_bus_write(make_cb("facedir "), 0xFF0098, dn)
            cb_handles[#cb_handles+1] = event.on_bus_write(make_cb("objstate"), 0xFF00AC, dn)
            cb_handles[#cb_handles+1] = event.on_bus_write(make_cb("movedir "), 0xFF000F, dn)
        end)
        if ok then log("installed bp on "..dn); break end
    end
end

for frame = 1, 4000 do
    current_frame = frame
    local pad = {}
    if in_capture then
        local t = frame - t0_frame
        if t >= SCENARIO.SCENARIO_LENGTH then
            log(string.format("f=%d capture done (t=%d)", frame, t))
            break
        end
        pad = SCENARIO.get_input_for_relative_frame(t) or {}
    elseif t0_frame < 0 then
        -- still booting — replay or Left fallback
        if frame <= REPLAY:length() then
            pad = REPLAY:pad_for_frame(frame) or {}
        end
        local m = ram_u8(BUS+0x12)
        local r = ram_u8(BUS+0xEB)
        if m == 0x05 and r == TARGET_ROOM then
            local ox = ram_u8(BUS+0x70)
            local oy = ram_u8(BUS+0x84)
            if stable_prev_x == ox and stable_prev_y == oy then
                stable_count = stable_count + 1
            else
                stable_count = 0
                stable_prev_x = ox
                stable_prev_y = oy
            end
            if stable_count >= LINK_STABLE then
                t0_frame = frame
                in_capture = true
                log(string.format("f=%d T=0 baseline x=%02X y=%02X — capture begins", frame, ox, oy))
            end
        end
    end
    safe_set(pad)
    if frame % 120 == 0 then
        log(string.format("HB f=%d mode=%02X room=%02X t=%d", frame, ram_u8(BUS+0x12), ram_u8(BUS+0xEB), tnow()))
    end
    emu.frameadvance()
end

log("DONE")
pcall(function() client.exit() end)
pcall(function() client.pause() end)
