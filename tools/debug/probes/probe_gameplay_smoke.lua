-- probe_gameplay_smoke.lua — does the game still play after today's data changes?
--
-- WHY: 2026-08-04 changed LevelInfo for all 9 dungeons (542a5ea1), 42 CRAM
-- palette words (99bf3173), and regenerated the whole legacy .inc set
-- (7b6fc521). Every verification so far was static or read four bytes. This
-- drives the ROM and records what the engine actually does.
--
-- SCOPE (RULE V1): this is a SMOKE test. It proves the engine runs, moves,
-- and renders — NOT that anything is NES-correct. Screenshots here are for
-- human triage of a failure, never for the pass/fail decision. Every verdict
-- below comes from a RAM/CRAM/SAT read with an expected value.
--
-- RULE V3: enumerate domains live; never assume a name.

local OUT      = "C:\\tmp\\gameplay_smoke_report.txt"
local SHOT_DIR = "C:\\tmp\\gameplay_smoke\\"
os.execute('mkdir "C:\\tmp" 2>NUL')
os.execute('mkdir "' .. SHOT_DIR .. '" 2>NUL')

------------------------------------------------------------------ domains ---
local function domain_names()
    local ok, list = pcall(memory.getmemorydomainlist)
    local names = {}
    if ok and type(list) == "table" then
        for _, d in ipairs(list) do names[tostring(d)] = true end
    end
    return names
end

local NAMES = domain_names()
local DOMAIN, BUS_BASE
for _, cand in ipairs({ "M68K BUS", "68K RAM", "Main RAM" }) do
    if NAMES[cand] then
        DOMAIN = cand
        BUS_BASE = (cand == "M68K BUS") and 0xFF0000 or 0x000000
        break
    end
end

local CRAM_DOMAIN = NAMES["CRAM"] and "CRAM" or nil
local VRAM_DOMAIN = NAMES["VRAM"] and "VRAM" or nil

