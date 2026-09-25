-- tools/lockstep/capture.lua — one lockstep capture, NES or Genesis.
--
-- Runner substitutes: @PRESET@ (absolute path of generated preset .lua),
-- @OUT@ (absolute output prefix, forward slashes), @MAXF@ (frames to
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

local OUT = "@OUT@"
local MAXF = tonumber("@MAXF@")
dofile("@PRESET@")
-- Seed alignment (T-101): NES RNG/FrameCounter state at gameplay start
-- depends on how many frames the NES title/file menus ran; Genesis uses a
-- deliberately custom title/FS and reseeds at entry. The runner captures
-- NES first and passes its sync-frame values of FrameCounter $15, Random
-- $18..$24 and StunCycle $26 here; they are written into Genesis at sync.
-- From then on each console advances them with its own per-frame code.
SEED = {}
@SEED@

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
if sys == "GEN" and PRESET.gen_entry == "xyz" then
    -- Disclosed debug entry (Genesis FS boots Q1 only until T-099):
    -- title X+Y+Z chord = quest 2 + debug_unlock_all_items. Arm the probe
    -- block so the gameplay mirror publishes; wait for 'W','P' at $FF7200.
    local function bw(a, v) memory.write_u8(0xFF0000 + a, v, "M68K BUS") end
    local function br(a) return memory.read_u8(0xFF0000 + a, "M68K BUS") end
    idle(30)
    local ok = false
    for i = 1, 1500 do
        bw(0x73F8, 0x52); bw(0x73F9, 0x50); bw(0x73FA, 0)
        joypad.set((i % 30 < 4) and { X = true, Y = true, Z = true } or {}, 1)
        emu.frameadvance()
        if br(0x7200) == 0x57 and br(0x7201) == 0x50 then ok = true; break end
    end
    if not ok then fail("X+Y+Z chord not accepted (6-button pad configured?)") return end
    meta:write("gen_entry=xyz (debug chord, all items unlocked)\n")
else
    idle(120); press({ Start = true }, 6); idle(120); press({ Start = true }, 6)
end
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
local function srd(o) return memory.read_u8(RAM_BASE + o, RAM_DOM) end
local function swr(o, v) memory.write_u8(RAM_BASE + o, v & 0xFF, RAM_DOM) end
local function slog(msg) meta:write("stage: " .. msg .. "\n") end
-- Genesis selects the B item from a private C static (RoomRom/src/main.c
-- s_b_item, b_item_t = 4-byte int), not NES SelectedItemSlot $656 (T-092).
-- A stage that selects an item on NES ($656) calls gen_b_item(v) to make
-- the same selection on Genesis. No-op on NES. Written, then read back.
local GEN_B_ITEM = tonumber("@SYM:s_b_item@")
local stage_failed = false
local stage_fail_why = ""
local function stage_fail(why) stage_failed = true; stage_fail_why = why; slog(why) end
local function gen_b_item(v)
    if sys ~= "GEN" then return end
    if GEN_B_ITEM == nil then stage_fail("gen_b_item: s_b_item symbol unresolved"); return end
    local a = (RAM_DOM == "M68K BUS") and GEN_B_ITEM or (GEN_B_ITEM - 0xFF0000)
    memory.write_u32_be(a, v, RAM_DOM)
    local back = memory.read_u32_be(a, RAM_DOM)
    slog(string.format("gen s_b_item @%06X = %d (read %d)", GEN_B_ITEM, v, back))
    if back ~= v then stage_fail("gen_b_item write did not stick") end
end
-- Genesis Link position/facing live in players[0] (src/state/link_state.h
-- LinkState: s16 x @+0, s16 y @+2, u8 dir @+6, u8 face @+7, s8 grid_offset
-- @+13); NES $70/$84/$98 are mirrored FROM it each tick, so a stage that
-- places Link on NES ($70/$84/$98/$394) calls gen_link_pos(x, y, nes_dir)
-- to place him on Genesis. face: 0 down, 1 up, 2 left, 3 right
-- (RoomRom/src/roomrom_main_state.h). No-op on NES. Read back.
local GEN_PLAYERS = tonumber("@SYM:players@")
-- Link's movement state proper lives in RoomRom/src/main.c statics:
-- s_link_dir (link_dir_t, 4-byte int: 1 down, 2 up, 3 left, 4 right) and
-- s_link_grid_offset (s8, NES ObjGridOffset $394 equivalent). A teleport
-- must reset them as the NES stage resets $98/$394, else the next turn
-- snaps Link toward a stale grid point.
local GEN_LINK_DIR = tonumber("@SYM:s_link_dir@")
local GEN_LINK_GRID = tonumber("@SYM:s_link_grid_offset@")
local NES_DIR_TO_LINK_DIR = { [0x01] = 4, [0x02] = 3, [0x04] = 1, [0x08] = 2 }
local NES_DIR_TO_FACE = { [0x01] = 3, [0x02] = 2, [0x04] = 0, [0x08] = 1 }
local function gen_link_pos(x, y, nes_dir)
    if sys ~= "GEN" then return end
    local face = NES_DIR_TO_FACE[nes_dir]
    if GEN_PLAYERS == nil or face == nil then
        stage_fail("gen_link_pos: players symbol unresolved or bad dir"); return
    end
    local a = (RAM_DOM == "M68K BUS") and GEN_PLAYERS or (GEN_PLAYERS - 0xFF0000)
    memory.write_u16_be(a + 0, x, RAM_DOM)
    memory.write_u16_be(a + 2, y, RAM_DOM)
    memory.write_u8(a + 6, nes_dir, RAM_DOM)
    memory.write_u8(a + 7, face, RAM_DOM)
    memory.write_u8(a + 13, 0, RAM_DOM)
    local bx, by = memory.read_u16_be(a, RAM_DOM), memory.read_u16_be(a + 2, RAM_DOM)
    local bd, bf = memory.read_u8(a + 6, RAM_DOM), memory.read_u8(a + 7, RAM_DOM)
    local bg = memory.read_u8(a + 13, RAM_DOM)
    slog(string.format("gen players[0] @%06X = %d,%d dir %02X face %d (read %d,%d dir %02X face %d grid %d)",
        GEN_PLAYERS, x, y, nes_dir, face, bx, by, bd, bf, bg))
    if bx ~= x or by ~= y or bd ~= nes_dir or bf ~= face or bg ~= 0 then
        stage_fail("gen_link_pos write did not stick")
        return
    end
    if GEN_LINK_DIR == nil or GEN_LINK_GRID == nil then
        stage_fail("gen_link_pos: s_link_dir / s_link_grid_offset unresolved"); return
    end
    local ad = (RAM_DOM == "M68K BUS") and GEN_LINK_DIR or (GEN_LINK_DIR - 0xFF0000)
    local ag = (RAM_DOM == "M68K BUS") and GEN_LINK_GRID or (GEN_LINK_GRID - 0xFF0000)
    local ld = NES_DIR_TO_LINK_DIR[nes_dir]
    memory.write_u32_be(ad, ld, RAM_DOM)
    memory.write_u8(ag, 0, RAM_DOM)
    local rld, rg = memory.read_u32_be(ad, RAM_DOM), memory.read_u8(ag, RAM_DOM)
    slog(string.format("gen s_link_dir=%d (read %d) s_link_grid_offset=0 (read %d)", ld, rld, rg))
    if rld ~= ld or rg ~= 0 then stage_fail("gen_link_pos static write did not stick") end
end
for f = 1, total do
    for _, st in ipairs(PRESET.stages) do
        if st.at == f - 1 then
            meta:write(string.format("stage at f=%d\n", f - 1))
            st.fn(srd, swr, slog, sys, gen_b_item, gen_link_pos)
        end
    end
    if stage_failed then ram:close(); fail(stage_fail_why) return end
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

-- Final-frame full video dump (RULE V3: every domain, full range).
-- NES: OAM (256), PALRAM (32), VRAM = CHR-RAM patterns (8 KB), CIRAM.
-- GEN: VRAM (64 KB; gameplay SAT at $F400 per RoomRom/src/main.c
-- init_video VDP_setSpriteListAddress), CRAM, VSRAM.
local function dump_domain(dom, suffix)
    if not names[dom] then meta:write("nodomain " .. dom .. "\n"); return end
    local size = memory.getmemorydomainsize(dom)
    local bytes = memory.read_bytes_as_array(0, size, dom)
    local chunk = {}
    for i = 1, size do chunk[i] = string.char(bytes[i]) end
    local fh = io.open(OUT .. suffix, "wb"); fh:write(table.concat(chunk)); fh:close()
    meta:write(string.format("dump %s -> %s (%d bytes)\n", dom, suffix, size))
end
if sys == "NES" then
    dump_domain("Battery RAM", ".wram")   -- NES $6000-$7FFF (LevelBlock/Info)
    dump_domain("OAM", ".oam"); dump_domain("PALRAM", ".pal")
    dump_domain("VRAM", ".chr"); dump_domain("CIRAM (nametables)", ".nt")
else
    dump_domain("VRAM", ".vram"); dump_domain("CRAM", ".cram"); dump_domain("VSRAM", ".vsram")
    dump_domain("SRAM", ".sram")   -- cart SRAM (logical byte k at index 2k+1)
    -- 68K work RAM (64 KB): NES mirror incl. $6000+ = $FFE000+.
    if names["68K RAM"] then dump_domain("68K RAM", ".m68k")
    else
        local fh = io.open(OUT .. ".m68k", "wb")
        local b = memory.read_bytes_as_array(0xFF0000, 0x10000, "M68K BUS")
        local ch = {}
        for i = 1, 0x10000 do ch[i] = string.char(b[i]) end
        fh:write(table.concat(ch)); fh:close()
        meta:write("dump M68K BUS FF0000-FFFFFF -> .m68k\n")
    end
end
meta:write(string.format("frames=%d\n", total))
meta:close()
client.exit()
