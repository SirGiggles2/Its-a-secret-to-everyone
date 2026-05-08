-- probe_nes_triforce_fire_chr.lua
-- PR-3 ground-truth: dump NES PPU pattern table tiles for $6E
-- (triforce piece) and $5C (candle fire frame 0) during active
-- render context.
--
-- Usage: launch BizHawk NES core with vanilla zelda1.nes, run this
-- script, navigate to (a) any UW boss room with triforce piece on
-- screen, (b) any UW dark room with candle activated. Press Z each
-- time to capture; output JSON appends to C:\tmp\nes_chr_capture.json.

local out_path = "C:\\tmp\\nes_chr_capture.json"

-- BizHawk NES core memory domains: "PPU Bus" reads pattern table.
-- $0000-$0FFF = pattern table 0 (sprites if PPUCTRL bit 3 = 0)
-- $1000-$1FFF = pattern table 1 (sprites if PPUCTRL bit 3 = 1)

local function dump_tile(bank_base, tile_id)
    local off = bank_base + tile_id * 16
    local bytes = {}
    for i = 0, 15 do
        local b = memory.read_u8(off + i, "PPU Bus")
        table.insert(bytes, string.format("%02X", b))
    end
    return table.concat(bytes)
end

local function nonzero_count(hex)
    local n = 0
    for i = 1, #hex, 2 do
        if hex:sub(i, i+1) ~= "00" then n = n + 1 end
    end
    return n
end

local function read_oam_tile_for_id(target_tile_id)
    -- Scan OAM for any sprite using target_tile_id; return its
    -- attribute byte (sub-pal in bits 0-1).
    for slot = 0, 63 do
        local oam_off = slot * 4
        local tile_id = memory.read_u8(oam_off + 1, "OAM")
        if tile_id == target_tile_id then
            return slot, memory.read_u8(oam_off + 2, "OAM")
        end
    end
    return nil, nil
end

local capture_count = 0
local prev_z = false

print("[probe_nes_chr] ready. Press Z in BizHawk to capture current frame.")
print("[probe_nes_chr] Will dump tile $6E + $5C from both PPU banks.")
print("[probe_nes_chr] Output: " .. out_path)

while true do
    local input = joypad.get(1)
    local z_pressed = input.Z or false

    if z_pressed and not prev_z then
        capture_count = capture_count + 1
        local frame = emu.framecount()

        -- Dump from both pattern banks for both tiles.
        local results = {}
        for _, tid in ipairs({0x6E, 0x5C, 0x9E, 0x44, 0xCE}) do
            for _, base in ipairs({{name="bank0", base=0x0000}, {name="bank1", base=0x1000}}) do
                local hex = dump_tile(base.base, tid)
                local nz = nonzero_count(hex)
                local oam_slot, oam_attr = read_oam_tile_for_id(tid)
                table.insert(results, string.format(
                    '    {"tile_id":"0x%02X","bank":"%s","ppu_addr":"0x%04X","bytes":"%s","nonzero":%d,"oam_slot":%s,"oam_attr":%s}',
                    tid, base.name, base.base + tid*16, hex, nz,
                    oam_slot and tostring(oam_slot) or "null",
                    oam_attr and string.format("\"0x%02X\"", oam_attr) or "null"
                ))
            end
        end

        -- Append entry to file.
        local f = io.open(out_path, "a")
        if f then
            f:write(string.format('{"capture":%d,"frame":%d,"tiles":[\n%s\n]},\n',
                capture_count, frame, table.concat(results, ",\n")))
            f:close()
            print(string.format("[probe_nes_chr] capture #%d at frame %d -> %s",
                capture_count, frame, out_path))
        end
    end
    prev_z = z_pressed

    emu.frameadvance()
end
