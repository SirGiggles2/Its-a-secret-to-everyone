-- bizhawk_t35_curcol_bp.lua
-- Narrow probe: log all writes to $FF00E8 (CurColumn), $FF0013 (GameSubmode),
-- and $FF0011 (IsUpdatingMode) whenever GameMode==$07 (scroll). Captures PC +
-- value for each hit. Runs bootflow then lets game play. No T0 gate — we log
-- everything-mode-7 and grep offline.

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

local replay_mod = dofile(repo_path("tools\\bootflow_replay.lua"))
local REPLAY = replay_mod.load(repo_path("tools\\bootflow_gen.txt"), "GEN")
if not REPLAY then error("bootflow_gen.txt missing") end

local OUT = repo_path("builds\\reports\\t35_curcol_bp.txt")
local BUS = 0xFF0000

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

-- Wipe SRAM
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

log("T35 GEN CurCol/sub/isupd watcher — mode=7 only")

local current_frame = 0
local current_mode = 0
local function make_cb(label, addr)
    return function(a, v, flags)
        local pc = "?"
        local ok, regs = pcall(function() return emu.getregisters() end)
        if ok and regs then pc = string.format("%08X", regs["M68K PC"] or regs["PC"] or 0) end
        log(string.format("WR f=%d %s val=%02X PC=%s mode=%02X sub=%02X curcol=%02X",
            current_frame, label, v or -1, pc,
            current_mode, ram_u8(0xFF0013), ram_u8(0xFF00E8)))
    end
end

local cb_handles = {}
for _, dn in ipairs({"System Bus", "68K BUS", "M68K BUS"}) do
    if AVAILABLE[dn] then
        local ok = pcall(function()
            cb_handles[#cb_handles+1] = event.on_bus_write(make_cb("CurCol", 0xFF00E8), 0xFF00E8, dn)
            cb_handles[#cb_handles+1] = event.on_bus_write(make_cb("sub   ", 0xFF0013), 0xFF0013, dn)
            cb_handles[#cb_handles+1] = event.on_bus_write(make_cb("isupd ", 0xFF0011), 0xFF0011, dn)
            cb_handles[#cb_handles+1] = event.on_bus_write(make_cb("mode  ", 0xFF0012), 0xFF0012, dn)
            cb_handles[#cb_handles+1] = event.on_bus_write(make_cb("hscrll", 0xFF00FD), 0xFF00FD, dn)
        end)
        if ok then log("installed bp on "..dn); break end
    end
end

for frame = 1, 4000 do
    current_frame = frame
    current_mode = ram_u8(BUS+0x12)
    local pad = REPLAY:pad_for_frame(frame) or {}
    if frame > REPLAY:length() then pad = {Left = true} end
    safe_set(pad)
    if frame % 60 == 0 then
        pcall(function() memory.usememorydomain("68K RAM") end)
        local mode2 = pcall(function() return memory.read_u8(0x12) end) and memory.read_u8(0x12) or 0
        local sub2 = memory.read_u8(0x13)
        local isupd2 = memory.read_u8(0x11)
        local curcol2 = memory.read_u8(0xE8)
        local room2 = memory.read_u8(0xEB)
        local fc2 = memory.read_u8(0x15)
        local exc = memory.read_u8(0x900)
        local exc1 = memory.read_u8(0x901)
        local pc_now = 0
        pcall(function() local r = emu.getregisters(); pc_now = r["M68K PC"] or r["PC"] or 0 end)
        log(string.format("HB f=%d mode=%02X sub=%02X isupd=%02X curcol=%02X room=%02X fc=%02X exc=%02X%02X pc=%08X",
            frame, mode2, sub2, isupd2, curcol2, room2, fc2, exc, exc1, pc_now))
    end
    emu.frameadvance()
end

log("DONE")
pcall(function() client.exit() end)
pcall(function() client.pause() end)
