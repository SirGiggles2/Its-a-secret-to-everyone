-- probe_save_persistence.lua — does a save survive a hard reset?
--
-- This is the only evidence that matters for the save system. Compiling,
-- linking and green gates say nothing about whether bytes reach the cart
-- and come back after power-off.
--
-- METHOD
--   1. boot -> A+B+C -> gameplay
--   2. read the live Items block (NES $657, 40 bytes) as a fingerprint
--   3. poke GameMode = $0D; mode_dispatch_update() runs every frame at
--      RoomRom/src/main.c:2304, so mode13_save_update fires next frame
--   4. confirm the mode returned to Play ($05)
--   5. read cart SRAM directly: slot 0 must open with magic $5A $A5 and
--      carry the same 40 Items bytes
--   6. HARD RESET the core
--   7. read cart SRAM again — magic and payload must still be there
--
-- Step 7 is the whole test. Steps 1-5 only establish that step 7 is
-- meaningful; if the save never got written, surviving a reset proves
-- nothing.
--
-- RULE V3: domains enumerated live. The Genesis core exposes a real
-- "SRAM" domain (confirmed by probe_gameplay_smoke), which is cart
-- battery RAM, NOT the $FF6000 work-RAM mirror.

local OUT = "C:\\tmp\\save_persistence_report.txt"
os.execute('mkdir "C:\\tmp" 2>NUL')

local SAVE_MAGIC_LO   = 0x5A
local SAVE_MAGIC_HI   = 0xA5
local ITEMS_NES_ADDR  = 0x0657
local ITEMS_BYTES     = 40
local GAME_MODE_ADDR  = 0x0012
local MODE_SAVE       = 0x0D
local MODE_PLAY       = 0x05

------------------------------------------------------------------ domains ---
local NAMES = {}
do
    local ok, list = pcall(memory.getmemorydomainlist)
    if ok and type(list) == "table" then
        for _, d in ipairs(list) do NAMES[tostring(d)] = true end
    end
end

local WORK, BUS_BASE
for _, cand in ipairs({ "M68K BUS", "68K RAM", "Main RAM" }) do
    if NAMES[cand] then
        WORK = cand
        BUS_BASE = (cand == "M68K BUS") and 0xFF0000 or 0x000000
        break
    end
end
local SRAM = NAMES["SRAM"] and "SRAM" or nil

