-- Visual sweep: bosses + key UW enemies via probe-warp.
-- Captures screenshot + slot state per room. Identifies missing/broken
-- enemy rendering or AI not-running.

local NES_BASE = 0x8000
local function R(o)   return memory.read_u8(NES_BASE + o, "68K RAM") end
local function W(o,v) memory.write_u8(NES_BASE + o, v, "68K RAM") end
local function CRAM_w(idx) return memory.read_u16_be(idx * 2, "CRAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end
local function safe_set(p)
  local ok = pcall(function() joypad.set(p or {}, 1) end)
  if not ok then joypad.set(p or {}) end
end

local PROBE_CTRL = 0x73F8

-- Boot via A+B+C chord
for _ = 1, 60 do emu.frameadvance() end
for _ = 1, 30 do
  safe_set({A=true, B=true, C=true,
            ["P1 A"]=true, ["P1 B"]=true, ["P1 C"]=true})
  emu.frameadvance()
end
safe_set({})
for _ = 1, 240 do emu.frameadvance() end

local out = io.open("C:/tmp/gen_boss_uw_visual.txt", "w")

-- FULL coverage sweep — all 9 UW levels (entry + boss room) + 12 OW
-- enemy-bearing rooms covering all OW enemy families.
local rooms = {
  -- OW enemy sample rooms (covers Octorok, Tektite, Lynel, Moblin,
  -- Leever, Peahat, Armos, Zora, Ghini, Rope, Keese — most OW types).
  {lv=0x00, rm=0x77, name="OW_start_r77"},
  {lv=0x00, rm=0x67, name="OW_Octorok_r67"},
  {lv=0x00, rm=0x44, name="OW_RedOctorok_r44"},
  {lv=0x00, rm=0x37, name="OW_Peahat_r37"},
  {lv=0x00, rm=0x04, name="OW_BlueLynel_r04"},
  {lv=0x00, rm=0x02, name="OW_RedLynel_r02"},
  {lv=0x00, rm=0x6E, name="OW_Leever_r6E"},
  {lv=0x00, rm=0x1B, name="OW_Tektite_r1B"},
  {lv=0x00, rm=0x28, name="OW_Armos_r28"},
  {lv=0x00, rm=0x5B, name="OW_Moblin_r5B"},
  {lv=0x00, rm=0x40, name="OW_LostHills_r40"},
  {lv=0x00, rm=0x70, name="OW_Zora_r70"},
  -- L1 — Aquamentus
  {lv=0x01, rm=0x73, name="L1_entry_r73"},
  {lv=0x01, rm=0x63, name="L1_combat_r63"},
  {lv=0x01, rm=0x36, name="L1_Aquamentus_r36"},
  -- L2 — Dodongo
  {lv=0x02, rm=0x7D, name="L2_entry_r7D"},
  {lv=0x02, rm=0x4F, name="L2_Dodongo_r4F"},
  -- L3 — Manhandla
  {lv=0x03, rm=0x60, name="L3_entry_r60"},
  {lv=0x03, rm=0x36, name="L3_Manhandla_r36"},
  -- L4 — Gleeok (2 necks)
  {lv=0x04, rm=0x7C, name="L4_entry_r7C"},
  {lv=0x04, rm=0x35, name="L4_Gleeok2_r35"},
  -- L5 — Digdogger
  {lv=0x05, rm=0x55, name="L5_entry_r55"},
  {lv=0x05, rm=0x36, name="L5_Digdogger_r36"},
  -- L6 — Gohma (red)
  {lv=0x06, rm=0x68, name="L6_entry_r68"},
  {lv=0x06, rm=0x37, name="L6_Gohma_r37"},
  -- L7 — Aquamentus again
  {lv=0x07, rm=0x12, name="L7_entry_r12"},
  {lv=0x07, rm=0x0F, name="L7_Aquamentus_r0F"},
  -- L8 — Gleeok 4 + Patra
  {lv=0x08, rm=0x57, name="L8_entry_r57"},
  {lv=0x08, rm=0x6A, name="L8_Gleeok4_r6A"},
  -- L9 — Ganon
  {lv=0x09, rm=0x71, name="L9_entry_r71"},
  {lv=0x09, rm=0x35, name="L9_Patra_r35"},
  {lv=0x09, rm=0x13, name="L9_Ganon_r13"},
}

local function warp(level, room)
  W(0x0098, 0x08)
  local scene = (level == 0) and 0 or 1
  memory.write_u8(PROBE_CTRL + 0, 0x52, "68K RAM")
  memory.write_u8(PROBE_CTRL + 1, 0x50, "68K RAM")
  memory.write_u8(PROBE_CTRL + 3, scene, "68K RAM")
  memory.write_u8(PROBE_CTRL + 4, level, "68K RAM")
  memory.write_u8(PROBE_CTRL + 5, 0, "68K RAM")
  memory.write_u8(PROBE_CTRL + 6, room, "68K RAM")
  memory.write_u8(PROBE_CTRL + 7, 0x5A, "68K RAM")
  for _ = 1, 30 do
    emu.frameadvance()
    if memory.read_u8(PROBE_CTRL + 7, "68K RAM") == 0 then break end
  end
  idle(240)
end

local SAT_BASE = 0xF400

for _, r in ipairs(rooms) do
  warp(r.lv, r.rm)

  out:write(string.format("\n=== %s (target lv=$%02X rm=$%02X | actual lv=$%02X rm=$%02X gm=$%02X) ===\n",
    r.name, r.lv, r.rm, R(0x0010), R(0x00EB), R(0x0012)))

  -- Slots
  out:write("Slots (1-19):\n")
  local any_slot = false
  for s = 1, 19 do
    local t = R(0x034F + s)
    if t ~= 0 then
      any_slot = true
      out:write(string.format("  s%02d t=$%02X x=$%02X y=$%02X dir=$%02X attr=$%02X ms=$%02X anim=$%02X hp=$%02X alive=$%02X\n",
        s, t, R(0x0070+s), R(0x0084+s), R(0x0098+s),
        R(0x04BF+s), R(0x0405+s), R(0x03E4+s),
        R(0x0485+s), R(0x0492+s)))
    end
  end
  if not any_slot then out:write("  (no slots populated)\n") end

  -- SAT entries
  out:write("SAT (visible):\n")
  local sat_count = 0
  for i = 0, 79 do
    local y    = memory.read_u16_be(SAT_BASE + i*8 + 0, "VRAM")
    local pat  = memory.read_u16_be(SAT_BASE + i*8 + 4, "VRAM")
    local x    = memory.read_u16_be(SAT_BASE + i*8 + 6, "VRAM")
    local pal = (pat >> 13) & 0x03
    local hf  = (pat >> 11) & 0x01
    local vf  = (pat >> 12) & 0x01
    local tile = pat & 0x07FF
    local ny = y & 0xFF
    if ny ~= 0 and ny < 0xF0 then
      sat_count = sat_count + 1
      if sat_count <= 30 then
        out:write(string.format("  sat%02d y=%d t=$%04X pal=%d hf=%d vf=%d x=%d\n",
          i, y, tile, pal, hf, vf, x))
      end
    end
  end
  out:write(string.format("  (total visible SAT entries: %d)\n", sat_count))

  client.screenshot(string.format("C:/tmp/gen_visual_%s_f240.png", r.name))
end

out:close()
client.exit()
