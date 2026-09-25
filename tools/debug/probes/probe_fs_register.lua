-- probe_fs_register.lua — T-099: register a name on an empty slot through
-- the File Select, then continue it into gameplay.
--
-- Route (controller only, fresh cart SRAM from run_probe.py):
--   title Start -> File Select; A on slot 0 (empty) -> name board;
--   type L I N K: board index 0 -> Down(11)=L A, Left x3 (8)=I A,
--   Right x5 (13)=N A, Left x3 (10)=K A; Start = finish registration.
--   Then A on slot 0 (now occupied) -> gameplay.
-- Checks (addresses: NES slot info / save block per save_serializer.h,
-- nes_ram = $FF8000 + off per platform_abi.h, cart logical k = SRAM 2k+1):
--   slot info name $638..$63F = L I N K + 4 spaces, active $633 = 1
--   hearts info $650/$651 = $22/$FF; cart file A: name at $002, items
--   HeartValues $01A+$18 = $22, HeartPartial = $FF, MaxBombs $01A+$25 = 8,
--   active $512 = 1, quest $51B = 0, markers + checksum valid
--   gameplay: GameMode $05, profile HeartValues $66F = $22, MaxBombs $67C = 8,
--   sword Items[0] $657 = 0 (a registered file owns no sword)
-- RULE V3: domains enumerated live. Screenshots are triage only.

local OUT = "C:\\tmp\\fs_register_report.txt"
local SHOT = "C:\\tmp\\fs_register_"
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

idle(120); tap({ Start = true }); idle(90)          -- title -> File Select
client.screenshot(SHOT .. "1_fs_empty.png")
tap({ A = true }); idle(20)                          -- empty slot 0 -> board
client.screenshot(SHOT .. "2_board.png")
tap({ Down = true }); tap({ A = true })              -- L
for _ = 1, 3 do tap({ Left = true }) end; tap({ A = true })   -- I
for _ = 1, 5 do tap({ Right = true }) end; tap({ A = true })  -- N
for _ = 1, 3 do tap({ Left = true }) end; tap({ A = true })   -- K
client.screenshot(SHOT .. "3_typed.png")
tap({ Start = true }); idle(30)                      -- finish registration
client.screenshot(SHOT .. "4_fs_registered.png")

local want_name = { 0x15, 0x12, 0x17, 0x14, 0x24, 0x24, 0x24, 0x24 }
local name_ok, cart_name_ok = true, true
for i = 0, 7 do
    if n(0x638 + i) ~= want_name[i + 1] then name_ok = false end
    if cart(0x002 + i) ~= want_name[i + 1] then cart_name_ok = false end
end
local sum = 0
for i = 0x002, 0x009 do sum = sum + cart(i) end
for i = 0x01A, 0x041 do sum = sum + cart(i) end
for i = 0x092, 0x211 do sum = sum + cart(i) end
for _, i in ipairs({ 0x512, 0x515, 0x518, 0x51B }) do sum = sum + cart(i) end
sum = sum & 0xFFFF
local cksum_ok = cart(0x51E) == 0x5A and cart(0x521) == 0xA5 and
                 cart(0x524) == (sum >> 8) and cart(0x525) == (sum & 0xFF)

local checks = {
    { "slot info name = LINK", name_ok },
    { "slot info active = 1", n(0x633) == 1 },
    { "slot info hearts = $22/$FF", n(0x650) == 0x22 and n(0x651) == 0xFF },
    { "cart file A name = LINK", cart_name_ok },
    { "cart file A hearts $22/$FF, max bombs 8",
      cart(0x01A + 0x18) == 0x22 and cart(0x01A + 0x19) == 0xFF and cart(0x01A + 0x25) == 0x08 },
    { "cart file A active 1, quest 0", cart(0x512) == 1 and cart(0x51B) == 0 },
    { "cart file A markers + checksum", cksum_ok },
}

tap({ A = true })                                    -- continue slot 0
local ready = -1
for i = 1, 900 do
    emu.frameadvance()
    if n(0x12) == 0x05 and n(0xEB) ~= 0 and n(0x66F) ~= 0 then ready = i; break end
end
idle(90)
client.screenshot(SHOT .. "5_gameplay.png")
checks[#checks + 1] = { "gameplay reached (GameMode $05)", ready > 0 }
checks[#checks + 1] = { "profile HeartValues $22 / MaxBombs 8", n(0x66F) == 0x22 and n(0x67C) == 0x08 }
checks[#checks + 1] = { "profile sword $657 = 0", n(0x657) == 0 }
checks[#checks + 1] = { "CurSaveSlot = 0", n(0x16) == 0 }

local pass, fail = 0, 0
for _, c in ipairs(checks) do
    if c[2] then pass = pass + 1 else fail = fail + 1 end
    f:write(string.format("  %-44s %s\n", c[1], c[2] and "OK" or "FAIL"))
end
f:write(string.format("profile: hearts=%02X partial=%02X maxbombs=%02X sword=%02X keys=%02X bombs=%02X\n",
    n(0x66F), n(0x670), n(0x67C), n(0x657), n(0x66E), n(0x658)))
f:write(string.format("VERDICT: %s %d/%d\n", fail == 0 and "PASS" or "FAIL", pass, pass + fail))
f:close()
client.exit()