local errs = {}
local function rd(addr, dom)
    local ok, v = pcall(memory.read_u8, addr, dom)
    if not ok or type(v) ~= "number" then
        errs[#errs + 1] = string.format("read $%X in %s failed", addr, tostring(dom))
        return nil
    end
    return v
end
local function nesram(off) return rd(BUS_BASE + 0x8000 + off, WORK) end
local function wr(addr, val, dom) pcall(memory.write_u8, addr, val, dom) end

local function fail(msg)
    local f = io.open(OUT, "w")
    f:write("probe_save_persistence — " .. os.date() .. "\n")
    f:write("VERDICT: UNVERIFIED — " .. msg .. "\n")
    f:close()
    print("UNVERIFIED: " .. msg)
    client.exit()
end

if WORK == nil then fail("no usable 68K domain") return end
if SRAM == nil then fail("core exposes no SRAM domain; cannot test persistence") return end

-------------------------------------------------------------------- drive ---
local function press(b, n) for _ = 1, n do joypad.set(b, 1); emu.frameadvance() end end
local function idle(n) for _ = 1, n do emu.frameadvance() end end

-- Gameplay entry. A single 8-frame chord at frame 150 stopped reaching
-- gameplay on the Sep builds (T-001: Items all zero, Mode $0D never
-- consumed; RoomId $EB is nonzero on the title, so it is not a gameplay
-- signal). Use the entry proven by the accepted Ganon/reward probes:
-- arm the debug probe control block ($FF73F8 'R','P',1) so the gameplay
-- mirror publishes, pulse A+B+C, and wait for the mirror signature 'W','P'
-- at $FF7200 with its frame counter past 5 (RoomRom/src/main.c
-- publish_state_mirror). The mirror is written only from gameplay tick.
local function wc(a, v) wr(BUS_BASE + a, v, WORK) end
local function rc(a) return rd(BUS_BASE + a, WORK) end
local function arm() wc(0x73F8, 0x52); wc(0x73F9, 0x50); wc(0x73FA, 1) end

idle(30)
local ready = -1
for i = 1, 1500 do
    arm()
    joypad.set((i % 30 < 4) and { A = true, B = true, C = true } or {}, 1)
    emu.frameadvance()
    if rc(0x7200) == 0x57 and rc(0x7201) == 0x50 and (rc(0x7203) or 0) > 5 then
        ready = i
        break
    end
end
joypad.set({}, 1)
idle(60)
if ready < 0 then fail("gameplay mirror never published (chord not accepted)") return end

-- Fingerprint the live inventory.
local items_before = {}
for i = 0, ITEMS_BYTES - 1 do
    local v = nesram(ITEMS_NES_ADDR + i)
    if v == nil then
        fail("Items read failed at offset " .. i .. "; fingerprint unusable")
        return
    end
    items_before[i] = v
end

-- Trigger Mode $0D.
wr(BUS_BASE + 0x8000 + GAME_MODE_ADDR, MODE_SAVE, WORK)
idle(12)
local mode_after = nesram(GAME_MODE_ADDR)

-- Read cart SRAM slot 0 BEFORE reset.
-- Genesis cart SRAM is byte-wide on ODD physical addresses: logical byte
-- k lands at domain index 2k+1. SGDK's SRAM_writeByte hides that, but
-- BizHawk's SRAM domain exposes the raw physical view, so a naive
-- sequential read returns $FF on every even index and shifts the payload.
-- Confirmed empirically on the first run of this probe: index 1 held the
-- $5A magic, index 3 held $A5, and indices 5/7/9 held Items[0..2].
local SRAM_STRIDE = 2
local SRAM_ODD    = 1
local function sram_slot0(n)
    local t = {}
    for i = 0, n - 1 do t[i] = rd(i * SRAM_STRIDE + SRAM_ODD, SRAM) end
    return t
end
local pre = sram_slot0(2 + ITEMS_BYTES)

local pre_magic = (pre[0] == SAVE_MAGIC_LO and pre[1] == SAVE_MAGIC_HI)
local pre_items_match = true
for i = 0, ITEMS_BYTES - 1 do
    if pre[2 + i] ~= items_before[i] then pre_items_match = false break end
end

------------------------------------------------------------------- reset ---
-- pcall succeeding only means no Lua error was raised. If reboot_core
-- silently did nothing, the still-live SRAM domain would pass every
-- after-reset check and hand back a false PASS on the one thing this
-- probe exists to measure. So require an OBSERVABLE teardown: after a
-- real reset the ROM is back at the title with gameplay state gone.
local pre_reset_room = nesram(0x00EB)
local pre_reset_mode = nesram(GAME_MODE_ADDR)

local called_ok = pcall(client.reboot_core)
idle(180)

local post_reset_room = nesram(0x00EB)
local post_reset_mode = nesram(GAME_MODE_ADDR)

-- Gameplay was live before ($77 / $05). If both are unchanged after, the
-- machine never restarted.
local observed_teardown =
    (pre_reset_room ~= post_reset_room) or (pre_reset_mode ~= post_reset_mode)
local rebooted = (called_ok == true) and observed_teardown

local post = sram_slot0(2 + ITEMS_BYTES)
local post_magic = (post[0] == SAVE_MAGIC_LO and post[1] == SAVE_MAGIC_HI)
local post_items_match = true
for i = 0, ITEMS_BYTES - 1 do
    if post[2 + i] ~= items_before[i] then post_items_match = false break end
end

------------------------------------------------------------------ verdict ---
local checks = {
    { "gameplay reached", ready > 0 },
    { "Mode $0D returned to Play ($05)", mode_after == MODE_PLAY },
    { "cart SRAM has magic BEFORE reset", pre_magic },
    { "cart SRAM Items match live BEFORE reset", pre_items_match },
    { "core rebooted", rebooted == true },
    { "cart SRAM has magic AFTER reset", post_magic },
    { "cart SRAM Items match AFTER reset", post_items_match },
}
local pass, failn = 0, 0
for _, c in ipairs(checks) do if c[2] then pass = pass + 1 else failn = failn + 1 end end

local f = io.open(OUT, "w")
f:write("probe_save_persistence — " .. os.date() .. "\n")
f:write("work domain: " .. WORK .. "   cart domain: " .. SRAM .. "\n")
f:write("gameplay ready at frame: " .. ready .. "\n")
f:write(string.format("GameMode after save poke: $%02X (want $%02X)\n",
                      mode_after or 0xFF, MODE_PLAY))
f:write("\nItems fingerprint (first 8 of 40): ")
for i = 0, 7 do f:write(string.format("%02X ", items_before[i] or 0xFF)) end
f:write("\nSRAM slot0 pre-reset  (first 10): ")
for i = 0, 9 do f:write(string.format("%02X ", pre[i] or 0xFF)) end
f:write("\nSRAM slot0 post-reset (first 10): ")
for i = 0, 9 do f:write(string.format("%02X ", post[i] or 0xFF)) end
f:write("\n\n")
for _, c in ipairs(checks) do
    f:write(string.format("  %-42s %s\n", c[1], c[2] and "OK" or "FAIL"))
end
if #errs > 0 then
    f:write("\nREAD ERRORS:\n")
    for _, e in ipairs(errs) do f:write("  " .. e .. "\n") end
end
f:write(string.format("\nVERDICT: %s — %d/%d\n",
        (failn == 0 and #errs == 0) and "PASS" or "FAIL", pass, pass + failn))
f:write("A save is only real if the two AFTER-reset checks pass.\n")
f:close()

print(string.format("save_persistence: %d/%d -> %s", pass, pass + failn, OUT))
client.exit()
