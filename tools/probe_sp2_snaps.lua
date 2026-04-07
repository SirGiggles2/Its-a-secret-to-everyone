-- Subphase=02 snapshot probe: advance until we reach specific (phase,subphase,curV,nt)
-- state points, screenshot each, then exit. Runs on both NES and Gen and writes
-- screenshots under builds/reports/sp2_<label>/.
local system = emu.getsystemid() or "?"
local is_gen = (system == "GEN" or system == "SAT")
local LABEL = is_gen and "gen" or "nes"
local OUT = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/builds/reports/sp2_" .. LABEL

local rd
if is_gen then
  rd = function(a) return memory.read_u8(a, "68K RAM") end
else
  rd = function(a) return mainmemory.read_u8(a) end
end

-- Target states: (phase, subphase, curV, ppuCtrl_nt_bit)
-- We want a sweep across subphase=02 covering NT0 and NT1 at multiple curV values.
local targets = {
  {1, 2, 0x08, 0},  -- start of sp2
  {1, 2, 0x20, 0},
  {1, 2, 0x40, 0},
  {1, 2, 0x60, 0},
  {1, 2, 0x80, 0},
  {1, 2, 0xA0, 0},
  {1, 2, 0xC0, 0},
  {1, 2, 0xE0, 0},
  {1, 2, 0x00, 1},  -- post NT-flip
  {1, 2, 0x20, 1},
  {1, 2, 0x40, 1},
  {1, 2, 0x60, 1},
  {1, 2, 0x80, 1},
  {1, 2, 0xA0, 1},
  {1, 2, 0xC0, 1},
  {1, 2, 0xE0, 1},
}
local ti = 1
local frame = 0
local trace = {}
table.insert(trace, string.format("# label=%s", LABEL))
table.insert(trace, "# target_idx,frame,phase,subphase,curV,ppuCtrl,nt")

while ti <= #targets and frame < 5000 do
  emu.frameadvance()
  frame = frame + 1
  local phase = rd(0x42C)
  local sub   = rd(0x42D)
  local curV  = rd(0xFC)
  local ctrl  = rd(0xFF)
  local nt    = (ctrl % 4 >= 2) and 1 or 0
  local t = targets[ti]
  if phase == t[1] and sub == t[2] and curV == t[3] and nt == t[4] then
    client.screenshot(string.format("%s/%s_t%02d_cV%02X_nt%d_f%05d.png",
      OUT, LABEL, ti, curV, nt, frame))
    table.insert(trace, string.format("%d,%d,%02X,%02X,%02X,%02X,%d",
      ti, frame, phase, sub, curV, ctrl, nt))
    ti = ti + 1
  end
end

local f = io.open(OUT .. "/" .. LABEL .. "_trace.txt", "w")
if f then f:write(table.concat(trace, "\n") .. "\n"); f:close() end
client.exit()
