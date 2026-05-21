-- probe_audio_diag.lua — verify music_play writes m_song_req $FFE001,
-- whether music_tick consumes it, and xgm_owns_chip state.

local OUT = "C:\\tmp\\audio_diag.txt"
local function nesram(off) return memory.read_u8(0x8000 + off, "68K RAM") end
local function dvr(off)    return memory.read_u8(off, "68K RAM") end  -- direct 68K offset

local function press(buttons, frames)
  for i = 1, frames do joypad.set(buttons, 1); emu.frameadvance() end
end
local function idle(n) for i = 1, n do emu.frameadvance() end end

local function snap(label, trace)
  trace[#trace+1] = string.format(
    "%-25s m_song_req=$%02X m_song=$%02X xgm_owns=$%02X gm=$%02X scene=??",
    label,
    dvr(0xE001),    -- m_song_req
    dvr(0xE000),    -- m_song (current)
    dvr(0xE02C),    -- xgm_owns_chip (per audio_adapter.c:31)
    nesram(0x0012)  -- gamemode
  )
end

local trace = {}
idle(60); snap("boot+60",          trace)
idle(60); snap("boot+120 (title)", trace)
-- Pre-chord music_play(0x80) called in debug_main_after_a4. Should fire title song.
press({A=true, B=true, C=true}, 8); idle(8); snap("post-chord", trace)
idle(60);  snap("post-chord+60",  trace)
idle(120); snap("post-chord+180", trace)
idle(120); snap("post-chord+300", trace)

local f = io.open(OUT, "w")
f:write("audio diag — " .. os.date() .. "\n")
f:write("=============================================================\n\n")
for _, l in ipairs(trace) do f:write(l .. "\n") end
f:write("\n")
f:write("Expected: m_song_req goes nonzero after music_play (boot title $80,\n")
f:write("          post-chord dungeon $40). music_tick clears it after consume.\n")
f:write("          xgm_owns_chip should stay $00 (revert state per audio_adapter.c).\n")
f:close()
print("Wrote " .. OUT)
