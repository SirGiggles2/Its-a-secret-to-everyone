-- capture_handoff_register.lua — boot Title.md, advance through intro,
-- press Start at frame 120 (lands native FS), advance 60 more frames so
-- FS renders, press A on slot 0 (cursor 0 default), advance ~120 more
-- frames so transpiled register-name screen has rendered, capture PNG.
local OUT = "C:\\tmp\\handoff_register.png"

for f = 1, 5 do emu.frameadvance() end
joypad.set({ Start = true }, 1); emu.frameadvance()
joypad.set({}, 1)
for f = 1, 15 do emu.frameadvance() end

joypad.set({ A = true }, 1); emu.frameadvance()
joypad.set({}, 1)
for f = 1, 60 do emu.frameadvance() end

client.screenshot(OUT)

-- Sample handoff probe markers + write to file.
local p   = memory.read_u8(0x07F2, "68K RAM")
local vbm = memory.read_u8(0x0FFC, "68K RAM")
local gm  = memory.read_u8(0x0012, "68K RAM")
local sm  = memory.read_u8(0x0013, "68K RAM")
local cs  = memory.read_u8(0x0016, "68K RAM")
local ppum = memory.read_u8(0x0805, "68K RAM")  -- PPUMASK shadow
local ppuc = memory.read_u8(0x0804, "68K RAM")  -- PPUCTRL shadow
local fh = io.open("C:\\tmp\\handoff_probe.txt", "w")
fh:write(string.format("probe=%02X vblank=%02X gm=%02X sm=%02X css=%02X ppum=%02X ppuc=%02X\n",
    p, vbm, gm, sm, cs, ppum, ppuc))
-- Sample VRAM tile 0 (fs leftover or transpiled overwrite?)
local v0 = memory.read_u32_be(0x0000, "VRAM")
fh:write(string.format("vram_tile0_first4bytes=%08X\n", v0))
-- Sample CRAM pal 0
local c0 = memory.read_u16_be(0, "CRAM")
local c1 = memory.read_u16_be(2, "CRAM")
fh:write(string.format("cram_pal0_color0_color1=%04X %04X\n", c0, c1))
fh:close()
client.exit()
