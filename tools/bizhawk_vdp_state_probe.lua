-- bizhawk_vdp_state_probe.lua
-- Dumps VDP register state, verifies tile data integrity, checks CRAM accuracy

local ROOT = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/"
local REPORT = ROOT .. "builds/reports/bizhawk_vdp_state_probe.txt"

local lines = {}
local function log(s) lines[#lines+1] = s end

local function bus_read(addr)
    local ok, v = pcall(function()
        memory.usememorydomain("M68K BUS")
        return memory.read_u8(addr)
    end)
    return ok and v or 0
end

local function vram_u8(addr)
    local ok, v = pcall(function()
        memory.usememorydomain("VRAM")
        return memory.read_u8(addr)
    end)
    return ok and v or 0
end

local function vram_u16(addr)
    local ok, v = pcall(function()
        memory.usememorydomain("VRAM")
        return memory.read_u16_be(addr)
    end)
    return ok and v or 0
end

local function cram_u16(addr)
    local ok, v = pcall(function()
        memory.usememorydomain("CRAM")
        return memory.read_u16_be(addr)
    end)
    return ok and v or 0
end

-- Run 300 frames
for i = 1, 300 do emu.frameadvance() end

log("=================================================================")
log("VDP State Probe — frame 300")
log("=================================================================")

-- Dump VDP registers by reading from Genesis VRAM domain
-- BizHawk GPGX exposes VDP registers via special memory domain
log("")
log("─── VDP Register State ───────────────────────────────────")
local has_vdp_regs = false
local ok, _ = pcall(function()
    memory.usememorydomain("VDP REGS")
    has_vdp_regs = true
end)
if has_vdp_regs then
    for i = 0, 23 do
        local v = memory.read_u8(i)
        log(string.format("  VDP R%02d = $%02X  (%s)", i, v,
            i==0 and "Mode 1" or
            i==1 and "Mode 2" or
            i==2 and "Plane A addr" or
            i==3 and "Window addr" or
            i==4 and "Plane B addr" or
            i==5 and "Sprite table" or
            i==6 and "---" or
            i==7 and "BG color" or
            i==10 and "H-int counter" or
            i==11 and "Mode 3 (scroll)" or
            i==12 and "Mode 4 (H res)" or
            i==13 and "H-scroll addr" or
            i==15 and "Auto-increment" or
            i==16 and "Plane size" or
            i==17 and "Window H pos" or
            i==18 and "Window V pos" or
            ""))
    end
else
    log("  VDP REGS domain not available")
    -- Try reading VDP state via known genesis_shell init values
    log("  (reading from genesis_shell VDP shadow if available)")
end

-- Check available memory domains
log("")
log("─── Memory Domains ───────────────────────────────────────")
local domains = memory.getmemorydomainlist()
for _, d in ipairs(domains) do
    log("  " .. d)
end

-- Check plane size: VDP R16 determines nametable width
-- $00=32x32, $01=64x32, $11=64x64, $10=32x64 (but $10 is officially invalid)
-- If plane is 64-wide, row stride = 128 bytes instead of 64, which would garble display

-- Dump a specific tile's VRAM data vs expected
log("")
log("─── Tile Data Integrity Check ────────────────────────────")

-- Tile $E0 (border corner, used in nametable row 2)
-- Genesis VRAM addr = tile_index × 32
for _, tileIdx in ipairs({0x24, 0xE0, 0xD5, 0x71}) do
    local vram_addr = tileIdx * 32
    local bytes = {}
    local nonzero = 0
    for j = 0, 31 do
        local b = vram_u8(vram_addr + j)
        bytes[#bytes+1] = string.format("%02X", b)
        if b ~= 0 then nonzero = nonzero + 1 end
    end
    log(string.format("  Tile $%03X (VRAM $%04X): %s  [%d non-zero bytes]",
        tileIdx, vram_addr, table.concat(bytes, " "), nonzero))
end

-- Check auto-increment value
log("")
log("─── VDP Auto-Increment ───────────────────────────────────")
if has_vdp_regs then
    memory.usememorydomain("VDP REGS")
    local ai = memory.read_u8(15)
    log(string.format("  R15 (auto-increment) = $%02X (%d bytes)", ai, ai))
    if ai ~= 2 then
        log("  WARNING: auto-increment is NOT 2! This will garble VRAM writes!")
    end
end

-- Check plane A base address
log("")
log("─── Plane A Configuration ────────────────────────────────")
if has_vdp_regs then
    memory.usememorydomain("VDP REGS")
    local r2 = memory.read_u8(2)
    local plane_a_addr = (r2 & 0x38) * 0x400
    log(string.format("  R02 = $%02X → Plane A base = $%04X", r2, plane_a_addr))
    if plane_a_addr ~= 0xC000 then
        log("  WARNING: Plane A is NOT at $C000!")
    end

    local r16 = memory.read_u8(16)
    local h_size = r16 & 3
    local v_size = (r16 >> 4) & 3
    local h_tiles = ({32, 64, 32, 128})[h_size + 1]  -- 0=32, 1=64
    local v_tiles = ({32, 32, 64, 128})[v_size + 1]
    log(string.format("  R16 = $%02X → Plane size = %dx%d tiles", r16, h_tiles, v_tiles))
    if h_tiles ~= 32 then
        log("  WARNING: Plane width is NOT 32! Row stride mismatch will garble display!")
    end
end

-- Full CRAM dump
log("")
log("─── CRAM (all 64 entries) ────────────────────────────────")
for pal = 0, 3 do
    local entries = {}
    for c = 0, 15 do
        entries[#entries+1] = string.format("%04X", cram_u16(pal * 32 + c * 2))
    end
    log(string.format("  pal%d: %s", pal, table.concat(entries, " ")))
end

-- Check nametable words at known positions with expected palettes
log("")
log("─── Nametable Spot Check (row 5 = border with palette data) ───")
local NT_BASE = 0xC000
for col = 0, 31 do
    local word = vram_u16(NT_BASE + 5 * 128 + col * 2)
    local tile = word & 0x7FF
    local pal = (word >> 13) & 3
    local hflip = (word >> 11) & 1
    local vflip = (word >> 12) & 1
    if col <= 5 or col >= 26 then
        log(string.format("  col%02d: word=$%04X tile=$%03X pal=%d hf=%d vf=%d",
            col, word, tile, pal, hflip, vflip))
    end
end

-- H/V scroll values
log("")
log("─── Scroll State ─────────────────────────────────────────")
if has_vdp_regs then
    memory.usememorydomain("VDP REGS")
    local r13 = memory.read_u8(13)
    local hscroll_addr = (r13 & 0x3F) * 0x400
    log(string.format("  H-scroll table at VRAM $%04X", hscroll_addr))
    -- Read first H-scroll entry
    local hscroll_a = vram_u16(hscroll_addr)
    local hscroll_b = vram_u16(hscroll_addr + 2)
    log(string.format("  H-scroll A = %d, H-scroll B = %d", hscroll_a, hscroll_b))
end
-- V-scroll from VSRAM
local ok2, _ = pcall(function()
    memory.usememorydomain("VSRAM")
    local vs_a = memory.read_u16_be(0)
    local vs_b = memory.read_u16_be(2)
    log(string.format("  V-scroll A = %d, V-scroll B = %d", vs_a, vs_b))
end)

-- Write
local fh = io.open(REPORT, "w")
for _, line in ipairs(lines) do fh:write(line .. "\n") end
fh:close()
print("VDP state probe written to: " .. REPORT)
client.exit()
