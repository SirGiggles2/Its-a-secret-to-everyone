-- probe_gen_boss_direct.lua — Phase 1 ground-truth boss capture (Genesis).
--
-- DIRECT PROBE_CTRL warp to each canonical NES boss room (NO $6BBC
-- self-discovery — that path read garbage and warped to non-rooms).
--
-- Boss CHR is loaded via the debug BOSS_TRIGGER, NOT auto-loaded on warp:
-- level_chr_boss_request() is NOT yet wired into the real scene-load path
-- (Phase 2 fixes that). This probe observes the boss-CHR machine in
-- isolation, the SAME proven path tools/debug/probe_boss_bank_dispatch.lua
-- uses. This is the RED baseline.
--
-- CONTROL-BYTE COLLISION (verified main.c:1883 vs main.c:2945):
--   The warp block uses ctrl[3..7] = scene/level/quest/room/0x5A.
--   The boss-trigger block uses ctrl[6]=$FF73FE (scene_id) + ctrl[7]=$FF73FF
--   (ack). Same two bytes. Boss-trigger runs EARLY in the tick, warp LATE,
--   so with flag 0x04 set the boss-trigger eats ctrl[6] before the warp
--   reads it. => we TOGGLE flag 0x04: clear it before each warp, set it
--   only for the boss-kick window.
--
-- Memory contract (RoomRom/src/roomrom_debug_runtime.h, main.c):
--   $FF73F8 'R'(0x52) | $FF73F9 'P'(0x50)   arm magic (gates mirror+warp+flags)
--   $FF73FA  flags: 0x01 HEAVY_MIRROR, 0x02 ENEMY_STRESS(!), 0x04 BOSS_TRIGGER
--   $FF73FB  warp dest_scene (1 = SCENE_UW)
--   $FF73FC  warp dest_level
--   $FF73FD  warp dest_quest
--   $FF73FE  warp dest_room_id  AND  boss-trigger scene_id (collision)
--   $FF73FF  warp trigger 0x5A  AND  boss-trigger ack (collision)
--   scene_id for boss = level + 3  (ROOMROM_SCENE_UW_L1=4 .. _L9=12)
--
-- State mirror (base $FF7200, magic 'W'(0x57)/'P'(0x50), BE) — sanctioned
-- decoded-state interface; needs HEAVY_MIRROR (0x01) for offsets >= 12.
--
-- VRAM (verified roomrom_vram_map.h / main.c:638):
--   BOSS_TILE_BASE = SPR_TILE_BASE(615) + 44 = 659 -> VRAM 659*32 = $5260
--   SAT  = $F400 (RoomRom gameplay, VDP_setSpriteListAddress(0xF400u))
--   planeA/B = $C000
--
-- Per RULE V3: enumerate domains live; dump FULL 64 KB VRAM + 64 KB 68K RAM
-- so every cell/tile is recoverable post-hoc regardless of window addresses.
-- Per RULE V1: bytes are the evidence; screenshots are triage only.
--
-- Output: $CODEX_BIZHAWK_ROOT/gen_boss_direct/<name>/...

local OUT = (os.getenv("CODEX_BIZHAWK_ROOT") or "C:\\tmp") .. "/gen_boss_direct"
os.execute('if not exist "' .. OUT:gsub("/","\\") .. '" mkdir "' .. OUT:gsub("/","\\") .. '"')

-- ---- Domain detection (RULE V3 rule 1: never assume a domain exists). ----
local function domain_exists(name)
  for _, d in ipairs(memory.getmemorydomainlist()) do
    if d == name then return true end
  end
  return false
end

-- RAM domain + base: "68K RAM"/"M68K RAM" use 0-based offsets ($FFxxxx ->
-- 0xxxxx); "M68K BUS" needs full $FFxxxx addresses.
local RAM_DOMAIN, RAM_BASE = "68K RAM", 0x0000
if domain_exists("68K RAM") then        RAM_DOMAIN, RAM_BASE = "68K RAM", 0x0000
elseif domain_exists("M68K RAM") then   RAM_DOMAIN, RAM_BASE = "M68K RAM", 0x0000
elseif domain_exists("M68K BUS") then   RAM_DOMAIN, RAM_BASE = "M68K BUS", 0xFF0000
end
local VRAM_DOMAIN = domain_exists("VRAM") and "VRAM"
  or (domain_exists("VDP VRAM") and "VDP VRAM") or "VRAM"

local function R(off)    return memory.read_u8(RAM_BASE + off, RAM_DOMAIN) end
local function W(off, v) memory.write_u8(RAM_BASE + off, v, RAM_DOMAIN) end
local function RW16(off) return R(off) * 256 + R(off + 1) end  -- BE u16
local function idle(n)   for _=1,n do emu.frameadvance() end end

