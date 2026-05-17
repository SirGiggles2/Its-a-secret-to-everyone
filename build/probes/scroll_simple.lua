-- scroll_simple.lua — from FRESH spawn, drive only DOWN for 300f.
-- Then UP for 300f. Walks straight south from start so we can see
-- if room $77 has a south exit, or if Link clamps on internal walls.
-- Also dumps s_walkable check + cave entry result.

local function R(o) return memory.read_u8(o, "68K RAM") end
local function R16BE(o)
  return memory.read_u8(o, "68K RAM") * 256 + memory.read_u8(o+1, "68K RAM")
end
local function S16BE(o)
  local v = R16BE(o); if v >= 0x8000 then v = v - 0x10000 end; return v
end
local function idle(n) for _=1,n do emu.frameadvance() end end

local OUT = "C:\\tmp\\scroll_simple.txt"
local f = io.open(OUT, "w")

local function snap(tag)
  f:write(string.format("%-12s fr=%04X sc=%d rm=$%02X X=$%04X Y=$%04X face=%d dir=%d walk=%d walkN=%d col=%d row=%d\n",
    tag, R16BE(0x7202), R(0x7204), R(0x7205),
    S16BE(0x7206) & 0xFFFF, S16BE(0x7208) & 0xFFFF,
    R(0x720A), R(0x720B), R(0x7223), R(0x7224), R(0x7225), R(0x7226)))
end

idle(60)
memory.write_u8(0x73F8, 0x52, "68K RAM")
memory.write_u8(0x73F9, 0x50, "68K RAM")
memory.write_u8(0x73FA, 0x01, "68K RAM")

for i=1,30 do joypad.set({A=true,B=true,C=true}, 1); emu.frameadvance() end
idle(30)
snap("entry")

-- DOWN only — straight south from spawn
f:write("\n=== DOWN only (from spawn) ===\n")
for i=1,300 do
  joypad.set({Down=true}, 1)
  emu.frameadvance()
  if i % 15 == 0 then snap("D+"..i) end
end
idle(20)
snap("D+end")

-- Re-enter via in-game (can't reset). Try UP from current position
f:write("\n=== UP from D-stuck pos ===\n")
for i=1,300 do
  joypad.set({Up=true}, 1)
  emu.frameadvance()
  if i % 15 == 0 then
    snap("U+"..i)
    -- Detect scene change to cave/UW
    local sc = R(0x7204)
    if sc ~= 0 then
      f:write(string.format("!!! scene change to %d at frame %d\n", sc, i))
      break
    end
  end
end
idle(20)
snap("U+end")

-- Continue UP if still in OW
for i=1,300 do
  joypad.set({Up=true}, 1)
  emu.frameadvance()
  if i % 30 == 0 then snap("U2+"..i) end
end
idle(20)
snap("U2+end")

client.screenshot("C:\\tmp\\scroll_simple.png")
f:write("\nDONE\n")
f:close()
gui.text(8, 8, "simple done")
idle(20)
client.exit()
