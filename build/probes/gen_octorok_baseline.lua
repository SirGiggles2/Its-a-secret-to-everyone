-- gen_octorok_baseline.lua — Genesis Debug.md: navigate to OW $67 via
-- MODE_TELEPORT, dump octorok spawn + AI state at room enter. Output for
-- byte-diff vs NES baseline.
local OUT = (os.getenv("CODEX_BIZHAWK_ROOT") or "C:\\tmp") .. "/octorok_baseline_gen.txt"

local function press(b, n)
  for _=1,n do joypad.set(b, 1); emu.frameadvance() end
  joypad.set({}, 1); emu.frameadvance()
end
local function idle(n) for _=1,n do emu.frameadvance() end end
-- A4 = $FF8000 per src/debug/a4_probe_asm.s:8. nes_ram[NES_OFF] lands at
-- 68K $FF8000+NES_OFF. BizHawk "68K RAM" domain covers $FF0000-$FFFFFF
-- so NES offset $XXXX maps to domain offset $8000+$XXXX.
local function R(addr) return memory.read_u8(0x8000 + addr, "68K RAM") end

-- Boot
idle(240)
-- ABC chord = only title-to-gameplay path per a4_probe_main.c:155.
-- Side effect: stress harness force-spawn 11 enemies in initial room.
-- Workaround: walk Up to room $67 which triggers fresh natural spawn
-- dispatch, overwriting stress slots with naturally-spawned octoroks.
press({A=true, B=true, C=true}, 8); idle(180)
press({Up=true}, 240); idle(120)

-- Confirm room
local room = R(0x00EB)
print(string.format("GEN room id $%02X (expected $67)", room))

local f = io.open(OUT, "w")
f:write(string.format("GEN OCTOROK BASELINE — room $%02X\n", room))
f:write("Link pos: X=$" .. string.format("%02X", R(0x0070)) ..
        " Y=$" .. string.format("%02X", R(0x0028)) .. "\n\n")

local function dump_frame(label, fr)
  f:write(string.format("\n--- %s (frame %d post-room-enter) ---\n", label, fr))
  f:write("slot | type | X    | Y    | dir | state | qspd\n")
  for slot = 0, 11 do
    local t   = R(0x034F + slot)
    local x   = R(0x0070 + slot)
    local y   = R(0x0028 + slot)
    local d   = R(0x0008 + slot)
    local s   = R(0x0090 + slot)
    local q   = R(0x04A0 + slot)
    f:write(string.format("  %2d |  $%02X |  $%02X |  $%02X | $%02X |  $%02X  | $%02X\n",
      slot, t, x, y, d, s, q))
  end
end

dump_frame("frame_0", 0)
for i = 1, 6 do
  idle(10)
  dump_frame("frame_" .. (i*10), i*10)
end

f:write("\n\nRandom table $0010..$001F:\n")
for i = 0x10, 0x1F do
  f:write(string.format("  $%02X = $%02X\n", i, R(i)))
end

f:close()
client.screenshot((os.getenv("CODEX_BIZHAWK_ROOT") or "C:\\tmp") .. "/octorok_baseline_gen.png")
print("wrote " .. OUT)
client.exit()
