-- NES Moblin live capture. Walk to OW room with Moblins (death
-- mountain). Force-poke Random to deterministic state. Capture 240
-- frames of slot 1 cells.
--
-- NES OW room $00 (NW corner) has Red Moblins. We boot, start file,
-- walk up to room $00 from start ($77).

local function R(o) return memory.read_u8(o, "RAM") end
local function W(o,v) memory.write_u8(o, v, "RAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end
local function tap(b) joypad.set({[b]=true},1); emu.frameadvance(); joypad.set({},1); emu.frameadvance() end

-- Boot through title + file select.
idle(120); tap("Start"); idle(30); tap("Start"); idle(60)
tap("Down"); tap("Down"); tap("Down"); tap("Start"); idle(60)
for _=1,8 do tap("Down") end; tap("Start"); idle(60)
tap("Up"); tap("Up"); tap("Up"); tap("Up"); tap("Up"); tap("Up"); idle(30)
tap("Start"); idle(120)

-- Walk north far enough to enter death mountain rooms.
for _=1,600 do
    joypad.set({Up=true},1); emu.frameadvance()
    if R(0x00EB) == 0x00 or R(0x00EB) == 0x01 then break end
end
joypad.set({},1)
idle(60)

-- Force-poke Random to match Genesis test.
W(0x0018, 0x40)
for i = 1, 12 do W(0x0018 + i, 0x00) end

-- Find any monster slot.
local target = nil
for s = 1, 11 do
    local t = R(0x034F + s)
    if t ~= 0 then target = s; break end
end

local f = io.open("C:/tmp/audit_moblin_nes.txt", "w")
f:write(string.format("# NES Moblin live capture | room=$%02X target_slot=%s\n",
    R(0x00EB), tostring(target)))

if target then
    for fr = 0, 239 do
        local s = target
        f:write(string.format(
            "fr%3d T$%02X X$%02X Y$%02X Q$%02X SHT$%02X WTS$%02X HR$%02X facing$%02X\n",
            fr,
            R(0x034F + s),
            R(0x0070 + s),
            R(0x0084 + s),
            R(0x03BC + s),
            R(0x0451 + s),
            R(0x0412 + s),
            R(0x04F0 + s),
            R(0x0098 + s)))
        emu.frameadvance()
    end
else
    f:write("# no enemy spawned in target room\n")
end

f:close()
client.exit()
