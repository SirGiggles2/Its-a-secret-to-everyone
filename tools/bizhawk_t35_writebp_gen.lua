-- bizhawk_t35_writebp_gen.lua
-- Watch writes to $FF0011 (IsUpdatingMode) and $FF0013 (GameSubmode) during the
-- T35 stall window. Logs (frame, addr, value, M68K PC) for every write while
-- frame is in the suspect range. Replays tools/bootflow_gen.txt to reach the
-- stall, then captures.

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

local OUT = repo_path("builds\\reports\\t35_writebp_gen.txt")
local BUS = 0xFF0000

local AVAILABLE = {}
do
    local ok, lst = pcall(memory.getmemorydomainlist)
    if ok and type(lst) == "table" then
        for _, n in ipairs(lst) do AVAILABLE[n] = true end
    end
end

local function ram_u8(bus_addr)
    local ofs = bus_addr - 0xFF0000
    for _, dn in ipairs({"68K RAM", "Main RAM"}) do
        if AVAILABLE[dn] then
            local ok, v = pcall(function()
                memory.usememorydomain(dn)
                return memory.read_u8(ofs)
            end)
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
do
    local needs_reboot = false
    for _, dn in ipairs({"SRAM","Cart (Save) RAM","Save RAM","Battery RAM","CartRAM"}) do
        if AVAILABLE[dn] then
            pcall(function()
                memory.usememorydomain(dn)
                local sz = memory.getmemorydomainsize(dn)
                local any = false
                for a=0,sz-1 do
                    if memory.readbyte(a) ~= 0 then any = true end
                    memory.writebyte(a, 0)
                end
                if any then needs_reboot = true end
            end)
        end
    end
    if needs_reboot then pcall(function() client.reboot_core() end) end
end

local lines = {}
local function log(s)
    lines[#lines+1] = s
    print(s)
    local f = io.open(OUT, "w")
    if f then f:write(table.concat(lines, "\n").."\n"); f:close() end
end

log("T35 GEN WRITE-BP — $FF0011 + $FF0013 watcher")
log(string.format("bootflow frames=%d", REPLAY:length()))

-- Install bus-write callbacks on M68K bus addresses for $FF0011 and $FF0013.
local current_frame = 0
local function make_cb(label, addr)
    return function(a, v, flags)
        -- BizHawk Genesis: addr passed is bus addr offset within domain.
        local pc = "?"
        local ok, regs = pcall(function() return emu.getregisters() end)
        if ok and regs then
            pc = string.format("%08X", regs["M68K PC"] or regs["PC"] or 0)
        end
        log(string.format("WR f=%d %s addr=%06X val=%02X PC=%s",
            current_frame, label, a or addr, v or -1, pc))
    end
end

local cb_handles = {}
for _, dn in ipairs({"System Bus", "68K BUS", "M68K BUS"}) do
    if AVAILABLE[dn] then
        local ok1 = pcall(function()
            cb_handles[#cb_handles+1] = event.on_bus_write(make_cb("isupd", 0xFF0011), 0xFF0011, dn)
            cb_handles[#cb_handles+1] = event.on_bus_write(make_cb("sub  ", 0xFF0013), 0xFF0013, dn)
        end)
        if ok1 then log("installed write-bp on domain "..dn); break end
    end
end
if #cb_handles == 0 then
    -- Fallback: try without scope arg
    local ok = pcall(function()
        cb_handles[#cb_handles+1] = event.on_bus_write(make_cb("isupd", 0xFF0011), 0xFF0011)
        cb_handles[#cb_handles+1] = event.on_bus_write(make_cb("sub  ", 0xFF0013), 0xFF0013)
    end)
    if ok then log("installed write-bp via default scope") else log("WARN: no write-bp installed") end
end

local t0 = -1
local stable_x, stable_y, stable_ct = nil, nil, 0
local WINDOW_START, WINDOW_END = 175, 200
local watch_active = false

for frame = 1, 6000 do
    current_frame = frame
    local pad = REPLAY:pad_for_frame(frame) or {}
    safe_set(pad)
    emu.frameadvance()

    local mode = ram_u8(BUS+0x12)
    local sub  = ram_u8(BUS+0x13)
    local room = ram_u8(BUS+0xEB)
    local isupd = ram_u8(BUS+0x11)
    local objx = ram_u8(BUS+0x70)
    local objy = ram_u8(BUS+0x84)

    if t0 < 0 and mode == 0x05 and room == 0x77 then
        if stable_x == objx and stable_y == objy then
            stable_ct = stable_ct + 1
            if stable_ct >= 60 then
                t0 = frame
                log(string.format("T0=%d set", frame))
            end
        else
            stable_ct = 0; stable_x = objx; stable_y = objy
        end
    end

    if t0 > 0 then
        local t = frame - t0
        if t == WINDOW_START and not watch_active then
            watch_active = true
            log(string.format("WATCH_BEGIN t=%d f=%d", t, frame))
        end
        if t >= WINDOW_START and t <= WINDOW_END then
            log(string.format("HB t=%d f=%d mode=$%02X sub=$%02X isupd=$%02X room=$%02X",
                t, frame, mode, sub, isupd, room))
        end
        if t > WINDOW_END then break end
    end
end

log("WATCH_DONE")
pcall(function() client.exit() end)
pcall(function() client.pause() end)
