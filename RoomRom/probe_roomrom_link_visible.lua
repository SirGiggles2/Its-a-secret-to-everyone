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

-- Press B (scene toggle to UW). Genesis controller mapping.
joypad.set({["P1 B"] = true}, 1)
wait(2)
joypad.set({["P1 B"] = false}, 1)
wait(60)

-- UW capture
client.screenshot(OUTDIR .. "/probe_link_uw.png")

print("probe done; screenshots written to " .. OUTDIR)
client.exit()
