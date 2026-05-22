-- probe_enemy_full_dump.lua — comprehensive per-enemy state dump.
-- ONE probe. Dumps EVERYTHING per enemy: full RAM, OAM, SAT, CRAM, VRAM
-- enemy CHR region, all object slots × all cells, audio, Link state,
-- registers, frame counter, screenshot. Per enemy: 4 files (bin/json/png/txt).
--
-- Cycles all in-scope enemy types. For each:
--   1. Ensure correct scene (OW for OW-native, MODE-toggle to UW for UW)
--   2. Arm $FF77D0 spawn
--   3. Wait 60f settle
--   4. Dump everything to C:/tmp/enemy_dumps/$XX_<name>/
--   5. Repeat

local function R(o) return memory.read_u8(o, "68K RAM") end
local function W(o,v) memory.write_u8(o, v, "68K RAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end
local function press(b, frames)
  for _ = 1, frames do joypad.set({[b]=true}, 1); emu.frameadvance() end
  joypad.set({}, 1); emu.frameadvance()
end

local ROOT = "C:/tmp/enemy_dumps/"
os.execute("mkdir " .. ROOT:gsub("/", "\\") .. " 2>NUL")

-- Enemy types + habitat (0=OW, 1=UW L1)
local TYPES = {
  {0x01, "BlueLynel",    0},  {0x02, "RedLynel",     0},
  {0x03, "BlueMoblin",   0},  {0x04, "RedMoblin",    0},
  {0x05, "BlueGoriya",   1},  {0x06, "RedGoriya",    1},
  {0x0B, "BlueDarknut",  1},  {0x0C, "RedDarknut",   1},
  {0x0F, "BlueLeever",   0},  {0x10, "RedLeever",    0},
  {0x11, "Zora",         0},
  {0x12, "Vire",         1},
  {0x13, "Zol",          1},  {0x14, "RedZol",       1},  {0x15, "Gel",          1},
  {0x16, "PolsVoice",    1},  {0x17, "LikeLike",     1},
  {0x1A, "Peahat",       0},
  {0x1B, "BlueKeese",    1},  {0x1C, "RedKeese",     1},  {0x1D, "BlackKeese",   1},
  {0x1E, "Armos",        0},
  {0x21, "Ghini",        0},  {0x22, "FlyingGhini",  1},
  {0x27, "Wallmaster",   1},  {0x28, "Rope",         1},
  {0x2A, "Stalfos",      1},
  {0x2B, "BlueBubble",   1},  {0x2C, "RedBubble",    1},  {0x2D, "BlueBubble2",  1},
  {0x30, "Gibdo",        1},
  {0x3F, "GuardFire",    0},  {0x40, "StandingFire", 1},
  -- Boss family
  {0x31, "Dodongo1",     1},  {0x32, "Dodongo2",     1},
  {0x33, "BlueGohma",    1},  {0x34, "RedGohma",     1},
  {0x38, "DigdoggerL",   1},  {0x39, "DigdoggerS",   1},
  {0x3A, "RedLamnola",   1},  {0x3B, "BlueLamnola",  1},
  {0x3C, "Manhandla",    1},
  {0x3D, "Aquamentus",   1},
  {0x3E, "Ganon",        1},
  {0x41, "Moldorm",      1},
  {0x47, "RedPatra",     1},  {0x48, "BluePatra",    1},
}

-- ========== Big dump function: dumps EVERYTHING ==========
local function full_dump(out_dir, label)
  os.execute("mkdir " .. out_dir:gsub("/", "\\") .. " 2>NUL")

  -- Screenshot
  client.screenshot(out_dir .. "/screenshot.png")

  -- Save full state (BizHawk savestate, can be reloaded)
  savestate.save(out_dir .. "/savestate.State")

  -- Full NES RAM mirror at $FF8000..$FF87FF (2048 bytes)
  local nes_ram_path = out_dir .. "/nes_ram.bin"
  local f = io.open(nes_ram_path, "wb")
  for off = 0, 0x7FF do f:write(string.char(R(0x8000 + off))) end
  f:close()

  -- Audio driver region $FFE000..$FFE0FF (256 bytes)
  local aud_f = io.open(out_dir .. "/audio_driver.bin", "wb")
  for off = 0xE000, 0xE0FF do aud_f:write(string.char(R(off))) end
  aud_f:close()

  -- VRAM (entire 64KB)
  local vram_path = out_dir .. "/vram.bin"
  local vram_f = io.open(vram_path, "wb")
  for off = 0, 0xFFFF do vram_f:write(string.char(memory.read_u8(off, "VRAM"))) end
  vram_f:close()

  -- CRAM (128 bytes = 64 colors × 2 bytes)
  local cram_f = io.open(out_dir .. "/cram.bin", "wb")
  for off = 0, 0x7F do cram_f:write(string.char(memory.read_u8(off, "CRAM"))) end
  cram_f:close()

  -- VSRAM
  local vsram_f = io.open(out_dir .. "/vsram.bin", "wb")
  for off = 0, 0x4F do vsram_f:write(string.char(memory.read_u8(off, "VSRAM"))) end
  vsram_f:close()

  -- Decoded JSON: per-slot object cells + Link + audio + scene + frame
  local j = io.open(out_dir .. "/state.json", "w")
  j:write("{\n")
  j:write(string.format('  "label": "%s",\n', label))
  j:write(string.format('  "frame": %d,\n', emu.framecount()))
  j:write(string.format('  "game_mode": "$%02X",\n', R(0x8012)))
  j:write(string.format('  "submode": "$%02X",\n', R(0x8013)))
  j:write(string.format('  "cur_level": "$%02X",\n', R(0x8010)))
  j:write(string.format('  "room_id": "$%02X",\n', R(0x80EB)))
  j:write(string.format('  "frame_counter": "$%02X",\n', R(0x8015)))
  j:write(string.format('  "scene_sentinel": "$%02X",\n', R(0x87E8)))
  j:write(string.format('  "rng_0": "$%02X",\n', R(0x8018)))
  j:write(string.format('  "rng_1": "$%02X",\n', R(0x8019)))
  j:write(string.format('  "rng_2": "$%02X",\n', R(0x801A)))
  j:write(string.format('  "hearts": "$%02X",\n', R(0x866F)))
  j:write(string.format('  "heart_partial": "$%02X",\n', R(0x8670)))
  j:write(string.format('  "btns_pressed": "$%02X",\n', R(0x80F8)))
  j:write(string.format('  "btns_down": "$%02X",\n', R(0x80FA)))
  j:write(string.format('  "raw_joy_lo": "$%02X",\n', R(0x87F0)))
  j:write(string.format('  "raw_joy_hi": "$%02X",\n', R(0x87F1)))
  j:write(string.format('  "music_song_req": "$%02X",\n', R(0xE001)))
  j:write(string.format('  "music_song_cur": "$%02X",\n', R(0xE000)))
  j:write(string.format('  "xgm_owns_chip": "$%02X",\n', R(0xE02C)))
  j:write(string.format('  "link": {"x":"$%02X","y":"$%02X","dir":"$%02X","face":"$%02X"},\n',
    R(0x8070), R(0x8084), R(0x808C), R(0x8098)))
  j:write('  "slots": [\n')
  for s = 1, 11 do
    j:write(string.format('    {"slot":%d,"type":"$%02X","x":"$%02X","y":"$%02X","dir":"$%02X","face":"$%02X","qspd":"$%02X","state":"$%02X","metastate":"$%02X","obj_timer":"$%02X","shoot_timer":"$%02X","wants_shoot":"$%02X","hit_react":"$%02X","shove_dir":"$%02X","shove_dist":"$%02X","hp":"$%02X","inv_mask":"$%02X","attr":"$%02X","anim_cntr":"$%02X","anim_frame":"$%02X","stun_timer":"$%02X","grid_off":"$%02X"}%s\n',
      s,
      R(0x834F+s), R(0x8070+s), R(0x8084+s), R(0x808C+s), R(0x8098+s),
      R(0x83BC+s), R(0x80AC+s), R(0x84D8+s), R(0x8028+s),
      R(0x8451+s), R(0x8412+s), R(0x84F0+s),
      R(0x80C0+s), R(0x80D3+s),
      R(0x8485+s), R(0x84B2+s), R(0x84BF+s),
      R(0x83D0+s), R(0x83E4+s), R(0x803D+s), R(0x8394+s),
      (s == 11) and "" or ","))
  end
  j:write('  ],\n')
  -- OAM mirror dump (256 bytes)
  j:write('  "oam_mirror_hex": "')
  for off = 0x0200, 0x02FF do j:write(string.format("%02x", R(0x8000+off))) end
  j:write('",\n')
  -- SAT first 32 entries (8 bytes each = 256 bytes)
  j:write('  "sat_hex": "')
  for off = 0xF800, 0xF9FF do j:write(string.format("%02x", memory.read_u8(off, "VRAM"))) end
  j:write('",\n')
  -- CRAM dump hex (128 bytes = 64 colors)
  j:write('  "cram_hex": "')
  for off = 0, 0x7F do j:write(string.format("%02x", memory.read_u8(off, "CRAM"))) end
  j:write('"\n')
  j:write("}\n")
  j:close()
end

-- ========== Boot ==========
idle(60)
for _ = 1, 30 do joypad.set({A=true,B=true,C=true},1); emu.frameadvance() end
joypad.set({},1); idle(120)

local current_scene = 0  -- 0 = OW
full_dump(ROOT .. "00_boot_OW", "post-chord OW initial")

-- ========== Main cycle ==========
for _, entry in ipairs(TYPES) do
  local type_id, name, want_scene = entry[1], entry[2], entry[3]

  -- NO scene switch. Stay in OW throughout. Per-enemy dump captures
  -- ALL state so analysis can see if enemy renders wrong in OW context.
  -- (User said: don't TP Link mid-test.)

  -- Force RNG deterministic
  W(0x8018, 0x40)
  for i = 1, 12 do W(0x8018 + i, 0x00) end

  -- Arm spawn at top-center safe position. Always habitat=0 (OW) since
  -- we don't switch scenes. UW enemies will render wrong but data captured.
  local sx, sy = 0x80, 0x88
  W(0x77D0, 0x46) W(0x77D1, 0x58)
  W(0x77D2, type_id) W(0x77D3, sx) W(0x77D4, sy)
  W(0x77D5, 0x01) W(0x77D6, 0x01) W(0x77D7, 0x00) W(0x77D8, 0x77)
  for _ = 1, 8 do emu.frameadvance() end
  W(0x77D0, 0) W(0x77D1, 0)

  -- Settle 60 frames
  for _ = 1, 60 do emu.frameadvance() end

  -- Full dump
  local dir = string.format("%s%02X_%s", ROOT, type_id, name)
  full_dump(dir, string.format("$%02X %s scene=%d", type_id, name, want_scene))
end

-- Final dump
full_dump(ROOT .. "ZZ_final", "after all enemies")

client.exit()
