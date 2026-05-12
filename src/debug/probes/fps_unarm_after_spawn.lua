-- Arm before chord (spawns 11 enemies), then UN-arm before
-- the sample window so publish_pre + publish_live + heavy
-- state mirror block all early-return. Enemies remain alive
-- so the per-slot enemy_update_fns dispatch keeps running.
--
-- Compares to fps_armed_no_enemies: if THIS one hits 60fps
-- and that one stayed at 27fps, the cost is in the publishes.

local OUTPUT_DIR = os.getenv("CODEX_PROBE_OUT") or "."
local STAGE1_FRAMES = 60
local CHORD_FRAMES = 30
local SETTLE_FRAMES = 60
local SAMPLE_FRAMES = 600

local function press(buttons, frames)
    for _ = 1, frames do
        joypad.set(buttons, 1)
        emu.frameadvance()
    end
end

local function read_frame_counter()
    return memory.read_u8(0x7202, "68K RAM") * 256
         + memory.read_u8(0x7203, "68K RAM")
end

press({}, STAGE1_FRAMES)

memory.write_u8(0x73F8, 0x52, "68K RAM") -- 'R'
memory.write_u8(0x73F9, 0x50, "68K RAM") -- 'P'
memory.write_u8(0x73FA, 0x03, "68K RAM") -- heavy mirror + enemy stress

press({A=true, B=true, C=true}, CHORD_FRAMES)
press({}, SETTLE_FRAMES)

-- Count alive before un-arm.
local alive_before = 0
for slot = 0, 11 do
    local a = memory.read_u8(0x8492 + slot, "68K RAM")
    if a ~= 0 then alive_before = alive_before + 1 end
end

-- UN-arm: clear shared probe control byte 0.
-- enemy_loop_probe_is_armed() now returns 0, so:
--   - enemy_loop_probe_publish_pre() skipped
--   - enemy_loop_probe_publish_live() skipped
--   - roomrom_debug_publish_state_mirror heavy block skipped
-- But enemies stay alive, so per-slot enemy_update_fns dispatch
-- keeps walking 11 slots.
memory.write_u8(0x73F8, 0x00, "68K RAM")

-- Settle a few frames so the new gating takes effect.
for _ = 1, 30 do emu.frameadvance() end

local start = read_frame_counter()
for _ = 1, SAMPLE_FRAMES do emu.frameadvance() end
local stop = read_frame_counter()
local game = stop - start
if game < 0 then game = game + 65536 end
local ratio = SAMPLE_FRAMES / math.max(game, 1)
local fps = 60.0 / ratio

local arm0 = memory.read_u8(0x73F8, "68K RAM")
local arm1 = memory.read_u8(0x73F9, "68K RAM")
local flags = memory.read_u8(0x73FA, "68K RAM")

local alive_after = 0
for slot = 0, 11 do
    local a = memory.read_u8(0x8492 + slot, "68K RAM")
    if a ~= 0 then alive_after = alive_after + 1 end
end

client.screenshot(OUTPUT_DIR .. "/fps_unarm_after_spawn.png")

local f = io.open(OUTPUT_DIR .. "/fps_unarm_after_spawn.txt", "w")
f:write("FPS Unarm After Spawn\n")
f:write("=====================\n\n")
f:write(string.format("Alive before unarm: %d\n", alive_before))
f:write(string.format("Alive after sample: %d\n", alive_after))
f:write(string.format("Sample window: %d emu frames\n", SAMPLE_FRAMES))
f:write(string.format("Game frames advanced: %d\n", game))
f:write(string.format("Avg emu/game ratio: %.3f\n", ratio))
f:write(string.format("Effective fps: %.2f (target 60.00)\n", fps))
f:write(string.format("Arm bytes during sample: %02X %02X flags=%02X (expect 00 50 / 03)\n", arm0, arm1, flags))
if ratio > 1.5 then
    f:write("\nVERDICT: LAG remains -> dispatch / something else.\n")
elseif ratio > 1.1 then
    f:write("\nVERDICT: minor lag.\n")
else
    f:write("\nVERDICT: 60fps -> publishes were the cost.\n")
end
f:close()

print(string.format("UNARM after spawn: alive=%d->%d game=%d fps=%.2f arm=%02X%02X",
    alive_before, alive_after, game, fps, arm0, arm1))
client.exit()
