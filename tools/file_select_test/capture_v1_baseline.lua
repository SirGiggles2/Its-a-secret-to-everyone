-- capture_v1_baseline.lua — boot fs_demo.md, advance 60 frames, capture PNG.
-- v1.9 visual smoke baseline: confirms static layout visible (border, headers,
-- row labels). After v1.10: also shows Link sprites + heart cursor.
--
-- Usage (copy to C:\tmp\ first):
--   EmuHawk.exe --lua=C:\tmp\capture_v1_baseline.lua C:\tmp\fs_demo.md
-- Output: C:\tmp\v1_frame_60.png  (copy to cmp/ after visual review)

local OUT_PNG = "C:\\tmp\\v1_frame_60.png"

print("capture_v1_baseline: out=" .. OUT_PNG)

-- Advance 60 frames to let display initialise and show static layout + sprites.
for f = 1, 60 do
    emu.frameadvance()
end

print("capture_v1_baseline: at frame=" .. emu.framecount() .. ", capturing...")
client.screenshot(OUT_PNG)
print("capture_v1_baseline: wrote " .. OUT_PNG)

client.exit()
