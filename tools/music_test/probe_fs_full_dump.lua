-- probe_fs_full_dump.lua
-- One-shot comprehensive dump for FS MIDI integration.
-- Captures every signal needed to diagnose freeze at FS:
--   * Audio peak before + after Start press (MIDI active vs silence)
--   * Screenshots: title, +1f after Start, +30f, +120f, +600f
--   * Memory state: gamemode, m_song, m_song_req, midi flag, MIDI_STATE block
--   * Plane A nametable head, CRAM, SAT, VRAM tile slice
--   * Frame-by-frame audio peak trace post-Start to catch where music dies

local OUT = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/tools/music_test/out"
os.execute('mkdir "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\tools\\music_test\\out" 2>nul')

local FLAG       = 0xFFE120  -- s_music_midi_active
local NES_GM     = 0xFF0012  -- NES gamemode
local M_SONG     = 0xFFE000  -- audio_driver m_song
local M_SONG_REQ = 0xFFE001
local MS_PLAY    = 0xFFE140  -- MIDI_STATE.MS_PLAY_PTR (long)
local MS_LOOP    = 0xFFE148  -- MS_LOOP_PTR
local MS_TIME    = 0xFFE14C  -- MS_TIME_NEXT (word)
local MS_END     = 0xFFE14E  -- MS_END_PTR (long)
local NES_PPUCTRL = 0xFF0804

local f = io.open(OUT .. "/full_dump.txt", "w")
local function log(s) f:write(s .. "\n") end

local function audio_peak()
    local ok, samples = pcall(function() return sound and sound.get and sound.get() end)
    if not ok or not samples then return -1 end
    local peak = 0
    for _, s in ipairs(samples) do
        local a = s; if a < 0 then a = -a end
        if a > peak then peak = a end
    end
    return peak
end

local function safe_set(pad)
    local ok = pcall(function() joypad.set(pad or {}, 1) end)
    if not ok then joypad.set(pad or {}) end
end

local function snap(label)
    log(string.format("== %s @frame %d ==", label, emu.framecount()))
    log(string.format("  gamemode($FF0012)   = 0x%02X", memory.readbyte(NES_GM,  "M68K BUS")))
    log(string.format("  midi_active($FFE120)= 0x%02X", memory.readbyte(FLAG,    "M68K BUS")))
    log(string.format("  m_song              = 0x%02X", memory.readbyte(M_SONG,  "M68K BUS")))
    log(string.format("  m_song_req          = 0x%02X", memory.readbyte(M_SONG_REQ,"M68K BUS")))
    log(string.format("  ppuctrl             = 0x%02X", memory.readbyte(NES_PPUCTRL,"M68K BUS")))
    log(string.format("  MS_PLAY_PTR         = 0x%08X", memory.read_u32_be(MS_PLAY,"M68K BUS")))
    log(string.format("  MS_LOOP_PTR         = 0x%08X", memory.read_u32_be(MS_LOOP,"M68K BUS")))
    log(string.format("  MS_END_PTR          = 0x%08X", memory.read_u32_be(MS_END, "M68K BUS")))
    log(string.format("  MS_TIME_NEXT        = 0x%04X", memory.read_u16_be(MS_TIME,"M68K BUS")))
    log(string.format("  audio_peak          = %d", audio_peak()))
    log("")
end

local function dump_vdp(label)
    log(string.format("-- VDP @ %s --", label))
    -- Plane A nametable head ($C000-$C03F)
    log("  Plane A first 32 cells:")
    local row = "    "
    for i = 0, 31 do
        local w = memory.read_u16_be(0xC000 + i*2, "VRAM")
        row = row .. string.format("%04X ", w)
        if (i+1) % 8 == 0 then log(row); row = "    " end
    end
    -- CRAM all 64 entries
    log("  CRAM (64 entries x 2 bytes BE):")
    local cram_row = "    "
    for i = 0, 63 do
        local hi = memory.read_u8(i*2,     "CRAM")
        local lo = memory.read_u8(i*2 + 1, "CRAM")
        cram_row = cram_row .. string.format("%02X%02X ", hi, lo)
        if (i+1) % 16 == 0 then log(cram_row); cram_row = "    " end
    end
    -- SAT entry 0 ($F800-$F807)
    log("  SAT entry 0:")
    local sat = "   "
    for i = 0xF800, 0xF807 do sat = sat .. string.format(" %02X", memory.read_u8(i, "VRAM")) end
    log(sat)
    log("")
end

-- Phase 1: Boot + Title
for i = 1, 90 do emu.frameadvance() end
snap("title_initial")
client.screenshot(OUT .. "/dump_title.png")
dump_vdp("title")

-- Phase 2: Start press
log(">>> Pressing Start <<<")
for i = 1, 4 do safe_set({Start = true}); emu.frameadvance() end
safe_set({})

-- Phase 3: Frame-by-frame trace right after Start (catch crash window)
log("Frame-by-frame post-Start trace (10 frames):")
for i = 1, 10 do
    emu.frameadvance()
    log(string.format("  +%df gm=0x%02X flag=0x%02X play=0x%08X time=0x%04X peak=%d",
        i,
        memory.readbyte(NES_GM, "M68K BUS"),
        memory.readbyte(FLAG, "M68K BUS"),
        memory.read_u32_be(MS_PLAY, "M68K BUS"),
        memory.read_u16_be(MS_TIME, "M68K BUS"),
        audio_peak()))
end
client.screenshot(OUT .. "/dump_post_start_10f.png")

-- Phase 4: settle
for i = 1, 60 do emu.frameadvance() end
snap("post_start_70f")
client.screenshot(OUT .. "/dump_post_start_70f.png")
dump_vdp("post_start_70f")

for i = 1, 180 do emu.frameadvance() end
snap("post_start_250f")
client.screenshot(OUT .. "/dump_post_start_250f.png")

-- Phase 5: long settle to see if MS_TIME_NEXT decrements (player advancing)
for i = 1, 600 do emu.frameadvance() end
snap("post_start_850f_4s_audio")

-- Final audio sample over 60 frames (~1 sec of sound)
log("Audio peak trace (60 frames at 850f mark):")
for i = 1, 60 do
    emu.frameadvance()
    if (i-1) % 6 == 0 then
        log(string.format("  +%df peak=%d MS_TIME=0x%04X MS_PLAY=0x%08X",
            i, audio_peak(),
            memory.read_u16_be(MS_TIME, "M68K BUS"),
            memory.read_u32_be(MS_PLAY, "M68K BUS")))
    end
end

snap("final")
f:close()
client.exit()