-- ---- Control / mirror offsets (68K-RAM-domain offsets) ----
local CTRL   = 0x73F8
local ARM0, ARM1 = CTRL+0, CTRL+1
local FLAGS  = CTRL+2          -- $FF73FA
local W_SCENE, W_LEVEL, W_QUEST = CTRL+3, CTRL+4, CTRL+5
local W_ROOM = CTRL+6          -- $FF73FE (also boss scene_id)
local W_TRIG = CTRL+7          -- $FF73FF (also boss ack)
local BOSS_TRIG, BOSS_ACK = 0x73FE, 0x73FF
local MIR = 0x7200             -- state mirror base
local SENT = 0x7000            -- runtime-up sentinel (0xA4,0x4A)

local FLAG_HEAVY, FLAG_BOSS = 0x01, 0x04

local BOSS_VRAM, BOSS_VRAM_BYTES = 0x5260, 2048   -- 659*32, 64 tiles

-- Canonical NES boss rooms (docs/audit/boss_room_ids.md).
local bosses = {
  {name="aquamentus",   lv=1, rm=0x35},
  {name="dodongo",      lv=2, rm=0x73},
  {name="manhandla",    lv=3, rm=0x0F},
  {name="gleeok_2head", lv=4, rm=0x45},
  {name="digdogger",    lv=5, rm=0x06},
  {name="gohma_red",    lv=6, rm=0x0F},
  {name="aquamentus_2", lv=7, rm=0x23},
  {name="gleeok_4head", lv=8, rm=0x1F},
  {name="patra_red",    lv=9, rm=0x1E},
  {name="ganon",        lv=9, rm=0x1F},
}

-- ---- Boot to gameplay via A+B+C chord (debug_enter). ----
idle(120)
for _=1,8 do
  joypad.set({["P1 A"]=true, ["P1 B"]=true, ["P1 C"]=true})
  emu.frameadvance()
end
joypad.set({})
-- Wait for RoomRom runtime sentinel (best-effort; do not hard-fail).
local sentinel_seen = false
for _=1,600 do
  emu.frameadvance()
  if R(SENT) == 0xA4 and R(SENT+1) == 0x4A then sentinel_seen = true; break end
end
idle(60)

-- ---- Domain enumeration dump (once). ----
do
  local f = io.open(OUT .. "/domains.txt", "w")
  f:write("ram_domain=" .. RAM_DOMAIN .. " base=" .. string.format("0x%X", RAM_BASE) .. "\n")
  f:write("vram_domain=" .. tostring(VRAM_DOMAIN) .. "\n")
  f:write("sentinel_seen=" .. tostring(sentinel_seen) .. "\n")
  f:write("--- domains ---\n")
  for _, d in ipairs(memory.getmemorydomainlist()) do f:write(d .. "\n") end
  f:close()
end

-- Arm the control block (magic) once.
W(ARM0, 0x52); W(ARM1, 0x50)

-- Warp to (scene=UW, level, quest, room). Boss flag MUST be clear so the
-- early boss-trigger block does not consume ctrl[6]/ctrl[7] first.
local function warp(level, quest, room)
  W(FLAGS, 0x00)                       -- disarm boss trigger for the warp
  idle(2)
  W(W_SCENE, 1); W(W_LEVEL, level); W(W_QUEST, quest); W(W_ROOM, room)
  W(W_TRIG, 0x5A)                      -- fire warp
  for _=1,90 do emu.frameadvance(); if R(W_TRIG) == 0 then break end end
  idle(90)                             -- room render + enemy CHR DMA -> READY
end

-- Kick boss CHR: set boss flag (+ heavy mirror), poke scene_id, await ack.
local function kick_boss(level)
  local ack0 = R(BOSS_ACK)
  W(FLAGS, FLAG_HEAVY | FLAG_BOSS)     -- 0x05
  W(BOSS_TRIG, level + 3)              -- scene_id = level+3 (UW_L1..L9 = 4..12)
  local fired = false
  for _=1,40 do
    emu.frameadvance()
    if R(BOSS_ACK) ~= ack0 then fired = true; break end
  end
  idle(60)                             -- boss DMA stages -> READY -> resident
  return fired, ack0, R(BOSS_ACK)
end

local function dump_bin(path, domain, base, n)
  local f = io.open(path, "wb")
  for a = 0, n-1 do f:write(string.char(memory.read_u8(base + a, domain))) end
  f:close()
end

local function dump_cram_hex(path)
  local h = io.open(path, "w")
  for pal = 0, 3 do
    h:write(string.format("PAL%d:", pal))
    for c = 0, 15 do
      h:write(string.format(" %02X%02X",
        memory.read_u8(pal*32 + c*2, "CRAM"),
        memory.read_u8(pal*32 + c*2 + 1, "CRAM")))
    end
    h:write("\n")
  end
  h:close()
