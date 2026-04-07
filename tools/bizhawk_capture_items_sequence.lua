-- Capture the intro item-scroll sequence on either NES or Genesis.
-- This is a broad frame-window capture from boot because the item roll is part
-- of the attract/intro pipeline, not the gameplay submenu state machine.
--
-- Output:
--   builds/reports/items_seq_<label>/<label>_fNNNNN.png
--   builds/reports/items_seq_<label>/<label>_trace.txt

local system = emu.getsystemid() or "?"
local is_genesis = (system == "GEN" or system == "SAT")

local domains = {}
for _, name in ipairs(memory.getmemorydomainlist()) do
  domains[name] = true
end

local function pick_domain(candidates)
  for _, name in ipairs(candidates) do
    if domains[name] then return name end
  end
  return nil
end

local function framecount()
  local ok, v = pcall(function() return emu.framecount() end)
  return ok and v or 0
end

local ram_domain = nil
if is_genesis then
  ram_domain = pick_domain({"68K RAM", "M68K RAM", "M68K BUS"})
end

local oam_domain = pick_domain({"OAM"})
local label = os.getenv("ITEM_LABEL")
if not label or label == "" then
  label = is_genesis and "gen" or "nes"
end

local out_dir = os.getenv("ITEM_OUT_DIR")
if not out_dir or out_dir == "" then
  out_dir = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/builds/reports/items_seq_" .. label
end
os.execute('mkdir "' .. out_dir:gsub("/", "\\") .. '" 2>nul')

local trace_path = out_dir .. "/" .. label .. "_trace.txt"
local start_frame = tonumber(os.getenv("ITEM_START") or "1600") or 1600
local end_frame = tonumber(os.getenv("ITEM_END") or "3200") or 3200
local step = tonumber(os.getenv("ITEM_STEP") or "1") or 1

local function rd_nes(addr)
  local ok, v = pcall(function() return memory.read_u8(addr, "RAM") end)
  return ok and v or 0xFF
end

local function rd_68k(addr)
  if not ram_domain then return 0xFF end
  local off = addr - 0xFF0000
  if ram_domain == "M68K BUS" then off = addr end
  local ok, v = pcall(function() return memory.read_u8(off, ram_domain) end)
  return ok and v or 0xFF
end

local function rd_shared(addr)
  if is_genesis then
    return rd_68k(0xFF0000 + addr)
  end
  return rd_nes(addr)
end

local function rd16_be(domain, addr)
  local ok, v = pcall(function() return memory.read_u16_be(addr, domain) end)
  return ok and v or 0xFFFF
end

local function rd16_ram(addr)
  if not ram_domain then return 0xFFFF end
  local off = addr - 0xFF0000
  if ram_domain == "M68K BUS" then off = addr end
  local ok, v = pcall(function() return memory.read_u16_be(off, ram_domain) end)
  return ok and v or 0xFFFF
end

local function rd_vsram0()
  if not is_genesis then return 0xFFFF end
  return rd16_be("VSRAM", 0)
end

local function visible_sprite_count()
  if is_genesis then
    local n = 0
    for i = 0, 79 do
      local base = 0xF800 + i * 8
      local y = rd16_be("VRAM", base)
      local x = rd16_be("VRAM", base + 6)
      if y >= 128 and y <= 352 and x >= 128 and x <= 448 then
        n = n + 1
      end
    end
    return n
  end

  if not oam_domain then return -1 end
  local n = 0
  for i = 0, 63 do
    local y = memory.read_u8(i * 4 + 0, oam_domain)
    if y < 0xEF then n = n + 1 end
  end
  return n
end

local trace = {}
table.insert(trace, string.format("# label=%s system=%s ramDomain=%s start=%d end=%d step=%d",
  label, system, tostring(ram_domain), start_frame, end_frame, step))
table.insert(trace, "# frame,gameMode,phase,subphase,frameCtr,curVScroll,curHScroll,ppuCtrl,switchReq,"
  .. "tileBufSel,lineCounter,vramHi,vramLo,textIndex,objYTick,vsram0,ppuScrlX,ppuScrlY,"
  .. "hintQCount,hintPendSplit,introScrollMode,stagedMode,stagedHintCtr,stagedBase,stagedEvent,"
  .. "activeHintCtr,stagedSegment,activeSegment,activeBase,activeEvent,spriteVisible,"
  .. "attrIndex,itemRow")

