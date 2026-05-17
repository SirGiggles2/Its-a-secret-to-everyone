-- Plan v5b T5.6 audio probe: verify audio_dispatch fires UW song on
-- debug-enter (A+B+C chord). Direct end-to-end test of the T5.5
-- gamemode-keyed dispatcher AFTER the line-1868 order fix:
--   gamemode-restore ($CD->$05) MUST run before audio_dispatch_tick.
--
-- Without the fix, dispatch sees $CD every frame -> default branch ->
-- never fires UW song. With the fix, dispatch sees $05 once after
-- restore -> resolves SONG_UW ($40) -> music_play() fires.

local OUT_PATH = "C:\\tmp\\probes\\audio_dispatch_uw.txt"
os.execute('if not exist "C:\\tmp\\probes" mkdir "C:\\tmp\\probes"')

local f = assert(io.open(OUT_PATH, "w"))
local function log(s) f:write(s .. "\n"); print(s) end

local function domain_exists(name)
    for _, d in ipairs(memory.getmemorydomainlist()) do
        if d == name then return true end
    end
    return false
end

local RAM_DOMAIN = "M68K BUS"
local CELL_BASE = 0x00FF0000
if domain_exists("68K RAM") then RAM_DOMAIN = "68K RAM"; CELL_BASE = 0x0000 end

local function r8(addr)
    memory.usememorydomain(RAM_DOMAIN)
    return memory.read_u8(CELL_BASE + addr)
end

local RAM_GAMEMODE      = 0x8012
local RAM_M_SONG        = 0xE000
local RAM_TITLE_PHASE   = 0x87F0   -- $07F0 — probe-state phase counter

log("audio_dispatch UW probe — plan v5b T5.6")

-- Wait for title_phase == 1 (title ready); cap 240 frames.
local title_ready = false
for fr = 1, 240 do
    emu.frameadvance()
    if r8(RAM_TITLE_PHASE) == 1 then title_ready = true; break end
end
log(string.format("title_ready=%s phase=0x%02X frame=%d",
    tostring(title_ready), r8(RAM_TITLE_PHASE), emu.framecount()))

local boot_song = r8(RAM_M_SONG)
local boot_mode = r8(RAM_GAMEMODE)
log(string.format("boot: gamemode=0x%02X m_song=0x%02X", boot_mode, boot_song))

-- Hold A+B+C chord for 8 frames; release 4 (per ph5_uw_t52 pattern).
for _ = 1, 8 do
    joypad.set({ ["P1 A"] = true, ["P1 B"] = true, ["P1 C"] = true }, 1)
    emu.frameadvance()
end
joypad.set({}, 1)
for _ = 1, 4 do emu.frameadvance() end

-- Settle 180 frames; debug-enter -> gamemode $05 -> audio_dispatch
-- edge-fires SONG_UW = $40.
for _ = 1, 180 do emu.frameadvance() end

local post_song = r8(RAM_M_SONG)
local post_mode = r8(RAM_GAMEMODE)
log(string.format("post-chord: gamemode=0x%02X m_song=0x%02X", post_mode, post_song))

local verdict
if post_song == 0x40 then
    verdict = "GREEN — audio_dispatch fired SONG_UW ($40) after debug-enter"
elseif post_song == 0x80 then
    verdict = "RED — title song still playing; UW dispatch never fired"
else
    verdict = string.format("RED — unexpected m_song 0x%02X", post_song)
end
log("VERDICT: " .. verdict)
f:close()
client.exit()
