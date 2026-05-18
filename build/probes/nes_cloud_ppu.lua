-- nes_cloud_ppu.lua — dump NES PPU tile $70/$71/$72/$73/$74/$75 raw
-- bytes via various memory domains. We need to know the actual pixel
-- data NES uses for cloud rendering.

local function R(o) return memory.read_u8(o, "RAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end
local function tap(btn) joypad.set({[btn]=true},1); emu.frameadvance(); joypad.set({},1); emu.frameadvance() end

idle(120)
tap("Start"); idle(30)
tap("Start"); idle(60)
tap("Down"); tap("Down"); tap("Down"); tap("Start"); idle(60)
for _=1,8 do tap("Down") end; tap("Start"); idle(60)
tap("Up"); tap("Up"); tap("Up"); tap("Up"); tap("Up"); tap("Up"); idle(30)
tap("Start"); idle(120)
for fr=1,400 do
  joypad.set({Up=true},1); emu.frameadvance()
  if R(0x00EB) == 0x67 then break end
end
joypad.set({},1)
idle(102)  -- wait for cloud frames

local f = io.open("C:\\tmp\\nes_cloud_ppu.txt", "w")

-- List available domains
f:write("=== Available memory domains ===\n")
for _, d in ipairs(memory.getmemorydomainlist()) do
  f:write("  " .. d .. "\n")
end

-- Try PPU access via different domain names
local domains = {"PPU Bus", "CHR VROM", "VRAM", "CHR", "CIRAM"}
for _, dom in ipairs(domains) do
  local ok, err = pcall(function()
    f:write(string.format("\n=== Domain '%s' tile $70 (raw 16 bytes) ===\n", dom))
    local s = ""
    for i=0,15 do
      s = s .. string.format("%02X ", memory.read_u8(0x700 + i, dom))
    end
    f:write("  " .. s .. "\n")
  end)
  if not ok then f:write("  ERROR: " .. tostring(err) .. "\n") end
end

f:close()
client.exit()
