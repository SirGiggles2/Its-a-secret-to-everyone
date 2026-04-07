local list = memory.getmemorydomainlist()
for i, name in ipairs(list) do
  print(name)
end
client.exit()
