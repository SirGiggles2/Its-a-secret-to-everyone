-- WHAT IF Phase 2 smoke test for BizHawk
--
-- Usage:
--   1. Open builds/whatif.md in BizHawk EmuHawk.
--   2. Run this script from Tools -> Lua Console.
--      or autoload it from the BizHawk Lua session list.
--
-- What it checks:
--   - the 68000 frame counter advances
--   - the renderer repopulates exactly 4 sprite entries each frame
--   - the sprite shadow table matches the smoke-scene 2x2 metasprite layout
--   - the queued transfer system processes non-zero work without overflow
--   - tilemap queue activity continues across multiple frames

local OUT_DIR  = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\VDP rebirth tools and asms\\WHAT IF\\builds\\reports\\"
local OUT_PATH = OUT_DIR .. "bizhawk_phase2_smoke.txt"

local ram_domains = { "M68K BUS", "68K RAM", "System Bus" }

os.execute('if not exist "' .. OUT_DIR .. '" mkdir "' .. OUT_DIR .. '"')
local log_file = assert(io.open(OUT_PATH, "w"))

local function log(msg)
    log_file:write(msg .. "\n")
    log_file:flush()
    print(msg)
end

local function try_read(domain, addr, kind)
    local ok, value = pcall(function()
        memory.usememorydomain(domain)
        if kind == "u8" then
            return memory.read_u8(addr)
        end
        if kind == "u16" then
            return memory.read_u16_be(addr)
        end
        if kind == "u32" then
            return memory.read_u32_be(addr)
        end
        error("unsupported read kind: " .. tostring(kind))
    end)
    if ok then
        return value
    end
    return nil
end

local function read_candidates(kind, addresses)
    for _, domain in ipairs(ram_domains) do
        for _, addr in ipairs(addresses) do
            local value = try_read(domain, addr, kind)
            if value ~= nil then
                return value, domain, addr
            end
        end
    end
    error("unable to read " .. kind .. " from any candidate address")
end

local function assert_equal(name, actual, expected)
    if actual ~= expected then
        error(string.format("%s mismatch: expected %s, got %s", name, expected, actual))
    end
end

local function read_sprite_entry(index)
    local base_candidates = {
        0xFF0380 + index * 8,
        0x0380 + index * 8,
    }

    local y = read_candidates("u16", { base_candidates[1], base_candidates[2] })
    local link = read_candidates("u16", { base_candidates[1] + 2, base_candidates[2] + 2 })
    local tile = read_candidates("u16", { base_candidates[1] + 4, base_candidates[2] + 4 })
    local x = read_candidates("u16", { base_candidates[1] + 6, base_candidates[2] + 6 })
    return y, link, tile, x
end

local function wait_frames(count)
    for _ = 1, count do
        emu.frameadvance()
    end
end

local function wait_for_smoke_ready(limit_frames, sprite_count_addrs, tilemap_activity_addrs, queue_processed_addrs)
    local max_sprite_count = 0
    local max_tilemap_activity = 0
    local max_processed_total = 0
    for sample = 1, limit_frames do
        emu.frameadvance()
        local sprite_count = read_candidates("u16", sprite_count_addrs)
        local tilemap_activity = read_candidates("u32", tilemap_activity_addrs)
        local processed_total = read_candidates("u32", queue_processed_addrs)
        if sprite_count > max_sprite_count then
            max_sprite_count = sprite_count
        end
        if tilemap_activity > max_tilemap_activity then
            max_tilemap_activity = tilemap_activity
        end
        if processed_total > max_processed_total then
            max_processed_total = processed_total
        end
        if sprite_count == 4 and tilemap_activity > 0 and processed_total > 0 then
            return sample
        end
    end
    error(string.format(
        "smoke scene never became ready within %d frames (max_sprite_count=%d max_tilemap_activity=%d max_processed_total=%d)",
        limit_frames,
        max_sprite_count,
        max_tilemap_activity,
        max_processed_total
    ))
end

