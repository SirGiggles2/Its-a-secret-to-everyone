-- ENTRY ONLY: boot current ROM, debug chord, synthetic warp into L1.
-- This tests the actual scene-load path, NOT normal dungeon traversal/combat.
-- Current contracts: roomrom_debug_runtime.h and main.c state-mirror publisher.
assert(HARNESS and HARNESS.scope == 'entry', 'runner entry context required')
local domains = {}
for _, name in pairs(memory.getmemorydomainlist()) do domains[name] = true end
if not (domains['68K RAM'] and domains['VRAM'] and domains['CRAM']) then
    HARNESS.finish('ERROR', {error = 'Genesis domains missing', domains = domains})
    return
end
local function r8(off) return memory.read_u8(off, '68K RAM') end
local function w8(off, value) memory.write_u8(off, value, '68K RAM') end
local function r16(off) return r8(off) * 256 + r8(off + 1) end
local mirror, control = 0x7200, 0x73F8
local function arm()
    w8(control, 0x52); w8(control + 1, 0x50)
    w8(control + 2, 1) -- heavy mirror: level/quest; no freeze or boss trigger
end
local function sample()
    return {frame = r16(mirror + 2), scene = r8(mirror + 4), room = r8(mirror + 5),
            x = r16(mirror + 6), y = r16(mirror + 8),
            level = r8(mirror + 16), quest = r8(mirror + 17)}
end
local function tick(n)
    for _ = 1, n do joypad.set({}, 1); emu.frameadvance() end
end
client.speedmode(400)
tick(30)
local title_path = HARNESS.screenshot_path:gsub('entry%.png$', 'title.png')
client.screenshot(title_path)
local entered = false
for frame = 1, 1500 do
    arm()
    joypad.set(frame % 30 < 4 and {A = true, B = true, C = true} or {}, 1)
    emu.frameadvance()
    if r8(mirror) == 0x57 and r8(mirror + 1) == 0x50 and r16(mirror + 2) > 5 then
        entered = true; break
    end
end
joypad.set({}, 1)
assert(entered, 'no live WP gameplay mirror after debug chord')
arm()
w8(control + 3, 1) -- SCENE_UW
w8(control + 4, HARNESS.level)
w8(control + 5, HARNESS.quest)
w8(control + 6, HARNESS.expected_room)
w8(control + 7, 0x5A)
local settled = false
for _ = 1, 240 do
    tick(1)
    local s = sample()
    if r8(control + 7) == 0 and s.scene == 1 and s.room == HARNESS.expected_room
        and s.level == HARNESS.level and s.quest == HARNESS.quest then
        settled = true; break
    end
end
assert(settled, 'warp did not acknowledge and publish requested room/level/quest')
local before = sample()
tick(60)
local after = sample()
after.frame_delta = (after.frame - before.frame) % 65536
assert(after.frame_delta > 0, 'gameplay frame counter stopped')
assert(after.scene == 1 and after.room == HARNESS.expected_room, 'entry drifted to another scene')
client.screenshot(HARNESS.screenshot_path)
savestate.save(HARNESS.state_path)
HARNESS.finish('ENTRY_ONLY', {entry = after,
    setup = 'debug chord + probe warp; no boss or normal traversal tested',
    domains = domains})
