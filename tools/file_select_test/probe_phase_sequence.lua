-- tools/file_select_test/probe_phase_sequence.lua
-- v2 Layer 1 RAM probe: verify phase machine + cursor nav.
-- Outputs CSV for tools/file_select_test/check_probe_sequence.py.
--
-- Sequence: hold no buttons until f=60 (FS_LOAD→FS_NAV), then press Down 4
-- times to walk cursor 0→4, then Up 4 times to walk back 4→0.

local REPO = os.getenv("CODEX_BIZHAWK_ROOT")
if not REPO or REPO == "" then
    REPO = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\.claude\\worktrees\\native-file-select"
end
local OUT_DIR = REPO .. "\\tools\\file_select_test\\out"
local OUT_CSV = OUT_DIR .. "\\phase_sequence.csv"
os.execute('mkdir "' .. OUT_DIR .. '" 2>nul')

-- Pick the M68K main RAM domain (BizHawk Genesis exposes "68K RAM" at 0..0xFFFF mapped to $FF0000+).
local domain = nil
for _, n in ipairs(memory.getmemorydomainlist()) do
    if n == "68K RAM" or n == "MD CART" or n == "Main RAM" then
        if n == "68K RAM" then domain = n end
    end
end
if not domain then domain = "68K RAM" end

local function rd(off) return memory.read_u8(off, domain) end

local fh = io.open(OUT_CSV, "w")
fh:write("frame,phase,cursor\n")

-- Edge-trigger: press for ONE frame each, then release for several frames so
-- fs_input_pressed() registers the rising edge exactly once per press.
-- v1.fix2 fs_input adds a 4-frame boot ignore window; first real edges land
-- only after frame ~4. Schedule presses well past that.
local PRESS = {}
local function add_press(start_frame, btn) PRESS[start_frame] = btn end

-- 4 Down presses spaced 30 frames apart starting at frame 60 → cursor 0→4.
for i = 0, 3 do add_press(60 + i * 30, "Down") end
-- Then 4 Up presses 30 frames apart → cursor 4→0.
for i = 0, 3 do add_press(60 + 4 * 30 + 30 + i * 30, "Up") end

local LAST_FRAME = 60 + 4 * 30 + 30 + 4 * 30 + 30   -- 330; sample tail

for f = 1, LAST_FRAME do
    local btn = PRESS[f]
    if btn then
        joypad.set({ [btn] = true }, 1)
    else
        joypad.set({}, 1)
    end
    emu.frameadvance()
    if f % 30 == 0 or PRESS[f] ~= nil or PRESS[f - 1] ~= nil then
        fh:write(string.format("%d,%02X,%02X\n", f, rd(0x07F0), rd(0x07F1)))
    end
end

fh:close()
print("probe_phase_sequence: wrote " .. OUT_CSV)
client.exit()
