-- probe_items_write_watch.lua — who writes the NES Items block?
--
-- Lockstep newgame (builds/reports/lockstep/newgame/diff.txt) showed
-- Items $0657..$067E becoming $30,$31,...,$57 at the frame the room
-- scrolls north from $77. This registers a write callback on the Genesis
-- mirror of Items[0] and Items[$27] ($FF8657 / $FF867E, platform_abi.h A4
-- base $FF8000) and logs the 68K PC + value of every write, then maps
-- nothing itself: PCs are resolved against Debug.out by the caller.
--
-- Route = lockstep capture route: Start, Start (File Select slot 0, empty
-- cart = New Game), sync on GameMode $05 + RoomId != 0, idle 120, Left 48,
-- idle 20, Up 60. RULE V3: domains enumerated live; callback API probed.

local OUT = "C:\\tmp\\items_write_watch.txt"
local f = io.open(OUT, "w")
local names = {}
for _, d in ipairs(memory.getmemorydomainlist()) do names[tostring(d)] = true end
local DOM, BASE
if names["68K RAM"] then DOM, BASE = "68K RAM", 0x8000
elseif names["M68K BUS"] then DOM, BASE = "M68K BUS", 0xFF8000
else f:write("UNVERIFIED: no 68K domain\n"); f:close(); client.exit(); return end
f:write("domain " .. DOM .. "\n")

local frame = 0
local hits = 0
local function cb(addr, val, flags)
    hits = hits + 1
    if hits <= 60 then
        local ok, pc = pcall(emu.getregister, "M68K PC")
        f:write(string.format("frame=%d addr=%X val=%s pc=%s\n", frame, addr or -1,
            tostring(val), ok and string.format("%06X", pc) or "?"))
    end
end
-- Watch the bus address; BizHawk callbacks take a system-bus address.
local ok1, e1 = pcall(event.on_bus_write, cb, 0xFF8657, "items0")
local ok2, e2 = pcall(event.on_bus_write, cb, 0xFF867E, "items27")
f:write(string.format("callback registered: %s %s (%s %s)\n", tostring(ok1), tostring(ok2),
    tostring(e1), tostring(e2)))
if not ok1 then f:close(); client.exit(); return end

local function rd(o) return memory.read_u8(BASE + o, DOM) end
local function step(btn, n) for _ = 1, n do joypad.set(btn, 1); emu.frameadvance(); frame = frame + 1 end end

step({}, 120); step({ Start = true }, 6); step({}, 120); step({ Start = true }, 6)
local sync = -1
for i = 1, 1500 do
    if rd(0x12) == 0x05 and rd(0xEB) ~= 0 then sync = frame; break end
    step({}, 1)
end
f:write("sync at frame " .. sync .. "\n")
step({}, 120); step({ Left = true }, 48); step({}, 20)
for i = 1, 60 do
    step({ Up = true }, 1)
end
f:write(string.format("end frame=%d room=%02X items0=%02X items27=%02X hits=%d\n",
    frame, rd(0xEB), rd(0x657), rd(0x67E), hits))
f:close()
client.exit()
