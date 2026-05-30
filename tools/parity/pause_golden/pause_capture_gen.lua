-- pause_capture_gen.lua — Genesis (Debug.md) pause/inventory SUBSCREEN golden.
--
-- Mirror of pause_capture_nes.lua for the port. ABC-chord into gameplay
-- (debug_unlock_all_items populates g_inventory so every owned slot
-- renders), press Start to open the subscreen, capture at the SAME
-- sub-states so pause_byte_diff.py compares each:
--   active.bin   — subscreen fully open (scroll settled)
--   blink0.bin / blink1.bin — 8 frames apart (cursor palette toggle)
-- Plus the animation truth:
--   scroll_open.csv  — per frame: VSRAM0 (plane-A vscroll), pause flag, scene
--   scroll_close.csv — same, during scroll-out
--   state.txt        — scene + key cells (located from full dumps)
--
-- Genesis domains (genplus-gx, verified probe_gen_cave_golden.lua):
--   "68K RAM" (nes_ram mirror @ $8000+nes_addr; port globals elsewhere),
--   "VRAM" (planes $C000/$E000, displayed SAT $F400 per cave differ),
--   "CRAM" (128B), "VSRAM" (80B vertical scroll).
--
-- Globals (prelude or defaults):
--   OUT_DIR : output root (default C:\tmp\pause_golden)
--   TAG     : subdir tag (default "gen_boot"; rename per captured scene)

OUT_DIR = OUT_DIR or "C:\\tmp\\pause_golden"
TAG     = TAG or "gen_boot"

local OUT = string.format("%s\\%s", OUT_DIR, TAG)
os.execute('if not exist "' .. OUT .. '" mkdir "' .. OUT .. '"')

-- ─── 68K RAM cell offsets (nes_ram mirror @ $8000; port state at low
--      addrs per probe_gen_cave_golden.lua) ─────────────────────────
local OFF_IN_GAMEPLAY = 0x0274
local OFF_SCENE_HI     = 0x0281   -- s_scene int (BE) — candidate, verified from dump
local OFF_SCENE_LO     = 0x0284
local function r8(o)   return memory.read_u8(o, "68K RAM") end
local function w8(o,v) memory.write_u8(o, v, "68K RAM") end
local function nes_r8(a) return r8(0x8000 + a) end
local function vsram0()
    -- VSRAM word 0 (bytes 0/1, big-endian) = plane-A vertical scroll.
    return (memory.read_u8(0, "VSRAM") << 8) | memory.read_u8(1, "VSRAM")
end
local function vsram1()
    -- VSRAM word 1 (bytes 2/3) = plane-B vscroll. Logged as cross-check so
    -- we can prove which plane the pause scroll moves (Review C6).
    return (memory.read_u8(2, "VSRAM") << 8) | memory.read_u8(3, "VSRAM")
end
local function idle(n) for _=1,n do emu.frameadvance() end end
local function press(b) joypad.set(b) end
local function press_for(b, n)
    press(b); emu.frameadvance(); press({}); idle(math.max(0, n - 1))
end
local function LOG(s)
    local fh = io.open(OUT .. "\\probe_log.txt", "a")
    if fh then fh:write(s .. "\n"); fh:close() end
    print(s)
end

-- ─── Enumerate domains (RULE V3) ────────────────────────────────────
do
    local doms = memory.getmemorydomainlist()
    local dl = io.open(OUT .. "\\domains.txt", "w")
    local have_vsram = false
    for _, d in ipairs(doms) do
        dl:write(string.format("%s: %d bytes\n", d, memory.getmemorydomainsize(d)))
        if d == "VSRAM" then have_vsram = true end
    end
    dl:close()
    -- Review C1: a missing/renamed VSRAM domain silently returns fallback
    -- zeros (looks like "no scroll", not an error). Fail loud instead.
    if not have_vsram then
        LOG("!!! VSRAM domain ABSENT — scroll ladder would be bogus. Check core. !!!")
    end
end

-- ─── Boot (A+B+C chord) ─────────────────────────────────────────────
local function boot_to_gameplay()
    for frame = 1, 1500 do
        if frame >= 30 and frame <= 600 and (frame % 30) == 0 then
            press({["P1 A"]=true, ["P1 B"]=true, ["P1 C"]=true})
        end
        emu.frameadvance()
        if r8(OFF_IN_GAMEPLAY) == 1 then idle(60); return true end
    end
    return false
end

-- ─── Locate s_scene live: log several candidate offsets so the real
--      one is unambiguous from the dump (RULE ZERO: don't trust a
--      single guessed offset). ───────────────────────────────────────
local function scene_guess()
    -- s_scene is a C global; main.c's MODE handler mirrors it to nes_ram
    -- [$07E8] (= 68K $87E8) after each toggle. That's the reliable read.
    return r8(0x8000 + 0x07E8)
end

