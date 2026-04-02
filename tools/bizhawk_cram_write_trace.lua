-- bizhawk_cram_write_trace.lua
-- Trace VDP register state and CRAM writes.
-- Focus: capture exactly what PPU_VADDR and data values are when CRAM changes.

local ROOT     = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\"
local OUT_PATH = ROOT .. "builds\\reports\\bizhawk_cram_write_trace.txt"
local f = assert(io.open(OUT_PATH, "w"))
local function log(msg) f:write(msg.."\n") f:flush() print(msg) end

local frame_count = 0
local CAPTURE_END = 120

local function rb(offset)
    local ok, v = pcall(function()
        memory.usememorydomain("M68K BUS")
        return memory.read_u8(0xFF0000 + offset)
    end)
    return ok and v or 0xFF
end

local function rw(addr)
    local ok, v = pcall(function()
        memory.usememorydomain("M68K BUS")
        return memory.read_u16_be(addr)
    end)
    return ok and v or 0
end

local function read_cram_u16(addr)
    for _, d in ipairs({"CRAM", "VDP CRAM", "Color RAM"}) do
        local ok, v = pcall(function()
            memory.usememorydomain(d)
            return memory.read_u16_be(addr)
        end)
        if ok and v ~= nil then return v end
    end
    return 0
end

log("=================================================================")
log("CRAM Write Trace — focused on frame 94-100")
log("=================================================================")
log("")

-- Snapshot all 64 CRAM entries
local prev_cram = {}
for i = 0, 63 do
    prev_cram[i] = read_cram_u16(i * 2)
end

-- Track VDP state by reading PPU state from NES RAM shadow
event.onframeend(function()
    frame_count = frame_count + 1
    if frame_count > CAPTURE_END then return end

    -- Read the zero-page pointer that TransferCurTileBuf uses
    local zp0 = rb(0x0000)
    local zp1 = rb(0x0001)
    local zp2 = rb(0x0002)
    local zp3 = rb(0x0003)

    -- Read PPU state
    local vaddr_hi = rb(0x0802)
    local vaddr_lo = rb(0x0803)
    local vaddr = vaddr_hi * 256 + vaddr_lo
    local latch = rb(0x0800)
    local ctrl = rb(0x0804)
    local pc = 0
    local ok, v = pcall(function()
        memory.usememorydomain("M68K BUS")
        return emu.getregister("M68K PC")
    end)
    if ok and v then pc = v end

    -- Check for any CRAM changes
    local changes = {}
    for i = 0, 63 do
        local cur = read_cram_u16(i * 2)
        if cur ~= prev_cram[i] then
            table.insert(changes, {idx=i, old=prev_cram[i], new=cur})
            prev_cram[i] = cur
        end
    end

    if #changes > 0 then
        log(string.format("=== CRAM CHANGE frame %d  PC=$%06X ===", frame_count, pc))
        log(string.format("  VADDR=$%04X latch=%d ctrl=$%02X", vaddr, latch, ctrl))
        log(string.format("  ZP: $%02X $%02X $%02X $%02X (ptr=$%04X)", zp0, zp1, zp2, zp3, zp1*256+zp0))
        log(string.format("  DynBuf[0]=$%02X DynBuf[1]=$%02X DynBuf[2]=$%02X DynBuf[3]=$%02X",
            rb(0x0302), rb(0x0303), rb(0x0304), rb(0x0305)))
        for _, c in ipairs(changes) do
            local pal = c.idx // 16
            local col = c.idx % 16
            log(string.format("  CRAM[%d][%02d] = $%04X → $%04X", pal, col, c.old, c.new))
        end
        log("")
    end

    -- Also log state at key frames
    if frame_count >= 90 and frame_count <= 100 then
        log(string.format("f%03d: PC=$%06X VADDR=$%04X latch=%d ZP=$%02X%02X DynBuf[0]=$%02X sub=$%02X",
            frame_count, pc, vaddr, latch, zp1, zp0, rb(0x0302), rb(0x042D)))
    end

    if frame_count == CAPTURE_END then
        log("")
        log("=================================================================")
        log("CRAM WRITE TRACE COMPLETE")
        log("=================================================================")
        f:close()
        client.exit()
    end
end)

while true do
    emu.frameadvance()
end
