-- gen_tilegrid_cycle.lua — drive Genesis Debug.md debug_tilegrid scene
-- through every (bank, sub_pal, sprite_page, 8x16) state via memory poke
-- + screenshot.
--
-- Entry: at title press MODE (BUTTON_MODE = 0x0800 bit on 6-button), which
-- jumps into debug_tilegrid_main. Scene polls $FF07E0..$FF07E4 each
-- iteration: write desired state + set $07E4=$AA to trigger apply.
--
-- Coverage: 8 * 4 * 4 * 2 = 256 states.

local OUT = os.getenv("CODEX_BIZHAWK_ROOT") or "C:\\tmp"
local DIR = OUT .. "/chr_cycle_gen"
os.execute('mkdir "' .. DIR:gsub("/","\\") .. '" 2>nul')

local function idle(n) for _=1,n do emu.frameadvance() end end
local function poke(addr, v) memory.write_u8(addr, v, "M68K BUS") end
local function read(addr) return memory.read_u8(addr, "M68K BUS") end

-- Boot wait for title display
idle(240)

-- Press MODE button (6-button extended bit). Try multiple button-name
-- styles since BizHawk gen+ core may vary.
for fr = 1, 24 do
  joypad.set({Mode=true, MODE=true, ["P1 Mode"]=true}, 1)
  emu.frameadvance()
end
joypad.set({}, 1)
idle(60)

-- Verify debug scene entered by sentinel at $FF07E4 = 0 (init cleared it).
-- If $07E4 stays non-zero, MODE press didn't trigger.
local sentinel = read(0xFF07E4)
print(string.format("debug-scene sentinel $FF07E4 = $%02X (expect $00)", sentinel))

-- Cycle every state
for bank = 0, 7 do
  for sub_pal = 0, 3 do
    for page = 0, 3 do
      for mode = 0, 1 do
        poke(0xFF07E0, bank)
        poke(0xFF07E1, sub_pal)
        poke(0xFF07E2, page)
        poke(0xFF07E3, mode)
        poke(0xFF07E4, 0xAA)
        -- Wait up to 60 frames for scene to ack (flag returns to 0).
        local waited = 0
        while read(0xFF07E4) == 0xAA and waited < 60 do
          emu.frameadvance()
          waited = waited + 1
        end
        idle(2)  -- extra settle
        local name = string.format("bank%d_sub%d_page%d_8x16%d", bank, sub_pal, page, mode)
        client.screenshot(DIR .. "/" .. name .. ".png")
      end
    end
  end
end

print("gen_tilegrid_cycle done — " .. (8*4*4*2) .. " captures")
client.exit()
