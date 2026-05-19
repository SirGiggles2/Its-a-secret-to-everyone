-- Phase N (2026-05-18): live OAM scan for NES sprite sub-pal 3 usage.
-- Hypothesis: sprite_subpal_census.json static analysis claims ITEM bank
-- "observed_range" includes sub-pal 3. We currently clamp sub-pal 3 to 2
-- in ROOMROM_SUBPAL_PAL (sprite_render.c) + translate_attrs
-- (enemy_render.c). If census claim is true, sub-pal 3 sprites render
-- with wrong colors today.
--
-- This probe: boot ROM, advance N frames, sample Genesis SAT every
-- frame, log any sprite where the OAM attr palette field == PAL3 (3).
-- Genesis SAT lives at $F400-$F67F per init_video.
--
-- Genesis SAT entry format (8 bytes):
--   word 0: Y coord
--   word 1: size byte + link byte
--   word 2: pal/prio/flip/tile (attr)
--   word 3: X coord
--
-- attr layout: [P V H pal(2) tile_id(11)]
-- pal bits = (attr >> 13) & 0x03
--
-- We want to find frames where pal==3 (PAL3 = NES sub-pal 2 today, OR
-- a misrouted sub-pal 3 sprite). To distinguish, also dump the tile_id;
-- tiles in ITEM/SPR range matching known ITEM bank IDs = sub-pal target.

local OUT = os.getenv("CODEX_BIZHAWK_ROOT") or "."
local LOG_PATH = OUT .. "/shots/subpal3_live.log"
os.execute('mkdir "' .. (OUT .. "/shots"):gsub("/", "\\") .. '" 2>nul')

local f = io.open(LOG_PATH, "w")
local function log(msg)
    f:write(msg .. "\n")
end

log("Phase N — sub-pal 3 live OAM probe")
log("====================================")
log("SAT base = $F400 (80 entries × 8 bytes)")
log("")

local SAT_BASE = 0xF400
local SAT_ENTRIES = 80

local function scan_sat()
    local pal3_hits = {}
    for i = 0, SAT_ENTRIES - 1 do
        local entry_addr = SAT_BASE + i * 8
        -- BizHawk: read VRAM domain. word 2 = attr (offset +4 within entry).
        local attr_hi = memory.read_u8(entry_addr + 4, "VRAM")
        local attr_lo = memory.read_u8(entry_addr + 5, "VRAM")
        local attr = attr_hi * 256 + attr_lo
        local pal = math.floor(attr / 0x2000) % 4
        if pal == 3 then
            local tile = attr % 0x800
            local y_hi = memory.read_u8(entry_addr + 0, "VRAM")
            local y_lo = memory.read_u8(entry_addr + 1, "VRAM")
            local y = y_hi * 256 + y_lo
            pal3_hits[#pal3_hits + 1] = string.format(
                "slot=%2d tile=%4d y=%d", i, tile, y)
        end
    end
    return pal3_hits
end

-- Skip 60 frames for boot, then scan every 30 frames for 5 seconds (300 frames).
for i = 1, 60 do emu.frameadvance() end

local total_unique_hits = {}
for sweep = 1, 10 do
    for i = 1, 30 do emu.frameadvance() end
    local hits = scan_sat()
    if #hits > 0 then
        log(string.format("frame=%d  PAL3 sprites: %d", emu.framecount(), #hits))
        for _, h in ipairs(hits) do
            log("  " .. h)
            total_unique_hits[h] = true
        end
    end
end

local unique_count = 0
for _ in pairs(total_unique_hits) do unique_count = unique_count + 1 end

log("")
log(string.format("Unique PAL3 sprite signatures observed: %d", unique_count))
if unique_count == 0 then
    log("RESULT: no PAL3 sprites in reachable scenes (title only,")
    log("Phase W title->story crash blocks gameplay observation).")
    log("Sub-pal 3 clamp in ROOMROM_SUBPAL_PAL appears safe in current scope.")
else
    log("RESULT: PAL3 sprites detected. Likely candle/magic_shot/red enemies")
    log("rendering correctly via Phase B/F routing (sub-pal 2 -> PAL3).")
    log("If any tile IDs land in the ITEM bank range and were expected to")
    log("use sub-pal 3 per NES asm, clamp is masking a regression.")
end
f:close()
print("subpal3_live_probe: wrote " .. LOG_PATH)
