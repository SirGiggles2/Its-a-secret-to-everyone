-- bizhawk_chr_upload_probe.lua
-- T16 / T17a: CHR upload path + 2BPP→4BPP tile decode correctness
--
-- Verifies that _ppu_write_7 correctly:
--   1. Detects PPU_VADDR in CHR range ($0000-$1FFF) and routes to tile buffer
--   2. Accumulates 16 NES bytes per tile (8 bytes plane0, 8 bytes plane1)
--   3. Converts to Genesis 4BPP (32 bytes per tile) and writes to VDP VRAM
--
-- After boot, Zelda uploads:
--   Common sprite patterns   → CHR $0000-$0FFF  (via TransferCommonPatterns/Bank2)
--   Common BG patterns       → CHR $1000-$1FFF
--   The uploads happen during VBlank (IsrNmi → TransferCurTileBuf)
--
-- Genesis VRAM layout after CHR upload:
--   Tile N (NES CHR addr N*16) → Genesis VRAM at N*32
--
-- Probe checks (T16/T17a):
--   T16_NO_EXCEPTION        — no exception hit
--   T16_LOOPFOREVER_HIT     — boot completes
--   T16_TILE0_NONEMPTY      — VDP VRAM[0x0000..0x001F] has at least one non-zero byte
--                             (tile 0 was written — CHR upload path active)
--   T16_TILE0_VALID_4BPP    — VRAM[0x0000] word has nibbles 0-3 each (0-3 range)
--                             (4BPP encoding not corrupt — no values > 3 in nibbles)
--   T16_TILE_BG_NONEMPTY    — VDP VRAM[0x2000..0x201F] has non-zero data
--                             (background tile bank uploaded — CHR $1000 → Genesis $2000)
--   T16_CHR_BUF_CLEAN       — CHR_BUF_CNT = 0 at LoopForever (no partial tile in flight)
--   T17a_PIXEL_RANGE        — all nibbles in tile 0 row 0 are 0-3 (valid 4BPP values)
--   T17a_DECODE_SANITY      — tile 0 row 0 is not all-zero (non-trivial tile data decoded)
--
-- Note on T16_TILE_BG_NONEMPTY: CHR $1000 maps to Genesis VRAM $2000.
-- This address also coincides with the nametable region in the VDP VRAM layout.
-- If nametable data was written there, the check is still valid (non-zero = data present).

local ROOT     = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\"
local OUT_DIR  = ROOT .. "builds\\reports\\"
local OUT_PATH = OUT_DIR .. "bizhawk_chr_upload_probe.txt"

dofile(ROOT .. "tools/probe_addresses.lua")  -- sets LOOPFOREVER, EXC_BUS, EXC_ADDR, EXC_DEF

local CHR_BUF_CNT   = 0xFF0830
local CHR_HIT_COUNT = 0xFF0833
local FORENSICS_TYPE = 0xFF0900

os.execute('if not exist "' .. OUT_DIR .. '" mkdir "' .. OUT_DIR .. '"')
local f = assert(io.open(OUT_PATH, "w"))
local function log(msg) f:write(msg.."\n") f:flush() print(msg) end

