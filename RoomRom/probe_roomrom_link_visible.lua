-- probe_roomrom_link_visible.lua
-- Boot RoomRom.md, exercise B/C/A/Start, capture screenshots in each state
-- to verify Link sprite + PAL3 survive every toggle.
-- Output PNGs into RoomRom/out/ for inspection via Read.

local OUT = os.getenv("CODEX_BIZHAWK_ROOT") or ""
if OUT == "" or OUT == nil then OUT = "." end
local OUTDIR = OUT .. "/RoomRom/out"

local function wait(n)
    for _ = 1, n do
        emu.frameadvance()
    end
end

-- BizHawk Genesis core uses unprefixed button names ("B" not "P1 B").
local function press(btn)
    for _ = 1, 3 do
        joypad.set({[btn] = true}, 1)
        emu.frameadvance()
    end
    joypad.set({}, 1)
    wait(60)
end

-- Boot for ~3 seconds so init_video / upload_chr / spawn complete.
wait(180)
client.screenshot(OUTDIR .. "/probe_link_00_ow.png")

press("B");     client.screenshot(OUTDIR .. "/probe_link_01_uw.png")
press("C");     client.screenshot(OUTDIR .. "/probe_link_02_uw_redux.png")
press("A");     client.screenshot(OUTDIR .. "/probe_link_03_uw_lvl_cycle.png")
press("Start"); client.screenshot(OUTDIR .. "/probe_link_04_uw_quest_toggle.png")
press("B");     client.screenshot(OUTDIR .. "/probe_link_05_ow.png")
press("C");     client.screenshot(OUTDIR .. "/probe_link_06_ow_redux.png")

print("probe done; screenshots written to " .. OUTDIR)
client.exit()
