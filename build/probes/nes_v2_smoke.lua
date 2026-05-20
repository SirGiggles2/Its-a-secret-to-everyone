-- NES V2 smoke test: cycle view pages 0..3 and screenshot.
local OUT = (os.getenv("CODEX_BIZHAWK_ROOT") or "C:\\tmp") .. "/v2_smoke"
os.execute('mkdir "' .. OUT:gsub("/","\\") .. '" 2>nul')

local function idle(n) for _=1,n do emu.frameadvance() end end
local function poke(addr, v) memory.write_u8(addr, v, "System Bus") end

idle(60)

for page = 0, 3 do
  poke(0x0010, 1)        -- bank 1 = OW (has both Common SPR + OW BG content)
  poke(0x0011, 0)        -- sub_pal 0
  poke(0x0015, page)     -- view page
  poke(0x0016, 0)        -- 8x16 mode 0
  idle(6)
  client.screenshot(OUT .. "/page" .. page .. ".png")
end

print("v2 smoke done")
client.exit()
