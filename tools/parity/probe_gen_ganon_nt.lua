-- T-004: focused Genesis Ganon room load and Plane A capture.
local OUT = 'C:/tmp/t004_gen_ganon'
local function r(a) return memory.read_u8(a,'68K RAM') end
local function w(a,v) memory.write_u8(a,v,'68K RAM') end
local function tick()
    joypad.set({},1)
    emu.frameadvance()
end
local function arm()
    w(0x73F8,0x52); w(0x73F9,0x50); w(0x73FA,1)
end
local ok,err=pcall(function()
    client.speedmode(400)
    for _=1,30 do tick() end
    local entered=false
    for i=1,1500 do
        arm()
        joypad.set(i%30<4 and {A=true,B=true,C=true} or {},1)
        emu.frameadvance()
        if r(0x7200)==0x57 and r(0x7201)==0x50 and r(0x7203)>5 then
            entered=true; break
        end
    end
    assert(entered,'debug gameplay mirror not reached')
    arm()
    w(0x73FB,1); w(0x73FC,9); w(0x73FD,1); w(0x73FE,0x42); w(0x73FF,0x5A)
    local ack=false
    for _=1,240 do
        tick()
        if r(0x73FF)==0 and r(0x7204)==1 and r(0x7205)==0x42 and r(0x7210)==9 then
            ack=true; break
        end
    end
    assert(ack,'L9Q1 $42 warp not acknowledged')
    local combat=false
    for _=1,650 do
        tick()
        if r(0x8000+0x12)==5 and r(0x8000+0xEB)==0x42 and r(0x8000+0x445)==2 then
            combat=true; break
        end
    end
    assert(combat,'Ganon combat phase not reached')
    for _=1,2 do tick() end
    local state=assert(io.open(OUT..'.txt','w'))
    state:write(string.format('mode=%02X level=%02X room=%02X phase=%02X D42=%02X\n',
        r(0x8000+0x12),r(0x8000+0x10),r(0x8000+0xEB),r(0x8000+0x445),
        r(0x8000+0x6A40)))
    state:close()
    local plane=assert(io.open(OUT..'.bin','wb'))
    for i=0,8191 do plane:write(string.char(memory.read_u8(0xC000+i,'VRAM'))) end
    plane:close()
    client.screenshot(OUT..'.png')
end)
if not ok then
    local f=assert(io.open(OUT..'.error.txt','w'))
    f:write(tostring(err)); f:close()
end
client.exit()
