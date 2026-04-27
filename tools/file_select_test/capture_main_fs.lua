-- capture_main_fs.lua — boot main ROM whatif.md, press Start at frame 120
-- (mid title display), advance 180 more frames so fs_main has rendered the
-- native File Select, capture PNG.
local OUT = "C:\\tmp\\main_fs_after_start.png"

for f = 1, 119 do emu.frameadvance() end
joypad.set({ Start = true }, 1); emu.frameadvance()
joypad.set({}, 1)
for f = 1, 200 do emu.frameadvance() end

client.screenshot(OUT)
print("capture_main_fs: wrote " .. OUT)
client.exit()
