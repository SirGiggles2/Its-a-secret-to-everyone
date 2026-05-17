-- list memory domains in BizHawk Genesis core
local f = io.open("C:\\tmp\\audio_domains.txt", "w")
for _, d in ipairs(memory.getmemorydomainlist()) do
  f:write(d .. " size=" .. tostring(memory.getmemorydomainsize(d)) .. "\n")
end
f:close()
client.exit()
