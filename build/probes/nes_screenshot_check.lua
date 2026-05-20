-- Just screenshot every 60 frames + dump ROM type info.
local f = io.open("C:/tmp/nes_screenshot_check.txt", "w")

-- Dump available memory domains
f:write("Available memory domains:\n")
for _, d in ipairs(memory.getmemorydomainlist()) do
  f:write("  " .. d .. "\n")
end
f:flush()

for n=1,8 do
  for _=1,60 do emu.frameadvance() end
  client.screenshot(string.format("C:/tmp/nes_check_%02d.png", n))
  f:write(string.format("screenshot %d at frame ~%d\n", n, n*60))
  f:flush()
end
f:close()
client.exit()
