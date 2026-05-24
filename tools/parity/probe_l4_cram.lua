local NES_BASE = 0x8000
local function R(o)   return memory.read_u8(NES_BASE + o, "68K RAM") end
local function W(o,v) memory.write_u8(NES_BASE + o, v, "68K RAM") end
local function CRAM_w(idx) return memory.read_u16_be(idx*2, "CRAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end
local function safe_set(p)
  local ok = pcall(function() joypad.set(p or {}, 1) end)
  if not ok then joypad.set(p or {}) end
end
local PROBE_CTRL = 0x73F8

for _ = 1, 60 do emu.frameadvance() end
for _ = 1, 30 do
  safe_set({A=true, B=true, C=true, ["P1 A"]=true, ["P1 B"]=true, ["P1 C"]=true})
  emu.frameadvance()
end
safe_set({})
for _ = 1, 240 do emu.frameadvance() end

local function warp(level, room)
  W(0x0098, 0x08)
  memory.write_u8(PROBE_CTRL + 0, 0x52, "68K RAM")
  memory.write_u8(PROBE_CTRL + 1, 0x50, "68K RAM")
  memory.write_u8(PROBE_CTRL + 3, 1, "68K RAM")
  memory.write_u8(PROBE_CTRL + 4, level, "68K RAM")
  memory.write_u8(PROBE_CTRL + 5, 0, "68K RAM")
  memory.write_u8(PROBE_CTRL + 6, room, "68K RAM")
  memory.write_u8(PROBE_CTRL + 7, 0x5A, "68K RAM")
  for _ = 1, 30 do
    emu.frameadvance()
    if memory.read_u8(PROBE_CTRL + 7, "68K RAM") == 0 then break end
  end
  idle(180)
end

local out = io.open("C:/tmp/gen_l4_cram.txt","w")

for _, lv in ipairs({1,4,8,9}) do
  local rm = (lv == 1) and 0x73 or (lv == 4) and 0x45 or (lv == 8) and 0x7F or 0x77
  warp(lv, rm)
  out:write(string.format("\n--- L%d r$%02X (actual lv=$%02X rm=$%02X) ---\n",
    lv, rm, R(0x0010), R(0x00EB)))
  out:write("PAL0 CRAM:")
  for i = 0, 15 do out:write(string.format(" %04X", CRAM_w(i))) end
  out:write("\nPAL1 CRAM:")
  for i = 16, 31 do out:write(string.format(" %04X", CRAM_w(i))) end
  out:write("\n")
  -- Sample BG_A plane row 12 col 0..15 (mid play area)
  out:write("BG_A row 12 (cols 0..15):")
  for col = 0, 15 do
    local word = memory.read_u16_be(0xC000 + (12*64 + col)*2, "VRAM")
    out:write(string.format(" %04X", word))
  end
  out:write("\n")
end

out:close()
client.exit()
