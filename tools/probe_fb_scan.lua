-- Dump the actual rendered framebuffer pixels at specific screen Y rows on Gen
-- for the frame sequence around the trigger. Gives ground truth about what the
-- VDP drew (not just what's in VRAM).
local OUT = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/builds/reports/fb_scan_gen.txt"

local frame = 0
while frame < 2309 do
  emu.frameadvance()
  frame = frame + 1
end

local f = io.open(OUT, "w")

local function scan_frame()
  local curV = memory.read_u8(0xFC, "68K RAM")
  f:write(string.format("=== frame=%d curV=%02X ===\n", frame, curV))
  -- Scan screen Y in rows where labels should be. Gen screen is 256x224 in H32.
  -- HEART label row = ~Y 72, FAIRY/CLOCK label row = ~Y 136, RUPY label row = ~Y 192.
  local rows_to_scan = {32, 40, 48, 56, 64, 72, 80, 96, 112, 128, 136, 144, 160, 176, 192, 200}
  for _,y in ipairs(rows_to_scan) do
    local line = string.format("y=%03d: ", y)
    -- Sample 32 x-positions across the 256-wide screen
    for xs=0,31 do
      local x = xs * 8
      -- Genesis framebuffer: gui.getpixel reads from currently displayed frame
      local ok, r, g, b = pcall(function()
        local px = client.getpixel and client.getpixel(x, y) or nil
        return px, px, px
      end)
      if client.getpixel then
        local px = client.getpixel(x, y)
        line = line .. string.format("%06X ", px or 0)
      else
        line = line .. "------ "
      end
    end
    f:write(line .. "\n")
  end
end

-- Try a few frames
for i=1,4 do
  emu.frameadvance()
  frame = frame + 1
  scan_frame()
end

f:close()
client.exit()
