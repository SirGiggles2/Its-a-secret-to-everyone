-- Read NES LBA_A[0]/LBA_B[0] live post-warp to r$00.
-- Disambiguates H1/H2/H3 for v6-B brown-bug.

local function R(o) return memory.read_u8(o, "RAM") end
local function W(o,v) memory.write_u8(o, v, "RAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end
local function press(b,h,s) h=h or 4; s=s or 30
  for _=1,h do joypad.set({[b]=true},1); emu.frameadvance() end
  joypad.set({},1); for _=1,s do emu.frameadvance() end
end

idle(360); press("Start",4,60)
press("Down",4,20); press("Down",4,20); press("Down",4,20); press("Start",4,60)
press("Start",4,60)
for _=1,5 do press("Down",4,8) end
for _=1,5 do press("Right",4,8) end
press("Start",4,60)
for _=1,5 do press("Up",4,12) end
press("Start",4,180); idle(180)

local out = io.open("C:/tmp/nes_lba_r00.txt","w")
out:write("--- Post-boot state (before warp) ---\n")
out:write(string.format("LBA_A[0]=$%02X  LBA_B[0]=$%02X  LBA_C[0]=$%02X  LBA_D[0]=$%02X\n",
  R(0x687E), R(0x68FE), R(0x697E), R(0x69FE)))
out:write(string.format("RoomId=$%02X CurLevel=$%02X GameMode=$%02X\n",
  R(0x00EB), R(0x0010), R(0x0012)))
out:write(string.format("Play area attr row0 (PlayAreaAttrs $6530+offset=byte 16): not visible from RAM. Sample first PAlpha=$%02X\n",
  R(0x6530)))

-- Warp to OW r$00
W(0x0070, 0x78); W(0x0084, 0x80); W(0x0098, 0x08)
W(0x0010, 0x00); W(0x00EB, 0x00); W(0x0012, 0x06)
idle(180)
W(0x00EB, 0x00); W(0x0010, 0x00); W(0x0012, 0x05)
idle(120)

out:write("\n--- Post-warp r$00 state ---\n")
out:write(string.format("LBA_A[0]=$%02X  LBA_B[0]=$%02X  LBA_C[0]=$%02X  LBA_D[0]=$%02X\n",
  R(0x687E), R(0x68FE), R(0x697E), R(0x69FE)))
out:write(string.format("RoomId=$%02X CurLevel=$%02X GameMode=$%02X\n",
  R(0x00EB), R(0x0010), R(0x0012)))

-- Read first 16 bytes of LBA_A + LBA_B + LBA_C + LBA_D
out:write("\nLBA_A[0..15]: ")
for i=0,15 do out:write(string.format("$%02X ", R(0x687E+i))) end
out:write("\nLBA_B[0..15]: ")
for i=0,15 do out:write(string.format("$%02X ", R(0x68FE+i))) end
out:write("\nLBA_C[0..15]: ")
for i=0,15 do out:write(string.format("$%02X ", R(0x697E+i))) end
out:write("\nLBA_D[0..15]: ")
for i=0,15 do out:write(string.format("$%02X ", R(0x69FE+i))) end
out:write("\n")

-- Calculate sub-pal selection per FillPlayAreaAttrs asm
local outer = R(0x687E) % 4
local inner = R(0x68FE) % 4
local nt_attr_tbl = {0x00, 0x55, 0xAA, 0xFF}
out:write(string.format("\nPer asm: outer=%d -> NT_attr=$%02X, inner=%d -> NT_attr=$%02X\n",
  outer, nt_attr_tbl[outer+1], inner, nt_attr_tbl[inner+1]))

client.screenshot("C:/tmp/nes_r00_lba.png")
out:close()
client.exit()
