-- probe_gen.lua — Genesis enemy_fix probe.
-- Boots Debug.md to gameplay, arms 'FX' hook per type in TYPES table,
-- traces 17 cells × 11 slots × 240 frames per type, appends to
-- C:/tmp/efx_gen_sweep.txt with ">>> TYPE $XX" delimiters.
--
-- Single BizHawk launch per full sweep. Per memory feedback_one_big_probe.

-- ============================ Config ===============================
-- Wave 1 batch: 9 wrapper-handled + neighbors for regression check.
-- Per-row: { type, x, y, dir, slot, habitat, room_id }
-- Final sweep: post-fix verification across all in-scope enemy types.
-- Each entry: { type, x, y, dir, slot, habitat, room_id }
local TYPES = {
  {0x01, 0x80, 0x80, 0x02, 1, 0, 0x77},  -- Red Lynel (NEW UPDATE port)
  {0x02, 0x80, 0x80, 0x02, 1, 0, 0x77},  -- Blue Lynel
  {0x03, 0x80, 0x80, 0x02, 1, 0, 0x77},  -- Blue Moblin (wrapper draw)
  {0x04, 0x80, 0x80, 0x02, 1, 0, 0x77},  -- Red Moblin
  {0x05, 0x80, 0x80, 0x02, 1, 0, 0x77},  -- Red Goriya
  {0x06, 0x80, 0x80, 0x02, 1, 0, 0x77},  -- Blue Goriya
  {0x07, 0x80, 0x80, 0x02, 1, 0, 0x77},  -- Slow Octorok (attr $05)
  {0x0B, 0x80, 0x80, 0x02, 1, 0, 0x77},  -- Blue Darknut (attr $81)
  {0x11, 0x80, 0x80, 0x04, 1, 0, 0x77},  -- Zora
  {0x17, 0x80, 0x80, 0x02, 1, 1, 0x70},  -- LikeLike (UW)
  {0x1E, 0x80, 0x80, 0x02, 1, 0, 0x77},  -- Armos (attr $C3)
  {0x22, 0x80, 0x80, 0x02, 1, 0, 0x77},  -- Flying Ghini (attr $81)
  {0x27, 0x80, 0x80, 0x04, 1, 1, 0x70},  -- Wallmaster (UW)
  {0x2A, 0x80, 0x80, 0x02, 1, 0, 0x77},  -- Stalfos
  {0x2B, 0x80, 0x80, 0x02, 1, 1, 0x70},  -- BlueBubble (UW)
  {0x3D, 0x80, 0x80, 0x02, 1, 1, 0x70},  -- Aquamentus (boss)
}
local FRAMES_PER_TYPE = 120
local OUT_PATH = "C:/tmp/efx_gen_sweep.txt"

-- ============================ Helpers ==============================
local function R(off)  return memory.read_u8(off, "68K RAM") end
local function W(off,v) memory.write_u8(off, v, "68K RAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end

-- Debug.md pins A4=$FF8000 per src/debug/a4_probe_asm.s:8, so NES RAM
-- mirror starts at 68K RAM domain offset 0x8000. NES $034F+slot reads
-- as 68K RAM offset $834F+slot.
local NES = 0x8000

-- Debug.md boots into TITLE state. A+B+C edge-trigger transitions to
-- ROOMROM gameplay (per src/debug/a4_probe_main.c:132). Hold the chord
-- briefly; first edge fires the state switch.
local function boot_to_gameplay()
  idle(120)
  -- Edge-trigger A+B+C: release first, then press for >1 frame
  joypad.set({},1); emu.frameadvance(); joypad.set({},1); emu.frameadvance()
  joypad.set({A=true,B=true,C=true},1); emu.frameadvance()
  joypad.set({A=true,B=true,C=true},1); emu.frameadvance()
  joypad.set({},1)
  idle(120)
  print(string.format("post-chord mode=$%02X room=$%02X fc=$%02X",
    R(NES + 0x0012), R(NES + 0x00EB), R(NES + 0x0015)))
end

-- Trace one frame of cell data for slot.
local function trace_frame(slot, fnum)
  return string.format("f%d t$%02X x$%02X y$%02X d$%02X qspd$%02X grid$%02X mvTm$%02X objTm$%02X stTm$%02X meta$%02X attr$%02X anim$%02X inv$%02X bnc$%02X hit$%02X shTm$%02X wTSh$%02X",
    fnum,
    R(NES + 0x034F + slot),
    R(NES + 0x0070 + slot), R(NES + 0x0084 + slot), R(NES + 0x0098 + slot),
    R(NES + 0x03BC + slot), R(NES + 0x03A8 + slot), R(NES + 0x0394 + slot),
    R(NES + 0x0028 + slot), R(NES + 0x003D + slot),
    R(NES + 0x0405 + slot), R(NES + 0x04BF + slot), R(NES + 0x03D0 + slot),
    R(NES + 0x03F8 + slot), R(NES + 0x0478 + slot), R(NES + 0x04F0 + slot),
    R(NES + 0x0451 + slot), R(NES + 0x0412 + slot))
end

-- Arm 'FX' hook for one type, wait for consume, trace N frames.
local function probe_type(t)
  local type_id, x, y, dir, slot, habitat, room = table.unpack(t)
  -- Write magic + params
  W(0x77D0, 0x46); W(0x77D1, 0x58)  -- 'F','X'
  W(0x77D2, type_id)
  W(0x77D3, x); W(0x77D4, y); W(0x77D5, dir)
  W(0x77D6, slot); W(0x77D7, habitat); W(0x77D8, room)
  -- Wait for hook to consume (magic cleared)
  local waited = 0
  while waited < 120 and (R(0x77D0) ~= 0 or R(0x77D1) ~= 0) do
    emu.frameadvance(); waited = waited + 1
  end
  if waited >= 120 then
    return string.format("ARM_FAIL type=$%02X waited=%d mode=$%02X room=$%02X fc=$%02X $77D0=$%02X $77D1=$%02X",
      type_id, waited, R(NES + 0x0012), R(NES + 0x00EB), R(NES + 0x0015), R(0x77D0), R(0x77D1))
  end
  -- Trace
  local lines = {}
  for f=0,FRAMES_PER_TYPE-1 do
    lines[#lines+1] = trace_frame(slot, f)
    emu.frameadvance()
  end
  return table.concat(lines, "\n")
end

-- ============================ Main =================================
boot_to_gameplay()

local f = io.open(OUT_PATH, "w")
if not f then print("FAILED to open " .. OUT_PATH); return end
f:write("# probe_gen.lua sweep\n")
for i, t in ipairs(TYPES) do
  f:write(string.format(">>> TYPE $%02X\n", t[1]))
  local trace = probe_type(t)
  f:write(trace); f:write("\n")
  f:flush()
end
f:close()
client.screenshot(string.format("C:/tmp/efx_gen_$%02X_final.png", TYPES[#TYPES][1]))
client.exit()
