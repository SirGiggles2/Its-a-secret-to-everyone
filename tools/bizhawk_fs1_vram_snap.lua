-- bizhawk_fs1_vram_snap.lua
-- Phase 9.2 — directly snapshot Plane A VRAM at frame 200 (well after the
-- Mode 1 init chain has fired) and dump the first 30 rows of NT0 + a hex
-- dump of NT_CACHE_BASE shadow in 68K RAM.
--
-- Plane A is at VDP VRAM $C000 in V64 layout (stride $80 bytes per row, 64
-- columns × 2 bytes/col = 128 bytes).  We dump rows 0..29.

local env_root = os.getenv("CODEX_BIZHAWK_ROOT")
local ROOT = (env_root and env_root ~= "" and env_root:gsub("/", "\\"))
    or "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\.claude\\worktrees\\nifty-chandrasekhar"
local OUT_TXT = ROOT .. "\\builds\\reports\\fs1_vram_snap.txt"

local lines = {}
local function log(s) lines[#lines + 1] = s end

local PLANE_A_BASE = 0xC000
local STRIDE = 0x80      -- 64 cols * 2 bytes
local COLS_TO_DUMP = 32  -- first 32 cols (the visible NES-equivalent area)

local function vram_word(off)
    return memory.read_u16_be(off, "VRAM")
end

local function dump_plane_a()
    log("--- Plane A NT0 (rows 0..29, cols 0..31) ---")
    for row = 0, 29 do
        local parts = {string.format("row %02d:", row)}
        for col = 0, COLS_TO_DUMP - 1 do
            local addr = PLANE_A_BASE + row * STRIDE + col * 2
            parts[#parts + 1] = string.format("%04X", vram_word(addr))
        end
        log(table.concat(parts, " "))
    end
end

local function dump_unique_tiles()
    log("--- Unique tile-low-bytes seen in Plane A NT0 (rows 0..29) ---")
    local seen = {}
    local order = {}
    for row = 0, 29 do
        for col = 0, COLS_TO_DUMP - 1 do
            local w = vram_word(PLANE_A_BASE + row * STRIDE + col * 2)
            local tile = w % 0x800   -- low 11 bits
            if not seen[tile] then
                seen[tile] = 0
                order[#order + 1] = tile
            end
            seen[tile] = seen[tile] + 1
        end
    end
    for _, t in ipairs(order) do
        log(string.format("  tile $%03X count=%d", t, seen[t]))
    end
end

local function ram_u8(bus_addr)
    return memory.read_u8(bus_addr - 0xFF0000, "68K RAM")
end

for f = 1, 220 do
    if f >= 90 and f <= 110 then
        joypad.set({["P1 Start"] = true})
    end
    emu.frameadvance()
end

log(string.format("=== fs1_vram_snap frame=%d mode=%02X sub=%02X ===",
    220, ram_u8(0xFF0012), ram_u8(0xFF0013)))

dump_plane_a()
dump_unique_tiles()

log("--- NT_CACHE_BASE (NES_RAM offset $0700, 32 rows × 32 cols = 0x3C0 bytes) ---")
-- NT_CACHE lives in 68K RAM somewhere; we don't know offset offhand.  Skip.

local fh = assert(io.open(OUT_TXT, "w"))
fh:write(table.concat(lines, "\n") .. "\n")
fh:close()
client.exit()
