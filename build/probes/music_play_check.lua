-- music_play_check.lua — verify audio dispatch fires + music ticks on gameplay entry.
-- Reads SongRequest ($0600), m_song ($E000), m_phrase ($E002), per-channel counters.
local function R(o) return memory.read_u8(o, "68K RAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end

local MIRROR = 0x8000
local OUT = "C:\\tmp\\music_check.txt"
local f = io.open(OUT, "w")

local function snap(lbl)
  f:write(string.format("%-22s gm=$%02X song_req=$%02X m_song=$%02X m_phrase=$%02X sq0_cnt=$%02X sq1_cnt=$%02X trg_cnt=$%02X room=$%02X\n",
    lbl,
    R(MIRROR+0x0012),  -- nes game_mode
    R(0x0600),          -- SongRequest bridge
    R(0xE000),          -- m_song current
    R(0xE002),          -- m_phrase
    R(0xE015),          -- m_sq0_cnt
    R(0xE00D),          -- m_sq1_cnt
    R(0xE01D),          -- m_trg_cnt
    R(MIRROR+0x00EB)))
end

idle(10)
snap("frame 10 (boot)")
idle(50)
snap("frame 60 (post-boot)")
idle(60)
snap("frame 120 (pre-chord)")

-- A+B+C chord -> gameplay
for i=1,30 do joypad.set({A=true,B=true,C=true},1); emu.frameadvance() end
snap("post-chord 30f")
idle(30)
snap("post-chord 60f")
idle(60)
snap("post-chord 120f")
idle(60)
snap("post-chord 180f")
idle(120)
snap("post-chord 300f")
idle(180)
snap("post-chord 480f")

-- Sample m_sq1_cnt rapidly to see if it advances (note-tick activity)
f:write("\n=== sq1_cnt sample over 60f ===\n")
for i=1,12 do
  local cnt = R(0xE00D)
  local song = R(0xE000)
  f:write(string.format("frame +%02d  m_song=$%02X m_sq1_cnt=$%02X m_sq1_len=$%02X m_sq0_cnt=$%02X\n",
    i*5, song, cnt, R(0xE00E), R(0xE015)))
  idle(5)
end

client.screenshot("C:\\tmp\\music_check.png")
f:close()
gui.text(8,8,"music check done")
idle(10)
client.exit()
