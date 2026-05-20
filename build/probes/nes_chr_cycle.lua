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
        idle(4)
        local name = string.format("bank%d_sub%d_page%d_8x16%d", bank, sub_pal, page, mode)
        client.screenshot(DIR .. "/" .. name .. ".png")
        -- Byte capture: full 8 KB CHR (sprite $0000-$0FFF + BG $1000-$1FFF).
        -- Read raw CHR ROM at the bank-specific offset (each CNROM page = 8 KB).
        -- "PPU Bus" on NES does not expose the cartridge-mapped CHR window;
        -- "CHR ROM" / "CHR" domain holds all pages linearly, so offset
        -- bank*8192 gives the active page contents.
        local chr_tbl = memory.readbyterange(bank * 8192, 8192, "CHR")
        local chr = {}
        for i = 0, 8191 do chr[i+1] = string.char(chr_tbl[i]) end
        local f = io.open(DIR .. "/" .. name .. ".chr.bin", "wb")
        f:write(table.concat(chr)); f:close()
        -- PALRAM 32 B per state
        local pal_tbl = memory.readbyterange(0, 32, "PALRAM")
        local pal = {}
        for i = 0, 31 do pal[i+1] = string.char(pal_tbl[i]) end
        f = io.open(DIR .. "/" .. name .. ".pal.bin", "wb")
        f:write(table.concat(pal)); f:close()
      end
    end
  end
end

print("nes_chr_cycle done — " .. (8*4*4*2) .. " captures")
client.exit()
