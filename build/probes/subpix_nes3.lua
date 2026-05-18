-- NES full-state slot 1 trace w/ memory-poke teleport + room-id verify.
-- Bails with diagnostic if not in room $67.
local function R(o) return memory.read_u8(o, "RAM") end
local function W(o,v) memory.write_u8(o, v, "RAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end
local function tap(btn) joypad.set({[btn]=true},1); emu.frameadvance(); joypad.set({},1); emu.frameadvance() end

local diag = io.open("C:/tmp/subpix_nes_diag.txt", "w")
local function log(msg) diag:write(msg .. "\n"); diag:flush() end

-- Boot dance from nes_z1_compare.lua (known working).
idle(120); tap("Start"); idle(30); tap("Start"); idle(60)
tap("Down"); tap("Down"); tap("Down"); tap("Start"); idle(60)
for _=1,8 do tap("Down") end; tap("Start"); idle(60)
tap("Up"); tap("Up"); tap("Up"); tap("Up"); tap("Up"); tap("Up"); idle(30)
tap("Start"); idle(120)
log(string.format("post-boot: GameMode=$%02X RoomId=$%02X LinkX=$%02X LinkY=$%02X",
  R(0x0012), R(0x00EB), R(0x0070), R(0x0084)))

-- Walk Up to $67. Watch room id transitions.
local last_room = R(0x00EB)
log(string.format("start-walk: RoomId=$%02X LinkX=$%02X LinkY=$%02X", last_room, R(0x0070), R(0x0084)))
for fr=1,800 do
  joypad.set({Up=true},1); emu.frameadvance()
  local r = R(0x00EB)
  if r ~= last_room then
    log(string.format("walk f%d: RoomId $%02X -> $%02X LinkX=$%02X LinkY=$%02X", fr, last_room, r, R(0x0070), R(0x0084)))
    last_room = r
  end
  if r == 0x67 then break end
end
joypad.set({},1)
log(string.format("post-walk: RoomId=$%02X LinkX=$%02X LinkY=$%02X", R(0x00EB), R(0x0070), R(0x0084)))

if R(0x00EB) ~= 0x67 then
  log("NOT IN ROOM $67, bailing")
  client.screenshot("C:/tmp/subpix_nes_fail.png")
  diag:close(); client.exit(); return
end

-- Wait for slot 1 populate
for fr=1,500 do
  if R(0x0350) ~= 0 then
    log(string.format("slot-1 populated at wait f%d type=$%02X", fr, R(0x0350)))
    break
  end
  emu.frameadvance()
end

if R(0x0350) == 0 then
  log("slot 1 never populated, bailing")
  diag:close(); client.exit(); return
end

local f = io.open("C:/tmp/subpix_nes.txt", "w")
f:write("=== NES full-state slot 1, 120 frames ===\n")
f:write("frame | X Y d qspd frac grid mvTm stTm meta shTm wTSh bnc hit inDir\n")
local SLOT = 1
for fr=0,239 do
  f:write(string.format("f%3d | X$%02X Y$%02X d$%02X qspd$%02X frac$%02X grid$%02X mvTm$%02X stTm$%02X meta$%02X shTm$%02X wTSh$%02X bnc$%02X hit$%02X inDir$%02X\n",
    fr,
    R(0x0070+SLOT), R(0x0084+SLOT), R(0x0098+SLOT),
    R(0x03BC+SLOT), R(0x03A8+SLOT), R(0x0394+SLOT),
    R(0x0028+SLOT), R(0x003D+SLOT), R(0x0405+SLOT),
    R(0x0451+SLOT), R(0x0412+SLOT), R(0x0478+SLOT), R(0x04F0+SLOT),
    R(0x03F8+SLOT)))
  emu.frameadvance()
end
f:close()
log("capture complete")
diag:close()
client.exit()
