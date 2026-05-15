-- Canonical scenario capture (S1 Phase F, Task F1).
--
-- Single Lua, multi-reboot. Drives the ROM through 9 deterministic
-- scenario waypoints in two passes (intro-no-input + FS-with-input)
-- and dumps a tagged binary VDP/CRAM/SAT/VSRAM/RAM snapshot at each.
--
-- One launch produces 9 *.bin files in OUT_DIR. Diff against a
-- post-cutover run of the same script via tools/probes/diff_capture.py
-- to verify F3-F6 retargeting is byte-clean against pre-cutover state.
--
-- DEFERRED scenarios (require pre-seeded SRAM with a registered save):
--   fs_file_delete_confirm, fs_registered_file_start
--
-- Phase timings observed in the post-D ROM:
--   PHASE_TITLE_LOAD     1 frame
--   PHASE_TITLE_DISPLAY  400 frames (TITLE_DISPLAY_FRAMES)
--   PHASE_TITLE_FADEOUT  ~14 frames
--   PHASE_BLACK_HOLD     180 frames (BLACK_HOLD_FRAMES)
--   PHASE_STORY_LOAD     1 frame
--   PHASE_STORY_RUN      (variable; capture mid-run)

local OUT_DIR = "C:\\tmp\\canonical"
os.execute("mkdir " .. OUT_DIR .. " 2>nul")

