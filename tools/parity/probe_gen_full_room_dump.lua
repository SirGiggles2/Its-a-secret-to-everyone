-- Plan v5 Phase D1 Gen side: TOTAL state dump per (level, room).
-- Pinned to GPGX (Genplus-gx). Matches probe_nes_full_room_dump.lua
-- output format byte-for-byte where possible.
--
-- NES RAM mirror lives at $FF8000+nes_off in 68K addr space, accessed
-- as "68K RAM" domain at offset $8000+nes_off (domain is 64KB at
-- $FF0000).
--
-- Gen-specific captures:
--   CRAM (128 bytes): palette — reverse-translated to NES color bytes
--   VRAM (64KB): SAT + tiles + nametables
--   VSRAM (80 bytes): scroll
--   Z80 RAM (8KB): audio driver code state

----------------------------------------------------------------------
-- Configuration (must match NES probe)
----------------------------------------------------------------------
-- Phase D1: uses probe-driven warp trigger added to RoomRom/src/main.c
-- (ctrl[3..7] at $FF73F8+3..7). Same code path as in-game warp.
local SCAN_ALL = true   -- full 128 OW + 9*128 UW sweep
local SINGLE_LV  = 0x00
local SINGLE_RM  = 0x73
local OUT_BASE   = "C:/tmp/dual/gen"
local SETTLE_FRAMES = 120
local TRACE_FRAMES  = 0
local PROBE_CTRL = 0x73F8   -- offset within "68K RAM" domain
local PROBE_ARM0 = 0x52     -- 'R'
local PROBE_ARM1 = 0x50     -- 'P'

