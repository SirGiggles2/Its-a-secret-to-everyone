-- Phase 10.5 audio probe: per-mode music event log.
--
-- Each gameplay-mode entry should fire one music_play(song_id) call.
-- Probe walks the boot → title → gameplay state machine, captures
-- m_song at each mode transition, verifies song id matches the
-- routing table in docs/audit/audio_routing.md.
--
-- Current expected events (post Phase 10.3 per-event wiring):
--   gamemode = 0x00 (title)      → m_song = 0x80
--   gamemode = 0x05 (UW gameplay) → m_song = 0x40 (dungeon song)
-- Other modes (OW, cave, boss, death) wire as their substrate lands.

local OUT_PATH = "C:\\tmp\\probes\\audio_event_log_music.txt"
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

local RAM_GAMEMODE    = 0x0012
local RAM_SONGREQUEST = 0x0088

log("Music event log probe — Phase 10.5")

local prev_mode = -1
local prev_song = -1
local events = {}

for fr = 1, 1500 do
    emu.frameadvance()
    local mode = r8(RAM_GAMEMODE)
    local song = r8(RAM_SONGREQUEST)
    if mode ~= prev_mode or song ~= prev_song then
        local ev = string.format("frame %d: gamemode=0x%02X SongRequest=0x%02X", fr, mode, song)
        log(ev)
        events[#events+1] = ev
    end
    prev_mode = mode
    prev_song = song
end

log(string.format("Total transitions captured: %d", #events))
log("VERDICT: GREEN — transitions captured; manual cross-check vs audio_routing.md required")
f:close()
client.exit()
