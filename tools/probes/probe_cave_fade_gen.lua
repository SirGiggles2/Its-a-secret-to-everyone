-- probe_cave_fade_gen.lua — Genesis Debug.md cave-fade verification.
--
-- Captures cave-fade state on the running Debug.md ROM and diffs vs
-- the NES baseline written by probe_cave_fade_nes.lua. Per Rule Zero
-- + plan Tier 1 Task 1.4 (Gate 2 RAM trace).
--
-- USAGE:
--   1. Boot builds/Debug.md in BizHawk (genplus-gx core).
--   2. Hit A+B+C at title to enter Debug gameplay (RoomRom debug-enter).
--   3. Walk Link onto entrance tile $24 in OW room $77 (or any cave-
--      entrance tile the cave_entrance_check at main.c:1885 recognises).
--   4. Script triggers capture from the first frame the entrance hits
--      (cave-entry sentinel $07FC increments) and runs for 24 frames.
--
-- OUTPUT:
--   tools/probes/captures/cave_fade_gen.txt  (human log)
--   tools/probes/captures/cave_fade_gen.bin  (binary; same format as
--                                              NES baseline — see
--                                              probe_cave_fade_nes.lua)
--
-- DIFF: tools/probes/baselines/cave_fade_nes_ground_truth.bin is the
-- byte-for-byte reference. Compare with a small diff script (TBD per
-- plan Task 1.4 Gate 2) — for now, eyeball matching cells in the .txt
-- logs.

local OUT_TXT = "tools/probes/captures/cave_fade_gen.txt"
local OUT_BIN = "tools/probes/captures/cave_fade_gen.bin"

os.execute('if not exist "tools\\probes\\captures" mkdir "tools\\probes\\captures"')

local CAPTURE_FRAMES = 24

local log_f = assert(io.open(OUT_TXT, "w"))
local bin_f = assert(io.open(OUT_BIN, "wb"))

local function log(s)
    log_f:write(s .. "\n")
    print(s)
end

local function u32le(v)
    return string.char(v & 0xFF) ..
           string.char((v >> 8) & 0xFF) ..
           string.char((v >> 16) & 0xFF) ..
           string.char((v >> 24) & 0xFF)
end

-- Genesis 68K BUS memory access ----------------------------------------
-- Per src/abi/platform_abi.h: Debug.md A4 = $00FF8000 (NES RAM base).
-- NES cell $XXXX -> 68K address $FF8000 + $XXXX.

local function domain_exists(name)
    for _, d in ipairs(memory.getmemorydomainlist()) do
        if d == name then return true end
    end
    return false
end

local RAM_DOMAIN = "M68K BUS"
local NES_BASE   = 0x00FF8000
if domain_exists("68K RAM") then
    RAM_DOMAIN = "68K RAM"
    NES_BASE   = 0x8000  -- 68K RAM domain is 0-indexed at $FF0000
end

local function nes_r8(addr)
    memory.usememorydomain(RAM_DOMAIN)
    return memory.read_u8(NES_BASE + addr)
end

local function transfer_buf_window()
    local buf = {}
    for i = 0x0302, 0x030F do
        buf[#buf + 1] = string.char(nes_r8(i))
    end
    return table.concat(buf)
end

-- Genesis CRAM read (64 colors * 2 bytes = 128 bytes) ------------------
local function cram_block()
    memory.usememorydomain("CRAM")
    local buf = {}
    for i = 0, 127 do
        buf[#buf + 1] = string.char(memory.read_u8(i))
    end
    return table.concat(buf)
end

-- Wait for cave-entry sentinel ($07FC) to increment --------------------
log("probe_cave_fade_gen — waiting for cave-entry trigger")
log("  ($07FC sentinel = cave-entry fire counter, set at main.c:1893)")

local fc0 = nes_r8(0x07FC)
log(string.format("  initial $07FC = 0x%02X — walk Link onto entrance tile to trigger", fc0))

local timeout = 7200  -- ~2 minutes at 60fps
local triggered = false
for _ = 1, timeout do
    emu.frameadvance()
    if nes_r8(0x07FC) ~= fc0 then
        triggered = true
        break
    end
end

if not triggered then
    log("TIMEOUT — $07FC never changed. Did you walk into a cave-entrance tile?")
    log_f:close()
    bin_f:close()
    return
end

local start_frame = emu.framecount()
log(string.format("triggered at framecount=%d", start_frame))

-- Header
bin_f:write("CFNB")
bin_f:write(u32le(1))
bin_f:write(u32le(start_frame))

log(string.format(
    "frame_off | $0012 GM | $0013 SM | $051C Fade | $0301 TxPos | $0302..$030F | CRAM 8..15"))

for off = 0, CAPTURE_FRAMES - 1 do
    local gm   = nes_r8(0x0012)
    local sm   = nes_r8(0x0013)
    local fade = nes_r8(0x051C)
    local pos  = nes_r8(0x0301)
    local tbw  = transfer_buf_window()
    local pal  = cram_block()

    -- Print CRAM slots 8..15 (PAL0[8..15] = cave subpal 2+3 region)
    -- inline as 2-byte words to compare against NES palette logic.
    local cram_hex = {}
    for slot = 8, 15 do
        local lo = string.byte(pal, slot * 2 + 1)
        local hi = string.byte(pal, slot * 2 + 2)
        cram_hex[#cram_hex + 1] = string.format("%02X%02X", hi, lo)
    end

    local tbw_hex = {}
    for i = 1, #tbw do
        tbw_hex[#tbw_hex + 1] = string.format("%02X", string.byte(tbw, i))
    end

    log(string.format(
        "  +%02d     | %02X       | %02X       | %02X         | %02X          | %s | %s",
        off, gm, sm, fade, pos,
        table.concat(tbw_hex, " "),
        table.concat(cram_hex, " ")))

    -- Binary record (matches NES baseline layout: 4 status bytes + 1 pos
    -- + 14 tbw + 32 pal bytes; we pack 32 of the 128 CRAM bytes that
    -- correspond to PAL0[0..15] for diff parity with NES PALRAM).
    bin_f:write(string.char(off))
    bin_f:write(string.char(gm))
    bin_f:write(string.char(sm))
    bin_f:write(string.char(fade))
    bin_f:write(string.char(pos))
    bin_f:write(tbw)
    bin_f:write(string.sub(pal, 1, 32))  -- PAL0 (16 colors * 2 bytes)

    emu.frameadvance()
end

log("")
log("Verification checklist (per plan Task 1.4):")
log("  1. $051C cycles $40..$45 during OUT_ENTRY (matches NES baseline).")
log("  2. CRAM PAL0[8..15] progressively darken to $0000 during fade-out.")
log("  3. $0012 GameMode = $05 throughout (RoomRom keeps Mode 5 Play;")
log("     NES uses $10 fade->$0B cave-mode — divergence expected).")
log("  4. SWAP frame: CRAM[8..15] snaps to cave colors then to black.")
log("  5. IN_CAVE phase: CRAM[8..15] ramps up from black to cave palette.")

bin_f:close()
log_f:close()
print("Done. Capture written to:")
print("  " .. OUT_TXT)
print("  " .. OUT_BIN)
