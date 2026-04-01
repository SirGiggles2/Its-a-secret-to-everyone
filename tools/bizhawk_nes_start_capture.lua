local root = [[C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\WHAT IF]]
local report_path = root .. [[\builds\reports\nes_start_capture.txt]]
local png_path = root .. [[\builds\reports\nes_start_capture.png]]
local json_path = root .. [[\builds\reports\nes_start_tilemap.json]]

memory.usememorydomain("System Bus")

local function write_report(lines)
  local f = io.open(report_path, "w")
  if not f then
    return
  end
  for _, line in ipairs(lines) do
    f:write(line, "\n")
  end
  f:close()
end

local function write_json_tilemap(path)
  local f = io.open(path, "w")
  if not f then
    return
  end

  f:write("{\n")
  f:write(string.format('  "room_id": %d,\n', memory.read_u8(0x00EB)))
  f:write('  "tile_rows": [\n')
  for row = 0, 21 do
    f:write("    [")
    for col = 0, 31 do
      local addr = 0x6530 + col * 22 + row
      local tile = memory.read_u8(addr)
      f:write(string.format("%d", tile))
      if col < 31 then
        f:write(", ")
      end
    end
    f:write("]")
    if row < 21 then
      f:write(",")
    end
    f:write("\n")
  end
  f:write("  ]\n")
  f:write("}\n")
  f:close()
end

local function press(buttons)
  joypad.set(buttons, 1)
  emu.frameadvance()
  joypad.set({}, 1)
  emu.frameadvance()
end

for _ = 1, 240 do
  emu.frameadvance()
end

press({ Start = true })
for _ = 1, 180 do
  emu.frameadvance()
end

press({ Start = true })
for _ = 1, 1500 do
  emu.frameadvance()
end

client.screenshot(png_path)
local room_id = memory.read_u8(0x00EB)
write_json_tilemap(json_path)
write_report({
  "Captured NES start screen candidate after title and file-select confirmation.",
  "PNG: " .. png_path,
  "Tilemap JSON: " .. json_path,
  "Frame: " .. tostring(emu.framecount()),
  string.format("RoomId: $%02X", room_id),
})
client.exit()
