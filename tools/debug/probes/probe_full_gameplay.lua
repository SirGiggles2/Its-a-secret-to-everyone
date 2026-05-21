-- probe_full_gameplay.lua — post-chord comprehensive state dump.
-- A+B+C chord -> 300 frames -> dump correct collision buffer ($6530+),
-- audio/sfx cells, link state, enemy slots, walk a bit, capture again.
-- Debug.md A4=$FF8000; nesram = 0x8000+off in 68K RAM domain.

local OUT = "C:\\tmp\\full_gameplay_report.txt"
local SHOT_DIR = "C:\\tmp\\full_gp\\"
os.execute("mkdir " .. SHOT_DIR .. " 2>NUL")

local function nesram(off) return memory.read_u8(0x8000 + off, "68K RAM") end
local function press(buttons, frames)
  for i = 1, frames do joypad.set(buttons, 1); emu.frameadvance() end
end
local function idle(frames)
  for i = 1, frames do emu.frameadvance() end
end

-- Sample collision tile buffer at NES $6530 + col*$16 (16 cols x 22 rows)
local function dump_collision_buf()
  local lines = {}
  for col = 0, 15 do
    local base = 0x6530 + col * 0x16
    local row_str = string.format("col%02d $%04X:", col, base)
    for row = 0, 21 do
      row_str = row_str .. string.format(" %02X", nesram(base + row))
    end
    lines[#lines+1] = row_str
  end
  return lines
end

local function dump_link_state()
  return {
    string.format("$0010 CurLevel    = $%02X", nesram(0x0010)),
    string.format("$0012 GameMode    = $%02X", nesram(0x0012)),
    string.format("$0013 GameSubmode = $%02X", nesram(0x0013)),
    string.format("$0015 FrameCnt    = $%02X", nesram(0x0015)),
    string.format("$0026 StunCycle   = $%02X", nesram(0x0026)),
    string.format("$0070 ObjX[0]     = $%02X", nesram(0x0070)),
    string.format("$0084 ObjY[0]     = $%02X", nesram(0x0084)),
    string.format("$008C ObjDir[0]   = $%02X", nesram(0x008C)),
    string.format("$00EB CurRoomId   = $%02X", nesram(0x00EB)),
    string.format("$00F8 BtnsPressed = $%02X", nesram(0x00F8)),
    string.format("$00FA BtnsDown    = $%02X", nesram(0x00FA)),
    string.format("$066F Hearts      = $%02X", nesram(0x066F)),
    string.format("$0670 HeartPart   = $%02X", nesram(0x0670)),
  }
end

local function dump_enemy_slots()
  -- 11 active slots: ObjType $034F+slot, ObjState $00AC+slot, ObjX $0071+slot, ObjY $0085+slot
  local lines = {}
  for slot = 1, 11 do
    local t  = nesram(0x034F + slot)
    local s  = nesram(0x00AC + slot)
    local x  = nesram(0x0070 + slot)
    local y  = nesram(0x0084 + slot)
    local hp = nesram(0x04F0 + slot)
    lines[#lines+1] = string.format("slot%02d type=$%02X st=$%02X x=$%02X y=$%02X hp=$%02X",
      slot, t, s, x, y, hp)
  end
  return lines
end

local function dump_audio_cells()
  -- music_play writes SongRequest somewhere; tick FluteTimer at $003C..
  -- Audio dispatcher state: scan candidate range
  return {
    string.format("$0600 SfxPrimary  = $%02X", nesram(0x0600)),
    string.format("$0608 SongRequest = $%02X", nesram(0x0608)),
    string.format("$0609 SongBitmap  = $%02X", nesram(0x0609)),
    string.format("$063A LowHealth   = $%02X", nesram(0x063A)),
    string.format("$063C FluteState  = $%02X", nesram(0x063C)),
  }
end

-- Boot settle
idle(120)
client.screenshot(SHOT_DIR .. "01_title.png")

-- A+B+C chord
press({A=true, B=true, C=true}, 8)
idle(8)
client.screenshot(SHOT_DIR .. "02_post_chord.png")

-- Settle gameplay
idle(120)
client.screenshot(SHOT_DIR .. "03_gameplay_stable.png")

-- Snapshot 1: stable in starting room
local snap1_link = dump_link_state()
local snap1_coll = dump_collision_buf()
local snap1_enemy = dump_enemy_slots()
local snap1_audio = dump_audio_cells()

-- Walk Right 90 frames
press({Right=true}, 90)
idle(20)
client.screenshot(SHOT_DIR .. "04_after_right.png")

-- Snapshot 2: after move
local snap2_link = dump_link_state()

-- Swing sword (A)
press({A=true}, 4)
idle(30)
client.screenshot(SHOT_DIR .. "05_after_sword.png")
local snap3_link = dump_link_state()
local snap3_enemy = dump_enemy_slots()

-- Walk Up to find scroll/room transition
press({Up=true}, 120)
idle(60)
client.screenshot(SHOT_DIR .. "06_after_up_120.png")
local snap4_link = dump_link_state()
local snap4_coll = dump_collision_buf()

local f = io.open(OUT, "w")
f:write("probe_full_gameplay report — " .. os.date() .. "\n")
f:write("===========================================================\n\n")

f:write("== SNAP 1: after chord + 120f settle ==\n")
for _, l in ipairs(snap1_link) do f:write("  " .. l .. "\n") end
f:write("\n")

f:write("Collision tile buffer $6530+ (16 cols x 22 rows):\n")
for _, l in ipairs(snap1_coll) do f:write("  " .. l .. "\n") end
f:write("\n")

f:write("Enemy slots 1..11:\n")
for _, l in ipairs(snap1_enemy) do f:write("  " .. l .. "\n") end
f:write("\n")

f:write("Audio cells:\n")
for _, l in ipairs(snap1_audio) do f:write("  " .. l .. "\n") end
f:write("\n")

f:write("== SNAP 2: after Right x90 ==\n")
for _, l in ipairs(snap2_link) do f:write("  " .. l .. "\n") end
f:write("\n")

f:write("== SNAP 3: after sword (A) ==\n")
for _, l in ipairs(snap3_link) do f:write("  " .. l .. "\n") end
f:write("Enemy slots after sword:\n")
for _, l in ipairs(snap3_enemy) do f:write("  " .. l .. "\n") end
f:write("\n")

f:write("== SNAP 4: after Up x120 ==\n")
for _, l in ipairs(snap4_link) do f:write("  " .. l .. "\n") end
f:write("\n")

f:write("Collision buffer after Up x120 (verify scroll repopulated):\n")
for _, l in ipairs(snap4_coll) do f:write("  " .. l .. "\n") end
f:write("\n")

-- Quick verdicts
local nonzero_coll = 0
for col = 0, 15 do
  for row = 0, 21 do
    if nesram(0x6530 + col*0x16 + row) ~= 0 then nonzero_coll = nonzero_coll + 1 end
  end
end
f:write(string.format("VERDICT collision: %d / 352 non-zero tiles ($6530+ buffer)\n", nonzero_coll))

local snap1_gm = nesram(0x0012)
f:write(string.format("VERDICT gamemode: $%02X (expect $05 Mode 5 Play)\n", snap1_gm))

f:close()
print("Wrote " .. OUT)
