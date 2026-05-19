-- chr_viewer_smoke.lua — boot custom NES test ROM, idle 120 frames,
-- screenshot + dump nametable + dump CHR. Confirms ROM doesn't crash
-- and renders SOMETHING.

local OUT = os.getenv("CODEX_BIZHAWK_ROOT") or "C:\\tmp"
local DIR = OUT .. "/chr_viewer_smoke"
os.execute('mkdir "' .. DIR:gsub("/","\\") .. '" 2>nul')

local function idle(n) for _=1,n do emu.frameadvance() end end

idle(120)
client.screenshot(DIR .. "/post_boot.png")

-- Dump CIRAM (active nametable) — 2 KB
do
  local chunks = {}
  for i = 0, 2047 do chunks[#chunks+1] = string.char(memory.read_u8(i, "CIRAM (nametables)")) end
  local f = io.open(DIR .. "/nt.bin", "wb"); f:write(table.concat(chunks)); f:close()
end

-- Dump CHR page 0 (8 KB)
do
  local chunks = {}
  for i = 0, 8191 do chunks[#chunks+1] = string.char(memory.read_u8(i, "CHR")) end
  local f = io.open(DIR .. "/chr_page0.bin", "wb"); f:write(table.concat(chunks)); f:close()
end

-- Dump PALRAM (32 B)
do
  local chunks = {}
  for i = 0, 31 do chunks[#chunks+1] = string.char(memory.read_u8(i, "PALRAM")) end
  local f = io.open(DIR .. "/palram.bin", "wb"); f:write(table.concat(chunks)); f:close()
end

-- State diagnostic — try multiple domains to find main NES CPU RAM
local f = io.open(DIR .. "/state.txt", "w")
f:write(string.format("frame=%d\n", emu.framecount()))
f:write("Domain list:\n")
for _, d in ipairs(memory.getmemorydomainlist()) do
  f:write("  " .. d .. "\n")
end
local function try(domain)
  local ok, v0 = pcall(function() return memory.read_u8(0x10, domain) end)
  local ok2, v4 = pcall(function() return memory.read_u8(0x14, domain) end)
  if ok and ok2 then
    f:write(string.format("  domain '%s' [$10]=$%02X [$14]=$%02X\n", domain, v0, v4))
  end
end
f:write("Reading $10/$14 across domains:\n")
for _, d in ipairs(memory.getmemorydomainlist()) do try(d) end
f:close()

print("smoke test done")
client.exit()
