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

for _ = 1, 60 do emu.frameadvance() end
for _ = 1, 30 do
  safe_set({A=true, B=true, C=true, ["P1 A"]=true, ["P1 B"]=true, ["P1 C"]=true})
  emu.frameadvance()
end
safe_set({})
for _ = 1, 240 do emu.frameadvance() end

-- Warp to OW r$00
W(0x0098, 0x08)
memory.write_u8(PROBE_CTRL + 0, 0x52, "68K RAM")
memory.write_u8(PROBE_CTRL + 1, 0x50, "68K RAM")
memory.write_u8(PROBE_CTRL + 3, 0, "68K RAM")
memory.write_u8(PROBE_CTRL + 4, 0, "68K RAM")
memory.write_u8(PROBE_CTRL + 5, 0, "68K RAM")
memory.write_u8(PROBE_CTRL + 6, 0x00, "68K RAM")  -- r$00
memory.write_u8(PROBE_CTRL + 7, 0x5A, "68K RAM")
for _ = 1, 30 do
  emu.frameadvance()
  if memory.read_u8(PROBE_CTRL + 7, "68K RAM") == 0 then break end
end
idle(240)

local out = io.open("C:/tmp/gen_r00.txt", "w")
out:write(string.format("rm=$%02X gm=$%02X\n", R(0x00EB), R(0x0012)))
out:write("PAL0 CRAM (sub-pal 2 [8..11] should be green):\n")
for i = 0, 15 do
  out:write(string.format("  PAL0[%2d] = $%04X\n", i, CRAM_w(i)))
end
out:close()
client.screenshot("C:/tmp/gen_r00_fresh.png")
client.exit()
