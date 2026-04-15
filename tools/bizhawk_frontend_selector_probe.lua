-- bizhawk_frontend_selector_probe.lua
-- Force Mode1TileTransferBuf on a settled file-select screen to determine
-- whether the selector-14 transfer path itself populates the nametable.

dofile((function()
    local env_root = os.getenv("CODEX_BIZHAWK_ROOT")
    if env_root and env_root ~= "" then
        env_root = env_root:gsub("/", "\\")
        return env_root .. "\\tools\\probe_root.lua"
    end
    local source = debug.getinfo(1, "S").source
    if source:sub(1, 1) == "@" then
        source = source:sub(2)
    end
    source = source:gsub("/", "\\")
    local tools_dir = source:match("^(.*)\\[^\\]+$")
    return tools_dir .. "\\probe_root.lua"
end)())

local OUT_DIR = repo_path("builds\\reports")
local OUT_TXT = repo_path("builds\\reports\\frontend_selector_probe.txt")
local BEFORE_PNG = repo_path("builds\\reports\\frontend_selector_before.png")
local AFTER_PNG = repo_path("builds\\reports\\frontend_selector_after.png")

os.execute('if not exist "' .. OUT_DIR .. '" mkdir "' .. OUT_DIR .. '"')

local function ram_read(bus_addr)
    return memory.read_u8(bus_addr - 0xFF0000, "68K RAM")
end

local function ram_write(bus_addr, value)
    memory.write_u8(bus_addr - 0xFF0000, value, "68K RAM")
end

local function nt_row(row)
    local parts = {}
    local base = 0x0840 + row * 32
    for col = 0, 31 do
        parts[#parts + 1] = string.format("%02X", memory.read_u8(base + col, "68K RAM"))
    end
    return table.concat(parts, " ")
end

local function log_line(lines, text)
    lines[#lines + 1] = text
    print(text)
end

local lines = {}
local press_start_from = 90
local press_start_to = 110
local settled_frame = nil

for frame = 1, 320 do
    if frame >= press_start_from and frame <= press_start_to then
        joypad.set({["P1 Start"] = true})
    end

    emu.frameadvance()

    local mode = ram_read(0xFF0012)
    local sub = ram_read(0xFF0013)
    local gate = ram_read(0xFF083D)
    if not settled_frame and mode == 0x01 and sub == 0x00 and gate == 0x00 and frame > 120 then
        settled_frame = frame
        break
    end
end

if not settled_frame then
    log_line(lines, "FAIL: did not reach settled file-select state")
    local fh = io.open(OUT_TXT, "w")
    if fh then
        fh:write(table.concat(lines, "\n") .. "\n")
        fh:close()
    end
    client.exit()
end

client.screenshot(BEFORE_PNG)
log_line(lines, string.format("settled_frame=%d mode=%02X sub=%02X sel=%02X",
    settled_frame, ram_read(0xFF0012), ram_read(0xFF0013), ram_read(0xFF0014)))
log_line(lines, "before_r06=" .. nt_row(6))
log_line(lines, "before_r08=" .. nt_row(8))
log_line(lines, "before_r17=" .. nt_row(17))

ram_write(0xFF0014, 0x14)
log_line(lines, "forced TileBufSelector=$14")

for _ = 1, 3 do
    emu.frameadvance()
end

client.screenshot(AFTER_PNG)
log_line(lines, string.format("after mode=%02X sub=%02X sel=%02X dyn0=%02X",
    ram_read(0xFF0012), ram_read(0xFF0013), ram_read(0xFF0014), ram_read(0xFF0302)))
log_line(lines, "after_r06=" .. nt_row(6))
log_line(lines, "after_r08=" .. nt_row(8))
log_line(lines, "after_r17=" .. nt_row(17))

local fh = assert(io.open(OUT_TXT, "w"))
fh:write(table.concat(lines, "\n") .. "\n")
fh:close()
client.exit()