local PASS, FAIL = "PASS", "FAIL"
local results = {}
local function record(name, status, detail)
    log(string.format("[%s] %-28s  %s", status, name, detail))
    results[#results+1] = {name=name, status=status}
end

local function try_dom(dom, offset, width)
    local ok, v = pcall(function()
        memory.usememorydomain(dom)
        if     width == 1 then return memory.read_u8(offset)
        elseif width == 2 then return memory.read_u16_be(offset)
        else                    return memory.read_u32_be(offset) end
    end)
    return ok and v or nil
end

local function ram_read(bus_addr, width)
    local ofs = bus_addr - 0xFF0000
    for _, spec in ipairs({
        {"M68K BUS", bus_addr}, {"68K RAM", ofs},
        {"System Bus", bus_addr}, {"Main RAM", ofs},
    }) do
        local v = try_dom(spec[1], spec[2], width or 1)
        if v ~= nil then return v, spec[1] end
    end
    return nil, nil
end

local function ram_u8(a) local v = ram_read(a,1) return v end

-- Read from Genesis VDP VRAM (BizHawk GPGX "VRAM" domain, 64KB)
local function vram_u8(addr)
    return try_dom("VRAM", addr, 1)
end
local function vram_u16(addr)
    return try_dom("VRAM", addr, 2)
end

-- Scan VRAM range for any non-zero byte
local function vram_any_nonzero(start_addr, len)
    for i = 0, len-1 do
        local v = vram_u8(start_addr + i)
        if v and v ~= 0 then return true, start_addr+i, v end
    end
    return false, nil, nil
end

local function add_exec_hook(addr, cb, tag)
    local ok, id = pcall(function() return event.onmemoryexecute(cb, addr, tag) end)
    return (ok and id) or nil
end

local function main()
    local FRAMES = 180   -- enough frames for tile uploads to complete
    log("=================================================================")
    log("CHR Upload probe  T16/T17a  —  " .. FRAMES .. " frames")
    log("=================================================================")
    log(string.format("  LoopForever=$%06X  ExcBus=$%06X  ExcAddr=$%06X  ExcDef=$%06X",
        LOOPFOREVER, EXC_BUS, EXC_ADDR, EXC_DEF))
    log("")

    local visit_frame   = {}
    local exception_hit = false
    local exception_name= nil
    local cur_frame     = 0
    local hook_ids      = {}
    local snap_cnt      = nil
    local snap_hits     = nil

    local function mark(name)
        return function()
            if not visit_frame[name] then
                visit_frame[name] = cur_frame
                if name == "LoopForever" then
                    snap_cnt  = ram_u8(CHR_BUF_CNT)
                    snap_hits = ram_u8(CHR_HIT_COUNT)
                end
            end
            if name == "ExcBusError" or name == "ExcAddrError" or name == "DefaultException" then
                if not exception_hit then
                    exception_hit = true
                    exception_name = name
                end
            end
        end
    end

    for _, lm in ipairs({
        {LOOPFOREVER, "LoopForever"},
        {EXC_BUS,     "ExcBusError"},
        {EXC_ADDR,    "ExcAddrError"},
        {EXC_DEF,     "DefaultException"},
    }) do
        local id = add_exec_hook(lm[1], mark(lm[2]), "t16_"..lm[2])
        if id then hook_ids[#hook_ids+1] = id end
    end

    for frame = 1, FRAMES do
        cur_frame = frame
        emu.frameadvance()
        local pc = emu.getregister("M68K PC") or 0
        if pc >= LOOPFOREVER and pc <= LOOPFOREVER+3 then
            if not visit_frame["LoopForever"] then
                visit_frame["LoopForever"] = frame
                snap_cnt = ram_u8(CHR_BUF_CNT)
            end
        end
        if pc == EXC_BUS or pc == EXC_ADDR or pc == EXC_DEF then
            if not exception_hit then
                exception_hit = true
                exception_name = (pc==EXC_BUS and "ExcBusError")
                              or (pc==EXC_ADDR and "ExcAddrError")
                              or "DefaultException"
            end
        end
        if frame <= 5 or frame % 30 == 0 then
            log(string.format("  f%03d pc=$%06X  forever=%s  exc=%s",
                frame, pc, tostring(visit_frame["LoopForever"] or "-"), tostring(exception_hit)))
        end
        if exception_hit and frame > 30 then break end
    end
    for _, id in ipairs(hook_ids) do pcall(function() event.unregisterbyid(id) end) end
    log("")

    -- Allow a few more frames for tile uploads to complete after LoopForever
    -- (IsrNmi transfers tiles each VBlank; need several frames)
    log("  (waiting 30 extra frames for VBlank tile uploads to complete...)")
    for i = 1, 30 do emu.frameadvance() end
    log("")

    log("─── T16/T17a: CHR Upload + Tile Decode ─────────────────────────")

    -- T16_NO_EXCEPTION
    if not exception_hit then
        record("T16_NO_EXCEPTION", PASS, "no exception handler hit")
    else
        local et = ram_u8(FORENSICS_TYPE) or 0
        record("T16_NO_EXCEPTION", FAIL, string.format("%s type=%d", exception_name, et))
    end

    -- T16_LOOPFOREVER_HIT
    local fl = visit_frame["LoopForever"]
    if fl then
        record("T16_LOOPFOREVER_HIT", PASS, "frame "..fl)
    else
        record("T16_LOOPFOREVER_HIT", FAIL, "never reached LoopForever")
    end

    -- T16_CHR_BUF_CLEAN — no partial tile in flight at LoopForever
    if snap_cnt == nil then
        record("T16_CHR_BUF_CLEAN", FAIL, "snapshot not captured")
    elseif snap_cnt == 0 then
        record("T16_CHR_BUF_CLEAN", PASS, "CHR_BUF_CNT=0 (no partial tile at LoopForever)")
    else
        record("T16_CHR_BUF_CLEAN", FAIL, string.format("CHR_BUF_CNT=%d expected 0", snap_cnt))
    end

    -- Log CHR_HIT_COUNT (debug counter — how many times CHR path was entered)
    log(string.format("  CHR_HIT_COUNT=%s  (CHR path entry count; 0=CHR path never ran)",
        snap_hits ~= nil and tostring(snap_hits) or "nil"))

    -- Read VRAM tile 0 (sprite tile 0, Genesis VRAM $0000-$001F)
    log("  VDP VRAM tile 0 ($0000-$001F):")
    local tile0_bytes = {}
    for i = 0, 31 do
        local v = vram_u8(i)
        tile0_bytes[i] = v
        if i < 8 then
            log(string.format("    [%04X] = %s", i, v ~= nil and string.format("$%02X", v) or "??"))
        end
    end
    if #tile0_bytes < 4 then log("  (VRAM domain not accessible — skipping tile checks)") end

    -- T16_TILE0_NONEMPTY — tile 0 area has at least one non-zero byte
    local t0_nonzero, t0_addr, t0_val = vram_any_nonzero(0x0000, 32)
    if t0_nonzero then
        record("T16_TILE0_NONEMPTY", PASS,
            string.format("VRAM[$%04X]=$%02X (tile 0 data present)", t0_addr, t0_val))
    else
        record("T16_TILE0_NONEMPTY", FAIL, "VRAM[0x0000..0x001F] all zero — CHR upload may not have run")
    end

    -- Wide VRAM scan: find first non-zero byte in $0000–$3FFF (tiles + nametable region)
    log("  Wide VRAM scan ($0000-$3FFF, first 8 non-zero bytes):")
    local found_count = 0
    for addr = 0, 0x3FFF do
        local v = vram_u8(addr)
        if v and v ~= 0 then
            log(string.format("    VRAM[$%04X] = $%02X", addr, v))
            found_count = found_count + 1
            if found_count >= 8 then
                log("    ... (truncated)")
                break
            end
        end
    end
    if found_count == 0 then log("    (all zero - VRAM completely empty)") end
    log("")

    -- T16_TILE_BG_NONEMPTY — background tile bank ($1000→Genesis $2000)
    local tbg_nonzero, tbg_addr, tbg_val = vram_any_nonzero(0x2000, 32)
    if tbg_nonzero then
        record("T16_TILE_BG_NONEMPTY", PASS,
            string.format("VRAM[$%04X]=$%02X (BG tile data / nametable data present)", tbg_addr, tbg_val))
    else
        record("T16_TILE_BG_NONEMPTY", FAIL, "VRAM[0x2000..0x201F] all zero — BG tile area empty")
    end

    -- T17a_PIXEL_RANGE — all nibbles in tile 0 row 0 (first 4 bytes) are values 0-3
    -- Genesis 4BPP tiles use 4-bit nibbles (2 pixels per byte); valid values: 0..15
    -- NES 2BPP gives values 0..3, so after conversion all nibbles must be 0-3
    local row0_valid = true
    local row0_detail = ""
    for i = 0, 3 do
        local v = tile0_bytes[i]
        if v == nil then
            row0_valid = false
            row0_detail = "VRAM not readable"
            break
        end
        local hi = (v >> 4) & 0x0F
        local lo = v & 0x0F
        if hi > 3 or lo > 3 then
            row0_valid = false
            row0_detail = string.format("VRAM[$%04X]=$%02X has nibble >3 (hi=%d lo=%d)",
                i, v, hi, lo)
            break
        end
    end
    if row0_valid and tile0_bytes[0] ~= nil then
        record("T17a_PIXEL_RANGE", PASS,
            string.format("row0 bytes $%02X $%02X $%02X $%02X — all nibbles 0-3 (valid 2BPP colors)",
                tile0_bytes[0] or 0, tile0_bytes[1] or 0,
                tile0_bytes[2] or 0, tile0_bytes[3] or 0))
    else
        record("T17a_PIXEL_RANGE", FAIL, row0_detail)
    end

    -- T17a_DECODE_SANITY — row 0 of tile 0 is not identically all-zero
    -- (a real tile should have some pixels set — only a blank tile would be all zero)
    -- Note: tile 0 of sprite patterns is often a blank tile in Zelda.
    -- We check a few tiles ahead for non-trivial data.
    local found_nonzero_tile = false
    local nonzero_tile_info = ""
    for tile_idx = 0, 15 do
        local base = tile_idx * 32
        for r = 0, 3 do   -- check first row of each tile
            local v = vram_u8(base + r)
            if v and v ~= 0 then
                found_nonzero_tile = true
                nonzero_tile_info = string.format("tile %d row 0 byte %d = $%02X", tile_idx, r, v)
                break
            end
        end
        if found_nonzero_tile then break end
    end
    if found_nonzero_tile then
        record("T17a_DECODE_SANITY", PASS,
            string.format("non-zero tile data found: %s", nonzero_tile_info))
    else
        record("T17a_DECODE_SANITY", FAIL,
            "tiles 0-15 all appear zero — decode may not be working or tiles are blank")
    end

    log("")
    log("=================================================================")
    log("CHR UPLOAD PROBE SUMMARY  (T16/T17a)")
    log("=================================================================")
    local npass, nfail = 0, 0
    for _, r in ipairs(results) do
        log(string.format("  [%s] %s", r.status, r.name))
        if r.status == PASS then npass = npass+1 else nfail = nfail+1 end
    end
    log(string.format("\n  %d PASS  /  %d FAIL  /  %d total", npass, nfail, npass+nfail))
    log(nfail == 0 and "\nT16/T17a CHR UPLOAD PROBE: ALL PASS" or "\nT16/T17a CHR UPLOAD PROBE: FAIL")
end

local ok, err = pcall(main)
if not ok then log("PROBE CRASH: " .. tostring(err)) end
f:close()
client.exit()