while framecount() < end_frame do
  emu.frameadvance()
  local frame = framecount()
  if frame >= start_frame and ((frame - start_frame) % step == 0) then
    local gameMode = rd_shared(0x0012)
    local phase = rd_shared(0x042C)
    local subphase = rd_shared(0x042D)
    local frameCtr = rd_shared(0x0015)
    local curV = rd_shared(0x00FC)
    local curH = rd_shared(0x00FD)
    local ppuCtrl = rd_shared(0x00FF)
    local switchReq = rd_shared(0x005C)
    local tileBufSel = rd_shared(0x0014)
    local lineCounter = rd_shared(0x041B)
    local vramHi = rd_shared(0x041D)
    local vramLo = rd_shared(0x041C)
    local textIndex = rd_shared(0x042E)
    local objYTick = rd_shared(0x0415)
    local attrIndex = rd_shared(0x0419)
    local itemRow = rd_shared(0x042F)

    local vsram0 = 0xFFFF
    local ppuScrlX = 0xFF
    local ppuScrlY = 0xFF
    local hintQCount = 0xFF
    local hintPendSplit = 0xFF
    local introScrollMode = 0xFF
    local stagedMode = 0xFF
    local stagedHintCtr = 0xFF
    local stagedBase = 0xFFFF
    local stagedEvent = 0xFFFF
    local activeHintCtr = 0xFF
    local stagedSegment = 0xFF
    local activeSegment = 0xFF
    local activeBase = 0xFFFF
    local activeEvent = 0xFFFF

    if is_genesis then
      vsram0 = rd_vsram0()
      ppuScrlX = rd_68k(0xFF0806)
      ppuScrlY = rd_68k(0xFF0807)
      hintQCount = rd_68k(0xFF0816)
      hintPendSplit = rd_68k(0xFF081E)
      introScrollMode = rd_68k(0xFF081F)
      stagedMode = rd_68k(0xFF080A)
      stagedHintCtr = rd_68k(0xFF080B)
      stagedBase = rd16_ram(0xFF080C)
      stagedEvent = rd16_ram(0xFF080E)
      activeBase = rd16_ram(0xFF0836)
      activeEvent = rd16_ram(0xFF0838)
      activeHintCtr = rd_68k(0xFF083A)
      stagedSegment = rd_68k(0xFF083B)
      activeSegment = rd_68k(0xFF083C)
    end

    table.insert(trace, string.format(
      "%05d,%02X,%02X,%02X,%02X,%02X,%02X,%02X,%02X,%02X,%02X,%02X,%02X,%02X,%02X,%04X,%02X,%02X,%02X,%02X,%02X,%02X,%02X,%04X,%04X,%02X,%02X,%02X,%04X,%04X,%d,%02X,%02X",
      frame, gameMode, phase, subphase, frameCtr, curV, curH, ppuCtrl, switchReq, tileBufSel,
      lineCounter, vramHi, vramLo, textIndex, objYTick, vsram0 & 0xFFFF, ppuScrlX & 0xFF,
      ppuScrlY & 0xFF, hintQCount & 0xFF, hintPendSplit & 0xFF, introScrollMode & 0xFF,
      stagedMode & 0xFF, stagedHintCtr & 0xFF, stagedBase & 0xFFFF, stagedEvent & 0xFFFF,
      activeHintCtr & 0xFF, stagedSegment & 0xFF, activeSegment & 0xFF, activeBase & 0xFFFF,
      activeEvent & 0xFFFF, visible_sprite_count(), attrIndex & 0xFF, itemRow & 0xFF
    ))

    client.screenshot(string.format("%s/%s_f%05d.png", out_dir, label, frame))
  end
end

local f = io.open(trace_path, "w")
if f then
  f:write(table.concat(trace, "\n") .. "\n")
  f:close()
end

client.exit()