local NES_BASE = 0x8000  -- 68K RAM offset for NES RAM mirror

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------
local function R(o)   return memory.read_u8(NES_BASE + o, "68K RAM") end
local function W(o,v) memory.write_u8(NES_BASE + o, v, "68K RAM") end
local function CRAM_w(idx) return memory.read_u16_be(idx * 2, "CRAM") end
local function VRAM_b(o) return memory.read_u8(o, "VRAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end
local function safe_set(pad)
  local ok = pcall(function() joypad.set(pad or {}, 1) end)
  if not ok then joypad.set(pad or {}) end
end

local function ensure_dir(path)
  os.execute('cmd /c mkdir "' .. path:gsub('/', '\\') .. '" 2>nul')
end

local function discover_domains()
  local candidates = {
    "68K RAM", "VRAM", "CRAM", "VSRAM", "Z80 RAM",
  }
  local set = {}
  for _, name in ipairs(candidates) do
    local ok, ret = pcall(memory.usememorydomain, name)
    if ok and ret then set[name] = true end
  end
  return set
end

----------------------------------------------------------------------
-- Gen CRAM word -> NES color index reverse-translate
-- Gen CRAM word format: 0000 BBB0 GGG0 RRR0 (12-bit BGR)
-- NES palette is 6-bit; reverse via a 64-entry lookup populated from
-- misc_palettes table. For now build from Gen color → nearest NES.
----------------------------------------------------------------------
local k_nes_to_cram = nil  -- lazy-built
local function build_cram_to_nes_map()
  -- The Gen-side ROM has misc_palettes baked in at known symbol.
  -- For probe, do brute reverse: enumerate 64 NES colors, convert to
  -- Gen CRAM via known formula, build inverse map.
  local nes_palette = {
    -- NES master palette (standard NTSC) in approximate Gen
    -- CRAM 12-bit format. This is the lookup that
    -- roomrom_bg_palette_nes_to_cram uses. Hardcoded from
    -- data/misc/palettes.c.
    [0x00]=0x0888, [0x01]=0x0A00, [0x02]=0x0820, [0x03]=0x0840,
    [0x04]=0x0660, [0x05]=0x0480, [0x06]=0x0080, [0x07]=0x000A,
    [0x08]=0x000C, [0x09]=0x000A, [0x0A]=0x0008, [0x0B]=0x0008,
    [0x0C]=0x0066, [0x0D]=0x0000, [0x0E]=0x0000, [0x0F]=0x0000,
    [0x10]=0x0CCC, [0x11]=0x0E40, [0x12]=0x0E20, [0x13]=0x0C80,
    [0x14]=0x0A8A, [0x15]=0x080E, [0x16]=0x00AE, [0x17]=0x028C,
    [0x18]=0x044A, [0x19]=0x0060, [0x1A]=0x0080, [0x1B]=0x008A,
    [0x1C]=0x008C, [0x1D]=0x0000, [0x1E]=0x0000, [0x1F]=0x0000,
    [0x20]=0x0EEE, [0x21]=0x0E84, [0x22]=0x0E66, [0x23]=0x0E48,
    [0x24]=0x0E6E, [0x25]=0x0C2E, [0x26]=0x06AE, [0x27]=0x08CE,
    [0x28]=0x08EE, [0x29]=0x002E, [0x2A]=0x02CE, [0x2B]=0x06EC,
    [0x2C]=0x0EEC, [0x2D]=0x0000, [0x2E]=0x0000, [0x2F]=0x0000,
    [0x30]=0x0EEE, [0x31]=0x0ECA, [0x32]=0x0EAA, [0x33]=0x0EAC,
    [0x34]=0x0EAE, [0x35]=0x0EAE, [0x36]=0x0CCE, [0x37]=0x0ACE,
    [0x38]=0x0ACE, [0x39]=0x0AEC, [0x3A]=0x0AEC, [0x3B]=0x0CEE,
    [0x3C]=0x0EEC, [0x3D]=0x0000, [0x3E]=0x0000, [0x3F]=0x0000,
  }
  local map = {}
  for nes, gen in pairs(nes_palette) do
    map[gen] = nes
  end
  return map
end

local function cram_to_nes(cram_word)
  if k_nes_to_cram == nil then k_nes_to_cram = build_cram_to_nes_map() end
  -- Exact match first
  if k_nes_to_cram[cram_word] then return k_nes_to_cram[cram_word] end
  -- Fall back: $FF marker for unknown (printed as raw hex)
  return 0xFF
end

----------------------------------------------------------------------
-- Boot to gameplay via A+B+C chord (Debug.md PHASE_TITLE_DISPLAY)
----------------------------------------------------------------------
local function boot_to_gameplay()
  for _ = 1, 60 do emu.frameadvance() end
  for _ = 1, 30 do
    safe_set({A=true, B=true, C=true,
              ["P1 A"]=true, ["P1 B"]=true, ["P1 C"]=true})
    emu.frameadvance()
  end
  safe_set({})
  for _ = 1, 120 do emu.frameadvance() end
end

----------------------------------------------------------------------
-- Warp via NES RAM mirror write
----------------------------------------------------------------------
local function warp(level, room)
  -- Arm probe-control + write warp fields + trigger.
  -- ctrl layout: [0]=ARM0 'R', [1]=ARM1 'P', [2]=flags,
  -- [3]=dest_scene, [4]=dest_level, [5]=dest_quest,
  -- [6]=dest_room_id, [7]=$5A trigger.
  -- Scene: 0=OW, 1=UW. Map level 0 -> OW, else UW with level.
  local scene = (level == 0) and 0 or 1
  memory.write_u8(PROBE_CTRL + 0, PROBE_ARM0, "68K RAM")
  memory.write_u8(PROBE_CTRL + 1, PROBE_ARM1, "68K RAM")
  memory.write_u8(PROBE_CTRL + 3, scene,      "68K RAM")
  memory.write_u8(PROBE_CTRL + 4, level,      "68K RAM")
  memory.write_u8(PROBE_CTRL + 5, 0,          "68K RAM")  -- quest 0
  memory.write_u8(PROBE_CTRL + 6, room,       "68K RAM")
  memory.write_u8(PROBE_CTRL + 7, 0x5A,       "68K RAM")  -- fire
  -- Wait for ack (ctrl[7] cleared) then settle for scene load
  for _ = 1, 30 do
    emu.frameadvance()
    if memory.read_u8(PROBE_CTRL + 7, "68K RAM") == 0 then break end
  end
  idle(SETTLE_FRAMES)
end

----------------------------------------------------------------------
-- Per-room static dump (matches NES probe format)
----------------------------------------------------------------------
local function dump_static(out, domains, level, room)
  out:write("# Plan v5 Phase D1 Gen dump\n")
  out:write(string.format("# target lv=$%02X rm=$%02X actual lv=$%02X rm=$%02X\n",
    level, room, R(0x0010), R(0x00EB)))

  -- [SCENE]
  out:write("\n[SCENE]\n")
  out:write(string.format("gm=$%02X\n", R(0x0012)))
  out:write(string.format("subm=$%02X\n", R(0x0013)))
  out:write(string.format("lv=$%02X\n", R(0x0010)))
  out:write(string.format("rm=$%02X\n", R(0x00EB)))
  out:write(string.format("fc=$%02X\n", R(0x0015)))
  out:write(string.format("rng=$%02X\n", R(0x0019)))
  out:write(string.format("invclk=$%02X\n", R(0x066C)))
  out:write(string.format("first_unwalk=$%02X\n", R(0x034A)))
  out:write(string.format("song_request=$%02X\n", R(0x0608)))
  out:write(string.format("bomb_count=$%02X\n", R(0x0658)))
  out:write(string.format("rupee_count=$%02X\n", R(0x066D)))
  out:write(string.format("key_count=$%02X\n", R(0x066E)))

  -- [LINK]
  out:write("\n[LINK]\n")
  out:write(string.format("x=$%02X\n", R(0x0070)))
  out:write(string.format("y=$%02X\n", R(0x0084)))
  out:write(string.format("dir=$%02X\n", R(0x008C)))
  out:write(string.format("state=$%02X\n", R(0x00AC)))
  out:write(string.format("anim=$%02X\n", R(0x03E4)))
  out:write(string.format("hp_cur=$%02X\n", R(0x066F)))
  out:write(string.format("hp_max=$%02X\n", R(0x066B)))
  out:write(string.format("hp_partial=$%02X\n", R(0x0670)))
  out:write(string.format("inv_timer=$%02X\n", R(0x04F0)))

  -- [PALRAM] reverse-translated from Gen CRAM.
  -- Gen layout:
  --   PAL0 [0..15] = NES BG palram bytes 0..15 (per load_palram_full)
  --   PAL1 [0..15] = NES SPR palram bytes 16..31
  -- Caveat: PAL2/PAL3 not represented in NES PALRAM format (Gen-only).
  out:write("\n[PALRAM]\n")
  out:write("# reverse-translated from Gen CRAM PAL0+PAL1\n")
  for i = 0, 31 do
    local pal_bank = (i < 16) and 0 or 1
    local slot     = (i % 16)
    local cram_idx = pal_bank * 16 + slot
    local cram_w   = CRAM_w(cram_idx)
    local nes_col  = cram_to_nes(cram_w)
    if nes_col == 0xFF then
      out:write(string.format("$3F%02X=?CRAM:%04X\n", i, cram_w))
    else
      out:write(string.format("$3F%02X=$%02X\n", i, nes_col))
    end
  end
  out:write("\n[CRAM_RAW]\n")
  for p = 0, 3 do
    out:write(string.format("PAL%d=", p))
    for s = 0, 15 do
      out:write(string.format("%04X ", CRAM_w(p*16 + s)))
    end
    out:write("\n")
  end

  -- [OAM] Gen SAT decomposed to NES OAM format
  -- SGDK SAT typically at VRAM $F000; 4 words per entry × 80 entries
  out:write("\n[OAM]\n")
  out:write("# Gen SAT decomposed (NES-OAM equiv: y/tile/attr/x per sprite)\n")
  local SAT_BASE = 0xF000
  for i = 0, 79 do
    local y    = memory.read_u16_be(SAT_BASE + i*8 + 0, "VRAM")
    local size = memory.read_u16_be(SAT_BASE + i*8 + 2, "VRAM")
    local pat  = memory.read_u16_be(SAT_BASE + i*8 + 4, "VRAM")
    local x    = memory.read_u16_be(SAT_BASE + i*8 + 6, "VRAM")
    local pal  = (pat >> 13) & 0x03
    local link = size & 0x7F
    out:write(string.format("sat%02d=y:%04X size:%04X pat:%04X x:%04X pal:%d link:%d\n",
      i, y, size, pat, x, pal, link))
  end

  -- [SLOTS] same shape as NES
  out:write("\n[SLOTS]\n")
  for s = 1, 11 do
    local t = R(0x034F + s)
    out:write(string.format("s%d=t:$%02X x:$%02X y:$%02X dir:$%02X " ..
      "qspd:$%02X frac:$%02X grid:$%02X mvTm:$%02X " ..
      "st:$%02X ms:$%02X tm:$%02X hp:$%02X inv:$%02X " ..
      "attr:$%02X anim:$%02X df:$%02X shvd:$%02X shvt:$%02X " ..
      "stun:$%02X shTm:$%02X wTSh:$%02X hit:$%02X inDir:$%02X\n",
      s, t,
      R(0x0070+s), R(0x0084+s), R(0x008C+s),
      R(0x03BC+s), R(0x03A8+s), R(0x0394+s), R(0x0028+s),
      R(0x00AC+s), R(0x0405+s), R(0x0028+s), R(0x0485+s), R(0x04F0+s),
      R(0x04BF+s), R(0x03E4+s), R(0x03D0+s),
      R(0x00C0+s), R(0x00D3+s),
      R(0x003D+s), R(0x0451+s), R(0x0412+s), R(0x04B2+s), R(0x03F8+s)))
  end

  -- [BG_A_PLANE] subset of nametable A (BG main plane)
  -- SGDK default plane A typically at VRAM $C000; 64x32 = 4KB of words
  out:write("\n[BG_A_PLANE]\n")
  local BGA_BASE = 0xC000
  for row = 0, 27 do  -- 28 visible rows
    out:write(string.format("bga_r%02d=", row))
    for col = 0, 31 do
      local word = memory.read_u16_be(BGA_BASE + (row * 64 + col) * 2, "VRAM")
      out:write(string.format("%04X", word))
    end
    out:write("\n")
  end

  -- [VRAM_TILE_SCENE_OBJ] first 114 tiles starting at SCENE_OBJ_TILE_BASE
  -- SCENE_OBJ = SPR_BASE(533) + 44 = 577. 114 tiles × 32 bytes = 3648 bytes.
  out:write("\n[VRAM_TILE_SCENE_OBJ]\n")
  local SCENE_OBJ_BASE = 577 * 32  -- VRAM byte offset
  for tile = 0, 113 do
    out:write(string.format("tile_%03d=", tile))
    for b = 0, 31 do
      out:write(string.format("%02X", VRAM_b(SCENE_OBJ_BASE + tile*32 + b)))
    end
    out:write("\n")
  end

  -- [CPU_REGS_GEN]
  out:write("\n[CPU_REGS_GEN]\n")
  local regs = {"D0", "D1", "D2", "D3", "D4", "D5", "D6", "D7",
                "A0", "A1", "A2", "A3", "A4", "A5", "A6", "A7",
                "USP", "SSP", "SR", "PC"}
  for _, r in ipairs(regs) do
    local ok, v = pcall(emu.getregister, r)
    if ok then
      out:write(string.format("%s=$%08X\n", r, v))
    else
      out:write(string.format("%s=ERR\n", r))
    end
  end

  -- [VSRAM] scroll
  out:write("\n[VSRAM]\n")
  if domains["VSRAM"] then
    for i = 0, 39 do
      out:write(string.format("vs%02d=%04X\n", i,
        memory.read_u16_be(i*2, "VSRAM")))
    end
  end

  -- [Z80_RAM] audio driver code state (8KB)
  out:write("\n[Z80_RAM_HEAD]\n")
  if domains["Z80 RAM"] then
    for line = 0, 15 do  -- first 256 bytes only (head)
      out:write(string.format("$%04X=", line*16))
      for i = 0, 15 do
        out:write(string.format("%02X", memory.read_u8(line*16 + i, "Z80 RAM")))
      end
      out:write("\n")
    end
  end

  -- [DOMAINS_DETECTED]
  out:write("\n[DOMAINS_DETECTED]\n")
  for name, _ in pairs(domains) do
    out:write(string.format("  %s\n", name))
  end

  -- [RAM_FULL] NES mirror 2KB
  out:write("\n[RAM_FULL]\n")
  for line = 0, 127 do
    out:write(string.format("$%04X=", line*16))
    for i = 0, 15 do
      out:write(string.format("%02X", R(line*16 + i)))
    end
    out:write("\n")
  end

  out:write("\n# SCAN_COMPLETE\n")
end

----------------------------------------------------------------------
-- Per-room capture orchestration
----------------------------------------------------------------------
local function capture_room(domains, level, room)
  warp(level, room)
  local actual_lv = R(0x0010)
  local actual_rm = R(0x00EB)
  local tag = string.format("lv%02X_rm%02X", actual_lv, actual_rm)
  local dir = string.format("%s/%s", OUT_BASE, tag)
  ensure_dir(dir)
  client.screenshot(string.format("%s/%s.png", dir, tag))
  client.screenshot(string.format("%s/_all/%s.png", OUT_BASE, tag))

  local static = io.open(dir .. "/static.txt", "w")
  if static then dump_static(static, domains, level, room); static:close() end

  -- Binary dumps
  local cramf = io.open(dir .. "/cram.bin", "wb")
  if cramf then
    for i = 0, 63 do
      local w = CRAM_w(i)
      cramf:write(string.char((w >> 8) & 0xFF))
      cramf:write(string.char(w & 0xFF))
    end
    cramf:close()
  end

  if TRACE_FRAMES > 0 then
    local trace = io.open(dir .. "/trace.txt", "w")
    for tf = 1, TRACE_FRAMES do
      if trace then
        trace:write(string.format("\n[FRAME_%03d]\n", tf))
        trace:write(string.format("rng=$%02X linkx=$%02X linky=$%02X\n",
          R(0x0019), R(0x0070), R(0x0084)))
        for s = 1, 11 do
          local t = R(0x034F + s)
          if t ~= 0 then
            trace:write(string.format("s%d=t:$%02X x:$%02X y:$%02X st:$%02X ms:$%02X anim:$%02X\n",
              s, t, R(0x0070+s), R(0x0084+s), R(0x00AC+s), R(0x0405+s), R(0x03E4+s)))
          end
        end
      end
      emu.frameadvance()
    end
    if trace then trace:close() end
  end
end

----------------------------------------------------------------------
-- Main
----------------------------------------------------------------------
ensure_dir(OUT_BASE)
ensure_dir(OUT_BASE .. "/_all")
boot_to_gameplay()

local domains = discover_domains()
print("Gen domains found:")
for name, _ in pairs(domains) do print("  " .. name) end

if SCAN_ALL then
  for room = 0, 127 do capture_room(domains, 0, room) end
else
  capture_room(domains, SINGLE_LV, SINGLE_RM)
end

local done = io.open(OUT_BASE .. "/SCAN_COMPLETE", "w")
if done then done:write("done\n"); done:close() end
print("Gen scan complete.")
client.exit()
