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
local SETTLE_FRAMES = 240
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
-- NES color → Gen CRAM word table. Extracted live from
-- data/misc/palettes.c (first 64 colors × 2 BE bytes).
-- Inverse used for Gen-CRAM → NES-color reverse-translation.
local k_nes_to_cram = {
  [0x00]=0x0888, [0x01]=0x0E00, [0x02]=0x0A00, [0x03]=0x0A24,
  [0x04]=0x0808, [0x05]=0x020A, [0x06]=0x002A, [0x07]=0x0028,
  [0x08]=0x0044, [0x09]=0x0080, [0x0A]=0x0060, [0x0B]=0x0060,
  [0x0C]=0x0640, [0x0D]=0x0000, [0x0E]=0x0000, [0x0F]=0x0000,
  [0x10]=0x0AAA, [0x11]=0x0E80, [0x12]=0x0E60, [0x13]=0x0E46,
  [0x14]=0x0C0C, [0x15]=0x060C, [0x16]=0x004E, [0x17]=0x026C,
  [0x18]=0x008A, [0x19]=0x00A0, [0x1A]=0x00A0, [0x1B]=0x04A0,
  [0x1C]=0x0880, [0x1D]=0x0000, [0x1E]=0x0000, [0x1F]=0x0000,
  [0x20]=0x0EEE, [0x21]=0x0EA4, [0x22]=0x0E86, [0x23]=0x0E88,
  [0x24]=0x0E8E, [0x25]=0x086E, [0x26]=0x068E, [0x27]=0x04AE,
  [0x28]=0x00AE, [0x29]=0x02EA, [0x2A]=0x06C6, [0x2B]=0x08E6,
  [0x2C]=0x0CC0, [0x2D]=0x0888, [0x2E]=0x0000, [0x2F]=0x0000,
  [0x30]=0x0EEE, [0x31]=0x0ECA, [0x32]=0x0EAA, [0x33]=0x0EAC,
  [0x34]=0x0EAE, [0x35]=0x0AAE, [0x36]=0x0ACE, [0x37]=0x0ACE,
  [0x38]=0x08CE, [0x39]=0x08EC, [0x3A]=0x0AEA, [0x3B]=0x0CEA,
  [0x3C]=0x0EE0, [0x3D]=0x0ECE, [0x3E]=0x0000, [0x3F]=0x0000,
}

