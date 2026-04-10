-- music_probe.lua
-- Watches the native M68K music player state at $FF0B00 and logs every change.
-- Also displays current state on-screen each frame so we can see what the
-- player is doing during the title/intro sequence.
--
-- State layout (see audio_driver.asm):
--   $FF0B00 m_song
--   $FF0B01 m_song_req
--   $FF0B02 m_phrase
--   $FF0B03 m_len_base
--   $FF0B04 m_env_sel
--   $FF0B08 m_script_ptr (4 bytes)
--   $FF0B0C m_sq1_off/cnt/len/vib/per

local MUSIC_BASE = 0xFF0B00

local last = {}
local frame = 0

local function rb(addr)
    return memory.read_u8(addr, "68K RAM")
end

local function rl(addr)
    return memory.read_u32_be(addr, "68K RAM")
end

local function snapshot()
    return {
        song     = rb(MUSIC_BASE + 0x00),
        song_req = rb(MUSIC_BASE + 0x01),
        phrase   = rb(MUSIC_BASE + 0x02),
        len_base = rb(MUSIC_BASE + 0x03),
        env_sel  = rb(MUSIC_BASE + 0x04),
        script   = rl(MUSIC_BASE + 0x08),
        sq1_off  = rb(MUSIC_BASE + 0x0C),
        sq0_off  = rb(MUSIC_BASE + 0x14),
        trg_off  = rb(MUSIC_BASE + 0x1C),
    }
end

local function log(msg)
    print(string.format("[f=%06d] %s", frame, msg))
end

local s = snapshot()
log(string.format("INIT song=%02X req=%02X phrase=%02X script=%08X",
    s.song, s.song_req, s.phrase, s.script))

while true do
    frame = frame + 1
    local cur = snapshot()

    -- Detect any state field change
    for k, v in pairs(cur) do
        if last[k] ~= v then
            if last[k] ~= nil then
                log(string.format("%-8s %02X -> %02X", k, last[k], v))
            end
            last[k] = v
        end
    end

    -- On-screen HUD
    gui.text(4, 4, string.format("SONG:%02X PHR:%02X",
        cur.song, cur.phrase), "white", "black", "bottomleft")
    gui.text(4, 14, string.format("LB:%02X ENV:%02X SCR:%08X",
        cur.len_base, cur.env_sel, cur.script), "white", "black", "bottomleft")
    gui.text(4, 24, string.format("S1:%02X S0:%02X TR:%02X",
        cur.sq1_off, cur.sq0_off, cur.trg_off), "white", "black", "bottomleft")

    emu.frameadvance()
end
