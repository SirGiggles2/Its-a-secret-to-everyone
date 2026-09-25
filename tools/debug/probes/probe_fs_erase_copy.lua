-- probe_fs_erase_copy.lua — T-099 COPY SAVE and ERASE SAVE.
--
-- Route (controller only, fresh cart): register "LINK" on slot 0 (same
-- inputs as probe_fs_register.lua), then:
--   COPY: cursor slot0 -> Down x3 (row 3 COPY) A -> pick src slot 0 A ->
--         Down (slot 1) A.  Cursor then rests on slot 1 (FS_LOAD redraw).
--   ERASE: Down x3 (row 4 ERASE) A -> pick Down (slot 1) A.
-- Checks: slot info (active $633+s, names $638+8s) and cart file A bytes
-- (logical: name $002+8s, items $01A+$28s, active $512+s, markers
-- $51E+s/$521+s, checksum $524+2s = 16-bit sum over the file).
-- RULE V3: domains enumerated live.

local OUT = "C:\\tmp\\fs_erase_copy_report.txt"
local SHOT = "C:\\tmp\\fs_erase_copy_"
local names = {}
for _, d in ipairs(memory.getmemorydomainlist()) do names[tostring(d)] = true end
local f = io.open(OUT, "w")
if not names["M68K BUS"] or not names["SRAM"] then
    f:write("UNVERIFIED: missing M68K BUS or SRAM domain\n"); f:close(); client.exit(); return
end
local function n(off) return memory.read_u8(0xFF8000 + off, "M68K BUS") end
local function cart(k) return memory.read_u8(2 * k + 1, "SRAM") end
local function hold(btn, frames) for _ = 1, frames do joypad.set(btn, 1); emu.frameadvance() end end
local function idle(frames) for _ = 1, frames do joypad.set({}, 1); emu.frameadvance() end end
local function tap(btn) hold(btn, 3); idle(6) end

local function file_ok(s)
    if cart(0x51E + s) ~= 0x5A or cart(0x521 + s) ~= 0xA5 then return false end
    local sum = 0
    for i = 0, 7 do sum = sum + cart(0x002 + 8 * s + i) end
    for i = 0, 0x27 do sum = sum + cart(0x01A + 0x28 * s + i) end
    for i = 0, 0x17F do sum = sum + cart(0x092 + 0x180 * s + i) end
    for _, b in ipairs({ 0x512, 0x515, 0x518, 0x51B }) do sum = sum + cart(b + s) end
    sum = sum & 0xFFFF
    return cart(0x524 + 2 * s) == (sum >> 8) and cart(0x525 + 2 * s) == (sum & 0xFF)
end
local LINK = { 0x15, 0x12, 0x17, 0x14, 0x24, 0x24, 0x24, 0x24 }
local function name_is(s, want, from_cart)
    for i = 0, 7 do
        local v = from_cart and cart(0x002 + 8 * s + i) or n(0x638 + 8 * s + i)
        if v ~= want[i + 1] then return false end
    end
    return true
end

idle(120); tap({ Start = true }); idle(90)
tap({ A = true }); idle(20)
tap({ Down = true }); tap({ A = true })
for _ = 1, 3 do tap({ Left = true }) end; tap({ A = true })
for _ = 1, 5 do tap({ Right = true }) end; tap({ A = true })
for _ = 1, 3 do tap({ Left = true }) end; tap({ A = true })
tap({ Start = true }); idle(30)

local checks = {}
local function check(label, ok) checks[#checks + 1] = { label, ok } end
check("registered slot 0 active + valid", n(0x633) == 1 and file_ok(0) and name_is(0, LINK, true))

for _ = 1, 3 do tap({ Down = true }) end; tap({ A = true })   -- COPY
tap({ A = true })                                               -- src slot 0
tap({ Down = true }); tap({ A = true }); idle(30)               -- dst slot 1
client.screenshot(SHOT .. "1_copied.png")
check("copy: slot 1 active", n(0x634) == 1)
check("copy: slot 1 name LINK (info + cart)", name_is(1, LINK, false) and name_is(1, LINK, true))
local items_same = true
for i = 0, 0x27 do if cart(0x01A + 0x28 + i) ~= cart(0x01A + i) then items_same = false end end
check("copy: slot 1 items == slot 0 items", items_same)
check("copy: slot 1 file A valid", file_ok(1))
check("copy: slot 0 still valid", file_ok(0) and n(0x633) == 1)

for _ = 1, 3 do tap({ Down = true }) end; tap({ A = true })   -- ERASE (cursor was slot 1)
tap({ Down = true }); tap({ A = true }); idle(30)               -- pick slot 1
client.screenshot(SHOT .. "2_erased.png")
check("erase: slot 1 inactive (info + cart)", n(0x634) == 0 and cart(0x513) == 0)
check("erase: slot 1 formatted file valid", file_ok(1))
check("erase: slot 1 name blank", name_is(1, { 0x24, 0x24, 0x24, 0x24, 0x24, 0x24, 0x24, 0x24 }, true))
check("erase: slot 0 untouched", file_ok(0) and n(0x633) == 1 and name_is(0, LINK, true))

local pass, fail = 0, 0
for _, c in ipairs(checks) do
    if c[2] then pass = pass + 1 else fail = fail + 1 end
    f:write(string.format("  %-44s %s\n", c[1], c[2] and "OK" or "FAIL"))
end
f:write(string.format("VERDICT: %s %d/%d\n", fail == 0 and "PASS" or "FAIL", pass, pass + fail))
f:close()
client.exit()
