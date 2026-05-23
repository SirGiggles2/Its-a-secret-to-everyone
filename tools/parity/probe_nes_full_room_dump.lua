-- Plan v5 Phase D1 NES side: TOTAL state dump per (level, room).
-- Pinned to NesHawk (cycle-accurate). Probes all available domains,
-- captures every byte we can reach: PALRAM, OAM, CIRAM, CHR, RAM,
-- CPU regs (via emu.getregister), screenshot at frame 180.
--
-- Single-room mode (default): hardcoded LEVEL/ROOM, dumps to
-- C:/tmp/dual/nes/lv<LV>_rm<RM>/static.txt + screenshots.
--
-- Multi-room mode: set SCAN_ALL=true. Iterates 128 OW rooms then
-- UW L1..L9 × 128 rooms = 1280 total. ~60 min wall-clock.

----------------------------------------------------------------------
-- Configuration
----------------------------------------------------------------------
-- Full sweep matched to Gen probe.
local SCAN_ALL = true
local SINGLE_LV  = 0x00
local SINGLE_RM  = 0x73
local OUT_BASE   = "C:/tmp/dual/nes"
local SETTLE_FRAMES = 120
local TRACE_FRAMES  = 0
local SCREENSHOT_FRAMES = {120}

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------
local function R(o)   return memory.read_u8(o, "RAM") end
local function W(o,v) memory.write_u8(o, v, "RAM") end
local function PAL(o) return memory.read_u8(o, "PALRAM") end
local function OAM(o) return memory.read_u8(o, "OAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end
local function press(b, hold, settle)
  for _=1,hold do joypad.set({[b]=true}, 1); emu.frameadvance() end
  joypad.set({}, 1); for _=1,settle do emu.frameadvance() end
end

local function ensure_dir(path)
  -- Lua-level: just create via os.execute mkdir. Idempotent.
  os.execute('cmd /c mkdir "' .. path:gsub('/', '\\') .. '" 2>nul')
end

local function discover_domains()
  -- Use memory.usememorydomain return value (true/false). pcall
  -- doesn't catch false returns; check explicitly.
  local candidates = {
    "RAM", "PALRAM", "OAM", "CIRAM (nametables)", "CIRAM",
    "CHR", "System Bus",
  }
  local set = {}
  for _, name in ipairs(candidates) do
    local ok, ret = pcall(memory.usememorydomain, name)
    if ok and ret then set[name] = true end
  end
  return set
end

local function safe_read_domain(addr, domain, set)
  if not set[domain] then return nil end
  return memory.read_u8(addr, domain)
end

----------------------------------------------------------------------
-- Boot to gameplay (file-select dance)
----------------------------------------------------------------------
local function boot_to_gameplay()
  idle(360); press("Start", 4, 60)
  press("Down",4,20); press("Down",4,20); press("Down",4,20)
  press("Start",4,60); press("Start",4,60)
  for _=1,5 do press("Down",4,8) end
  for _=1,5 do press("Right",4,8) end
  press("Start",4,60)
  for _=1,5 do press("Up",4,12) end
  press("Start",4,180); idle(180)
end

----------------------------------------------------------------------
-- Warp via RAM write
----------------------------------------------------------------------
local function warp(level, room)
  -- Pre-center Link BEFORE Mode 6 trigger.
  W(0x0070, 0x78)
  W(0x0084, 0x80)
  -- Force ObjDir=$08 (UP) so AssignObjSpawnPositions picks list 3
  -- consistently. Both probes do this so spawn-pos parity holds.
  W(0x0098, 0x08)
  W(0x0010, level)
  W(0x00EB, room)
  W(0x0012, 0x06)
  idle(SETTLE_FRAMES)
  W(0x0070, 0x78)
  W(0x0084, 0x80)
  W(0x00EB, room)
end

----------------------------------------------------------------------
-- Per-room snapshot dump
----------------------------------------------------------------------
local function dump_static(out, domains, level, room)
  out:write("# Plan v5 Phase D1 NES dump\n")
  out:write(string.format("# target lv=$%02X rm=$%02X actual lv=$%02X rm=$%02X\n",
    level, room, R(0x0010), R(0x00EB)))
  out:write(string.format("# BizHawk core domains: %d available\n", 0))

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

  -- [PALRAM]
  out:write("\n[PALRAM]\n")
  for i = 0, 31 do
    out:write(string.format("$3F%02X=$%02X\n", i, PAL(i)))
  end

  -- [OAM] full 64 sprites
  out:write("\n[OAM]\n")
  for i = 0, 63 do
    local y = OAM(i*4 + 0)
    local t = OAM(i*4 + 1)
    local a = OAM(i*4 + 2)
    local x = OAM(i*4 + 3)
    out:write(string.format("oam%02d=y:$%02X t:$%02X a:$%02X x:$%02X pal:%d\n",
      i, y, t, a, x, a & 0x03))
  end

  -- [SLOTS] enemy state for 12 slots × full ObjVars range
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

  -- [CIRAM] nametable + attribute table dumps
  out:write("\n[CIRAM]\n")
  local ciram_domain
  for _, n in ipairs({"CIRAM (nametables)", "CIRAM"}) do
    if domains[n] then ciram_domain = n; break end
  end
  if ciram_domain then
    out:write(string.format("# domain=%s\n", ciram_domain))
    for nt = 0, 1 do
      out:write(string.format("# NT%d ($%04X..)\n", nt, 0x2000 + nt*0x400))
      local base = nt * 0x400
      for row = 0, 29 do
        out:write(string.format("nt%d_r%02d=", nt, row))
        for col = 0, 31 do
          out:write(string.format("%02X", memory.read_u8(base + row*32 + col, ciram_domain)))
        end
        out:write("\n")
      end
      out:write(string.format("nt%d_attr=", nt))
      for i = 0, 63 do
        out:write(string.format("%02X", memory.read_u8(base + 960 + i, ciram_domain)))
      end
      out:write("\n")
    end
  else
    out:write("# CIRAM domain not available\n")
  end

  -- [CHR] currently-mapped 8KB pattern table — only if CHR domain
  -- actually exists. MMC1 carts (Z1) may expose only "CHR" (not "CHR VROM").
  out:write("\n[CHR_WINDOW]\n")
  if domains["CHR"] then
    out:write("# domain=CHR\n")
    for line = 0, 511 do
      out:write(string.format("$%04X=", line*16))
      for i = 0, 15 do
        out:write(string.format("%02X", memory.read_u8(line*16 + i, "CHR")))
      end
      out:write("\n")
    end
  else
    out:write("# CHR domain not available; skip\n")
  end

  -- [CPU_REGS_NES] via emu.getregister
  out:write("\n[CPU_REGS_NES]\n")
  local regs = {"A", "X", "Y", "PC", "S", "P"}
  for _, r in ipairs(regs) do
    local ok, v = pcall(emu.getregister, r)
    if ok then
      out:write(string.format("%s=$%04X\n", r, v))
    else
      out:write(string.format("%s=ERR\n", r))
    end
  end

  -- [DOMAINS] discovery dump for debugging
  out:write("\n[DOMAINS_DETECTED]\n")
  for name, _ in pairs(domains) do
    out:write(string.format("  %s\n", name))
  end

  -- [RAM_FULL] all 2KB main RAM (catches stack $0100, scratch, all
  -- variables Z1 uses)
  out:write("\n[RAM_FULL]\n")
  for line = 0, 127 do  -- 2048 / 16
    out:write(string.format("$%04X=", line*16))
    for i = 0, 15 do
      out:write(string.format("%02X", R(line*16 + i)))
    end
    out:write("\n")
  end

  out:write("\n# SCAN_COMPLETE\n")
end

----------------------------------------------------------------------
-- Per-room dynamic trace dump
----------------------------------------------------------------------
local function dump_trace(out)
  out:write("# Plan v5 Phase D1 trace — 60 frames\n")
  for f = 0, TRACE_FRAMES - 1 do
    out:write(string.format("\n[FRAME_%03d]\n", f))
    out:write(string.format("rng=$%02X linkx=$%02X linky=$%02X linkdir=$%02X linkst=$%02X linkanim=$%02X linkhp=$%02X\n",
      R(0x0019), R(0x0070), R(0x0084), R(0x008C), R(0x00AC), R(0x03E4), R(0x066F)))
    for s = 1, 11 do
      local t = R(0x034F + s)
      if t ~= 0 then
        out:write(string.format("s%d=t:$%02X x:$%02X y:$%02X dir:$%02X qspd:$%02X frac:$%02X grid:$%02X mvTm:$%02X st:$%02X ms:$%02X tm:$%02X anim:$%02X shvd:$%02X shvt:$%02X inv:$%02X hit:$%02X\n",
          s, t, R(0x0070+s), R(0x0084+s), R(0x008C+s),
          R(0x03BC+s), R(0x03A8+s), R(0x0394+s), R(0x0028+s),
          R(0x00AC+s), R(0x0405+s), R(0x0028+s), R(0x03E4+s),
          R(0x00C0+s), R(0x00D3+s), R(0x04F0+s), R(0x04B2+s)))
      end
    end
    emu.frameadvance()
  end
end

----------------------------------------------------------------------
-- Per-room: warp + static dump + screenshots + trace
----------------------------------------------------------------------
local function capture_room(domains, level, room)
  warp(level, room)
  local actual_lv = R(0x0010)
  local actual_rm = R(0x00EB)
  local tag = string.format("lv%02X_rm%02X", actual_lv, actual_rm)
  local dir = string.format("%s/%s", OUT_BASE, tag)
  ensure_dir(dir)

  -- PNG in dir AND flat-named copy at OUT_BASE root for easy browse
  client.screenshot(string.format("%s/%s.png", dir, tag))
  client.screenshot(string.format("%s/_all/%s.png", OUT_BASE, tag))

  local static = io.open(dir .. "/static.txt", "w")
  if static then dump_static(static, domains, level, room); static:close() end

  local oamf = io.open(dir .. "/oam.bin", "wb")
  if oamf then for i = 0, 255 do oamf:write(string.char(OAM(i))) end; oamf:close() end
  local palf = io.open(dir .. "/palram.bin", "wb")
  if palf then for i = 0, 31 do palf:write(string.char(PAL(i))) end; palf:close() end

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
print("NES domains found:")
for name, _ in pairs(domains) do print("  " .. name) end

if SCAN_ALL then
  -- OW only for first pass; UW after Gen UW warp works.
  for room = 0, 127 do capture_room(domains, 0, room) end
else
  capture_room(domains, SINGLE_LV, SINGLE_RM)
end

-- Sentinel for harness
local done = io.open(OUT_BASE .. "/SCAN_COMPLETE", "w")
if done then done:write("done\n"); done:close() end
print("NES scan complete.")
client.exit()
