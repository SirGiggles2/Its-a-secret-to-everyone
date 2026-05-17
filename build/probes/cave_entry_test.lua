-- cave_entry_test.lua — walk Link into the cave at top of room $77.
-- Verify SCENE_CAVE transition fires + cave room renders + cave_palette
-- applies. Boot room $77 has cave entry tile near top-center.

local function R(o) return memory.read_u8(o, "68K RAM") end
local function W(o,v) memory.write_u8(o, v, "68K RAM") end
local function R16BE(o) return R(o)*256 + R(o+1) end
local function idle(n) for _=1,n do emu.frameadvance() end end

local OUT = "C:\\tmp\\cave_entry.txt"
local f = io.open(OUT, "w")

idle(60)
for i=1,30 do joypad.set({A=true,B=true,C=true}, 1); emu.frameadvance() end
W(0x73F8, 0x52); W(0x73F9, 0x50); W(0x73FA, 0x00)
idle(60)

local function state(label)
  f:write(string.format("%s scene=%d room=$%02X x=$%02X y=$%02X fc=%d\n",
    label, R(0x7204), R(0x7205), R(0x7207), R(0x7209), R16BE(0x7202)))
end

state("[01 boot]")
client.screenshot("C:\\tmp\\cave_01_boot.png")

-- Walk Up — Link starts at Y=$8D, cave tile likely around Y=$30-$40
for _=1,250 do joypad.set({Up=true}, 1); emu.frameadvance() end
idle(60)
state("[02 walked up 250]")
client.screenshot("C:\\tmp\\cave_02_walked_up.png")

-- More Up to ensure cave-entry tile hit
for _=1,150 do joypad.set({Up=true}, 1); emu.frameadvance() end
idle(60)
state("[03 walked up more]")
client.screenshot("C:\\tmp\\cave_03_more_up.png")

-- Capture cave-entry sentinels per main.c:1812 ($07FC = entry counter,
-- $07FD = last standing tile)
local entry_counter = R(0x87FC)
local standing_tile = R(0x87FD)
f:write(string.format("entry_counter=%d standing_tile=$%02X\n",
  entry_counter, standing_tile))

-- Walk Down to leave cave (if entered)
for _=1,200 do joypad.set({Down=true}, 1); emu.frameadvance() end
idle(60)
state("[04 walked down to leave cave]")
client.screenshot("C:\\tmp\\cave_04_post_down.png")

f:write("\nDONE\n")
f:close()
idle(15)
client.exit()
