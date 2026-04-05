-- Time-series: dump Gen VRAM tile $A0 (copy 0) and $4A0 (copy 3) at many frames
-- to find when their shapes diverge. Expansion invariant: shapes must match
-- across the 4 copies (only pixel-bias values differ).
local OUT = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/builds/reports/tile_a0_timeseries.txt"
local fh = io.open(OUT, "w")

local function tile_shape(tile)
  -- Return an 8-char-per-row shape string where each pixel is:
  --   "." if nibble == 0, "X" otherwise
  -- This strips bias differences, leaving pure shape for comparison.
  local s = {}
  local base = tile * 32
  for r = 0, 7 do
    local row = ""
    for c = 0, 3 do
      local b = memory.read_u8(base + r*4 + c, "VRAM")
      local hi = (b >> 4) & 0xF
      local lo = b & 0xF
      row = row .. (hi == 0 and "." or "X") .. (lo == 0 and "." or "X")
    end
    s[r+1] = row
  end
  return s
end

local function shapes_equal(a, b)
  for i = 1, 8 do if a[i] ~= b[i] then return false end end
  return true
end

local function dump_frame(f)
  local c0 = tile_shape(0x0A0)
  local c3 = tile_shape(0x4A0)
  local eq = shapes_equal(c0, c3)
  fh:write(string.format("--- f%d  c0==c3: %s ---\n", f, tostring(eq)))
  if not eq then
    fh:write("  c0:             c3:\n")
    for r = 1, 8 do fh:write("  " .. c0[r] .. "    " .. c3[r] .. "\n") end
  end
end

-- Sample densely during boot + title + intro window
local targets = {
  60, 90, 120, 150, 180, 210, 240, 270, 300, 330, 360, 390, 420, 450, 480,
  510, 540, 570, 600, 630, 660, 690, 700, 720, 750, 800, 900, 1000, 1200, 1400
}
for _, f in ipairs(targets) do
  while emu.framecount() < f do emu.frameadvance() end
  dump_frame(f)
end
fh:close()
client.exit()
