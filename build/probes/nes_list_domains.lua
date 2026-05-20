-- nes_list_domains.lua — dump available memory domain names so we know
-- the exact string to pass to memory.readbyterange for raw CHR ROM.
local OUT = os.getenv("CODEX_BIZHAWK_ROOT") or "C:\\tmp"
local path = OUT .. "/nes_domains.txt"
local f = io.open(path, "w")
local list = memory.getmemorydomainlist()
for i, d in ipairs(list) do
  local sz = memory.getmemorydomainsize(d)
  f:write(string.format("%s\t%d\n", d, sz))
end
f:close()
print("wrote " .. path)
client.exit()
