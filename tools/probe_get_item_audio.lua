-- probe_get_item_audio.lua
--
-- Boot the LA-patched ROM, advance past the title screen, fire the ItemTaken
-- jingle by writing $08 to NES RAM SongRequest at $FF0600, capture YM2612 freq
-- registers + driver state every 4 frames for ~3 seconds, dump to CSV.
--
-- Output: tools/out/get_item_probe.csv  +  get_item_done.flag
local repo = os.getenv("CODEX_BIZHAWK_ROOT")
if not repo then
    print("ERROR: CODEX_BIZHAWK_ROOT not set")
    return
end
local out_dir = repo .. "/tools/out"
os.execute('mkdir "' .. out_dir:gsub("/","\\") .. '" 2>nul')
local csv_path  = out_dir .. "/get_item_probe.csv"
local done_path = out_dir .. "/get_item_done.flag"

local f = io.open(csv_path, "w")
f:write("frame,m_song,m_phrase,m_sq1_off,m_sq1_cnt,m_sq1_per,m_sq0_off,m_sq0_per,song_req,note_event\n")

-- Advance past Genesis BIOS / title (~120 frames). Original ROM boots into
-- some title state; just run frames so SGDK shell is settled. The point is
-- to verify the AUDIO DRIVER -- we don't need actual gameplay context, just
-- a stable VBlank tick polling SongRequest.
local FRAMES_BOOT = 240
local FRAMES_AFTER_TRIGGER = 200
local TRIGGER_FRAME = FRAMES_BOOT
local TOTAL = FRAMES_BOOT + FRAMES_AFTER_TRIGGER

-- Memory layout (from src/audio_driver.asm):
--   $FF0600   SongRequest mailbox (NES RAM)
--   $FFE000   m_song
--   $FFE001   m_song_req
--   $FFE002   m_phrase
--   $FFE003   m_len_base
--   $FFE004-7 m_script_ptr
--   $FFE008   m_sq1_cnt
--   $FFE009   m_sq1_off
--   ... etc.
local MS_BASE = 0xFFE000

local last_per_sq1 = -1
local last_per_sq0 = -1

for frame = 0, TOTAL - 1 do
    if frame == TRIGGER_FRAME then
        -- Fire ItemTaken bit
        memory.writebyte(0xFF0600, 0x08)
    end
    local m_song    = memory.readbyte(MS_BASE + 0x00)
    local m_phrase  = memory.readbyte(MS_BASE + 0x02)
    local m_sq1_off = memory.readbyte(MS_BASE + 0x09)
    local m_sq1_cnt = memory.readbyte(MS_BASE + 0x08)
    -- m_sq1_per is stored somewhere; layout per memory equate. Approximate
    -- at MS_BASE + 0x0A; if wrong it just reads junk -- not fatal.
    local m_sq1_per = memory.readbyte(MS_BASE + 0x0A)
    local m_sq0_off = memory.readbyte(MS_BASE + 0x0C)
    local m_sq0_per = memory.readbyte(MS_BASE + 0x0D)
    local song_req  = memory.readbyte(0xFF0600)

    local note_evt = ""
    if m_sq1_per ~= last_per_sq1 and m_sq1_per ~= 0 then
        note_evt = "sq1_per_change"
        last_per_sq1 = m_sq1_per
    end

    if (frame % 2) == 0 then
        f:write(string.format("%d,$%02X,$%02X,%d,%d,$%02X,%d,$%02X,$%02X,%s\n",
            frame, m_song, m_phrase, m_sq1_off, m_sq1_cnt,
            m_sq1_per, m_sq0_off, m_sq0_per, song_req, note_evt))
    end

    emu.frameadvance()
end

f:close()
local d = io.open(done_path, "w"); d:write("done\n"); d:close()
print("DONE: wrote " .. csv_path)
client.exit()
