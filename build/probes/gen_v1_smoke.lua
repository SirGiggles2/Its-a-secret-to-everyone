-- Quick V1 smoke test: enter scene, cycle 4 pages, screenshot each.
local OUT = (os.getenv("CODEX_BIZHAWK_ROOT") or "C:\\tmp") .. "/v1_smoke"
os.execute('mkdir "' .. OUT:gsub("/","\\") .. '" 2>nul')

local function idle(n) for _=1,n do emu.frameadvance() end end
local function poke(addr, v) memory.write_u8(addr, v, "M68K BUS") end

idle(240)
-- C+Start chord to enter scene
joypad.set({C=true, Start=true}, 1)
for _=1,8 do emu.frameadvance() end
joypad.set({}, 1)
idle(60)

-- Cycle each page 0..3 via poke + screenshot
for page = 0, 3 do
  poke(0xFF07E0, 0)        -- bank 0
  poke(0xFF07E1, 0)        -- sub_pal 0
  poke(0xFF07E2, page)     -- view page
  poke(0xFF07E3, 0)        -- 8x16 mode 0
  poke(0xFF07E4, 0xAA)     -- trigger
  local timeout = 60
  while memory.read_u8(0xFF07E4, "M68K BUS") ~= 0 and timeout > 0 do
    emu.frameadvance()
    timeout = timeout - 1
  end
  idle(6)
  client.screenshot(OUT .. "/page" .. page .. ".png")
end

print("v1 smoke done")
client.exit()
