-- Capture NES Z1 spawn positions at EXACT frame slots first populate.
-- Slot 1 NES ObjType lives at $034F+1 = $0350.
local R = function(o) return memory.read_u8(o, "RAM") end
local idle = function(n) for _=1,n do emu.frameadvance() end end
local tap = function(btn) joypad.set({[btn]=true},1); emu.frameadvance(); joypad.set({},1); emu.frameadvance() end

idle(120); tap("Start"); idle(30); tap("Start"); idle(60)
tap("Down"); tap("Down"); tap("Down"); tap("Start"); idle(60)
for _=1,8 do tap("Down") end; tap("Start"); idle(60)
tap("Up"); tap("Up"); tap("Up"); tap("Up"); tap("Up"); tap("Up"); idle(30)
tap("Start"); idle(120)

-- Walk Up; stop when room id = $67
for _=1,400 do joypad.set({Up=true},1); emu.frameadvance(); if R(0x00EB) == 0x67 then break end end
joypad.set({},1)

-- Wait until slot 1 type becomes non-zero
for _=1,200 do if R(0x0350) ~= 0 then break end; emu.frameadvance() end

local f = io.open("C:/tmp/nes_spawn_67_exact.txt", "w")
local function dump(label, fh)
  fh:write(string.format("\n--- %s ---\n", label))
  for s=1,11 do
    local t = R(0x034F + s)
    if t ~= 0 then
      fh:write(string.format("  slot %2d: type=$%02X X=$%02X Y=$%02X dir=$%02X qspd=$%02X\n",
        s, t, R(0x0070+s), R(0x0084+s), R(0x0098+s), R(0x03BC+s)))
    end
  end
end

f:write("=== NES room $67 spawn at exact populate-frame ===\n")
dump("f0 (slot 1 type just became non-zero)", f)
emu.frameadvance()
dump("f1", f)
emu.frameadvance()
dump("f2", f)
for _=1,5 do emu.frameadvance() end
dump("f8", f)

f:write(string.format("\nLinkObjDir ($0098) = $%02X\n", R(0x0098)))
f:write(string.format("SpawnCycle ($0624) = $%02X\n", R(0x0624)))
f:write(string.format("LinkX ($0070) = $%02X, LinkY ($0084) = $%02X\n", R(0x0070), R(0x0084)))
f:write(string.format("ObjectFirstUnwalkableTile ($034A) = $%02X\n", R(0x034A)))
f:close()
client.exit()
