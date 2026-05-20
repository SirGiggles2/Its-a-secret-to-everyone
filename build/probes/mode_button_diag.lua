-- mode_button_diag.lua — diagnose why MODE button doesn't trigger debug
-- tilegrid entry from intro_main.
--
-- Procedure:
--   1. Idle 240 frames (let title settle, past frame<4 guard).
--   2. Sample $FF07F0..$FF07FF (intro sentinels + joy mirror).
--   3. Press various button combos via joypad.set, capture per-frame.
--   4. Report what intro_main's poll_mode actually sees.

local OUT = os.getenv("CODEX_BIZHAWK_ROOT") or "C:\\tmp"
local DIR = OUT .. "/mode_button_diag"
os.execute('mkdir "' .. DIR:gsub("/","\\") .. '" 2>nul')

local function idle(n) for _=1,n do emu.frameadvance() end end
local function R8(addr) return memory.read_u8(addr, "M68K BUS") end
local function R8sb(addr) return memory.read_u8(addr, "System Bus") end

local f = io.open(DIR .. "/diag.txt", "w")
local function log(s) f:write(s .. "\n"); print(s) end

log("=== mode_button_diag ===")
log("domains: " .. table.concat(memory.getmemorydomainlist(), ", "))

-- Boot wait
idle(240)
client.screenshot(DIR .. "/01_title.png")

-- Probe nes_ram sentinels at $FF07F0..$FF07FF
log("\n--- $FF07F0..$FF07FF after 240 boot frames ---")
local line = ""
for off = 0x07F0, 0x07FF do
  line = line .. string.format("%02X ", R8(0xFF0000 + off))
end
log(line)

-- Try pressing buttons one at a time, capture frame after
local function press_and_sample(btns, label)
  for fr = 1, 12 do
    joypad.set(btns, 1)
    emu.frameadvance()
  end
  joypad.set({}, 1)
  emu.frameadvance()
  emu.frameadvance()
  local lo = R8(0xFF07F3)
  local hi = R8(0xFF07F4)
  log(string.format("after %-12s: $07F3=%02X $07F4=%02X (joy=$%02X%02X)",
      label, lo, hi, hi, lo))
end

press_and_sample({A=true}, "A")
press_and_sample({B=true}, "B")
press_and_sample({Start=true}, "Start")
-- Try various button names BizHawk might use for MODE
press_and_sample({Mode=true}, "Mode")
press_and_sample({MODE=true}, "MODE")
press_and_sample({["P1 Mode"]=true}, "P1 Mode")
press_and_sample({X=true}, "X")
press_and_sample({Y=true}, "Y")
press_and_sample({Z=true}, "Z")
press_and_sample({}, "(release)")

-- Also: try the buttons available in this BizHawk by enumerating
log("\n--- joypad.get() reveals available buttons ---")
local cur = joypad.get(1)
for k, v in pairs(cur) do log(string.format("  %s = %s", tostring(k), tostring(v))) end

f:close()
print("done")
client.exit()
