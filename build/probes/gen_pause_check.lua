-- Check current pause behavior: enter gameplay, press Start, screenshot.
local OUT = os.getenv("CODEX_BIZHAWK_ROOT") or "C:\\tmp"

local function press(b, n)
  for _=1,n do joypad.set(b, 1); emu.frameadvance() end
  joypad.set({}, 1); emu.frameadvance()
end
local function idle(n) for _=1,n do emu.frameadvance() end end
local function R(addr) return memory.read_u8(0x8000 + addr, "68K RAM") end

idle(240)
press({A=true, B=true, C=true}, 8); idle(120)
client.screenshot(OUT .. "/pause_before.png")

-- Press Start
press({Start=true}, 6); idle(60)
client.screenshot(OUT .. "/pause_after1.png")
idle(60)
client.screenshot(OUT .. "/pause_after2.png")

local pause_flag = R(0x00E0)
print(string.format("Pause flag $E0 = $%02X", pause_flag))

-- Unpause
press({Start=true}, 6); idle(60)
client.screenshot(OUT .. "/pause_resume.png")

local pause_flag_after = R(0x00E0)
print(string.format("Pause flag after 2nd Start = $%02X", pause_flag_after))

client.exit()
