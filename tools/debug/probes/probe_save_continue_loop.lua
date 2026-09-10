-- probe_save_continue_loop.lua — the whole loop, end to end.
--
--   title -> START -> File Select -> slot 0 -> New Game
--   modify inventory so the save is distinguishable from defaults
--   save via GameMode $0D (the mode NES Mode 8 "SAVE" selects)
--   HARD RESET
--   title -> START -> File Select -> slot 0 -> Continue
--   inventory must come back
--
-- This is what "you can play it and come back to it" means. Every earlier
-- save probe proved a piece; this proves the round trip a player takes.
--
-- SCOPE (RULE V1): control flow + state. Not an NES-parity claim.
-- RULE V3: domains enumerated live.

local OUT      = "C:\\tmp\\save_continue_report.txt"
local SHOT_DIR = "C:\\tmp\\save_continue\\"
os.execute('mkdir "C:\\tmp" 2>NUL')
os.execute('mkdir "' .. SHOT_DIR .. '" 2>NUL')

local ITEMS      = 0x0657   -- NES Items block, 40 bytes (Variables.inc)
local ITEMS_N    = 40
local RUPEES     = 0x066D   -- a byte inside the Items block, easy to eyeball
local GAME_MODE  = 0x0012
local CUR_ROOM   = 0x00EB
local MODE_SAVE  = 0x0D
local MODE_PLAY  = 0x05

local NAMES = {}
do
    local ok, list = pcall(memory.getmemorydomainlist)
    if ok and type(list) == "table" then
        for _, d in ipairs(list) do NAMES[tostring(d)] = true end
    end
end
local WORK, BUS
for _, c in ipairs({ "M68K BUS", "68K RAM", "Main RAM" }) do
    if NAMES[c] then
        WORK = c
        BUS = (c == "M68K BUS") and 0xFF0000 or 0
        break
    end
end

local errs = {}
local function rd(a, d)
    local ok, v = pcall(memory.read_u8, a, d)
    if not ok or type(v) ~= "number" then
        errs[#errs + 1] = string.format("read $%X", a); return nil
    end
    return v
end
local function nes(off) return rd(BUS + 0x8000 + off, WORK) end
local function nesw(off, v) pcall(memory.write_u8, BUS + 0x8000 + off, v, WORK) end
local function hex(v) return v and string.format("$%02X", v) or "<fail>" end

local function bail(msg)
    local f = io.open(OUT, "w")
    f:write("probe_save_continue_loop\nVERDICT: UNVERIFIED — " .. msg .. "\n")
    f:close(); print("UNVERIFIED: " .. msg); client.exit()
end
if WORK == nil then bail("no usable 68K domain") return end

local function press(b, n) for _ = 1, n do joypad.set(b, 1); emu.frameadvance() end end
local function idle(n) for _ = 1, n do emu.frameadvance() end end

-- title -> START -> File Select -> START -> gameplay. Returns frame the
-- room populated, or -1.
local function boot_through_fs()
    idle(150)
    press({ Start = true }, 6)
    idle(90)                      -- File Select
    press({ Start = true }, 6)    -- confirm slot 0
    for i = 1, 900 do
        emu.frameadvance()
        local r = nes(CUR_ROOM)
        if r and r ~= 0x00 then idle(60) return i end
    end
    return -1
end

------------------------------------------------------- pass 1: new game ---
local ready1 = boot_through_fs()
if ready1 < 0 then bail("first boot never reached gameplay") return end
client.screenshot(SHOT_DIR .. "01_new_game.png")

local rupees_before = nes(RUPEES)

-- Make the save unmistakably distinct from a fresh profile. The marker is
-- DERIVED from the current value rather than fixed: a constant could
-- happen to equal what the slot already holds, and then "restored after
-- reset" would pass without the write ever having been saved.
local MARK = ((rupees_before or 0) + 0x2A) % 0x100
if MARK == (rupees_before or 0) then MARK = (MARK + 1) % 0x100 end
nesw(RUPEES, MARK)
idle(4)
local rupees_marked = nes(RUPEES)

-- Save. GameMode $0D is exactly what Mode 8's "SAVE" selection sets
-- (k_mode8_selection_to_mode = {$03 Continue, $0D Save, $00 Retry}).
nesw(GAME_MODE, MODE_SAVE)
idle(12)
local mode_after_save = nes(GAME_MODE)
client.screenshot(SHOT_DIR .. "02_after_save.png")

------------------------------------------------------------ hard reset ---
local pre_room = nes(CUR_ROOM)
local called_ok = pcall(client.reboot_core)
idle(180)
local post_room = nes(CUR_ROOM)
-- pcall only says no Lua error was raised; require observable teardown.
local rebooted = (called_ok == true) and (pre_room ~= post_room)

------------------------------------------------------ pass 2: continue ---
local ready2 = boot_through_fs()
client.screenshot(SHOT_DIR .. "03_after_continue.png")
local rupees_restored = (ready2 > 0) and nes(RUPEES) or nil

local checks = {
    { "new game reached gameplay",        ready1 > 0 },
    { "marker differs from fresh value",  MARK ~= rupees_before },
    { "inventory byte was modified",      rupees_marked == MARK },
    { "save returned to Play ($05)",      mode_after_save == MODE_PLAY },
    { "core rebooted (observable)",       rebooted },
    { "continue reached gameplay",        ready2 > 0 },
    { "inventory restored after reset",   rupees_restored == MARK },
}
local pass, fail = 0, 0
for _, c in ipairs(checks) do if c[2] then pass = pass + 1 else fail = fail + 1 end end

local f = io.open(OUT, "w")
f:write("probe_save_continue_loop — " .. os.date() .. "\n")
f:write("domain: " .. WORK .. "\n")
f:write(string.format("gameplay ready: pass1 frame %d, pass2 frame %d\n",
        ready1, ready2))
f:write(string.format("room across reset: %s -> %s\n", hex(pre_room), hex(post_room)))
f:write(string.format("\ninventory byte $%04X:\n", RUPEES))
f:write(string.format("  fresh new game : %s\n", hex(rupees_before)))
f:write(string.format("  after marking  : %s (wrote $%02X)\n", hex(rupees_marked), MARK))
f:write(string.format("  after continue : %s\n", hex(rupees_restored)))
f:write("\n")
for _, c in ipairs(checks) do
    f:write(string.format("  %-36s %s\n", c[1], c[2] and "OK" or "FAIL"))
end
if #errs > 0 then
    f:write("\nREAD ERRORS:\n")
    for _, e in ipairs(errs) do f:write("  " .. e .. "\n") end
end
f:write(string.format("\nVERDICT: %s — %d/%d\n",
        (fail == 0 and #errs == 0) and "PASS" or "FAIL", pass, pass + fail))
f:write("The loop is only real if the last check passes.\n")
f:close()

print(string.format("save_continue_loop: %d/%d -> %s", pass, pass + fail, OUT))
client.exit()
