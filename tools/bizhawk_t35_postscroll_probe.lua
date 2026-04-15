-- bizhawk_t35_postscroll_probe.lua
-- Stage C probe: post-scroll freeze + t=333 corruption diagnosis.
-- Replays bootflow, then holds Left (matching t35 scenario), sampling
-- per-frame PC + SR + zero-page fields + joypad input across the
-- window where Gen Link freezes and then RAM goes to garbage.
--
-- Window: frames 820..1000 (approximately t=200..380 relative to T0=621).
-- Writes one line per frame to builds/reports/t35_postscroll_probe.txt.

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

local OUT = repo_path("builds\\reports\\t35_postscroll_probe.txt")

local AVAILABLE = {}
do
    local ok, lst = pcall(memory.getmemorydomainlist)
    if ok and type(lst) == "table" then for _, n in ipairs(lst) do AVAILABLE[n] = true end end
end

local function ram_u8(ofs)
    pcall(function() memory.usememorydomain("68K RAM") end)
    local ok, v = pcall(function() return memory.read_u8(ofs) end)
    if ok then return v end
    return 0
end

local function ram_u16(ofs)
    pcall(function() memory.usememorydomain("68K RAM") end)
    local ok, v = pcall(function() return memory.read_u16_be(ofs) end)
    if ok then return v end
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

log("T35 Stage C postscroll probe — per-frame PC+SR+RAM sampling")

-- Catch exception vector dispatches via bus-write to supervisor stack.
-- Simpler: every frame sample SR high bits + SP and log if in supervisor
-- mode (shouldn't be during game loop).
local exc_seen = {}
for _, dn in ipairs({"System Bus", "M68K BUS", "68K BUS"}) do
    if AVAILABLE[dn] then
        -- Watch writes near the exception save area ($FF0900..$FF090F)
        pcall(function()
            event.on_bus_write(function(a, v)
                local pc = "?"
                local ok, r = pcall(function() return emu.getregisters() end)
                if ok and r then pc = string.format("%08X", r["M68K PC"] or r["PC"] or 0) end
                exc_seen[#exc_seen+1] = string.format("EXC addr=%06X val=%02X PC=%s",
                    a or 0, v or 0, pc)
            end, 0xFF0900, dn)
        end)
        break
    end
end

local BOOT = REPLAY:length()  -- typically 618
log(string.format("bootflow frames=%d", BOOT))
local LEFT_FRAMES_AFTER = 300 -- hold Left for this many frames past bootflow

local WINDOW_START = BOOT + 200  -- ~t=200
local WINDOW_END   = BOOT + 400  -- ~t=400

for frame = 1, BOOT + 420 do
    local pad = REPLAY:pad_for_frame(frame) or {}
    if frame > BOOT and frame <= BOOT + LEFT_FRAMES_AFTER then
        pad = {Left = true}
    end
    safe_set(pad)

    -- Per-frame sampling in the window only (to keep log size reasonable)
    if frame >= WINDOW_START and frame <= WINDOW_END then
        local mode   = ram_u8(0x12)
        local sub    = ram_u8(0x13)
        local isupd  = ram_u8(0x11)
        local room   = ram_u8(0xEB)
        local x      = ram_u8(0x70)
        local y      = ram_u8(0x84)
        local dir    = ram_u8(0x98)
        local fc     = ram_u8(0x15)
        local held   = ram_u8(0xF4)  -- JoypadButtons shadow (if present)
        local curcol = ram_u8(0xE8)
        local hsc    = ram_u8(0xFD)
        local exc0   = ram_u8(0x900)
        local exc1   = ram_u8(0x901)
        local pc, sr, sp = 0, 0, 0
        local ok, r = pcall(function() return emu.getregisters() end)
        if ok and r then
            pc = r["M68K PC"] or r["PC"] or 0
            sr = r["M68K SR"] or r["SR"] or 0
            sp = r["M68K SP"] or r["SP"] or r["A7"] or 0
        end
        local t = frame - (BOOT + 60)  -- approximate t relative to scenario T0
        log(string.format(
            "f=%d t=%+d pc=%08X sr=%04X sp=%08X mode=%02X sub=%02X isupd=%02X "
            .. "room=%02X x=%02X y=%02X dir=%02X fc=%02X held=%02X curcol=%02X hsc=%02X exc=%02X%02X",
            frame, t, pc, sr, sp, mode, sub, isupd, room, x, y, dir, fc, held,
            curcol, hsc, exc0, exc1))
    end
    emu.frameadvance()
end

log("")
log(string.format("EXC events captured: %d", #exc_seen))
for _, s in ipairs(exc_seen) do log(s) end

log("DONE")
pcall(function() client.exit() end)
pcall(function() client.pause() end)
