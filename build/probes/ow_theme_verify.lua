-- ow_theme_verify.lua — verify XGM-driver OW theme dispatch.
--
-- Path: boot -> 30-frame A+B+C chord (enters debug gameplay) ->
--       poke scene=OW (0) + room -> let audio_dispatch_tick fire ->
--       check $FFE02C (xgm_owns_chip) flips to 1.
--
-- Output: C:\tmp\ow_theme_verify.txt + .png

local function R(o)   return memory.read_u8(o, "68K RAM") end
local function W(o,v) memory.write_u8(o, v, "68K RAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end

local OUT_TXT = "C:\\tmp\\ow_theme_verify.txt"
local OUT_PNG = "C:\\tmp\\ow_theme_verify.png"
local f = io.open(OUT_TXT, "w")
local function logf(fmt, ...) f:write(string.format(fmt, ...) .. "\n"); f:flush() end

-- $FF-prefixed M68K addresses map to 68K RAM domain at low 16 bits.
local M_SONG       = 0xE000  -- $FFE000
local M_SONG_REQ   = 0xE001  -- $FFE001
local XGM_OWNS     = 0xE02C  -- $FFE02C (our new flag)
local NES_GM       = 0x0012  -- $FF0012
local NES_SCENE    = 0x7204  -- per music_state_audit pattern
local NES_ROOM     = 0x7205
local TP_REG_0     = 0x73F8
local TP_REG_1     = 0x73F9
local TP_REG_2     = 0x73FA
local SONG_REQ_BR  = 0x0600  -- $FF0600 NES SongRequest bridge

logf("=== ow_theme_verify ===")
logf("rom: %s", gameinfo.getromname())

idle(60)
logf("[01 pre-boot]")
logf("  gm=$%02X  m_song=$%02X  xgm_owns=$%02X",
     R(NES_GM), R(M_SONG), R(XGM_OWNS))

-- A+B+C chord enters debug gameplay runtime
for _=1,30 do joypad.set({A=true,B=true,C=true}, 1); emu.frameadvance() end

-- Teleport regs (per music_state_audit pattern). Scene=OW(0) implied.
W(TP_REG_0, 0x52); W(TP_REG_1, 0x50); W(TP_REG_2, 0x00)
idle(60)

logf("[02 post-chord]")
logf("  gm=$%02X  scene=%d  room=$%02X  m_song=$%02X  xgm_owns=$%02X",
     R(NES_GM), R(NES_SCENE), R(NES_ROOM), R(M_SONG), R(XGM_OWNS))

-- 300-frame trace: watch xgm_owns_chip transitions
logf("--- 300-frame trace ---")
local prev_owns = -1
local prev_song = -1
local prev_gm   = -1
for fr = 1, 300 do
  emu.frameadvance()
  local owns = R(XGM_OWNS)
  local song = R(M_SONG)
  local gm   = R(NES_GM)
  if owns ~= prev_owns or song ~= prev_song or gm ~= prev_gm then
    logf("  f%3d  gm=$%02X  m_song=$%02X  xgm_owns=$%02X", fr, gm, song, owns)
    prev_owns = owns; prev_song = song; prev_gm = gm
  end
end

-- Final state
logf("[03 final]")
logf("  gm=$%02X  scene=%d  room=$%02X", R(NES_GM), R(NES_SCENE), R(NES_ROOM))
logf("  m_song=$%02X  song_req=$%02X  xgm_owns=$%02X",
     R(M_SONG), R(SONG_REQ_BR), R(XGM_OWNS))

-- Check Z80 RAM for XGM state if domain available
for _, d in ipairs(memory.getmemorydomainlist()) do
  if d == "Z80 RAM" then
    -- XGM v1 sets command word at Z80 $0100 region — observe.
    logf("Z80 status bytes [$0100..$0110]:")
    local s = ""
    for off = 0x0100, 0x0110 do
      s = s .. string.format("%02X ", memory.read_u8(off, "Z80 RAM"))
    end
    logf("  %s", s)
    break
  end
end

client.screenshot(OUT_PNG)
logf("screenshot: %s", OUT_PNG)
f:close()
idle(10)
client.exit()
