local OUT_DIR = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\VDP rebirth tools and asms\\WHAT IF\\builds\\reports\\"
local OUT_PATH = OUT_DIR .. "bizhawk_phase3_room_fidelity_probe.json"

local ROOM_BASE = 0xFF0600
local ROOM_ROWS = 22
local ROOM_COLS = 32
local ROOM_ROW_STRIDE = 64
local PLANE_A_BASE = 0x8000
local PLANE_TOP_ROW = 6
local PLANE_ROW_STRIDE = 128

os.execute('if not exist "' .. OUT_DIR .. '" mkdir "' .. OUT_DIR .. '"')

local function read_u16(domain, addr)
  memory.usememorydomain(domain)
  return memory.read_u16_be(addr)
end

local function json_array(values)
  local parts = {}
  for i = 1, #values do
    parts[#parts + 1] = tostring(values[i])
  end
  return "[" .. table.concat(parts, ",") .. "]"
end

local function dump_matrix(domain, base, rows, cols, row_stride)
  local lines = {}
  for row = 0, rows - 1 do
    local values = {}
    for col = 0, cols - 1 do
      local addr = base + row * row_stride + col * 2
      values[#values + 1] = read_u16(domain, addr)
    end
    lines[#lines + 1] = json_array(values)
  end
  return "[\n    " .. table.concat(lines, ",\n    ") .. "\n  ]"
end

local function dump_words(domain, base, count)
  local values = {}
  for index = 0, count - 1 do
    values[#values + 1] = read_u16(domain, base + index * 2)
  end
  return json_array(values)
end

local function main()
  for _ = 1, 30 do
    emu.frameadvance()
  end

  local room_id = read_u16("M68K BUS", 0xFF003C)
  local room_rows = dump_matrix("M68K BUS", ROOM_BASE, ROOM_ROWS, ROOM_COLS, ROOM_ROW_STRIDE)
  local vram_rows = dump_matrix("VRAM", PLANE_A_BASE + PLANE_TOP_ROW * PLANE_ROW_STRIDE, ROOM_ROWS, ROOM_COLS, PLANE_ROW_STRIDE)
  local cram_words = dump_words("CRAM", 0x0000, 64)

  local fh = assert(io.open(OUT_PATH, "w"))
  fh:write("{\n")
  fh:write('  "room_id": ', tostring(room_id), ",\n")
  fh:write('  "cram_words": ', cram_words, ",\n")
  fh:write('  "room_rows": ', room_rows, ",\n")
  fh:write('  "vram_rows": ', vram_rows, "\n")
  fh:write("}\n")
  fh:close()
end

local ok, err = pcall(main)
if not ok then
  local fh = io.open(OUT_PATH, "w")
  if fh then
    fh:write('{"error":"', tostring(err):gsub("\\", "\\\\"):gsub('"', '\\"'), '"}\n')
    fh:close()
  end
end

client.exit()
