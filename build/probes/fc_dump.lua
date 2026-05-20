-- fc_dump.lua — instrument s_frame_counter raw bytes pre/post teleport.
local function R(o) return memory.read_u8(o, "68K RAM") end
local function R16BE(o) return R(o)*256 + R(o+1) end
local function idle(n) for _=1,n do emu.frameadvance() end end
local function tap(btn,h,r)
  h=h or 4; r=r or 12
  for _=1,h do joypad.set({[btn]=true},1); emu.frameadvance() end
  for _=1,r do joypad.set({},1); emu.frameadvance() end
end

local MIRROR = 0x8000
local OUT = "C:\\tmp\\fc_dump.txt"
local f = io.open(OUT, "w")

idle(60)
memory.write_u8(0x73F8, 0x52, "68K RAM")
memory.write_u8(0x73F9, 0x50, "68K RAM")
memory.write_u8(0x73FA, 0x00, "68K RAM")

for i=1,30 do joypad.set({A=true,B=true,C=true},1); emu.frameadvance() end
idle(60)

local function dump(lbl)
  f:write(string.format("%-16s fc=%5d (hi=%02X lo=%02X) arm=%02X %02X room=$%02X mode=$%02X\n",
    lbl, R16BE(0x7202), R(0x7202), R(0x7203),
    R(0x73F8), R(0x73F9),
    R(0x7205), R(MIRROR+0x0012)))
end

dump("post-boot")
idle(60)
dump("after idle60")
idle(60)
dump("after idle120")

-- Teleport
tap("X")
dump("after tap X")
tap("Left")
dump("after tap L1")
tap("Left")
dump("after tap L2")
tap("Left")
dump("after tap L3")
tap("Left")
dump("after tap L4")
tap("Up")
dump("after tap U")
tap("X")
dump("after tap X exit")
idle(40)
dump("after idle40")
idle(60)
dump("after idle100")

-- Re-arm in case clobbered
memory.write_u8(0x73F8, 0x52, "68K RAM")
memory.write_u8(0x73F9, 0x50, "68K RAM")
idle(20)
dump("after rearm idle20")

idle(60)
dump("after rearm idle80")

f:close()
gui.text(8,8,"fc dump done")
idle(20)
client.exit()
