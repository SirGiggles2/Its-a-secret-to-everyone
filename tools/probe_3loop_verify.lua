-- Verify intro loops 3 times without errors
-- Captures screenshots at key positions for each loop
-- Tracks game state transitions to confirm clean looping

local OUT_DIR = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/builds/reports/loop_verify"
os.execute('mkdir "' .. OUT_DIR:gsub("/", "\\") .. '" 2>nul')

local LOG = OUT_DIR .. "/loop_verify.txt"
local f = io.open(LOG, "w")
f:write("# 3-Loop Intro Verification\n\n")

local system = emu.getsystemid() or "?"
local is_genesis = (system == "GEN" or system == "SAT")

local domains = {}
for _, name in ipairs(memory.getmemorydomainlist()) do
    domains[name] = true
end

local ram_domain = nil
if is_genesis then
    for _, name in ipairs({"68K RAM", "M68K RAM", "M68K BUS"}) do
        if domains[name] then ram_domain = name; break end
    end
end

local function rd(addr)
    if is_genesis then
        local off = addr
        if ram_domain == "M68K BUS" then off = 0xFF0000 + addr end
        local ok, v = pcall(function() return memory.read_u8(off, ram_domain) end)
        return ok and v or 0xFF
    end
    local ok, v = pcall(function() return memory.read_u8(addr, "RAM") end)
    return ok and v or 0xFF
end

-- State tracking
local loop_count = 0
local prev_phase = 0xFF
local prev_subphase = 0xFF
local item_scroll_started = false
local item_scroll_ended = false
local items_seen = {}  -- textIndex values seen this loop
local last_text_index = -1
local scroll_start_frame = 0
local MIN_SCROLL_FRAMES = 500  -- must last 500+ frames to count as real scroll

-- Key frames to screenshot per loop
local screenshot_items = {
    [0x05] = "heart_clock",
    [0x09] = "rupy_5rupies",
    [0x0F] = "sword_whitesword",
    [0x16] = "arrow_silverarrow",
    [0x1A] = "raft_stepladder",
    [0x1D] = "triforce",
}

local screenshot_taken = {}

-- Run for 15000 frames (enough for 3+ full loops)
local MAX_FRAME = 20000

while emu.framecount() < MAX_FRAME do
    emu.frameadvance()
    local fc = emu.framecount()

    local phase = rd(0x042C)
    local subphase = rd(0x042D)
    local textIndex = rd(0x042E)
    local itemRow = rd(0x042F)
    local gameMode = rd(0x0012)

    -- Detect item scroll start (phase=1, subphase=2)
    if phase == 0x01 and subphase == 0x02 and not item_scroll_started then
        item_scroll_started = true
        item_scroll_ended = false
        items_seen = {}
        scroll_start_frame = fc
        f:write(string.format("Loop %d: Item scroll STARTED at frame %d\n", loop_count + 1, fc))

        -- Screenshot at start
        client.screenshot(string.format("%s/loop%d_start_f%05d.png", OUT_DIR, loop_count + 1, fc))
    end

    -- Track items during scroll
    if item_scroll_started and not item_scroll_ended and phase == 0x01 and subphase == 0x02 then
        if textIndex ~= last_text_index then
            items_seen[textIndex] = true
            last_text_index = textIndex
        end

        -- Take screenshots at key text indices
        local key = screenshot_items[textIndex]
        local shot_key = string.format("loop%d_%02X", loop_count + 1, textIndex)
        if key and not screenshot_taken[shot_key] then
            screenshot_taken[shot_key] = true
            client.screenshot(string.format("%s/loop%d_%s_f%05d.png", OUT_DIR, loop_count + 1, key, fc))
            f:write(string.format("  Screenshot: %s at frame %d (textIdx=%02X itemRow=%02X)\n",
                key, fc, textIndex, itemRow))
        end
    end

    -- Detect item scroll end (phase changes away from 1/2)
    if item_scroll_started and not item_scroll_ended then
        if phase ~= 0x01 or subphase ~= 0x02 then
            local scroll_duration = fc - scroll_start_frame
            if scroll_duration < MIN_SCROLL_FRAMES then
                -- Too short, false detection — reset
                item_scroll_started = false
                f:write(string.format("  (false start, only %d frames — ignoring)\n", scroll_duration))
            else
                item_scroll_ended = true
                item_scroll_started = false
                loop_count = loop_count + 1

                local item_count = 0
                for _ in pairs(items_seen) do item_count = item_count + 1 end

                f:write(string.format("Loop %d: Item scroll ENDED at frame %d (%d unique textIndex values, %d frames)\n",
                    loop_count, fc, item_count, scroll_duration))

                -- Screenshot at end
                client.screenshot(string.format("%s/loop%d_end_f%05d.png", OUT_DIR, loop_count, fc))

                -- Check completeness
                if item_count < 25 then
                    f:write(string.format("  WARNING: Only %d text indices seen, expected 25+\n", item_count))
                else
                    f:write(string.format("  OK: %d text indices seen\n", item_count))
                end

                if loop_count >= 3 then
                    f:write(string.format("\n3 loops completed successfully at frame %d\n", fc))
                    break
                end
            end
        end
    end

    -- Reset for next loop detection
    if item_scroll_ended and (phase == 0x01 and subphase == 0x02) then
        -- New item scroll starting
        item_scroll_started = true
        item_scroll_ended = false
        items_seen = {}
        last_text_index = -1
        f:write(string.format("\nLoop %d: Item scroll STARTED at frame %d\n", loop_count + 1, fc))
        client.screenshot(string.format("%s/loop%d_start_f%05d.png", OUT_DIR, loop_count + 1, fc))
    end
end

if loop_count < 3 then
    f:write(string.format("\nWARNING: Only completed %d loops in %d frames\n", loop_count, MAX_FRAME))
end

f:close()
print("Loop verification complete: " .. LOG)
client.exit()
