-- probe_fs_entry.lua — does START at the title reach the File Select, and
-- does picking a slot reach gameplay?
--
-- The File Select was linked into Debug.md but unreachable until now:
-- debug_poll_title had no entry for it, and fs_handoff jumped to an ASM
-- trampoline that is not in this build. This drives the new path.
--
-- SCOPE (RULE V1): smoke. Proves the control flow connects. It is NOT a
-- claim that the File Select renders correctly or matches the NES.
-- Screenshots are triage material; the verdict comes from state reads.
--
-- RULE V3: domains enumerated live.

local OUT      = "C:\\tmp\\fs_entry_report.txt"
local SHOT_DIR = "C:\\tmp\\fs_entry\\"
os.execute('mkdir "C:\\tmp" 2>NUL')
os.execute('mkdir "' .. SHOT_DIR .. '" 2>NUL')

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

local errs = {}
local function rd(a, d)
    local ok, v = pcall(memory.read_u8, a, d)
    if not ok or type(v) ~= "number" then
        errs[#errs + 1] = string.format("read $%X failed", a)
        return nil
    end
    return v
end
-- Two different windows, deliberately. fs_handoff.c writes through
-- nes_ram, which is A4-pinned to $FF8000, so its marker is at $FF87F2.
-- fs_phase.c writes through its own M68K_RAM base of $FF0000, so the
-- phase byte is at $FF07F0. Reading either at the other's base returns
-- unrelated memory, which would look like a real failure.
local function nesram(off) return rd(BUS_BASE + 0x8000 + off, WORK) end
local function fsram(off)  return rd(0xFF0000 + off, WORK) end
local function hex(v) return v and string.format("$%02X", v) or "<fail>" end

local FS_LOAD, FS_NAV, FS_HANDOFF = 0, 1, 7

if WORK == nil then
    local f = io.open(OUT, "w")
    f:write("UNVERIFIED: no usable 68K domain\n")
    f:close()
    print("UNVERIFIED: no domain")
    client.exit()
    return
end

local function press(b, n) for _ = 1, n do joypad.set(b, 1); emu.frameadvance() end end
local function idle(n) for _ = 1, n do emu.frameadvance() end end

local steps = {}
local function snap(label)
    client.screenshot(SHOT_DIR .. label .. ".png")
    steps[#steps + 1] = {
        label = label,
        -- $FF87F2 = fs_handoff progress marker ($CC once handoff began).
        marker = nesram(0x07F2),
        mode   = nesram(0x0012),
        room   = nesram(0x00EB),
        slot   = nesram(0x0016),   -- CurSaveSlot, seeded by fs_handoff
        -- $FF07F0 = fs_phase.c current phase. FS-exclusive: nothing else
        -- in the boot path writes it, so it is the only read here that
        -- can actually prove the File Select was entered.
        phase  = fsram(0x07F0),
        cursor = fsram(0x07F1),
    }
end

idle(150);                        snap("01_title")
press({ Start = true }, 6)
idle(90);                         snap("02_after_start")   -- expect File Select

-- Commit to a slot. The FS phase machine starts at FS_LOAD then FS_NAV;
-- START confirms the highlighted slot.
press({ Start = true }, 6)
idle(150);                        snap("03_after_select")

-- Give gameplay time to come up if the handoff fired.
local ready = -1
for i = 1, 900 do
    emu.frameadvance()
    local r = nesram(0x00EB)
    if r and r ~= 0x00 then ready = i; break end
end
idle(60);                         snap("04_gameplay")

local title, fs, sel, play = steps[1], steps[2], steps[3], steps[4]

-- The File Select must be proven ENTERED, not merely "something changed".
-- A jump straight from title to gameplay would satisfy a bare
-- state-changed check and hand back a false PASS on the exact thing this
-- probe exists to measure. fs_phase's byte is the only FS-exclusive
-- signal in the boot path.
local reached_fs = (fs.phase == FS_LOAD) or (fs.phase == FS_NAV)
                   or (fs.phase == FS_HANDOFF)

local checks = {
    { "title reached (GameMode $CD sentinel)", title.mode == 0xCD },
    { "File Select entered (fs_phase valid)", reached_fs },
    { "handoff marker set ($CC)", (sel.marker == 0xCC) or (play.marker == 0xCC) },
    { "gameplay room populated", ready > 0 },
    { "GameMode is Play ($05)", play.mode == 0x05 },
}

local pass, fail = 0, 0
for _, c in ipairs(checks) do if c[2] then pass = pass + 1 else fail = fail + 1 end end

local f = io.open(OUT, "w")
f:write("probe_fs_entry — " .. os.date() .. "\n")
f:write("domain: " .. WORK .. "\n")
f:write("gameplay ready at frame: " .. ready .. "\n\n")
f:write("step             marker mode room slot\n")
for _, s in ipairs(steps) do
    f:write(string.format("%-16s %s  %s  %s  %s\n", s.label,
        hex(s.marker), hex(s.mode), hex(s.room), hex(s.slot)))
end
f:write("\n")
for _, c in ipairs(checks) do
    f:write(string.format("  %-38s %s\n", c[1], c[2] and "OK" or "FAIL"))
end
if #errs > 0 then
    f:write("\nREAD ERRORS:\n")
    for _, e in ipairs(errs) do f:write("  " .. e .. "\n") end
end
f:write(string.format("\nVERDICT: %s — %d/%d\n",
        (fail == 0 and #errs == 0) and "PASS" or "FAIL", pass, pass + fail))
f:write("Scope: control flow only. Not a rendering or NES-parity claim.\n")
f:close()

print(string.format("fs_entry: %d/%d -> %s", pass, pass + fail, OUT))
client.exit()
