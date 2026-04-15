-- bizhawk_t35_diag_gen.lua
-- Minimal replay-and-dump probe. Replays tools/bootflow_gen.txt and dumps
-- IsUpdatingMode/SecretColorCycle/sub/mode/hscroll/dir per frame to
-- builds/reports/t35_diag_gen.txt for frames covering T=150..260 (absolute
-- frame range computed once T0 is found).

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

local OUT = repo_path("builds\\reports\\t35_diag_gen.txt")
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

-- Wipe SRAM + reboot (mirror main gen capture behavior)
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

log("T35 GEN DIAG — IsUpdatingMode + SecretColorCycle trace")
log(string.format("bootflow frames=%d", REPLAY:length()))

local t0 = -1
local stable_x, stable_y, stable_ct = nil, nil, 0

for frame = 1, 3000 do
    if frame % 200 == 0 then
        log(string.format("HB f=%d mode=$%02X sub=$%02X room=$%02X isupd=$%02X",
            frame, ram_u8(BUS+0x12), ram_u8(BUS+0x13), ram_u8(BUS+0xEB), ram_u8(BUS+0x11)))
    end
    local pad = REPLAY:pad_for_frame(frame) or {}
    safe_set(pad)
    emu.frameadvance()

    local mode = ram_u8(BUS+0x12)
    local sub  = ram_u8(BUS+0x13)
    local room = ram_u8(BUS+0xEB)
    local isupd = ram_u8(BUS+0x11)
    local secret = ram_u8(BUS+0x51A)
    local whirl = ram_u8(BUS+0x522)
    local hsc = ram_u8(BUS+0xFD)
    local dir = ram_u8(BUS+0x3F8)
    local objx = ram_u8(BUS+0x70)
    local objy = ram_u8(BUS+0x84)

    -- Detect T0 = Mode5 room$77 Link stable 60f
    if t0 < 0 and mode == 0x05 and room == 0x77 then
        if stable_x == objx and stable_y == objy then
            stable_ct = stable_ct + 1
            if stable_ct >= 60 then
                t0 = frame
                log(string.format("T0=%d (frame) set", frame))
            end
        else
            stable_ct = 0; stable_x = objx; stable_y = objy
        end
    end

    if t0 > 0 then
        local t = frame - t0
        if t >= 150 and t <= 260 then
            log(string.format("t=%3d f=%d mode=$%02X sub=$%02X isupd=$%02X secret=$%02X whirl=$%02X room=$%02X dir=$%02X hsc=$%02X",
                t, frame, mode, sub, isupd, secret, whirl, room, dir, hsc))
        end
        if t > 260 then break end
    end
end

log("DIAG_DONE")
pcall(function() client.exit() end)
pcall(function() client.pause() end)
