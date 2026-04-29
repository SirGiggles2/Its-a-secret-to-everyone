-- Probe: confirm only pal1 slots 8-11 cycle while heart on screen,
-- pal1 slots 4-7 stay static, story BG slots 0-3 stay static.
local ROOT = os.getenv("CODEX_BIZHAWK_ROOT") or "."
local LOG  = ROOT .. "/probe_heart_flash.log"
local SHOT = ROOT .. "/probe_heart_flash"

local f = io.open(LOG, "w")
local function log(s) f:write(s .. "\n"); f:flush() end

log("system: " .. tostring(emu.getsystemid()))

-- Genesis CRAM: 64 words, each 16 bits BE.
local function pal_word(pal, slot)
    local off = (pal * 16 + slot) * 2
    return memory.read_u16_be(off, "CRAM")
end

local function snapshot()
    local r = {}
    for slot = 0, 15 do r[slot] = pal_word(1, slot) end
    return r
end

-- Frame milestones inside heart-visible window.
-- story_pause = 250 frames, then scroll @ 0.5 px/frame.
-- Heart top px = 352, visible when pixel_count in (128, 368).
-- 128 px = 256 scroll-tick frames = 512 vblank frames, +250 pause = ~762.
-- Window ends at 368 px = 736 frames after scroll start = ~986.
-- Sample at 800, 850, 900, 950 to capture multiple cycle states.
local STAMPS = {800, 850, 900, 950, 1000}
local snaps = {}

emu.frameadvance()
local target_idx = 1
while target_idx <= #STAMPS do
    local fr = emu.framecount()
    if fr >= STAMPS[target_idx] then
        local s = snapshot()
        snaps[target_idx] = s
        log(string.format("frame %d: pal1 = %04X %04X %04X %04X | %04X %04X %04X %04X | %04X %04X %04X %04X | %04X %04X %04X %04X",
            fr, s[0], s[1], s[2], s[3], s[4], s[5], s[6], s[7],
            s[8], s[9], s[10], s[11], s[12], s[13], s[14], s[15]))
        client.screenshot(string.format("%s_f%d.png", SHOT, fr))
        target_idx = target_idx + 1
    end
    emu.frameadvance()
end

-- Diff analysis: slots 4-7 should be identical across all snaps; 8-11 should change.
local function eq_range(a, b, lo, hi)
    for s = lo, hi do if a[s] ~= b[s] then return false end end
    return true
end

local static_47 = true
local change_811 = false
for i = 2, #snaps do
    if not eq_range(snaps[1], snaps[i], 4, 7) then static_47 = false end
    if not eq_range(snaps[1], snaps[i], 8, 11) then change_811 = true end
end

log("")
log("RESULT:")
log("  pal1[4..7] static across snaps: " .. tostring(static_47) .. " (expected: true)")
log("  pal1[8..11] changed across snaps: " .. tostring(change_811) .. " (expected: true)")
log("PASS = " .. tostring(static_47 and change_811))

f:close()
client.exit()
