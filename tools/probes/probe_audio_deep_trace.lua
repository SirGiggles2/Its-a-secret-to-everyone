-- T5.0.x diagnostic — track all audio state cells per frame
-- to pinpoint where $01 enters m_song.
--
-- Reads:
--   gm at $FF8012 (A4-relative NES RAM)
--   m_song at $FFE000
--   m_song_req at $FFE001
--   m_phrase: search for it later
--   $FF0600 (SongRequest bridge cell, NOT A4-relative)

local OUT_PATH = "C:\\tmp\\probes\\audio_deep_trace.txt"
os.execute('if not exist "C:\\tmp\\probes" mkdir "C:\\tmp\\probes"')

local f = assert(io.open(OUT_PATH, "w"))
local function log(s) f:write(s .. "\n"); print(s) end

local function r8(addr)
    memory.usememorydomain("68K RAM")
    return memory.read_u8(addr)
end

local RAM_GM         = 0x8012  -- nes_ram[$12] = $FF8012
local RAM_SONGREQ    = 0x0600  -- $FF0600 (audio bridge)
local RAM_M_SONG     = 0xE000  -- audio_driver m_song
local RAM_M_SONG_REQ = 0xE001  -- audio_driver m_song_req

log("Deep audio trace — gm/songreq($FF0600)/m_song/m_song_req")
log("frame | gm | $0600 | m_song | m_song_req")

local prev_state = ""
for fr = 1, 200 do
    emu.frameadvance()
    local gm     = r8(RAM_GM)
    local sreq   = r8(RAM_SONGREQ)
    local msong  = r8(RAM_M_SONG)
    local msreq  = r8(RAM_M_SONG_REQ)
    local state  = string.format("%02X-%02X-%02X-%02X", gm, sreq, msong, msreq)
    if state ~= prev_state then
        log(string.format("fr=%3d gm=%02X $0600=%02X m_song=%02X m_song_req=%02X",
            fr, gm, sreq, msong, msreq))
        prev_state = state
    end
end

log("DONE")
f:close()
client.exit()
