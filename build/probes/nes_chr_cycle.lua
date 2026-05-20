-- nes_chr_cycle.lua — drive NES test ROM (chr_viewer_rom.nes) through every
-- (bank, sub_pal, sprite_page, 8x16) state via memory poke + screenshot.
-- Coverage: 8 * 4 * 4 * 2 = 256 states.

local OUT = os.getenv("CODEX_BIZHAWK_ROOT") or "C:\\tmp"
local DIR = OUT .. "/chr_cycle_nes"
os.execute('mkdir "' .. DIR:gsub("/","\\") .. '" 2>nul')

local function idle(n) for _=1,n do emu.frameadvance() end end

-- Boot wait for reset + first NMI cycle
idle(60)

local function poke(addr, v) memory.write_u8(addr, v, "System Bus") end

for bank = 0, 7 do
  for sub_pal = 0, 3 do
    for page = 0, 3 do
      for mode = 0, 1 do
        poke(0x0010, bank)
        poke(0x0011, sub_pal)
        poke(0x0015, page)
        poke(0x0016, mode)
        -- Wait 4 NMI frames for handler to apply bank/subpal/page/8x16
        idle(4)
        local name = string.format("bank%d_sub%d_page%d_8x16%d", bank, sub_pal, page, mode)
        client.screenshot(DIR .. "/" .. name .. ".png")
      end
    end
  end
end

print("nes_chr_cycle done — " .. (8*4*4*2) .. " captures")
client.exit()
