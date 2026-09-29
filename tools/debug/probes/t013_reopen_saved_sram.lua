-- T-013: run in a NEW isolated BizHawk process against the prior save run's
-- private profile. Read cart SRAM after boot to prove close/reopen persistence.
local OUT = 'C:/tmp/t013_reopen_saved_sram'
local ok, err = pcall(function()
    for _=1,90 do emu.frameadvance() end
    local domains={}
    for _, name in ipairs(memory.getmemorydomainlist()) do domains[name]=true end
    assert(domains['SRAM'], 'Genesis SRAM domain unavailable')
    local f=assert(io.open(OUT..'.bin','wb'))
    for i=0,0xA5F do f:write(string.char(memory.read_u8(i,'SRAM'))) end
    f:close()
    local state=assert(io.open(OUT..'.txt','w'))
    state:write(string.format('frames=90 SRAM bytes=%d header=%02X,%02X,%02X,%02X\n',
        0xA60, memory.read_u8(1,'SRAM'), memory.read_u8(3,'SRAM'),
        memory.read_u8(5,'SRAM'), memory.read_u8(7,'SRAM')))
    state:close()
end)
if not ok then
    local f=assert(io.open(OUT..'.error.txt','w'))
    f:write(tostring(err));f:close()
end
client.exit()
