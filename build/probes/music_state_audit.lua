-- music_state_audit.lua — verify music driver state at boot + gameplay.
-- m_song at $FFE000 = 68K RAM domain offset $E000.
-- Sample over 600 emu frames to see what song values get loaded.

local function R(o) return memory.read_u8(o, "68K RAM") end
local function W(o,v) memory.write_u8(o, v, "68K RAM") end
local function R16BE(o) return R(o)*256 + R(o+1) end
local function idle(n) for _=1,n do emu.frameadvance() end end

local OUT = "C:\\tmp\\music_state.txt"
local f = io.open(OUT, "w")

local M_SONG = 0xE000

idle(60)
f:write(string.format("[01 pre-boot]    m_song=$%02X\n", R(M_SONG)))

-- A+B+C chord enters debug mode (forces gameplay scene)
for i=1,30 do joypad.set({A=true,B=true,C=true}, 1); emu.frameadvance() end
W(0x73F8, 0x52); W(0x73F9, 0x50); W(0x73FA, 0x00)
idle(60)
f:write(string.format("[02 post-chord]  m_song=$%02X scene=%d room=$%02X\n",
  R(M_SONG), R(0x7204), R(0x7205)))

-- Sample m_song over 200 frames
local song_changes = {}
local prev_song = R(M_SONG)
song_changes[#song_changes+1] = {0, prev_song}
for i=1,200 do
  emu.frameadvance()
  local cur = R(M_SONG)
  if cur ~= prev_song then
    song_changes[#song_changes+1] = {i, cur}
    prev_song = cur
  end
end
f:write("m_song changes over 200f:\n")
for _,v in ipairs(song_changes) do
  f:write(string.format("  frame %d: m_song=$%02X\n", v[1], v[2]))
end

f:write(string.format("[03 final]       m_song=$%02X\n", R(M_SONG)))

-- Probe XGM Z80 status — the Z80 ID_TABLE is at $1C00 in Z80 space.
-- BizHawk exposes Z80 BUS or Z80 RAM domain.
local has_z80 = false
for _, d in ipairs(memory.getmemorydomainlist()) do
  if d == "Z80 RAM" then has_z80 = true; break end
end
f:write(string.format("Z80 RAM domain available: %s\n", tostring(has_z80)))

f:close()
idle(15)
client.exit()
