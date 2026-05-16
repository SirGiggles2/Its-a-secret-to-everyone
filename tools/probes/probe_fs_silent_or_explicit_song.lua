-- Phase 10.5 audio probe: FS routing parity.
--
-- Per docs/audit/audio_routing.md, file-select audio is keyed off
-- gamemode == 0x01, NOT off title bitmap. Pre-pivot bug
-- (memory project_fs_no_song_change): InitMode1 doesn't write
-- SongRequest so title song bleeds through FS.
--
-- Probe: boot Debug.md, advance to title, press Start, wait for FS
-- entry, capture SongRequest (NES $88 mirror). Assert: FS song id
-- (silence $00 per current routing) or explicit FS song; NEVER the
-- title id $80.

local OUT_PATH = "C:\\tmp\\probes\\fs_silent_or_explicit_song.txt"

local function domain_exists(name)
    for _, d in ipairs(memory.getmemorydomainlist()) do
        if d == name then return true end
    end
    return false
end

local RAM_DOMAIN = "M68K BUS"
local CELL_BASE = 0x00FF0000
if domain_exists("68K RAM") then
    RAM_DOMAIN = "68K RAM"; CELL_BASE = 0x0000
elseif domain_exists("M68K RAM") then
    RAM_DOMAIN = "M68K RAM"; CELL_BASE = 0x0000
end

local function r8(addr)
    memory.usememorydomain(RAM_DOMAIN)
    return memory.read_u8(CELL_BASE + addr)
end

-- Debug.md A4 = $FF8000 per platform_abi.h:11. NES cell -> +$8000.
-- NES Variables.inc:
--   gamemode      := $12   (M68K $FF8012, 68K RAM offset $8012)
-- audio_driver.asm:
--   m_song equ MUSIC_BASE+$00, MUSIC_BASE=$FFE000 -> 68K RAM offset $E000
local RAM_GAMEMODE      = 0x8012
local RAM_SONGREQUEST   = 0xE000  -- m_song direct (absolute, no +$8000)

os.execute('if not exist "C:\\tmp\\probes" mkdir "C:\\tmp\\probes"')

local f = assert(io.open(OUT_PATH, "w"))
local function log(s) f:write(s .. "\n"); print(s) end

log("FS routing probe — Phase 10.5")
log(string.format("RAM domain: %s, base 0x%X", RAM_DOMAIN, CELL_BASE))

-- Phase 1: cold boot 200 frames (title settled).
for _ = 1, 200 do emu.frameadvance() end
local title_song = r8(RAM_SONGREQUEST)
local title_mode = r8(RAM_GAMEMODE)
log(string.format("frame %d title: gamemode=0x%02X SongRequest=0x%02X",
    emu.framecount(), title_mode, title_song))

-- Phase 2: press Start to advance to FS.
-- Genplus-gx Genesis button name is "Start" (CamelCase), NOT "P1 Start".
joypad.set({Start = true})
emu.frameadvance()
joypad.set({})

-- Phase 3: wait up to 200 frames for gamemode = $01 (FileSelect).
local fs_seen = false
for _ = 1, 300 do
    emu.frameadvance()
    if r8(RAM_GAMEMODE) == 0x01 then fs_seen = true; break end
end

local fs_song = r8(RAM_SONGREQUEST)
local fs_mode = r8(RAM_GAMEMODE)
log(string.format("frame %d fs: gamemode=0x%02X SongRequest=0x%02X fs_seen=%s",
    emu.framecount(), fs_mode, fs_song, tostring(fs_seen)))

-- Phase 4: verdict.
-- Routing table per audio_routing.md: FS = silence $00 OR explicit
-- FS song id. NEVER title $80.
local verdict
if fs_song == 0x80 then
    verdict = "RED — title song bleeds through FS (project_fs_no_song_change regression)"
elseif fs_seen then
    verdict = "GREEN — FS routing per table"
else
    verdict = "RED — gamemode never reached FS within 500 frames"
end
log("VERDICT: " .. verdict)
f:close()
client.exit()