local function vram_block(start, size)
    local buf = {}
    for i = 0, size - 1 do
        buf[#buf + 1] = string.char(memory.read_u8(start + i, "VRAM"))
    end
    return table.concat(buf)
end

local function dom_block(domain, size)
    local buf = {}
    for i = 0, size - 1 do
        buf[#buf + 1] = string.char(memory.read_u8(i, domain))
    end
    return table.concat(buf)
end

local function u32le(v)
    return string.char(v & 0xFF) ..
           string.char((v >> 8) & 0xFF) ..
           string.char((v >> 16) & 0xFF) ..
           string.char((v >> 24) & 0xFF)
end

local function fnv32(s)
    local h = 2166136261
    for i = 1, #s do
        h = (h ~ string.byte(s, i)) * 16777619
        h = h & 0xFFFFFFFF
    end
    return h
end

local function capture(name)
    local plana = vram_block(0xC000, 0x2000)
    local planb = vram_block(0xE000, 0x2000)
    local sat   = vram_block(0xFC00, 640)
    local cram  = dom_block("CRAM", 128)
    local vsra  = dom_block("VSRAM", 80)
    local zp    = dom_block("68K RAM", 256)
    local payload_for_hash = plana .. planb .. sat .. cram .. vsra
    local hash = fnv32(payload_for_hash)

    local path = OUT_DIR .. "\\" .. name .. ".bin"
    local f = io.open(path, "wb")
    f:write("GDMP")
    f:write(u32le(1))
    f:write(u32le(emu.framecount()))
    f:write(u32le(hash))

    local function region(tag, p)
        f:write(tag)
        f:write(u32le(#p))
        f:write(p)
    end
    region("PLNA", plana)
    region("PLNB", planb)
    region("SAT_", sat)
    region("CRAM", cram)
    region("VSRA", vsra)
    region("RAM_", zp)
    region("END_", "")
    f:close()

    -- log marker so a tail of console output proves which captures fired
    print(string.format("captured %-32s frame=%d hash=0x%08X path=%s",
        name, emu.framecount(), hash, path))
end

local function press_one_frame(btn_table)
    joypad.set(btn_table, 1)
end

-- =============================================================
-- PASS A: cold boot, NO input. Intro phase machine plays through.
-- =============================================================

local pass_a_targets = {
    [200]  = "title_idle",          -- mid title_display
    [700]  = "intro_story_p1",      -- after fadeout + black, into story
    -- Phase 11 master-plan probe: intro_story_loop — capture mid
    -- second attract cycle (after first story page completes and
    -- the attract loop wraps back). Story scroll is ~600 frames per
    -- pass; ~1500 lands well inside the 2nd loop.
    [1500] = "intro_story_loop",
}

while emu.framecount() < 1600 do
    local fr = emu.framecount()
    if pass_a_targets[fr] then
        capture(pass_a_targets[fr])
    end
    emu.frameadvance()
end

-- =============================================================
-- PASS B: reboot, press Start at title, drive FS scenarios.
-- After client.reboot_core(), emu.framecount() resets to 0.
-- =============================================================

client.reboot_core()
-- Allow one frame after reboot so emulator settles.
emu.frameadvance()

-- B-pass timeline (relative to post-reboot framecount):
--   100  press Start (title takes Start to advance to FS)
--   180  capture title_to_fs (mid handoff fade)
--   260  capture fs_fresh_cursor (FS settled)
--   270  press Down (cursor moves to slot 2)
--   280  press Down (cursor moves to slot 3)
--   290  press Down (cursor wraps or hits OPTIONS row)
--   320  capture fs_cursor_wrap
--   330  cursor up to slot 1, press A to enter name-entry
--       (slot 1 empty -> name entry mode)
--   400  capture fs_name_entry_create
--   410  press B to backspace (or Up/Down on letter table)
--   460  capture fs_name_entry_backspace
--   470  press B to leave name entry, navigate to ERASE SAVE
--   570  press A on ERASE SAVE row -> delete prompt
--   620  press B on delete prompt -> cancel
--   650  capture fs_file_delete_cancel

local b_steps = {
    -- frame -> {action, label}
    [100]  = { press = {Start = true} },
    [180]  = { snap  = "title_to_fs" },
    [260]  = { snap  = "fs_fresh_cursor" },
    [270]  = { press = {Down = true} },
    [280]  = { press = {Down = true} },
    [290]  = { press = {Down = true} },
    [300]  = { press = {Down = true} },
    [310]  = { press = {Down = true} },     -- ensure wrap visited
    [320]  = { snap  = "fs_cursor_wrap" },
    [330]  = { press = {Up = true} },
    [340]  = { press = {Up = true} },
    [350]  = { press = {Up = true} },
    [360]  = { press = {Up = true} },
    [370]  = { press = {A = true} },        -- enter name-entry on slot 1
    [400]  = { snap  = "fs_name_entry_create" },
    [410]  = { press = {A = true} },        -- pick a letter
    [430]  = { press = {B = true} },        -- backspace
    [460]  = { snap  = "fs_name_entry_backspace" },
    [470]  = { press = {B = true} },        -- exit name entry
    [490]  = { press = {Down = true} },
    [510]  = { press = {Down = true} },
    [530]  = { press = {Down = true} },
    [550]  = { press = {Down = true} },     -- navigate to ERASE SAVE row
    [570]  = { press = {A = true} },        -- pick ERASE SAVE
    [600]  = { press = {Down = true} },     -- highlight a slot in delete mode
    [620]  = { press = {B = true} },        -- cancel
    [650]  = { snap  = "fs_file_delete_cancel" },
    -- Phase 11 master-plan probes (Redux FS-compatible):
    -- fs_players_cycle: navigate cursor back up + over to PLAYERS row
    --   (row 5), press Right to cycle 1->2.
    [700]  = { press = {Up = true} },     -- approach PLAYERS row from above
    [720]  = { press = {Up = true} },
    [740]  = { press = {Right = true} },  -- cycle 1->2 on PLAYERS row
    [770]  = { snap  = "fs_players_cycle" },
    -- fs_options_enter: navigate to OPTIONS row (6), press A.
    [790]  = { press = {Down = true} },   -- PLAYERS -> OPTIONS
    [820]  = { press = {A = true} },      -- enter OPTIONS submenu
    [860]  = { snap  = "fs_options_enter" },
}

while emu.framecount() < 900 do
    local fr = emu.framecount()
    local step = b_steps[fr]
    if step then
        if step.press then press_one_frame(step.press) end
        if step.snap  then capture(step.snap) end
    end
    emu.frameadvance()
end

print("DONE: 11 captures in " .. OUT_DIR)
client.exit()
