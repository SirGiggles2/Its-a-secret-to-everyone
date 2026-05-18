-- A3 Out-of-Scope baseline — NES side.
-- NES has no equivalent to Genesis FX force-spawn arm. Instead, walk to
-- known rooms containing each out-of-scope type and capture state.
--
-- Octoroks: OW room $77 (start area) usually has red slow octoroks.
-- Tektites: death mountain rooms $00, $01, $0F (north OW).
--
-- This probe is a placeholder framework — actual room sequences for
-- $07, $08, $09, $0A, $0D, $0E need to be filled in based on aldonunez
-- room manifests. For initial A3 baseline, only $07 (Red Slow Octorok)
-- in room $77 is captured; remaining types deferred to first shared-
-- infra commit that touches that family.

local function R(o) return memory.read_u8(o, "RAM") end

local function idle(n) for _=1,n do emu.frameadvance() end end
local function tap(b) joypad.set({[b]=true},1); emu.frameadvance(); joypad.set({},1); emu.frameadvance() end

-- Boot through title + file select.
idle(120); tap("Start"); idle(30); tap("Start"); idle(60)
tap("Down"); tap("Down"); tap("Down"); tap("Start"); idle(60)
for _=1,8 do tap("Down") end; tap("Start"); idle(60)
tap("Up"); tap("Up"); tap("Up"); tap("Up"); tap("Up"); tap("Up"); idle(30)
tap("Start"); idle(120)

-- Now in OW room $77 (start). Walk up one screen to ensure room loaded.
for _=1,80 do joypad.set({Up=true},1); emu.frameadvance() end
joypad.set({},1)
idle(20)

-- Force-poke Random to match Genesis side.
memory.write_u8(0x0018, 0x40, "RAM")
for i = 1, 12 do memory.write_u8(0x0018 + i, 0x00, "RAM") end
emu.frameadvance()

local f = io.open("C:/tmp/baseline_outofscope_nes.txt", "w")
f:write("# NES out-of-scope baseline | type slot fr cells...\n")

-- Find first non-empty enemy slot.
local target_slot = nil
for s = 1, 11 do
    if R(0x034F + s) ~= 0 then
        target_slot = s
        break
    end
end

if target_slot then
    local t = R(0x034F + target_slot)
    for fr = 0, 239 do
        f:write(string.format(
            "T$%02X s%d f%3d %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X\n",
            t, target_slot, fr,
            R(0x034F + target_slot), R(0x0070 + target_slot), R(0x0084 + target_slot),
            R(0x008C + target_slot), R(0x03BC + target_slot), R(0x04BF + target_slot),
            R(0x04B8 + target_slot), R(0x00AC + target_slot), R(0x04D8 + target_slot),
            R(0x0028 + target_slot), R(0x003D + target_slot), R(0x04F0 + target_slot),
            R(0x0490 + target_slot), R(0x0498 + target_slot)))
        emu.frameadvance()
    end
else
    f:write("# no enemy in room\n")
end

f:close()
client.exit()
