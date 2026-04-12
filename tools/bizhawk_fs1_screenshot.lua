-- bizhawk_fs1_screenshot.lua
-- Phase 9.2 — capture screenshot of FS1 mode at frame 220, plus dump
-- CRAM (palettes 0-3 BG, 4-7 SPR) and SAT (sprite 0-30) for visual diagnosis.

local env_root = os.getenv("CODEX_BIZHAWK_ROOT")
local ROOT = (env_root and env_root ~= "" and env_root:gsub("/", "\\"))
    or "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\.claude\\worktrees\\nifty-chandrasekhar"
local OUT_PNG = ROOT .. "\\builds\\reports\\fs1_current_mode1.png"
local OUT_TXT = ROOT .. "\\builds\\reports\\fs1_current_state.txt"

local lines = {}
local function log(s) lines[#lines + 1] = s end

local function ram_u8(bus_addr)
    return memory.read_u8(bus_addr - 0xFF0000, "68K RAM")
end

for f = 1, 220 do
    if f >= 90 and f <= 110 then
        joypad.set({["P1 Start"] = true})
    end
    emu.frameadvance()
end

client.screenshot(OUT_PNG)

log(string.format("=== fs1_current_state frame=220 mode=%02X sub=%02X ===",
    ram_u8(0xFF0012), ram_u8(0xFF0013)))

log("--- CRAM 64 entries (4 BG palettes, 4 SPR palettes, big-endian words) ---")
for pal = 0, 7 do
    local parts = {string.format("pal %d (%s):", pal, (pal < 4) and "BG" or "SPR")}
    for col = 0, 15 do
        local addr = (pal * 16 + col) * 2
        local w = memory.read_u16_be(addr, "CRAM")
        parts[#parts + 1] = string.format("%04X", w)
    end
    log(table.concat(parts, " "))
end

log("--- VRAM SAT @ $F800: 64 sprites x 8 bytes (Y, size+next, attr+tile, X) ---")
local SAT_BASE = 0xF800
for i = 0, 30 do
    local base = SAT_BASE + i * 8
    local y = memory.read_u16_be(base + 0, "VRAM")
    local sz = memory.read_u16_be(base + 2, "VRAM")  -- bits: size, next link
    local at = memory.read_u16_be(base + 4, "VRAM")  -- attr+tile
    local x = memory.read_u16_be(base + 6, "VRAM")
    log(string.format("spr %02d: Y=%04X SZ=%04X AT=%04X X=%04X", i, y, sz, at, x))
end

local fh = assert(io.open(OUT_TXT, "w"))
fh:write(table.concat(lines, "\n") .. "\n")
fh:close()
client.exit()
