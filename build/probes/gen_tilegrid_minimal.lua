-- gen_tilegrid_minimal.lua — minimum repro to test poke pipeline.
-- Boots Debug.md, presses MODE, pokes one state, screenshots.
-- Reads $FF07E4 sentinel before + after to confirm scene running.

local OUT = os.getenv("CODEX_BIZHAWK_ROOT") or "C:\\tmp"
local DIR = OUT .. "/chr_cycle_min"
os.execute('mkdir "' .. DIR:gsub("/","\\") .. '" 2>nul')

local function idle(n) for _=1,n do emu.frameadvance() end end
local function poke(addr, v) memory.write_u8(addr, v, "M68K BUS") end
local function read(addr) return memory.read_u8(addr, "M68K BUS") end

local log = io.open(DIR .. "/log.txt", "w")
local function L(s) log:write(s .. "\n"); print(s) end

idle(240)
L("frame=240 sentinel=$" .. string.format("%02X", read(0xFF07E4)))
client.screenshot(DIR .. "/01_title.png")

-- Try several MODE button names
for fr = 1, 30 do
  joypad.set({Mode=true, MODE=true, ["P1 Mode"]=true}, 1)
  emu.frameadvance()
end
joypad.set({}, 1)
idle(30)

L("post-MODE press sentinel=$" .. string.format("%02X", read(0xFF07E4)))
client.screenshot(DIR .. "/02_post_mode.png")

-- Poke state bank=3, sub_pal=2, page=1, 8x16=0
poke(0xFF07E0, 3)
poke(0xFF07E1, 2)
poke(0xFF07E2, 1)
poke(0xFF07E3, 0)
poke(0xFF07E4, 0xAA)
idle(30)
L("post-poke sentinel=$" .. string.format("%02X", read(0xFF07E4)) .. " (expect $00 if scene ack'd)")
client.screenshot(DIR .. "/03_post_poke.png")

-- Now press A button manually (cycle bank via button instead of poke)
for fr = 1, 6 do
  joypad.set({A=true}, 1); emu.frameadvance()
end
joypad.set({}, 1); idle(30)
L("post-A sentinel=$" .. string.format("%02X", read(0xFF07E4)))
client.screenshot(DIR .. "/04_post_A.png")

log:close()
print("minimal done")
client.exit()
