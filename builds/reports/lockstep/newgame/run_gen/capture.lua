-- tools/lockstep/capture.lua — one lockstep capture, NES or Genesis.
--
-- Runner substitutes: C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/builds/reports/lockstep/newgame/preset.lua (absolute path of generated preset .lua),
-- C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/builds/reports/lockstep/newgame/gen (absolute output prefix, forward slashes), 100000 (frames to
-- record after sync). Genesis runs also get @SYM:...@ tokens resolved.
--
-- 1. Enumerate memory domains live (RULE V3). Refuse to guess a name.
-- 2. Before the first emulated frame, write the preset into cart RAM:
--    NES: file A slot 0 image at $6000-relative offsets (presets.py).
--    GEN: 43-byte slot 0 payload into "SRAM" at index 2k+1.
-- 3. Drive the real front end: Start at title, Start on slot 0.
-- 4. Sync = first frame GameMode ($12) == $05 AND RoomId ($EB) != 0
--    (Genesis FS handoff writes GameMode $05 several frames before the
--    room is installed; GameMode alone synced on an empty state). Then play
--    PRESET.script (per-frame buttons) and dump the 2 KB NES work RAM
--    every frame to <OUT>.ram (frames x 2048) plus <OUT>.txt meta.
--    GEN NES RAM = 68K $FF8000 + off (platform_abi.h A4 base).
-- Output <OUT>.err on any failure; the differ treats missing files as ERROR.

local OUT = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/builds/reports/lockstep/newgame/gen"
local MAXF = tonumber("100000")
dofile("C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/builds/reports/lockstep/newgame/preset.lua")
-- Seed alignment (T-101): NES RNG/FrameCounter state at gameplay start
-- depends on how many frames the NES title/file menus ran; Genesis uses a
-- deliberately custom title/FS and reseeds at entry. The runner captures
-- NES first and passes its sync-frame values of FrameCounter $15, Random
-- $18..$24 and StunCycle $26 here; they are written into Genesis at sync.
-- From then on each console advances them with its own per-frame code.
SEED = {}
SEED[0x15]=0x2C SEED[0x18]=0xCF SEED[0x19]=0x7A SEED[0x1A]=0xE4 SEED[0x1B]=0x11 SEED[0x1C]=0xD9 SEED[0x1D]=0xFA SEED[0x1E]=0x49 SEED[0x1F]=0xBD SEED[0x20]=0x2E SEED[0x21]=0x54 SEED[0x22]=0x08 SEED[0x23]=0xA0 SEED[0x24]=0xB1 SEED[0x26]=0x00

local errf = nil
local function fail(msg)
    local f = io.open(OUT .. ".err", "w"); f:write(msg .. "\n"); f:close()
    client.exit()
end