local errs = {}
local function rd(addr, dom)
    local ok, v = pcall(memory.read_u8, addr, dom)
    if not ok or type(v) ~= "number" then
        errs[#errs + 1] = string.format("read $%X in %s failed", addr, tostring(dom))
        return nil
    end
    return v
end

local function nesram(off) return rd(BUS_BASE + 0x8000 + off, DOMAIN) end
local function hex(v) return v and string.format("$%02X", v) or "<fail>" end

-------------------------------------------------------------------- drive ---
local function press(btns, frames)
    for _ = 1, frames do joypad.set(btns, 1); emu.frameadvance() end
end
local function idle(frames) for _ = 1, frames do emu.frameadvance() end end

local steps = {}
local function snap(label)
    client.screenshot(SHOT_DIR .. label .. ".png")
    steps[#steps + 1] = {
        label = label,
        mode  = nesram(0x0012),   -- GameMode
        room  = nesram(0x00EB),   -- CurRoomId
        x     = nesram(0x0070),   -- ObjX[0]  (Link)
        y     = nesram(0x0084),   -- ObjY[0]
        face  = nesram(0x008C),   -- ObjDir[0]
        hp    = nesram(0x066F),   -- HeartValues
    }
end

if DOMAIN == nil then
    local f = io.open(OUT, "w")
    f:write("FAIL: no usable 68K domain. Domains seen:\n")
    for n in pairs(NAMES) do f:write("  " .. n .. "\n") end
    f:close()
    print("FAIL: no usable memory domain")
    client.exit()
    return
end

idle(150);                       snap("01_title")
press({ A = true, B = true, C = true }, 8)

-- Wait for the NES RAM mirror to actually populate. The first run of this
-- probe drove Link 200 frames after the chord while CurRoomId/ObjX were
-- still $00, so the inputs were consumed during init and the reads were
-- meaningless. Poll for CurRoomId rather than guessing a frame count.
local ready_frame = -1
for i = 1, 900 do
    emu.frameadvance()
    local room = nesram(0x00EB)
    if room and room ~= 0x00 then ready_frame = i; break end
end
idle(60);                        snap("02_gameplay")
press({ Right = true }, 60); idle(10);  snap("03_walk_right")
press({ Up = true }, 60);    idle(10);  snap("04_walk_up")
press({ A = true }, 4);      idle(20);  snap("05_sword")
idle(60);                        snap("06_settle")

------------------------------------------------------------------ verdicts ---
local g = steps[2]                      -- after chord
local last = steps[#steps]
local moved_x = (steps[3].x and g.x) and (steps[3].x ~= g.x)
local moved_y = (steps[4].y and steps[3].y) and (steps[4].y ~= steps[3].y)

-- CRAM: counts populated palette bytes. This says palettes were INITIALISED.
-- It deliberately does NOT claim the screen rendered: CRAM can stay populated
-- from the title screen, display can be off, and index 0 can cover everything.
-- Review 2026-08-04 caught the earlier "screen not black" wording.
local cram_nonzero = 0
if CRAM_DOMAIN then
    for i = 0, 127 do
        local b = rd(i, CRAM_DOMAIN)
        if b and b ~= 0 then cram_nonzero = cram_nonzero + 1 end
    end
end

-- Render signal that can actually fail: Link's sprite must be live in the
-- Sprite Attribute Table with an on-screen Y. SAT base is read from VDP
-- register 5 rather than hardcoded (RULE V3 — a wrong base silently reads
-- zeros and would fake a pass). If no VDP-register domain is exposed, the
-- check reports UNKNOWN instead of inventing a verdict.
local sat_checked, sat_link_live = false, false
local VDPREG = NAMES["VDP Registers"] and "VDP Registers" or nil
if VDPREG and VRAM_DOMAIN then
    local r5 = rd(5, VDPREG)
    if r5 then
        local sat_base = (r5 & 0x7F) * 0x200
        -- SGDK sprite entry: y(2) link(1) size(1) attr(2) x(2)
        local y_hi, y_lo = rd(sat_base, VRAM_DOMAIN), rd(sat_base + 1, VRAM_DOMAIN)
        if y_hi and y_lo then
            local y = ((y_hi << 8) | y_lo) - 128
            sat_checked = true
            sat_link_live = (y > 0 and y < 240)
        end
    end
end

local checks = {
    { "entered gameplay (GameMode $05)", g.mode == 0x05 },
    { "Link has hearts (HeartValues != 0)", (g.hp or 0) ~= 0 },
    { "Link moved on Right", moved_x == true },
    { "Link moved on Up", moved_y == true },
    { "still in Play at end", last.mode == 0x05 },
    { "CRAM populated (palette init only)", cram_nonzero > 0 },
}
if sat_checked then
    checks[#checks + 1] = { "SAT slot 0 sprite on-screen (render)", sat_link_live }
end

local pass, fail = 0, 0
for _, c in ipairs(checks) do
    if c[2] then pass = pass + 1 else fail = fail + 1 end
end

local f = io.open(OUT, "w")
f:write("probe_gameplay_smoke — " .. os.date() .. "\n")
f:write("domain: " .. DOMAIN .. "  cram: " .. tostring(CRAM_DOMAIN) ..
        "  vram: " .. tostring(VRAM_DOMAIN) .. "\n")
f:write("gameplay state ready at frame: " .. tostring(ready_frame) .. "\n")
local dn = {}
for n in pairs(NAMES) do dn[#dn + 1] = n end
table.sort(dn)
f:write("domains exposed: " .. table.concat(dn, ", ") .. "\n\n")
f:write("step            mode room    x    y face   hp\n")
for _, s in ipairs(steps) do
    f:write(string.format("%-15s %s  %s  %s  %s  %s  %s\n", s.label,
        hex(s.mode), hex(s.room), hex(s.x), hex(s.y), hex(s.face), hex(s.hp)))
end
f:write("\nCRAM non-zero bytes (of 128): " .. cram_nonzero ..
        "   (palette init only, NOT a render claim)\n")
f:write("SAT render check: " ..
        (sat_checked and (sat_link_live and "slot 0 on-screen" or "slot 0 OFF-SCREEN")
                      or "UNKNOWN (no VDP-register domain exposed)") .. "\n\n")
for _, c in ipairs(checks) do
    f:write(string.format("  %-40s %s\n", c[1], c[2] and "OK" or "FAIL"))
end
if #errs > 0 then
    f:write("\nREAD ERRORS:\n")
    for _, e in ipairs(errs) do f:write("  " .. e .. "\n") end
end
f:write(string.format("\nVERDICT: %s — %d/%d smoke checks pass\n",
    (fail == 0 and #errs == 0) and "PASS" or "FAIL", pass, pass + fail))
f:write("Scope: engine runs/moves/renders. NOT a NES-correctness claim.\n")
f:close()

print(string.format("gameplay_smoke: %d/%d pass -> %s", pass, pass + fail, OUT))
client.exit()
