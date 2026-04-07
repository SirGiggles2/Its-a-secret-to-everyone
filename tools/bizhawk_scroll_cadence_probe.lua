-- Log the intro story-scroll state every frame through the title-story window.
-- Run separately against NES ROM and Gen ROM, then diff to find where the
-- vertical scroll / nametable / line-transfer sequences diverge.
--
-- Detects system automatically via emu.getsystemid() and writes to a
-- system-appropriate filename.
--
-- Important correction:
--   The intro story scroll is driven by CurVScroll at $00FC, not $00FD.
--   The earlier probe logged $00FD (CurHScroll / $2005 first write), which
--   stays at 0 during this scene and cannot explain cadence drift.
--
-- In BizHawk/GPGX, the mapped Genesis work RAM block is exposed as the
-- "68K RAM" domain with the NES mirror starting at offset $0000, so the same
-- offsets work directly there.

local sysid = emu.getsystemid()
local OUT, read_ram
local function u8(v) return v & 0xFF end

if sysid == "NES" then
  OUT = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/builds/reports/scroll_cadence_nes.csv"
  read_ram = function(a) return memory.read_u8(a, "RAM") end
elseif sysid == "GEN" then
  OUT = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/builds/reports/scroll_cadence_gen.csv"
  read_ram = function(a) return memory.read_u8(a, "68K RAM") end
else
  error("unsupported system: " .. tostring(sysid))
end

local fh = io.open(OUT, "w")
fh:write(
  "frame,curVScroll,curHScroll,curPpuCtrl,switchNTReq,gameMode,isSprite0Active," ..
  "demoPhase,demoSubphase,demoLineTextIndex,demoNTWraps,lineCounter,lineAttrIndex," ..
  "lineDstLo,lineDstHi,attrDstLo,attrDstHi,phase0Cycle,phase0Timer,transferBufSel,demoBusy\n"
)

-- Skip to intro window start (after boot+fade completes)
while emu.framecount() < 850 do emu.frameadvance() end

-- Log every frame for 700 frames (covers full story scroll + wrap)
for i = 0, 700 do
  local f = emu.framecount()
  local cur_v = read_ram(0x00FC)
  local cur_h = read_ram(0x00FD)
  local ctrl  = read_ram(0x00FF)
  local sw_nt = read_ram(0x005C)
  local mode  = read_ram(0x0012)
  local sp0   = read_ram(0x00E3)
  local ph    = read_ram(0x042C)
  local sub   = read_ram(0x042D)
  local text  = read_ram(0x042E)
  local wraps = read_ram(0x0415)
  local linec = read_ram(0x041B)
  local lattr = read_ram(0x0419)
  local dlo   = read_ram(0x041C)
  local dhi   = read_ram(0x041D)
  local alo   = read_ram(0x0417)
  local ahi   = read_ram(0x0418)
  local cyc0  = read_ram(0x0437)
  local tmr0  = read_ram(0x0438)
  local buf   = read_ram(0x0014)
  local busy  = read_ram(0x0011)
  fh:write(string.format(
    "%d,%02X,%02X,%02X,%02X,%02X,%02X,%02X,%02X,%02X,%02X,%02X,%02X,%02X,%02X,%02X,%02X,%02X,%02X,%02X,%02X\n",
    f,
    u8(cur_v), u8(cur_h), u8(ctrl), u8(sw_nt), u8(mode), u8(sp0),
    u8(ph), u8(sub), u8(text), u8(wraps), u8(linec), u8(lattr),
    u8(dlo), u8(dhi), u8(alo), u8(ahi), u8(cyc0), u8(tmr0), u8(buf), u8(busy)
  ))
  emu.frameadvance()
end

fh:close()
client.exit()
