-- vscroll_blackbar.lua
-- Force room-jump via TELEPORT mode (X button) to skip walking, then
-- walk into top edge of room 0x57 to trigger v-scroll UP into 0x47.
-- Capture EVERY emu frame during the scroll-active window — looking
-- for the "black bar" visual artifact.

local OUTDIR = "C:\\tmp\\blackbar\\"
os.execute("mkdir " .. OUTDIR .. " 2>NUL")

local function press(buttons, frames)
    for i = 1, frames do joypad.set(buttons, 1); emu.frameadvance() end
end
local function idle(frames)
    for i = 1, frames do emu.frameadvance() end
end

-- Boot.
idle(120)
press({A=true, B=true, C=true}, 30)
idle(360)
-- Now in OW room 0x77 default.

-- Walk UP for a LONG time so Link reaches the top edge and v-scroll triggers.
-- Use a polling loop: detect scroll active by watching BG_A V-scroll
-- register change. BG_A V-scroll lives at VSRAM offset 0..1.
local function read_vscroll()
    return memory.read_u8(0, "VSRAM") * 256 + memory.read_u8(1, "VSRAM")
end

local initial_vscroll = read_vscroll()
local f = io.open(OUTDIR .. "scroll_log.csv", "w")
f:write("emu,vscroll_y,vdelta,event\n")

local screenshot_n = 0
local function snap(label)
    screenshot_n = screenshot_n + 1
    local name = string.format(OUTDIR .. "frame_%03d_%s.png", screenshot_n, label)
    client.screenshot(name)
end

-- Pre-walk screenshot for baseline.
snap("pre")

-- Hold UP for up to 2400 frames or until full scroll observed.
local prev_vs = read_vscroll()
local scroll_active = false
local scroll_started_at = -1
local scroll_done = false
local in_scroll_frames = 0

for i = 1, 2400 do
    joypad.set({Up=true}, 1)
    emu.frameadvance()

    local vs = read_vscroll()
    local vd = vs - prev_vs
    local event = ""
    if vd ~= 0 then
        event = "vscroll_change"
        if not scroll_active then
            scroll_active = true
            scroll_started_at = i
        end
        in_scroll_frames = in_scroll_frames + 1
        snap(string.format("scroll_%02d", in_scroll_frames))
    elseif scroll_active and vd == 0 and i - scroll_started_at > 4 then
        -- Scroll just stopped (no change for 4 frames after activity)
        if in_scroll_frames > 0 then
            scroll_done = true
            event = "scroll_done"
            snap("post_scroll")
            break
        end
    end
    f:write(string.format("%d,%d,%d,%s\n", emu.framecount(), vs, vd, event))
    prev_vs = vs
end

-- Continue a bit more after scroll completes for stable post-state.
joypad.set({}, 1)
idle(120)
snap("post_settle")

f:close()

local fs = io.open(OUTDIR .. "summary.log", "w")
fs:write(string.format("scroll_active observed: %s\n", scroll_active and "YES" or "NO"))
fs:write(string.format("scroll_done observed: %s\n", scroll_done and "YES" or "NO"))
fs:write(string.format("frames during scroll: %d\n", in_scroll_frames))
fs:write(string.format("initial vscroll: 0x%X\n", initial_vscroll))
fs:write(string.format("final vscroll:   0x%X\n", read_vscroll()))
fs:write(string.format("screenshots saved: %d\n", screenshot_n))
fs:close()

gui.text(8, 8, "vscroll_blackbar done")
client.exit()
