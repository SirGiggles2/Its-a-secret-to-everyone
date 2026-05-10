-- Bypass-sweep FPS profiler. Writes bitmask to $FF73FD to disable
-- subsystem chunks per profile window. Finds the lag culprit.

local OUTPUT_DIR = os.getenv("CODEX_PROBE_OUT") or "."
local STAGE1_FRAMES = 60
local CHORD_FRAMES = 30
local SETTLE_FRAMES = 60
local SAMPLE_FRAMES = 300

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

local function set_bypass(mask)
    memory.write_u8(0x73FD, mask, "68K RAM")
end

local function profile(label, mask)
    set_bypass(mask)
    -- settle 30 frames so mask takes effect
    for _ = 1, 30 do emu.frameadvance() end
    local start = read_frame_counter()
    for _ = 1, SAMPLE_FRAMES do emu.frameadvance() end
    local stop = read_frame_counter()
    local game = stop - start
    if game < 0 then game = game + 65536 end
    local fps = game * 60.0 / SAMPLE_FRAMES
    return string.format("%-30s mask=$%02X emu=%d game=%d fps=%.2f",
        label, mask, SAMPLE_FRAMES, game, fps)
end

press({}, STAGE1_FRAMES)
press({A=true, B=true, C=true}, CHORD_FRAMES)
press({}, SETTLE_FRAMES)

local results = {}
table.insert(results, profile("BASELINE (full pipeline)",        0x00))
table.insert(results, profile("skip combat/projectiles",         0x01))
table.insert(results, profile("skip damage/rupee tick",          0x02))
table.insert(results, profile("skip HUD refresh",                0x04))
table.insert(results, profile("skip enemy_loop_tick",            0x08))
table.insert(results, profile("skip publish_state_mirror",       0x10))
table.insert(results, profile("skip ALL subsystems",             0x1F))
set_bypass(0x00)

client.screenshot(OUTPUT_DIR .. "/fps_bypass_sweep.png")

local f = io.open(OUTPUT_DIR .. "/fps_bypass_sweep.txt", "w")
f:write("FPS Bypass Sweep\n")
f:write("================\n\n")
for _, line in ipairs(results) do
    f:write(line .. "\n")
end
f:close()

for _, line in ipairs(results) do print(line) end
client.exit()