local function main()
    local frame_counter_addrs = { 0xFF0000, 0x0000 }
    local sprite_count_addrs = { 0xFF001A, 0x001A }
    local queue_submit_count_addrs = { 0xFF0018, 0x0018 }
    local queue_overflow_addrs = { 0xFF0010, 0x0010 }
    local queue_last_count_addrs = { 0xFF0012, 0x0012 }
    local tilemap_activity_addrs = { 0xFF0014, 0x0014 }
    local queue_processed_addrs = { 0xFF001C, 0x001C }
    local expected = {
        { y = 248, link = 1, tile = 41, x = 264 },
        { y = 248, link = 2, tile = 42, x = 272 },
        { y = 256, link = 3, tile = 43, x = 264 },
        { y = 256, link = 0, tile = 44, x = 272 },
    }

    local ready_after = wait_for_smoke_ready(240, sprite_count_addrs, tilemap_activity_addrs, queue_processed_addrs)
    local frame_before, frame_domain, frame_addr = read_candidates("u32", frame_counter_addrs)
    local pc_before = emu.getregister("M68K PC") or 0
    local tilemap_before, tilemap_domain, tilemap_addr = read_candidates("u32", tilemap_activity_addrs)
    local processed_before, processed_domain, processed_addr = read_candidates("u32", queue_processed_addrs)
    wait_frames(5)
    local frame_after = read_candidates("u32", frame_counter_addrs)
    local pc_after = emu.getregister("M68K PC") or 0

    log(string.format("smoke scene became ready after %d warmup frames", ready_after))
    log(string.format("frame counter source: domain=%s addr=%06X", tostring(frame_domain), frame_addr))
    log(string.format("tilemap activity source: domain=%s addr=%06X", tostring(tilemap_domain), tilemap_addr))
    log(string.format("processed queue source: domain=%s addr=%06X", tostring(processed_domain), processed_addr))
    log(string.format("pc before=%06X after=%06X", pc_before, pc_after))

    if frame_after <= frame_before and pc_after == pc_before then
        error(string.format(
            "no frame or PC progress detected: frame_before=%d frame_after=%d pc=%06X",
            frame_before,
            frame_after,
            pc_after
        ))
    end

    local sprite_domain, sprite_addr
    local max_sprite_count = 0
    local matched_frame = nil
    local queue_submit_domain, queue_submit_addr
    local queue_last_domain, queue_last_addr
    local overflow_domain, overflow_addr
    local max_queue_submit = 0
    local max_queue_last = 0
    local max_overflow = 0
    local tilemap_after = tilemap_before
    local processed_after = processed_before
    local tilemap_change_frames = 0
    local previous_tilemap_value = tilemap_before

    for sample = 1, 60 do
        emu.frameadvance()
        local sprite_count
        sprite_count, sprite_domain, sprite_addr = read_candidates("u16", sprite_count_addrs)
        local queue_submit_count
        queue_submit_count, queue_submit_domain, queue_submit_addr = read_candidates("u16", queue_submit_count_addrs)
        local queue_last
        queue_last, queue_last_domain, queue_last_addr = read_candidates("u16", queue_last_count_addrs)
        local overflow
        overflow, overflow_domain, overflow_addr = read_candidates("u16", queue_overflow_addrs)
        local tilemap_activity = read_candidates("u32", tilemap_activity_addrs)
        local queue_processed = read_candidates("u32", queue_processed_addrs)
        if sprite_count > max_sprite_count then
            max_sprite_count = sprite_count
        end
        if queue_submit_count > max_queue_submit then
            max_queue_submit = queue_submit_count
        end
        if queue_last > max_queue_last then
            max_queue_last = queue_last
        end
        if overflow > max_overflow then
            max_overflow = overflow
        end
        tilemap_after = tilemap_activity
        processed_after = queue_processed
        if tilemap_activity ~= previous_tilemap_value then
            tilemap_change_frames = tilemap_change_frames + 1
            previous_tilemap_value = tilemap_activity
        end

        if sprite_count == 4 then
            local matched = true
            for index = 0, 3 do
                local y, link, tile, x = read_sprite_entry(index)
                local entry = expected[index + 1]
                if y ~= entry.y or (link % 256) ~= entry.link or tile ~= entry.tile or x ~= entry.x then
                    matched = false
                    break
                end
            end
            if matched then
                matched_frame = sample
                break
            end
        end
    end

    log(string.format("sprite count source: domain=%s addr=%06X", tostring(sprite_domain), sprite_addr))
    log(string.format("queue submit-count source: domain=%s addr=%06X", tostring(queue_submit_domain), queue_submit_addr))
    log(string.format("queue last-count source: domain=%s addr=%06X", tostring(queue_last_domain), queue_last_addr))
    log(string.format("queue overflow source: domain=%s addr=%06X", tostring(overflow_domain), overflow_addr))
    log(string.format("max sprite count observed=%d", max_sprite_count))
    log(string.format("max submitted queue count observed=%d", max_queue_submit))
    log(string.format("max processed queue count observed=%d", max_queue_last))
    log(string.format("tilemap activity advanced from %d to %d", tilemap_before, tilemap_after))
    log(string.format("processed queue total advanced from %d to %d", processed_before, processed_after))
    log(string.format("tilemap activity changed on %d sampled frames", tilemap_change_frames))
    log(string.format("max overflow observed=%d", max_overflow))
    if matched_frame == nil then
        error(string.format("did not observe expected metasprite over 60 frames (max sprite_count=%d)", max_sprite_count))
    end
    if max_queue_submit == 0 then
        error("transfer queue was never submitted with any entries")
    end
    if processed_after <= processed_before then
        error(string.format(
            "transfer queue never processed work: before=%d after=%d",
            processed_before,
            processed_after
        ))
    end
    if tilemap_after <= tilemap_before or tilemap_change_frames < 3 then
        error(string.format(
            "tilemap queue activity did not persist: before=%d after=%d changed_frames=%d",
            tilemap_before,
            tilemap_after,
            tilemap_change_frames
        ))
    end
    if max_overflow ~= 0 then
        error(string.format("transfer queue overflowed: max_overflow=%d", max_overflow))
    end

    console.clear()
    console.log("WHAT IF Phase 2 smoke test: PASS")
    console.log(string.format("Frame counter advanced from %d to %d", frame_before, frame_after))
    console.log(string.format("Observed expected metasprite after %d sample frames", matched_frame))
    console.log(string.format("Tilemap activity advanced from %d to %d", tilemap_before, tilemap_after))
    console.log(string.format("Processed queue total advanced from %d to %d", processed_before, processed_after))
    log("WHAT IF Phase 2 smoke test: PASS")
    log(string.format("Frame counter advanced from %d to %d", frame_before, frame_after))
    log(string.format("Observed expected metasprite after %d sample frames", matched_frame))
    log(string.format("Processed queue total advanced from %d to %d", processed_before, processed_after))
    log(string.format("Tilemap activity advanced from %d to %d", tilemap_before, tilemap_after))
end

local ok, err = pcall(main)
if not ok then
    local message = "WHAT IF Phase 2 smoke test: FAIL - " .. tostring(err)
    console.clear()
    console.log(message)
    log(message)
end

log_file:close()
client.exit()
