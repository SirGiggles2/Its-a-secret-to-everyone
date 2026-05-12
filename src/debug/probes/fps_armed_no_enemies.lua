-- ARMED state, but enemies cleared after spawn so per-frame
-- enemy_update_fns dispatch loop fast-paths. Isolates per-frame
-- publish_pre + publish_live + heavy state-mirror cost from the
-- 11-slot enemy update cost.
--
-- NES RAM base = $FF8000 in Debug.md (platform_abi.h:13).
-- ENEMY_TYPE(slot)       = $FF8000 + 0x034F + slot = $FF834F + slot
-- ENEMY_ALIVE_FLAG(slot) = $FF8000 + 0x0492 + slot = $FF8492 + slot
-- 68K RAM domain offsets: 0x834F + slot, 0x8492 + slot.

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

-- Capture pre-clear alive count snapshot.
local alive_before = 0
for slot = 0, 11 do
    local a = memory.read_u8(0x8492 + slot, "68K RAM")
    if a ~= 0 then alive_before = alive_before + 1 end
end

-- Clear all 12 enemy slots (TYPE + ALIVE).
for slot = 0, 11 do
    memory.write_u8(0x834F + slot, 0, "68K RAM")
    memory.write_u8(0x8492 + slot, 0, "68K RAM")
end

-- Verify.
local alive_after = 0
for slot = 0, 11 do
    local a = memory.read_u8(0x8492 + slot, "68K RAM")
    if a ~= 0 then alive_after = alive_after + 1 end
end

-- Settle a few frames so any in-flight metastate winds down.
for _ = 1, 30 do emu.frameadvance() end

local start = read_frame_counter()
for _ = 1, SAMPLE_FRAMES do emu.frameadvance() end
local stop = read_frame_counter()
local game = stop - start
if game < 0 then game = game + 65536 end
local ratio = SAMPLE_FRAMES / math.max(game, 1)
local fps = 60.0 / ratio

client.screenshot(OUTPUT_DIR .. "/fps_armed_no_enemies.png")

local arm0 = memory.read_u8(0x73F8, "68K RAM")
local arm1 = memory.read_u8(0x73F9, "68K RAM")
local flags = memory.read_u8(0x73FA, "68K RAM")

local f = io.open(OUTPUT_DIR .. "/fps_armed_no_enemies.txt", "w")
f:write("FPS Armed (no enemies)\n")
f:write("======================\n\n")
f:write(string.format("Alive before clear: %d\n", alive_before))
f:write(string.format("Alive after clear:  %d\n", alive_after))
f:write(string.format("Sample window: %d emu frames\n", SAMPLE_FRAMES))
f:write(string.format("Game frames advanced: %d\n", game))
f:write(string.format("Avg emu/game ratio: %.3f\n", ratio))
f:write(string.format("Effective fps: %.2f (target 60.00)\n", fps))
f:write(string.format("Arm bytes: %02X %02X flags=%02X\n", arm0, arm1, flags))
if ratio > 1.5 then
    f:write("\nVERDICT: LAG remains -> publishes + heavy mirror are cost.\n")
elseif ratio > 1.1 then
    f:write("\nVERDICT: minor lag remains.\n")
else
    f:write("\nVERDICT: 60fps -> enemy dispatch was the cost.\n")
end
f:close()

print(string.format("ARMED no-enemies: alive=%d->%d game=%d fps=%.2f",
    alive_before, alive_after, game, fps))
client.exit()
