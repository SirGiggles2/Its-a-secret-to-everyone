-- NES stock ROM probe with per-FAMILY init replication.
-- Covers walker + flyer + jumper + special + bubble.
-- Boss types deferred (multi-segment state complex).

local function R(o) return memory.read_u8(o, "RAM") end
local function W(o,v) memory.write_u8(o, v, "RAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end
local function press(btn, hold_f, settle_f)
  hold_f = hold_f or 4; settle_f = settle_f or 30
  for _ = 1, hold_f do joypad.set({[btn]=true}, 1); emu.frameadvance() end
  joypad.set({}, 1); for _ = 1, settle_f do emu.frameadvance() end
end

local ROOT = "C:/tmp/nes_v4/"
os.execute("mkdir " .. ROOT:gsub("/", "\\") .. " 2>NUL")
os.execute("mkdir " .. (ROOT .. "boot"):gsub("/", "\\") .. " 2>NUL")
local function shot(p) client.screenshot(ROOT .. p) end

local OBJECT_TYPE_TO_ATTRS = {
  [0]=0xFF, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x05,
       0x05, 0x05, 0x05, 0x81, 0x81, 0x81, 0x81, 0x01,
       0x01, 0x81, 0x01, 0x01, 0x43, 0x43, 0x81, 0x81,
       0x81, 0x81, 0x01, 0x81, 0x81, 0x81, 0x01, 0x81,
       0x81, 0x81, 0x81, 0x81, 0x81, 0xC3, 0xC3, 0x89,
       0x89, 0x81, 0x81, 0x89, 0x89, 0x89, 0x89, 0x83,
       0x81, 0x89, 0x89, 0xC9, 0xC9, 0x81, 0x81, 0x81,
       0xA9, 0xA9, 0x41, 0x41, 0x89, 0x89, 0x81, 0x81,
       0x81, 0xC1, 0xC1, 0xC1, 0xC1, 0xC1, 0x81, 0x81,
       0x81, 0xA1, 0xA1, 0x81, 0x81, 0x81, 0x81, 0x81,
       0x81, 0x81, 0x81, 0xE3, 0xE3, 0xE3, 0xE3, 0xE3,
       0xE1, 0xE1, 0xE1, 0xE1, 0xE1, 0x81, 0x81,
}
local OBJECT_HP_PAIRS = {
  [0]=0x06, 0x43, 0x25, 0x31, 0x12, 0x24, 0x81, 0x14,
      0x22, 0x42, 0x00, 0xA9, 0x8F, 0x20, 0x00, 0x3F,
      0xF9, 0xFA, 0x46, 0x62, 0x11, 0x2F, 0xFF, 0xFF,
      0x7F, 0xF6, 0x2F, 0xFF, 0xFF, 0x22, 0x46, 0xF1,
      0xF2, 0xAA, 0xAA, 0xFB, 0xBF, 0xF0,
}
local function hp(t)
  local i = math.floor(t/2); local p = OBJECT_HP_PAIRS[i] or 0
  if t%2==1 then return (p%16)*16 else return p - (p%16) end
end
local function attr(t) return OBJECT_TYPE_TO_ATTRS[t] or 0 end

local NO_CLOUD = {[0x1E]=1, [0x22]=1, [0x11]=1, [0x0F]=1, [0x10]=1, [0x1A]=1}

local function init_obj(slot, t, x, y)
  -- Common init (every type)
  W(0x034F+slot, t); W(0x0070+slot, x); W(0x0084+slot, y); W(0x008C+slot, 0x00)
  W(0x04BF+slot, attr(t)); W(0x0485+slot, hp(t))
  W(0x04F0+slot, 0); W(0x00C0+slot, 0); W(0x00D3+slot, 0); W(0x003D+slot, 0)
  W(0x03BC+slot, 0x20); W(0x03D0+slot, 0x10); W(0x03E4+slot, 0)
  W(0x04B2+slot, 0); W(0x00AC+slot, 0); W(0x0444+slot, 0); W(0x0498+slot, 0)

  -- Cloud or no
  if NO_CLOUD[t] or t >= 0x53 then
    W(0x0028+slot, 0); W(0x04D8+slot, 0)
  else
    W(0x0028+slot, slot); W(0x04D8+slot, 0x01)
  end

  -- Per-type tweaks
  if t == 0x0B then
    W(0x04B2+slot, 0xF6); W(0x03BC+slot, 0x20)
  elseif t == 0x0C then
    W(0x04B2+slot, 0xF6); W(0x03BC+slot, 0x28)
  elseif t == 0x07 or t == 0x09 or t == 0x21 then
    W(0x03BC+slot, 0x20)
  elseif t == 0x08 or t == 0x0A then
    W(0x03BC+slot, 0x30)
  elseif t == 0x15 then
    W(0x00AC+slot, 0x02)
  elseif t == 0x2B or t == 0x2C or t == 0x2D then
    W(0x03BC+slot, 0x40)
  elseif t == 0x1A then
    W(0x008C+slot, 0x08); W(0x0498+slot, 0x1F)
  elseif t == 0x1B then
    W(0x008C+slot, 0x01); W(0x0498+slot, 0x1F)
  elseif t == 0x1C or t == 0x1D then
    W(0x008C+slot, 0x01); W(0x0498+slot, 0x7F)
  elseif t == 0x11 then
    W(0x00AC+slot, 0x01)
  end
end

-- ===== Boot =====
idle(360); shot("boot/01_title.png")
press("Start", 4, 60); shot("boot/02_fs.png")
press("Down",4,20); press("Down",4,20); press("Down",4,20); shot("boot/03_register.png")
press("Start",4,60); shot("boot/04_reg.png")
press("Start",4,60); shot("boot/05_slot.png")
for _=1,5 do press("Down",4,8) end
for _=1,5 do press("Right",4,8) end
press("Start",4,60); shot("boot/06_save.png")
for _=1,5 do press("Up",4,12) end
press("Start",4,180); shot("boot/07_in_game.png")
idle(180)

local gm = R(0x0012); local rm = R(0x00EB)
local vf = io.open(ROOT .. "boot/verdict.txt", "w")
vf:write(string.format("GameMode=$%02X RoomId=$%02X\n", gm, rm))
if gm ~= 0x05 then vf:write("FAIL\n"); vf:close(); client.exit(); return end
vf:write("OK Mode 5\n"); vf:close()

-- ===== Full dump =====
local function full_dump(out_dir, label)
  os.execute("mkdir " .. out_dir:gsub("/", "\\") .. " 2>NUL")
  client.screenshot(out_dir .. "/screenshot.png")
  savestate.save(out_dir .. "/savestate.State")
  local bf = io.open(out_dir .. "/nes_ram.bin", "wb")
  for off = 0, 0x7FF do bf:write(string.char(R(off))) end
  bf:close()
  local of = io.open(out_dir .. "/oam.bin", "wb")
  for off = 0, 0xFF do of:write(string.char(memory.read_u8(off, "OAM"))) end
  of:close()
  local pf = io.open(out_dir .. "/palram.bin", "wb")
  for off = 0, 0x1F do pf:write(string.char(memory.read_u8(off, "PALRAM"))) end
  pf:close()
  local cf = io.open(out_dir .. "/chr.bin", "wb")
  for off = 0, 0x1FFF do cf:write(string.char(memory.read_u8(off, "CHR"))) end
  cf:close()
  local nf = io.open(out_dir .. "/nt.bin", "wb")
  for off = 0, 0xFFF do nf:write(string.char(memory.read_u8(off, "CIRAM (nametables)"))) end
  nf:close()
  local j = io.open(out_dir .. "/state.json", "w")
  j:write(string.format('{"label":"%s","frame":%d,"gm":"$%02X","rm":"$%02X","fc":"$%02X",\n',
    label, emu.framecount(), R(0x0012), R(0x00EB), R(0x0015)))
  j:write(string.format('"link":{"x":"$%02X","y":"$%02X","dir":"$%02X"},\n',
    R(0x0070), R(0x0084), R(0x008C)))
  j:write('"slots":[')
  for s = 1, 11 do
    j:write(string.format('{"s":%d,"t":"$%02X","x":"$%02X","y":"$%02X","dir":"$%02X","qspd":"$%02X","st":"$%02X","ms":"$%02X","tm":"$%02X","hp":"$%02X","inv":"$%02X","attr":"$%02X"}%s',
      s, R(0x034F+s), R(0x0070+s), R(0x0084+s), R(0x008C+s),
      R(0x03BC+s), R(0x00AC+s), R(0x04D8+s), R(0x0028+s),
      R(0x0485+s), R(0x04B2+s), R(0x04BF+s),
      (s==11) and "" or ","))
  end
  j:write('],"oam_hex":"')
  for off = 0, 0xFF do j:write(string.format("%02x", memory.read_u8(off, "OAM"))) end
  j:write('","palram_hex":"')
  for off = 0, 0x1F do j:write(string.format("%02x", memory.read_u8(off, "PALRAM"))) end
  j:write('"}\n')
  j:close()
end

full_dump(ROOT .. "00_init", "Mode-5 initial")

local TYPES = {
  {0x01,"BlueLynel"},  {0x02,"RedLynel"},
  {0x03,"BlueMoblin"}, {0x04,"RedMoblin"},
  {0x05,"BlueGoriya"}, {0x06,"RedGoriya"},
  {0x07,"Octorok"},    {0x08,"FastOctorok"},
  {0x09,"Octorok2"},   {0x0A,"FastOctorok2"},
  {0x0B,"BlueDarknut"},{0x0C,"RedDarknut"},
  {0x0D,"Tektite"},    {0x0E,"FastTektite"},
  {0x0F,"BlueLeever"}, {0x10,"RedLeever"},
  {0x11,"Zora"},
  {0x12,"Vire"},       {0x13,"Zol"},     {0x15,"Gel"},
  {0x16,"PolsVoice"},  {0x17,"LikeLike"},
  {0x1A,"Peahat"},     {0x1B,"BlueKeese"},
  {0x1C,"RedKeese"},   {0x1D,"BlackKeese"},
  {0x1E,"Armos"},      {0x21,"Ghini"},
  {0x22,"FlyingGhini"},
  {0x27,"Wallmaster"}, {0x28,"Rope"},
  {0x2A,"Stalfos"},
  {0x2B,"BlueBubble"}, {0x2C,"RedBubble"},  {0x2D,"BlueBubble2"},
  {0x30,"Gibdo"},
}

for _, e in ipairs(TYPES) do
  local t, name = e[1], e[2]
  -- Clear slots 2-11
  for s = 2, 11 do
    W(0x034F+s, 0); W(0x0485+s, 0); W(0x04D8+s, 0); W(0x00AC+s, 0); W(0x04BF+s, 0)
    W(0x008C+s, 0); W(0x03BC+s, 0); W(0x0028+s, 0)
  end
  -- Force RNG
  W(0x0018, 0x40)
  for i = 1, 12 do W(0x0018 + i, 0x00) end
  -- Init enemy
  init_obj(1, t, 0x80, 0x88)
  -- Settle 90f
  for _ = 1, 90 do emu.frameadvance() end
  -- Dump
  full_dump(string.format("%s%02X_%s", ROOT, t, name), string.format("$%02X %s", t, name))
end

full_dump(ROOT .. "ZZ_final", "end")
client.exit()
