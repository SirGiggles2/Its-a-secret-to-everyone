-- T5.0.x diagnostic v2 — log EVERY frame state 1..100 (no transition gate)
-- Goal: pin exactly when music_play(0x80) reaches m_song, and when $01 enters.

local OUT_PATH = "C:\\tmp\\probes\\audio_deep_trace_v2.txt"
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
local RAM_M_PHRASE   = 0xE002  -- audio_driver m_phrase (next slot after m_song_req)
local RAM_TUNE0      = 0x0604  -- silence req shadow
local RAM_TUNE1      = 0x0602  -- silence req shadow

log("Deep audio trace v2 — full per-frame, no gate")
log("fr | gm | $604 | $602 | $600 | m_song | m_req | m_phrase")

for fr = 1, 120 do
    emu.frameadvance()
    log(string.format("fr=%3d gm=%02X $604=%02X $602=%02X $600=%02X m_song=%02X m_req=%02X m_phrase=%02X",
        fr,
        r8(RAM_GM),
        r8(RAM_TUNE0),
        r8(RAM_TUNE1),
        r8(RAM_SONGREQ),
        r8(RAM_M_SONG),
        r8(RAM_M_SONG_REQ),
        r8(RAM_M_PHRASE)))
end

log("DONE")
f:close()
client.exit()
