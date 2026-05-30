-- probe_nes_boss_direct.lua — Phase 1 NES mirror for boss ground truth.
--
-- NES Z1 (real ROM) reference for the 10 canonical boss rooms. Mirror of
-- tools/parity/probe_gen_boss_direct.lua so diff_boss.py can byte-diff
-- spawn (ObjType/X/Y/HP) + (later) CHR/PAL. NES warp = poke level/room +
-- force GameMode 6→5 (the proven path in probe_nes_known_bosses.lua).
--
-- NES RAM is direct (domain "RAM", no $8000 offset — this is the real
-- NES). Per RULE V3: enumerate domains live, capture every domain in full.
--
-- diff_boss.py NES contract per boss dir:
--   wram.bin (2KB $0000-$07FF), oam.bin (256B), palram.bin (32B $3F00),
--   ciram.bin (2KB nametables), vram_chr.bin (8KB CHR-RAM — Z1 is CHR-RAM,
--   patterns live in NesHawk "VRAM" domain per RULE V3), state.txt, png.
--
-- Output: $CODEX_BIZHAWK_ROOT/nes_boss_direct/<name>/...

local OUT = (os.getenv("CODEX_BIZHAWK_ROOT") or "C:\\tmp") .. "/nes_boss_direct"
os.execute('if not exist "' .. OUT:gsub("/","\\") .. '" mkdir "' .. OUT:gsub("/","\\") .. '"')

-- ---- Domain enumeration (RULE V3 rule 1). ----
local DOMS = memory.getmemorydomainlist()
local function has(name) for _,d in ipairs(DOMS) do if d==name then return true end end return false end
local RAM   = has("RAM") and "RAM" or (has("WRAM") and "WRAM" or "RAM")
-- CHR-RAM: NesHawk exposes Z1 patterns as "VRAM" (no "CHR" domain).
local CHR   = has("VRAM") and "VRAM" or (has("CHR VRAM") and "CHR VRAM" or nil)
-- PALRAM / OAM / nametables: prefer dedicated domains, fall back to PPU Bus.
local PAL   = has("PALRAM") and "PALRAM" or (has("PPU Bus") and "PPU Bus" or nil)
local OAMD  = has("OAM") and "OAM" or nil
local CIRAM = has("CIRAM (nametables)") and "CIRAM (nametables)"
           or (has("CIRAM") and "CIRAM" or (has("PPU Bus") and "PPU Bus" or nil))

local function R(a)   return memory.read_u8(a, RAM) end
local function W(a,v) memory.write_u8(a, v, RAM) end
local function idle(n) for _=1,n do emu.frameadvance() end end
local function press(b,h,s) h=h or 4; s=s or 30
  for _=1,h do joypad.set({[b]=true},1); emu.frameadvance() end
  joypad.set({},1); for _=1,s do emu.frameadvance() end
end

-- Canonical NES boss rooms (docs/audit/boss_room_ids.md) — same order/ids
-- as the Genesis probe so diff_boss.py matches dirs by name.
local bosses = {
  {name="aquamentus",   lv=1, rm=0x35, otype=0x3D},
  {name="dodongo",      lv=2, rm=0x73, otype=0x31},
  {name="manhandla",    lv=3, rm=0x0F, otype=0x3C},
  {name="gleeok_2head", lv=4, rm=0x45, otype=0x43},
  {name="digdogger",    lv=5, rm=0x06, otype=0x38},
  {name="gohma_red",    lv=6, rm=0x0F, otype=0x33},
  {name="aquamentus_2", lv=7, rm=0x23, otype=0x3D},
  {name="gleeok_4head", lv=8, rm=0x1F, otype=0x45},
  {name="patra_red",    lv=9, rm=0x1E, otype=0x47},
  {name="ganon",        lv=9, rm=0x1F, otype=0x3E},
}

-- ---- Boot + start a game (proven nav from probe_nes_known_bosses). ----
idle(360); press("Start",4,60)
press("Down",4,20); press("Down",4,20); press("Down",4,20); press("Start",4,60)
press("Start",4,60)
for _=1,5 do press("Down",4,8) end
for _=1,5 do press("Right",4,8) end
press("Start",4,60)
for _=1,5 do press("Up",4,12) end
press("Start",4,180); idle(180)

do
  local f = assert(io.open(OUT .. "/domains.txt", "w"))
  f:write("RAM="..RAM.." CHR="..tostring(CHR).." PAL="..tostring(PAL)..
          " OAM="..tostring(OAMD).." CIRAM="..tostring(CIRAM).."\n")
  for _,d in ipairs(DOMS) do f:write(d.."\n") end
  f:close()
end

local function dump_bin(path, domain, base, n)
  if not domain then return end
  local f = assert(io.open(path, "wb"), "open "..path)
  for a=0,n-1 do f:write(string.char(memory.read_u8(base+a, domain))) end
  f:close()
end

local function dump_state(dir, b)
  local f = assert(io.open(dir.."/state.txt", "w"))
  f:write(string.format("boss=%s level=$%02X room=$%02X expect_otype=$%02X\n",
    b.name, b.lv, b.rm, b.otype))
  f:write(string.format("actual Level $10=$%02X RoomId $EB=$%02X GameMode $12=$%02X BossRoomId $6BBC=$%02X\n",
    R(0x10), R(0xEB), R(0x12), R(0x6BBC)))
  f:write("Slots 0..15 (s: type x y dir state hp attr) — ObjType nonzero:\n")
  local any=false
  for s=0,15 do
    local t=R(0x034F+s)
    if t~=0 and t~=0xFF then any=true
      f:write(string.format("  s%02d t=$%02X x=$%02X y=$%02X dir=$%02X st=$%02X hp=$%02X attr=$%02X\n",
        s, t, R(0x0070+s), R(0x0084+s), R(0x008C+s), R(0x00AC+s), R(0x0485+s), R(0x04BF+s)))
    end
  end
  if not any then f:write("  (no nonzero ObjType)\n") end
  f:close()
end

for _, b in ipairs(bosses) do
  local dir = OUT .. "/" .. b.name
  os.execute('if not exist "' .. dir:gsub("/","\\") .. '" mkdir "' .. dir:gsub("/","\\") .. '"')
  -- Stage room load: set pos + level/room, force mode 6 (load) then 5 (play).
  W(0x0070, 0x78); W(0x0084, 0x80); W(0x0098, 0x08)
  W(0x0010, b.lv); W(0x00EB, b.rm); W(0x0012, 0x06)
  idle(180)
  W(0x00EB, b.rm); W(0x0010, b.lv); W(0x0012, 0x05)
  W(0x0070, 0x78); W(0x0084, 0x80)
  idle(150)

  client.screenshot(dir .. "/screen.png")
  dump_state(dir, b)
  dump_bin(dir .. "/wram.bin",     RAM,   0x0000, 0x0800)
  dump_bin(dir .. "/oam.bin",      OAMD,  0x0000, 0x0100)
  dump_bin(dir .. "/palram.bin",   PAL,   (PAL=="PPU Bus") and 0x3F00 or 0x0000, 0x20)
  dump_bin(dir .. "/ciram.bin",    CIRAM, (CIRAM=="PPU Bus") and 0x2000 or 0x0000, 0x0800)
  dump_bin(dir .. "/vram_chr.bin", CHR,   0x0000, 0x2000)
end

print("wrote " .. OUT)
client.exit()
