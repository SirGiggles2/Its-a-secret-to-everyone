-- Genesis VDP/CRAM/VRAM/VSRAM/SAT capture (S1 Phase F, Task F1/F2 support).
--
-- Produces a single binary dump file at the configured FRAME_TARGET.
-- Format = sequence of tagged regions (see diff_capture.py for the
-- canonical reader):
--
--   header: 4 bytes magic "GDMP" + 4 bytes version u32 LE + 4 bytes
--           frame counter u32 LE + 4 bytes ROM hash truncated u32 LE
--   regions: each is 4-byte ascii tag + 4-byte length u32 LE + payload
--   terminator: tag "END_" with length 0
--
-- Tags (4-char fixed):
--   "PLNA"  Plane A nametable (8 KB at VRAM $C000..$DFFF)
--   "PLNB"  Plane B nametable (8 KB at VRAM $E000..$FFFF)
--   "SAT_"  Sprite attribute table (640 bytes at VRAM $FC00..$FE7F)
--   "CRAM"  Color RAM (128 bytes total)
--   "VSRA"  Vertical scroll RAM (80 bytes total)
--   "RAM_"  68K work RAM page $FF0000..$FF00FF (256 bytes - selected ZP)
--
-- Frame target is configurable via global FRAME_TARGET set before
-- this script loads, default 240. Output path also configurable via
-- DUMP_OUT, default C:\\tmp\\capture_gen.bin.

local FRAME_TARGET = FRAME_TARGET or 240
local DUMP_OUT     = DUMP_OUT or "C:\\tmp\\capture_gen.bin"

-- Wait for target frame, then capture.
while emu.framecount() < FRAME_TARGET do
    emu.frameadvance()
end

local function vram_read_block(start, size)
    local buf = {}
    for i = 0, size - 1 do
        buf[#buf + 1] = string.char(memory.read_u8(start + i, "VRAM"))
    end
    return table.concat(buf)
end

local function cram_read()
    local buf = {}
    for i = 0, 127 do
        buf[#buf + 1] = string.char(memory.read_u8(i, "CRAM"))
    end
    return table.concat(buf)
end

local function vsram_read()
    local buf = {}
    for i = 0, 79 do
        buf[#buf + 1] = string.char(memory.read_u8(i, "VSRAM"))
    end
    return table.concat(buf)
end

local function ram_read_zp()
    local buf = {}
    for i = 0, 255 do
        buf[#buf + 1] = string.char(memory.read_u8(i, "68K RAM"))
    end
    return table.concat(buf)
end

local function u32le(v)
    return string.char(v & 0xFF) ..
           string.char((v >> 8) & 0xFF) ..
           string.char((v >> 16) & 0xFF) ..
           string.char((v >> 24) & 0xFF)
end

local plana = vram_read_block(0xC000, 0x2000)
local planb = vram_read_block(0xE000, 0x2000)
local sat   = vram_read_block(0xFC00, 640)
local cram  = cram_read()
local vsra  = vsram_read()
local zp    = ram_read_zp()

-- Trivial 32-bit hash of dump payload for header (helps spot which
-- ROM produced the dump without re-reading the whole file).
local function fnv32(s)
    local h = 2166136261
    for i = 1, #s do
        h = (h ~ string.byte(s, i)) * 16777619
        h = h & 0xFFFFFFFF
    end
    return h
end
local payload_for_hash = plana .. planb .. sat .. cram .. vsra
local rom_hash_trunc = fnv32(payload_for_hash)

local f = io.open(DUMP_OUT, "wb")
-- Header
f:write("GDMP")
f:write(u32le(1))                          -- version
f:write(u32le(emu.framecount()))           -- frame
f:write(u32le(rom_hash_trunc))             -- payload-hash trunc

local function region(tag, payload)
    f:write(tag)
    f:write(u32le(#payload))
    f:write(payload)
end

region("PLNA", plana)
region("PLNB", planb)
region("SAT_", sat)
region("CRAM", cram)
region("VSRA", vsra)
region("RAM_", zp)
region("END_", "")

f:close()
client.exit()
