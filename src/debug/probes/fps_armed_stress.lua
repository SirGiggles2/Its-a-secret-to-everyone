-- FPS profile under armed probe stress.
-- Writes 'RP' + heavy-mirror/enemy-stress flags BEFORE A+B+C so
-- enemy_loop_probe_run() force-spawns 11 slots and the heavy
-- state mirror block runs every frame. Worst-case perf path.

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

-- Arm the heavy enemy-loop stress probe BEFORE chord so
-- roomrom_debug_enter sees ARMED on entry.
memory.write_u8(0x73F8, 0x52, "68K RAM") -- 'R'
memory.write_u8(0x73F9, 0x50, "68K RAM") -- 'P'
memory.write_u8(0x73FA, 0x03, "68K RAM") -- heavy mirror + enemy stress

press({A=true, B=true, C=true}, CHORD_FRAMES)
press({}, SETTLE_FRAMES)

local start = read_frame_counter()
for _ = 1, SAMPLE_FRAMES do emu.frameadvance() end
local stop = read_frame_counter()
local game = stop - start
if game < 0 then game = game + 65536 end
local ratio = SAMPLE_FRAMES / math.max(game, 1)
local fps = 60.0 / ratio

client.screenshot(OUTPUT_DIR .. "/fps_armed_stress.png")

local arm0 = memory.read_u8(0x73F8, "68K RAM")
local arm1 = memory.read_u8(0x73F9, "68K RAM")
local flags = memory.read_u8(0x73FA, "68K RAM")

local f = io.open(OUTPUT_DIR .. "/fps_armed_stress.txt", "w")
f:write("FPS Armed Stress\n")
f:write("================\n\n")
f:write(string.format("Sample window: %d emu frames\n", SAMPLE_FRAMES))
f:write(string.format("Game frames advanced: %d\n", game))
f:write(string.format("Avg emu/game ratio: %.3f\n", ratio))
f:write(string.format("Effective fps: %.2f (target 60.00)\n", fps))
f:write(string.format("Probe arm bytes: %02X %02X flags=%02X (expect 52 50 / 03)\n", arm0, arm1, flags))
if ratio > 1.5 then
    f:write("\nVERDICT: LAG under armed stress.\n")
elseif ratio > 1.1 then
    f:write("\nVERDICT: minor lag under armed stress.\n")
else
    f:write("\nVERDICT: 60fps under armed stress.\n")
end
f:close()

print(string.format("ARMED stress: emu=%d game=%d ratio=%.3f fps=%.2f arm=%02X%02X",
    SAMPLE_FRAMES, game, ratio, fps, arm0, arm1))
client.exit()
