-- FPS profile: UW vs OW.
-- Default scene boots to SCENE_UW. MODE edge-press toggles to SCENE_OW.

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
    local hi = memory.read_u8(0x7202, "68K RAM")
    local lo = memory.read_u8(0x7203, "68K RAM")
    return hi * 256 + lo
end

local function read_scene()
    return memory.read_u8(0x7204, "68K RAM")  -- p[4] = s_scene
end

local function profile(label)
    local start = read_frame_counter()
    for _ = 1, SAMPLE_FRAMES do emu.frameadvance() end
    local stop = read_frame_counter()
    local game = stop - start
    if game < 0 then game = game + 65536 end
    local ratio = SAMPLE_FRAMES / math.max(game, 1)
    local fps = 60.0 / ratio
    return string.format("%s: emu=%d game=%d ratio=%.3f fps=%.2f scene=%d",
        label, SAMPLE_FRAMES, game, ratio, fps, read_scene())
end

-- Boot
press({}, STAGE1_FRAMES)
press({A=true, B=true, C=true}, CHORD_FRAMES)
press({}, SETTLE_FRAMES)

-- Profile UW (default)
local uw_line = profile("UW")

-- Toggle to OW via MODE edge press
press({Mode=true}, 4)
press({}, SETTLE_FRAMES)
local ow_line = profile("OW")

-- Toggle back UW
press({Mode=true}, 4)
press({}, SETTLE_FRAMES)
local uw2_line = profile("UW2")

client.screenshot(OUTPUT_DIR .. "/fps_uw_vs_ow.png")

local f = io.open(OUTPUT_DIR .. "/fps_uw_vs_ow.txt", "w")
f:write("FPS UW vs OW\n")
f:write("============\n\n")
f:write(uw_line .. "\n")
f:write(ow_line .. "\n")
f:write(uw2_line .. "\n")
f:close()

print(uw_line)
print(ow_line)
print(uw2_line)
client.exit()
