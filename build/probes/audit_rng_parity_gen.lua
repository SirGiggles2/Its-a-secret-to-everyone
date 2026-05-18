-- A1 RNG parity gate — Genesis (Debug.md) side.
-- Captures Random[0..12] every frame for 600 frames after entering
-- ROOMROM mode (where rng_next ticks per frame).
--
-- Debug.md boot flow: debug_main_after_a4 -> debug_enter_title ->
-- debug_poll_title loop (RNG idle) until A+B+C chord -> roomrom_debug_enter
-- (rng_seed plants {$40, 0..0}) -> roomrom_debug_tick (rng_next per frame).

local function R(o) return memory.read_u8(o, "68K RAM") end

-- Boot to title.
for _ = 1, 240 do emu.frameadvance() end

-- Press A+B+C to enter ROOMROM mode (chord triggers state transition).
joypad.set({A=true, B=true, C=true}, 1)
for _ = 1, 6 do emu.frameadvance() end
joypad.set({}, 1)

-- Let roomrom_debug_enter complete (rng_seed runs here).
for _ = 1, 30 do emu.frameadvance() end

-- Capture 600 frames of Random[0..12].
local f = io.open("C:/tmp/rng_parity_gen.txt", "w")
f:write("# Genesis rng parity capture | frame Random[0..12]\n")
for fr = 0, 599 do
    f:write(string.format(
        "%4d %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X\n",
        fr,
        R(0x8018), R(0x8019), R(0x801A), R(0x801B), R(0x801C),
        R(0x801D), R(0x801E), R(0x801F), R(0x8020), R(0x8021),
        R(0x8022), R(0x8023), R(0x8024)))
    emu.frameadvance()
end
f:close()
client.exit()