local k_cram_to_nes = nil
local function cram_to_nes(cram_word)
  if k_cram_to_nes == nil then
    k_cram_to_nes = {}
    -- Build inverse. Multiple NES colors map to same CRAM word.
    -- Canonical PALRAM uses HIGHER index ($30 white, $37 yellow,
    -- $16 red, $0F black). Iterate $00→$3F so later (higher) wins.
    for n = 0x00, 0x3F do
      local cw = k_nes_to_cram[n]
      if cw then k_cram_to_nes[cw] = n end
    end
    k_cram_to_nes[0x0000] = 0x0F  -- canonical universal black
    k_cram_to_nes[0x0888] = 0x00  -- bg-black variant ($00 over $2D)
    -- $36 and $37 both map to $0ACE. NES OW uses $37 at sub-pal 2/3
    -- yellow-green positions ($3F0A/$3F0E). Prefer $37.
    k_cram_to_nes[0x0ACE] = 0x37
  end
  if k_cram_to_nes[cram_word] then return k_cram_to_nes[cram_word] end
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
  -- Force ObjDir=$08 (UP) so AssignObjSpawnPositions picks list 3
  -- consistently. Matches NES probe — both pick same list.
  W(0x0098, 0x08)
  local scene = (level == 0) and 0 or 1
  memory.write_u8(PROBE_CTRL + 0, PROBE_ARM0, "68K RAM")
  memory.write_u8(PROBE_CTRL + 1, PROBE_ARM1, "68K RAM")
  memory.write_u8(PROBE_CTRL + 3, scene,      "68K RAM")
  memory.write_u8(PROBE_CTRL + 4, level,      "68K RAM")
  memory.write_u8(PROBE_CTRL + 5, 0,          "68K RAM")
  memory.write_u8(PROBE_CTRL + 6, room,       "68K RAM")
  memory.write_u8(PROBE_CTRL + 7, 0x5A,       "68K RAM")
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
  -- Gen layout per src/game/world/bg_palette.c:
  --   PAL0 [0..15] = NES BG palram bytes 0..15
  --   PAL1 [0..15] = NES SPR palram bytes 16..31 (initial load from static palram)
  --   PAL2 [0..3]  = NES SPR sub-pal 3 (per-room patched — overrides $3F1C..F)
  --   PAL3 [0..3]  = NES SPR sub-pal 2 (red ramp — overrides $3F18..B)
  -- For NES PALRAM equivalence: $3F18..B = PAL3, $3F1C..F = PAL2 (post-patch).
  out:write("\n[PALRAM]\n")
  out:write("# reverse-translated; sub-pals 2/3 read from PAL3/PAL2 (live patched)\n")
  -- Helper: read NES color at logical PALRAM index
  local function read_palram(i)
    local cram_idx
    if i < 16 then
      cram_idx = i  -- BG: PAL0
    elseif i >= 24 and i < 28 then
      cram_idx = 48 + (i - 24)  -- sub-pal 2 → PAL3[0..3]
    elseif i >= 28 then
      cram_idx = 32 + (i - 28)  -- sub-pal 3 → PAL2[0..3]
    else
      cram_idx = 16 + (i - 16)  -- sub-pal 0/1 → PAL1[0..7]
    end
    return CRAM_w(cram_idx)
  end
  for i = 0, 31 do
    local cram_w = read_palram(i)
    local nes_col = cram_to_nes(cram_w)
    -- SPR universal-mirror slots: NES uses $00 not $0F at $3F10/14/18/1C
    if (i == 16 or i == 20 or i == 24 or i == 28) and nes_col == 0x0F then
      nes_col = 0x00
    end
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

  -- [OAM] Gen SAT decomposed to NES OAM format (oam00..63).
  -- NES OAM byte format: y / tile / attr (vfh--pal2) / x
  -- Gen SAT word format: Y(16) SIZE+LINK(16) PRI+PAL+FV+FH+TILE(16) X(16)
  -- Convert each populated SAT entry to NES OAM key. NES has 64 OAM
  -- slots so we truncate to first 64.
  out:write("\n[OAM]\n")
  out:write("# Gen SAT decomposed to NES-OAM 4-byte equiv (y/tile/attr/x)\n")
  -- SAT base = $F400 per RoomRom/src/main.c:618 VDP_setSpriteListAddress.
  local SAT_BASE = 0xF400
  out:write(string.format("# SAT_BASE=$%04X\n", SAT_BASE))
  local oam_idx = 0
  for i = 0, 79 do
    if oam_idx >= 64 then break end
    local y    = memory.read_u16_be(SAT_BASE + i*8 + 0, "VRAM")
    local pat  = memory.read_u16_be(SAT_BASE + i*8 + 4, "VRAM")
    local x    = memory.read_u16_be(SAT_BASE + i*8 + 6, "VRAM")
    local pal      = (pat >> 13) & 0x03
    local h_flip   = (pat >> 11) & 0x01
    local v_flip   = (pat >> 12) & 0x01
    local prio_gen = (pat >> 15) & 0x01
    -- NES attr: bit5=behind-bg (Gen prio inverse), bit6=hflip, bit7=vflip, bits 0-1=pal
    -- Gen pal 0..3 maps to NES sub-pal 0..3 (lossy: PAL2=spal3, PAL3=spal2)
    local nes_pal
    if pal == 0 then nes_pal = 0
    elseif pal == 1 then nes_pal = 0  -- PAL1 = Link sub-pal 0 (route 0)
    elseif pal == 2 then nes_pal = 3  -- PAL2 = sub-pal 3 (Blue Moblin)
    elseif pal == 3 then nes_pal = 2  -- PAL3 = sub-pal 2 (red)
    end
    local nes_attr = nes_pal | (v_flip << 7) | (h_flip << 6) | (((1 - prio_gen) & 0x01) << 5)
    local nes_y    = y & 0xFF
    local nes_tile = pat & 0xFF
    local nes_x    = x & 0xFF
    out:write(string.format("oam%02d=y:$%02X t:$%02X a:$%02X x:$%02X pal:%d\n",
      oam_idx, nes_y, nes_tile, nes_attr, nes_x, nes_pal))
    oam_idx = oam_idx + 1
  end
  while oam_idx < 64 do
    out:write(string.format("oam%02d=y:$F8 t:$00 a:$00 x:$00 pal:0\n", oam_idx))
    oam_idx = oam_idx + 1
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
  -- OW (128 rooms) + UW L1..L9 (128 rooms each = 1152 max; ~636 valid)
  for room = 0, 127 do capture_room(domains, 0, room) end
  for lv = 1, 9 do
    for room = 0, 127 do capture_room(domains, lv, room) end
  end
else
  capture_room(domains, SINGLE_LV, SINGLE_RM)
end

local done = io.open(OUT_BASE .. "/SCAN_COMPLETE", "w")
if done then done:write("done\n"); done:close() end
print("Gen scan complete.")
client.exit()
