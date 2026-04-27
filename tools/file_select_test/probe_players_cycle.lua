-- tools/file_select_test/probe_players_cycle.lua
-- v3 RAM probe: walk cursor down to PLAYERS row, cycle L/R, verify probe byte.
-- Output CSV consumed by check_players_cycle.py.

local REPO = os.getenv("CODEX_BIZHAWK_ROOT")
if not REPO or REPO == "" then
    REPO = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\.claude\\worktrees\\native-file-select"
end
local OUT_DIR = REPO .. "\\tools\\file_select_test\\out"
local OUT_CSV = OUT_DIR .. "\\players_cycle.csv"
os.execute('mkdir "' .. OUT_DIR .. '" 2>nul')

local function rd(off) return memory.read_u8(off, "68K RAM") end

local fh = io.open(OUT_CSV, "w")
fh:write("frame,phase,cursor,players\n")

-- Edge presses: 1 frame on, ~14 frames off so fs_input_pressed picks up rising edge.
local PRESS = {}
local function add_press(start, btn) PRESS[start] = btn end

-- Walk cursor 0 -> 5 (PLAYERS) via 5 Down presses, 30 frames apart.
for i = 0, 4 do add_press(60 + i * 30, "Down") end
local AFTER_NAV = 60 + 5 * 30   -- frame 210 = cursor at PLAYERS

-- Right x3 (1->2->3->4), then Right (4->1 wrap), then Left (1->4 wrap).
add_press(AFTER_NAV + 30, "Right")  -- 240
add_press(AFTER_NAV + 60, "Right")  -- 270
add_press(AFTER_NAV + 90, "Right")  -- 300
add_press(AFTER_NAV + 120, "Right") -- 330 wraps to 1
add_press(AFTER_NAV + 150, "Left")  -- 360 wraps to 4

local LAST = AFTER_NAV + 180  -- frame 390

for f = 1, LAST do
    local btn = PRESS[f]
    if btn then joypad.set({ [btn] = true }, 1) else joypad.set({}, 1) end
    emu.frameadvance()
    if f % 30 == 0 or PRESS[f] ~= nil or PRESS[f - 1] ~= nil then
        fh:write(string.format("%d,%02X,%02X,%02X\n", f, rd(0x07F0), rd(0x07F1), rd(0x07F2)))
    end
end

fh:close()
print("probe_players_cycle: wrote " .. OUT_CSV)
client.exit()
