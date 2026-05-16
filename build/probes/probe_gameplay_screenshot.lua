-- probe_gameplay_screenshot.lua — boot + enter debug mode + take a
-- screenshot of gameplay. Auto-walk a bit to verify Link + enemies move.

local SHOT = "C:\\tmp\\gameplay.png"
local OUT  = "C:\\tmp\\gameplay.txt"

local function R(off) return memory.read_u8(0x8000 + off, "68K RAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end
local function press(b, n) for _=1,n do joypad.set(b, 1); emu.frameadvance() end end

idle(60)
memory.write_u8(0x73FC, 0x45, "68K RAM")
memory.write_u8(0x73FD, 0x50, "68K RAM")
idle(60)
press({A=true,B=true,C=true}, 30)
idle(60)
press({Right=true}, 30)
press({Down=true}, 30)
press({A=true}, 15)
press({Left=true}, 20)
idle(60)
client.screenshot(SHOT)

local f = io.open(OUT, "w")
f:write(string.format("gamemode=$%02X\n", R(0x0012)))
f:write(string.format("Link X=$%02X Y=$%02X face=$%02X state=$%02X\n",
    R(0x0070), R(0x0084), R(0x0098), R(0x00AC)))
f:write(string.format("RoomId=$%02X\n", R(0x00EB)))
f:write(string.format("Hearts=$%02X heart_partial=$%02X\n", R(0x066F), R(0x0670)))
f:write(string.format("Rupees=$%02X bombs=$%02X keys=$%02X\n",
    R(0x066D), R(0x0658), R(0x0666)))
f:write(string.format("SwordLevel=$%02X\n", R(0x0657)))
f:write(string.format("FrameCounter=$%02X\n", R(0x0015)))
f:write("\nEnemy slots (1..11):\n")
for slot=1,11 do
    f:write(string.format("  slot%02d alive=%02X type=%02X X=%02X Y=%02X hp=%02X st=%02X ms=%02X\n",
        slot, R(0x0492+slot), R(0x034F+slot), R(0x0070+slot), R(0x0084+slot),
        R(0x0485+slot), R(0x00AC+slot), R(0x0405+slot)))
end
f:close()
gui.text(8, 8, "gameplay shot done")
client.exit()
