-- probe_roomrom_link_visible.lua
-- Boot RoomRom.md, capture OW + UW screenshots with Link visible.
-- Output PNGs into RoomRom/out/ for inspection via Read.

local OUT = os.getenv("CODEX_BIZHAWK_ROOT") or ""
if OUT == "" or OUT == nil then OUT = "." end
local OUTDIR = OUT .. "/RoomRom/out"

local function wait(n)
    for _ = 1, n do
        emu.frameadvance()
    end
end

-- Boot for ~2 seconds so init_video / upload_chr / spawn complete.
wait(120)

-- OW capture
client.screenshot(OUTDIR .. "/probe_link_ow.png")

-- Press B (scene toggle to UW). BizHawk Genesis core uses unprefixed names.
for _ = 1, 3 do
    joypad.set({B = true}, 1)
    emu.frameadvance()
end
joypad.set({}, 1)
wait(120)

-- UW capture
client.screenshot(OUTDIR .. "/probe_link_uw.png")

print("probe done; screenshots written to " .. OUTDIR)
client.exit()
