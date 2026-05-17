-- fps_isolate_enemies.lua — test hypothesis: enemy_loop_tick is hot path.
--
-- 1. Boot, advance past title (A+B+C chord enters debug mode)
-- 2. Hold UP 600 frames to trigger scroll → post-scroll state
-- 3. Phase R1: measure 200f FPS with enemies populated
-- 4. Zero ObjType[$70..$7B] in NES RAM mirror (12 slots × type+0x10 stride)
-- 5. Phase R2: measure 200f FPS with enemies wiped
-- 6. Write fps_isolate_enemies.txt with verdict
--
-- NES_RAM mirror in 68K RAM domain at $8000 (RAM_A4_BASE). ObjType lives
-- at NES $0070..$007B (12 slots). nes_ram[$0070] = enemy slot 0 type.

local function R(o) return memory.read_u8(o, "68K RAM") end
local function W(o,v) memory.write_u8(o, v, "68K RAM") end
local function R16BE(o) return R(o)*256 + R(o+1) end
local function idle(n) for _=1,n do emu.frameadvance() end end

local OUT = "C:\\tmp\\fps_isolate_enemies.txt"
local f = io.open(OUT, "w")

-- A4-pinned at $FF0000; 68K RAM domain offset 0 = nes_ram[0]. NES Z1 cells
-- map 1:1 — ObjType at $034F+slot, ENEMY_ALIVE_FLAG at $0492+slot, ObjX at
-- $0070+slot, ObjY at $0084+slot. State mirror lives at $7200+ (separate
-- region populated by roomrom_debug_publish_state_mirror after arm magic
-- at $73F8/$73F9).
local FC_ADDR      = 0x7202
local ROOM_ADDR    = 0x7205
local X_ADDR       = 0x7207
local Y_ADDR       = 0x7209
local OBJTYPE_BASE = 0x834F
local OBJALIVE_BASE = 0x8492
local OBJX_BASE    = 0x8070

local function fc() return R16BE(FC_ADDR) end

-- Boot past title
idle(60)
-- Toggle debug mode via A+B+C
for i=1,30 do joypad.set({A=true, B=true, C=true}, 1); emu.frameadvance() end
-- Arm state mirror
W(0x73F8, 0x52)
W(0x73F9, 0x50)
W(0x73FA, 0x00)
idle(60)

f:write(string.format("=== boot done: room=$%02X x=$%02X y=$%02X fc=%d ===\n",
  R(ROOM_ADDR), R(X_ADDR), R(Y_ADDR), fc()))

-- Phase scroll: hold UP 600 frames
for i=1,600 do joypad.set({Up=true}, 1); emu.frameadvance() end
idle(30)
f:write(string.format("=== after scroll: room=$%02X x=$%02X y=$%02X fc=%d ===\n",
  R(ROOM_ADDR), R(X_ADDR), R(Y_ADDR), fc()))

-- Snapshot enemy slots BEFORE wipe
f:write("ObjType pre-wipe: ")
for slot=0,11 do
  local v = R(OBJTYPE_BASE + slot)
  f:write(string.format("$%02X ", v))
end
f:write("\n")
f:write("ObjAlive pre-wipe: ")
for slot=0,11 do
  local v = R(OBJALIVE_BASE + slot)
  f:write(string.format("$%02X ", v))
end
f:write("\n")

-- Phase R1: measure FPS with enemies present
local fc0 = fc()
for i=1,300 do emu.frameadvance() end
local game = fc() - fc0
if game < 0 then game = game + 65536 end
local r1 = game/300
f:write(string.format("Phase R1 (with enemies): %d game frames / 300 emu = %.3f\n",
  game, r1))

-- Zero ObjType AND ObjAlive for slots 1..11 (leave slot 0 = Link)
for slot=1,11 do
  W(OBJTYPE_BASE + slot, 0x00)
  W(OBJALIVE_BASE + slot, 0x00)
end
idle(10)

-- Phase R2: measure FPS with enemies wiped
fc0 = fc()
for i=1,300 do emu.frameadvance() end
game = fc() - fc0
if game < 0 then game = game + 65536 end
local r2 = game/300
f:write(string.format("Phase R2 (enemies wiped): %d game frames / 300 emu = %.3f\n",
  game, r2))

f:write(string.format("\nDELTA: %.3f -> %.3f (recovery = %+.3f)\n", r1, r2, r2-r1))
if r2 - r1 > 0.15 then
  f:write("VERDICT: enemy load is hot path\n")
elseif r2 >= 0.95 then
  f:write("VERDICT: enemy load is hot path (fully recovered)\n")
else
  f:write("VERDICT: NOT enemies — look elsewhere\n")
end

client.screenshot("C:\\tmp\\fps_isolate_enemies.png")
f:close()
gui.text(8, 8, "done")
idle(20)
client.exit()
