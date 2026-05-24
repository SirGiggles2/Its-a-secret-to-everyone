-- v6-A iter: read $FF6BBC (BossRoomId) live after each L# entry warp.
-- Then warp to discovered boss room + capture screenshot.

local NES_BASE = 0x8000
local function R(o)   return memory.read_u8(NES_BASE + o, "68K RAM") end
local function W(o,v) memory.write_u8(NES_BASE + o, v, "68K RAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end
local function safe_set(p)
  local ok = pcall(function() joypad.set(p or {}, 1) end)
  if not ok then joypad.set(p or {}) end
end
local PROBE_CTRL = 0x73F8

-- Boot
for _ = 1, 60 do emu.frameadvance() end
for _ = 1, 30 do
  safe_set({A=true, B=true, C=true,
            ["P1 A"]=true, ["P1 B"]=true, ["P1 C"]=true})
  emu.frameadvance()
end
safe_set({})
for _ = 1, 240 do emu.frameadvance() end

local function warp(level, room)
  W(0x0098, 0x08)
  memory.write_u8(PROBE_CTRL + 0, 0x52, "68K RAM")
  memory.write_u8(PROBE_CTRL + 1, 0x50, "68K RAM")
  memory.write_u8(PROBE_CTRL + 3, 1, "68K RAM")    -- scene=UW
  memory.write_u8(PROBE_CTRL + 4, level, "68K RAM")
  memory.write_u8(PROBE_CTRL + 5, 0, "68K RAM")
  memory.write_u8(PROBE_CTRL + 6, room, "68K RAM")
  memory.write_u8(PROBE_CTRL + 7, 0x5A, "68K RAM")
  for _ = 1, 30 do
    emu.frameadvance()
    if memory.read_u8(PROBE_CTRL + 7, "68K RAM") == 0 then break end
  end
  idle(240)
end

-- L# entry rooms guessed from NES Z1 maps (no $6BAD reader yet).
-- After warp install_uw runs which populates $6BBC for the level
-- regardless of which room we entered.
local entry_rooms = {
  {lv=1, rm=0x73},
  {lv=2, rm=0x7D},
  {lv=3, rm=0x60},
  {lv=4, rm=0x45},
  {lv=5, rm=0x55},
  {lv=6, rm=0x68},
  {lv=7, rm=0x12},
  {lv=8, rm=0x10},
  {lv=9, rm=0x71},
}

local out = io.open("C:/tmp/gen_real_bosses.txt", "w")
out:write("# Level | StartRoomId($6BAD) | TriforceRoomId($6BAE) | BossRoomId($6BBC)\n")

local discovered = {}
for _, e in ipairs(entry_rooms) do
  warp(e.lv, e.rm)
  local start_room = R(0x6BAD)
  local triforce_room = R(0x6BAE)
  local boss_room = R(0x6BBC)
  out:write(string.format("L%d | $%02X | $%02X | $%02X\n",
    e.lv, start_room, triforce_room, boss_room))
  discovered[e.lv] = {start=start_room, triforce=triforce_room, boss=boss_room}
end
out:flush()

-- Now warp to each discovered boss room + screenshot
out:write("\n# Boss room captures:\n")
for lv, info in pairs(discovered) do
  if info.boss ~= 0 and info.boss < 0x80 then
    warp(lv, info.boss)
    local snap = string.format("C:/tmp/gen_real_L%d_boss_r%02X", lv, info.boss)
    out:write(string.format("\n=== L%d boss r$%02X (actual lv=$%02X rm=$%02X) ===\n",
      lv, info.boss, R(0x0010), R(0x00EB)))
    out:write("Slots:\n")
    for s = 1, 19 do
      local t = R(0x034F + s)
      if t ~= 0 then
        out:write(string.format("  s%02d t=$%02X x=$%02X y=$%02X dir=$%02X attr=$%02X hp=$%02X\n",
          s, t, R(0x0070+s), R(0x0084+s), R(0x0098+s),
          R(0x04BF+s), R(0x0485+s)))
      end
    end
    client.screenshot(snap .. ".png")
  end
end

out:close()
client.exit()