-- ─── GCGD bundle writer (cave_byte_diff GenBundle compatible) ───────
-- "GCGD"(4) frame(1) menu(1) scene(1) objtype1(1) CRAM[128] VRAM[64K]
-- 68K[64K] VSRAM[80]. GenBundle reads through VRAM (SAT@$F400); the 68K
-- + VSRAM trail is for pause-specific scroll/state checks.
local function vram_block(start, size)
    local buf = {}
    for i = 0, size - 1 do buf[#buf+1] = string.char(memory.read_u8(start + i, "VRAM")) end
    return table.concat(buf)
end
local function dom_block(dom, size)
    local buf = {}
    for i = 0, size - 1 do buf[#buf+1] = string.char(memory.read_u8(i, dom)) end
    return table.concat(buf)
end
local function capture(name)
    local f = io.open(OUT .. "\\" .. name, "wb")
    f:write("GCGD")
    f:write(string.char(0))                 -- frame slot (unused for pause)
    f:write(string.char(0))                 -- menu slot
    f:write(string.char(scene_guess()))     -- scene
    f:write(string.char(nes_r8(0x0350)))    -- objtype1 (unused here)
    f:write(dom_block("CRAM", 128))
    f:write(vram_block(0x0000, 0x10000))    -- FULL 64KB VRAM (SAT@$F400 + tiles)
    f:write(dom_block("68K RAM", 0x10000))  -- FULL 64KB work RAM (port state)
    f:write(dom_block("VSRAM", 80))         -- vertical scroll
    f:close()
    LOG(string.format("wrote %s scene=%d vsram0=$%04X", name, scene_guess(), vsram0()))
end

-- ─── Scroll ladder log (animation truth: VSRAM0 per frame) ──────────
local function log_ladder(csv_name, max_frames, settle_pred)
    local f = io.open(OUT .. "\\" .. csv_name, "w")
    f:write("frame,VSRAM0,VSRAM1,scene,in_gameplay\n")
    local stable, last = 0, -1
    for k = 0, max_frames - 1 do
        local v = vsram0()
        f:write(string.format("%d,%d,%d,%d,%d\n", k, v, vsram1(), scene_guess(), r8(OFF_IN_GAMEPLAY)))
        if v == last then stable = stable + 1 else stable = 0 end
        last = v
        if settle_pred and settle_pred(v, stable) then break end
        emu.frameadvance()
    end
    f:close()
end

-- ─── UW (dungeon) entry — proven L1 warp (probe_gen_dungeon_golden) ──
local function read_room() return r8(0x0041) end
local function write_link_xy(x,y)
    w8(0x1564,(x>>8)&0xFF) w8(0x1565,x&0xFF) w8(0x1566,(y>>8)&0xFF) w8(0x1567,y&0xFF)
end
local function force_warp_tile(col,row,tile)
    w8(0x8000+0x6530+col*0x16+row, tile); w8(0x0285+col*22+row, tile)
end
local function navigate_to_room(target)
    write_link_xy(0x78,0x70); press_for({["P1 X"]=true},8)
    for _=1,64 do
        local cur=read_room(); if cur==target then break end
        local cc,cr=cur&0x0F,(cur>>4)&0x07; local tc,tr=target&0x0F,(target>>4)&0x07
        if cc>tc then press_for({["P1 Left"]=true},16) elseif cc<tc then press_for({["P1 Right"]=true},16)
        elseif cr>tr then press_for({["P1 Up"]=true},16) elseif cr<tr then press_for({["P1 Down"]=true},16) else break end
    end
    press_for({["P1 X"]=true},8); idle(30)
end
-- Enter the underworld: the MODE button toggles s_scene OW<->UW
-- (main.c BUTTON_MODE handler) and seeds UW room $73 (L1 Q1 StartRoomId).
local function enter_dungeon()
    press_for({["P1 Mode"]=true}, 6)
    idle(60)
    LOG(string.format("after MODE: scene(07E8)=%d room=$%02X", scene_guess(), read_room()))
    return scene_guess() == 1
end

-- ─── Main ───────────────────────────────────────────────────────────
LOG("Gen pause golden TAG=" .. TAG)
if not boot_to_gameplay() then print("BOOT FAIL"); client.exit(); return end
if TAG == "uw" then
    if not enter_dungeon() then LOG("!!! UW NOT REACHED !!!") end
    LOG(string.format("post-dungeon scene=%d room=$%02X", scene_guess(), read_room()))
end
LOG(string.format("post-boot scene=%d vsram0=$%04X", scene_guess(), vsram0()))
client.screenshot(OUT .. "\\00_pre.png")

-- Open subscreen: bare Start.
press_for({["P1 Start"]=true}, 4)
-- Log scroll-in until VSRAM settles (stable ≥ 20 frames).
log_ladder("scroll_open.csv", 90, function(_, stable) return stable >= 20 end)

idle(10)
client.screenshot(OUT .. "\\01_active.png")
capture("active.bin")

-- Blink: two bundles 8 frames apart (Genesis cursor pal toggles every 8
-- frames of s_cursor_frame). The differ checks the cursor SAT palette.
capture("blink0.bin")
idle(8)
capture("blink1.bin")

-- state.txt — record located scene + pause cells for triage.
do
    local f = io.open(OUT .. "\\state.txt", "w")
    f:write(string.format("TAG=%s\n", TAG))
    f:write(string.format("scene(lo $0284)=%d  hi $0281=%d\n", r8(OFF_SCENE_LO), r8(OFF_SCENE_HI)))
    f:write(string.format("in_gameplay $0274=%d\n", r8(OFF_IN_GAMEPLAY)))
    f:write(string.format("VSRAM0=$%04X (active)\n", vsram0()))
    f:write(string.format("nes_ram Items $8657=$%02X (expect $FF if unlocked)\n", nes_r8(0x0657)))
    f:write(string.format("nes_ram SelectedB $8656=$%02X\n", nes_r8(0x0656)))
    f:close()
end

-- Close: bare Start, log scroll-out until VSRAM settles back.
press_for({["P1 Start"]=true}, 4)
log_ladder("scroll_close.csv", 90, function(_, stable) return stable >= 20 end)
client.screenshot(OUT .. "\\02_post.png")

print("done: " .. OUT)
client.exit()
