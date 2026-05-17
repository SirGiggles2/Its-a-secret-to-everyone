-- sfx_trigger.lua — boot, force SFX trigger via direct RAM write, sample
-- Z80 status to confirm playback path. Then mash B (sword swing) to
-- exercise the natural trigger path. Writes audit log + screenshot.

local function R(o) return memory.read_u8(o, "68K RAM") end
local function W(o,v) memory.write_u8(o, v, "68K RAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end

local OUT = "C:\\tmp\\sfx_trigger.txt"
local f = io.open(OUT, "w")

-- Boot past title via A+B+C chord, arm state mirror
idle(60)
for i=1,30 do joypad.set({A=true,B=true,C=true}, 1); emu.frameadvance() end
W(0x73F8, 0x52); W(0x73F9, 0x50); W(0x73FA, 0x00)
idle(60)

f:write(string.format("post-boot: scene=%d room=$%02X x=$%02X y=$%02X\n",
  R(0x7204), R(0x7205), R(0x7207), R(0x7209)))

-- audio_driver.asm:572 sfx_counter equ DMC_BASE+$01, DMC_BASE=$FFE100
-- → 68K RAM offset $E101. dmc_trigger writes 1-based sample idx before
-- forwarding to audio_sfx_play.
-- NES sword on A button. Z1 needs inventory sword level set at NES $0657
-- = 68K RAM offset $8657 (A4 base $FF8000).
-- audio_adapter.c sentinels at NES $07F0 (last sfx id) + $07F1 (counter).
-- A4 base $FF8000 → 68K RAM offsets $87F0/$87F1.
local sfx_id_addr  = 0x87F0
local sfx_cnt_addr = 0x87F1
local sword_level_addr = 0x8657
W(sword_level_addr, 0x01)   -- give Link a wooden sword
idle(10)
f:write(string.format("sword_level: $%02X\n", R(sword_level_addr)))

local before = R(sfx_cnt_addr)
local before_id = R(sfx_id_addr)
f:write(string.format("sfx counter pre-mash: %d (last_id=$%02X)\n", before, before_id))

-- Tap A repeatedly (must release each frame so pressed edge fires).
-- combat_try_swing gated on (pressed & BUTTON_A) = joy & ~prev_joy,
-- so held A → only frame 0 fires. Alternate A/none for press-release.
local events = 0
local prev = before
for i=1,120 do
  local b = (i % 4 < 2) and {A=true} or {}   -- 2-frame press, 2-frame release
  joypad.set(b, 1); emu.frameadvance()
  local cur = R(sfx_cnt_addr)
  if cur ~= prev then
    f:write(string.format("frame %d: sfx_counter $%02X -> $%02X\n",
      i, prev, cur))
    events = events + 1
    prev = cur
  end
end
f:write(string.format("SFX trigger events (A=sword): %d\n", events))

-- Also try B + Up (item use) just in case
prev = R(dmc_idx_addr)
for i=1,60 do
  joypad.set({B=true}, 1); emu.frameadvance()
  local cur = R(sfx_cnt_addr)
  if cur ~= prev then
    f:write(string.format("frame %d (B): sfx_counter $%02X -> $%02X\n",
      i, prev, cur))
    events = events + 1
    prev = cur
  end
end

client.screenshot("C:\\tmp\\sfx_trigger.png")
idle(10)
client.exit()