end

local function nonzero_count(domain, base, n)
  local c = 0
  for a = 0, n-1 do if memory.read_u8(base + a, domain) ~= 0 then c = c + 1 end end
  return c
end

local function dump_state(dir, b, fired, ack0, ack1)
  local f = io.open(dir .. "/state.txt", "w")
  f:write(string.format("boss=%s level=%d room=$%02X scene_id=%d\n",
    b.name, b.lv, b.rm, b.lv + 3))
  f:write(string.format("frame=%d\n", emu.framecount()))
  f:write(string.format("boss_kick_fired=%s ack %d->%d\n", tostring(fired), ack0, ack1))
  f:write(string.format("boss_chr_vram_nonzero=%d/%d (base $%04X)\n",
    nonzero_count(VRAM_DOMAIN, BOSS_VRAM, BOSS_VRAM_BYTES), BOSS_VRAM_BYTES, BOSS_VRAM))
  -- VERIFIED decoded state from the sanctioned mirror (magic 'W'/'P').
  f:write("--- mirror (VERIFIED, $FF7200) ---\n")
  f:write(string.format("mirror_magic=%02X%02X (expect 5750)\n", R(MIR+0), R(MIR+1)))
  f:write(string.format("mir.frame=%d scene=%d room=$%02X\n",
    RW16(MIR+2), R(MIR+4), R(MIR+5)))
  f:write(string.format("mir.link_x=%d link_y=%d face=%d\n",
    RW16(MIR+6), RW16(MIR+8), R(MIR+10)))
  f:write(string.format("mir.uw_level=%d uw_quest=%d\n", R(MIR+16), R(MIR+17)))
  f:write(string.format("mir.enemy_chr_swap_state=%d active_scene=%d (heavy-mirror)\n",
    R(MIR+112), R(MIR+113)))
  -- RAW NES RAM mirror cells (NES addr == 68K offset; verified $7000-$76FF
  -- debug blocks sit above Z1 save $6000-$6FFF). Authoritative copy in
  -- m68k_ram.bin; re-slice if any base assumption proves wrong (Phase 4).
  f:write("--- raw NES cells (NES addr = 68K offset) ---\n")
  f:write(string.format("GameMode $12=$%02X  Level $10=$%02X  RoomId $EB=$%02X\n",
    R(0x12), R(0x10), R(0xEB)))
  f:write(string.format("BossRoomId $6BBC=$%02X  StartRoomId $6BAD=$%02X\n",
    R(0x6BBC), R(0x6BAD)))
  f:write(string.format("LBA_A $687E+rm=$%02X  LBA_C $697E+rm=$%02X\n",
    R(0x687E + b.rm), R(0x697E + b.rm)))
  f:write("Slots (s: type x y dir hp attr meta) — per Phase 0.A cell map:\n")
  local any = false
  for s = 1, 19 do
    local t = R(0x034F + s)
    if t ~= 0 then
      any = true
      f:write(string.format("  s%02d t=$%02X x=$%02X y=$%02X dir=$%02X hp=$%02X attr=$%02X meta=$%02X\n",
        s, t, R(0x0070+s), R(0x0084+s), R(0x0098+s), R(0x0485+s), R(0x04BF+s), R(0x0405+s)))
    end
  end
  if not any then f:write("  (all slots empty)\n") end
  f:close()
end

for _, b in ipairs(bosses) do
  local dir = OUT .. "/" .. b.name
  os.execute('if not exist "' .. dir:gsub("/","\\") .. '" mkdir "' .. dir:gsub("/","\\") .. '"')
  warp(b.lv, 0, b.rm)
  local fired, ack0, ack1 = kick_boss(b.lv)

  client.screenshot(dir .. "/screen.png")
  dump_state(dir, b, fired, ack0, ack1)
  dump_cram_hex(dir .. "/cram.hex")
  dump_bin(dir .. "/cram.bin",      "CRAM",      0,         128)
  dump_bin(dir .. "/plane_a.bin",   VRAM_DOMAIN, 0xC000,    4096)
  dump_bin(dir .. "/sat.bin",       VRAM_DOMAIN, 0xF400,    640)
  dump_bin(dir .. "/boss_chr.bin",  VRAM_DOMAIN, BOSS_VRAM, BOSS_VRAM_BYTES)
  dump_bin(dir .. "/vram_full.bin", VRAM_DOMAIN, 0,         0x10000)
  dump_bin(dir .. "/m68k_ram.bin",  RAM_DOMAIN,  RAM_BASE,  0x10000)
end

print("wrote " .. OUT)
client.exit()