local names = {}
for _, d in ipairs(memory.getmemorydomainlist()) do names[tostring(d)] = true end
local domlist = {}
for n in pairs(names) do domlist[#domlist + 1] = n end
table.sort(domlist)

local sys = emu.getsystemid()
local RAM_DOM, RAM_BASE, SAVE_DOM, SAVE_STRIDE, SAVE_ODD, SAVE_BASE
if sys == "NES" then
    if names["RAM"] then RAM_DOM, RAM_BASE = "RAM", 0
    elseif names["System Bus"] then RAM_DOM, RAM_BASE = "System Bus", 0
    else fail("NES: no RAM or System Bus domain; have " .. table.concat(domlist, ",")) return end
    if names["Battery RAM"] then SAVE_DOM, SAVE_BASE = "Battery RAM", 0x6000
    elseif names["WRAM"] then SAVE_DOM, SAVE_BASE = "WRAM", 0x6000
    elseif names["System Bus"] then SAVE_DOM, SAVE_BASE = "System Bus", 0
    else fail("NES: no save RAM domain; have " .. table.concat(domlist, ",")) return end
    SAVE_STRIDE, SAVE_ODD = 1, 0
elseif sys == "GEN" then
    if names["68K RAM"] then RAM_DOM, RAM_BASE = "68K RAM", 0x8000
    elseif names["M68K BUS"] then RAM_DOM, RAM_BASE = "M68K BUS", 0xFF8000
    else fail("GEN: no 68K RAM domain; have " .. table.concat(domlist, ",")) return end
    if not names["SRAM"] then fail("GEN: no SRAM domain; have " .. table.concat(domlist, ",")) return end
    SAVE_DOM, SAVE_STRIDE, SAVE_ODD, SAVE_BASE = "SRAM", 2, 1, 0
else
    fail("unknown system " .. tostring(sys)) return
end

local meta = io.open(OUT .. ".txt", "w")
meta:write(string.format("system=%s ram=%s+%X save=%s domains=%s preset=%s\n",
    sys, RAM_DOM, RAM_BASE, SAVE_DOM, table.concat(domlist, ","), PRESET.name))

-- 2. preset into cart RAM (before frame 1)
local wrote = 0
if sys == "NES" then
    for a, b in pairs(PRESET.nes_wram) do
        memory.write_u8(a - SAVE_BASE, b, SAVE_DOM); wrote = wrote + 1
    end
    for a, b in pairs(PRESET.nes_wram) do
        if memory.read_u8(a - SAVE_BASE, SAVE_DOM) ~= b then
            fail(string.format("NES save write did not stick at $%04X", a)) return
        end
    end
else
    for k, b in ipairs(PRESET.gen_slot0) do
        memory.write_u8((k - 1) * SAVE_STRIDE + SAVE_ODD, b, SAVE_DOM); wrote = wrote + 1
    end
end
meta:write(string.format("preset_bytes_written=%d\n", wrote))

local function gm() return memory.read_u8(RAM_BASE + 0x12, RAM_DOM) end
local function room() return memory.read_u8(RAM_BASE + 0xEB, RAM_DOM) end
local function press(btn, n) for _ = 1, n do joypad.set(btn, 1); emu.frameadvance() end end
local function idle(n) for _ = 1, n do joypad.set({}, 1); emu.frameadvance() end end

-- 3. front end: Start (title -> file select), Start (slot 0 -> load)
local boot = 0
idle(120); press({ Start = true }, 6); idle(120); press({ Start = true }, 6)
local sync = -1
for i = 1, 1500 do
    if gm() == 0x05 and room() ~= 0 then sync = i; break end
    idle(1)
end
if sync < 0 then fail(string.format("GameMode never reached $05 (last $%02X)", gm())) return end
-- Sync on the first LIVE gameplay tick: FrameCounter ($15) advancing.
-- Genesis installs the room a few frames before its tick starts.
local live = -1
for i = 1, 300 do
    local before = memory.read_u8(RAM_BASE + 0x15, RAM_DOM)
    idle(1)
    if memory.read_u8(RAM_BASE + 0x15, RAM_DOM) ~= before then live = i; break end
end
if live < 0 then fail("FrameCounter never advanced after GameMode $05") return end
local seeded = 0
for a, v in pairs(SEED) do memory.write_u8(RAM_BASE + a, v, RAM_DOM); seeded = seeded + 1 end
meta:write(string.format("sync_after_menu_frames=%d live_after=%d seeded=%d\n", sync, live, seeded))

-- 4. script + per-frame RAM dump
local function btns(s)
    local t = {}
    for c in s:gmatch(".") do
        if c == "U" then t.Up = true elseif c == "D" then t.Down = true
        elseif c == "L" then t.Left = true elseif c == "R" then t.Right = true
        elseif c == "A" then t.A = true elseif c == "B" then t.B = true
        elseif c == "S" then t.Start = true
        elseif c == "s" then if sys == "NES" then t.Select = true else t.C = true end end
    end
    return t
end
local seq = {}
for _, step in ipairs(PRESET.script) do
    for _ = 1, step[1] do seq[#seq + 1] = step[2] end
end
local ram = io.open(OUT .. ".ram", "wb")
local total = math.min(MAXF, #seq)
for f = 1, total do
    local bytes = memory.read_bytes_as_array(RAM_BASE, 0x800, RAM_DOM)
    local chunk = {}
    for i = 1, 0x800 do chunk[i] = string.char(bytes[i]) end
    ram:write(table.concat(chunk))
    meta:write(string.format("f=%d in=%s gm=%02X sub=%02X fc=%02X room=%02X\n",
        f - 1, seq[f], bytes[0x13], bytes[0x14], bytes[0x16], bytes[0xEC]))
    joypad.set(btns(seq[f]), 1)
    emu.frameadvance()
end
ram:close()
client.screenshot(OUT .. ".png")
meta:write(string.format("frames=%d\n", total))
meta:close()
client.exit()
