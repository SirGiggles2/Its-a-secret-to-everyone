-- Dump SAT slot 8 + PAL1 entries 8-11 mid-fire-active.
-- VDP SAT in Genesis lives at $C000 + offset (set by SGDK).
-- Use BizHawk "VRAM" + "CRAM" domains.

do
    local ok = pcall(function() memory.usememorydomain("68K RAM") end)
    if not ok then memory.usememorydomain("Main RAM") end
end

local function read_main(off) return memory.read_u8(off, "68K RAM") end

-- VRAM SAT base: SGDK default $F400 in VDP VRAM. Each entry = 8 bytes:
--   y_lo y_hi sz link_attr_hi attr_lo tile_hi tile_lo x_hi x_lo
-- Actually Genesis sprite entry = 8 bytes:
--   $0: Y_pos (10 bits, lower 8 here, upper 2 in $1)
--   $1: link (next sprite) + size
--   $2: attr_hi (priority/pal/flip/tile_hi)
--   $3: tile_lo
--   ...wait — proper layout:
--   bytes 0-1: Y position (s16 BE)
--   byte 2: size+link top byte? Need accurate layout.
-- Genesis SAT entry (from VDP doc):
--   word 0: y position
--   word 1: high nibble = size (HHVV bits), low byte = link
--   word 2: priority/pal/flip/tile (TILE_ATTR_FULL format)
--   word 3: x position

local function read_vram(off)
    return memory.read_u8(off, "VRAM")
end

local function read_cram_word(idx)
    -- CRAM is 64 entries, 9-bit color, 16-bit aligned.
    local hi = memory.read_u8(idx*2, "CRAM")
    local lo = memory.read_u8(idx*2 + 1, "CRAM")
    return hi*256 + lo
end

local SAT_BASE = 0xAC00  -- CombinedDebug actual SAT base (not SGDK default $F400)
local DBG = 0x7280
local out = "C:\\tmp\\cd_sat_pal1.txt"

local fcount = 0
local dumped = false

while fcount < 600 do
    local input = {}
    if fcount >= 60 and fcount < 80 then
        input.A = true; input.B = true; input.C = true
    end
    if fcount == 200 or fcount == 201 then input.Z = true end
    if fcount == 230 or fcount == 231 then input.Z = true end
    if fcount == 260 or fcount == 261 then input.Z = true end
    if fcount == 320 or fcount == 321 then input.B = true end
    joypad.set(input, 1)

    -- Dump at frame 350 (mid-fire active per prior probe).
    if fcount == 350 and not dumped then
        dumped = true
        local f = io.open(out, "w")
        if f then
            -- Look for sprite-table-like entries: y_pos != 0 and y_pos < $200,
            -- size byte plausible (1-15), x_pos in screen range.
            f:write("=== Sprite-pattern hunt across whole VRAM ===\n")
            local hits = 0
            for off = 0, 0xFFF8, 8 do
                local r = {}
                for i = 0, 7 do r[i] = read_vram(off + i) end
                local y = r[0]*256 + r[1]
                local sz = r[2]
                local link = r[3]
                local x = r[6]*256 + r[7]
                -- Plausible sprite: y in [0x80, 0x1FF], x in [0x80, 0x1FF],
                -- size byte low 4 bits in 0..15, link byte 0..127.
                if y >= 0x80 and y <= 0x1FF and x >= 0x80 and x <= 0x1FF
                    and sz <= 0x0F and link <= 0x7F then
                    if hits < 20 then
                        f:write(string.format("$%04X: y=%d x=%d sz=%d link=%d attr=$%02X%02X tile_lo=$%02X\n",
                            off, y, x, sz, link, r[4], r[5], r[5]))
                        hits = hits + 1
                    end
                end
            end
            f:write(string.format("(showed first %d sprite-pattern hits)\n\n", hits))
            -- Scan whole VRAM for nonzero sprite-like patterns.
            f:write("=== VRAM scan: nonzero 8-byte chunks $C000-$FFFF ===\n")
            local found_count = 0
            for off = 0xC000, 0xFFF8, 8 do
                local r = {}
                for i = 0, 7 do r[i] = read_vram(off + i) end
                local nz = 0
                for i = 0, 7 do if r[i] ~= 0 then nz = nz + 1 end end
                if nz >= 4 and found_count < 30 then
                    f:write(string.format("$%04X: %02X %02X %02X %02X %02X %02X %02X %02X (nz=%d)\n",
                        off, r[0], r[1], r[2], r[3], r[4], r[5], r[6], r[7], nz))
                    found_count = found_count + 1
                end
            end
            f:write(string.format("(showed first %d of nonzero chunks)\n\n", found_count))
            -- SAT slot 8 = SAT_BASE + 8*8 = $F440
            f:write("=== SAT slot 8 (candle fire) at frame 350 ===\n")
            local slot8 = SAT_BASE + 8*8
            local raw = {}
            for i = 0, 7 do raw[i] = read_vram(slot8 + i) end
            f:write(string.format("raw bytes: %02X %02X %02X %02X %02X %02X %02X %02X\n",
                raw[0], raw[1], raw[2], raw[3], raw[4], raw[5], raw[6], raw[7]))
            local y = raw[0]*256 + raw[1]
            local size = (raw[2] >> 0) & 0x0F
            local link = raw[3]
            local attr = raw[4]*256 + raw[5]
            local x = raw[6]*256 + raw[7]
            local tile = attr & 0x07FF
            local pal = (attr >> 13) & 0x03
            local pri = (attr >> 15) & 0x01
            local hflip = (attr >> 11) & 0x01
            local vflip = (attr >> 12) & 0x01
            f:write(string.format("y=%d size=%d link=%d attr=$%04X x=%d\n",
                y, size, link, attr, x))
            f:write(string.format("decoded: tile=%d pal=%d pri=%d hflip=%d vflip=%d\n",
                tile, pal, pri, hflip, vflip))
            f:write("\n=== SAT slots 0-9 (all) ===\n")
            for slot = 0, 9 do
                local b = SAT_BASE + slot*8
                local r = {}
                for i = 0, 7 do r[i] = read_vram(b + i) end
                local sy = r[0]*256 + r[1]
                local sx = r[6]*256 + r[7]
                local sa = r[4]*256 + r[5]
                local stile = sa & 0x07FF
                f:write(string.format("slot %d: y=%d x=%d size=%d link=%d tile=%d attr=$%04X\n",
                    slot, sy, sx, r[2] & 0x0F, r[3], stile, sa))
            end
            f:write("\n=== CRAM PAL1 (entries 16-31) ===\n")
            for i = 16, 31 do
                f:write(string.format("PAL1[%2d] = $%04X\n", i, read_cram_word(i)))
            end
            f:write("\n=== mirror diag ===\n")
            f:write(string.format("$FF7280 arrow=%d $FF7281 fire=%d $FF7282 b_item=%d\n",
                read_main(0x7280), read_main(0x7281), read_main(0x7282)))
            f:close()
        end
        print("[probe_cd_sat] dumped to " .. out)
    end

    fcount = fcount + 1
    emu.frameadvance()
end
