-- T-004: inspect both NES CIRAM nametables and installed room-layout byte
-- through the same Ganon entry used by the 2026-09-23 live reference capture.
local ENTRY = os.getenv('T004_ENTRY_MODE') or 'mode4'
assert(ENTRY == 'mode3' or ENTRY == 'mode4')
local OUT = 'C:/tmp/t004_ganon_nt'
local function r(a) return memory.read_u8(a, 'RAM') end
local function w(a,v) memory.write_u8(a,v, 'RAM') end
local function tick(n)
    for _=1,n do joypad.set({},1); emu.frameadvance() end
end
local f = assert(io.open(OUT..'.txt','w'))
local function state(tag)
    f:write(string.format('%s mode=%02X sub=%02X level=%02X room=%02X phase=%02X D42=%02X D76=%02X switch=%02X odd=%02X vscroll=%02X\n',
        tag, r(0x12), r(0x13), r(0x10), r(0xEB), r(0x445),
        memory.read_u8(0x6A40,'System Bus'), memory.read_u8(0x6A74,'System Bus'),
        r(0x5C), r(0x5F), r(0xFC)))
    f:flush()
end
local function dump_ciram(tag)
    local out=assert(io.open(OUT..'_'..tag..'.bin','wb'))
    for i=0,2047 do out:write(string.char(memory.read_u8(i,'CIRAM (nametables)'))) end
    out:close()
end
local function dump_pal(tag)
    local out=assert(io.open(OUT..'_'..tag..'_pal.bin','wb'))
    for i=0,31 do out:write(string.char(memory.read_u8(i,'PALRAM'))) end
    out:close()
end
local ok, err=pcall(function()
    client.speedmode(400)
    savestate.load('C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/builds/reports/recovery/p1-nes/approach.State')
    state('savestate')
    w(0x10,9); tick(4)
    w(0x49E,0x70); w(0x65,0x70); w(0x5B,2); w(0x12,0x10)
    local loaded=false
    for _=1,300 do
        tick(1)
        if r(0x12)>=5 and r(0x12)<=7 and r(0x10)==9 then loaded=true; break end
    end
    assert(loaded,'level 9 did not enter play')
    state('level9')
    dump_ciram('level9')
    dump_pal('level9')
    memory.write_u8(0x6BAD,0x42,'System Bus')
    w(0xEB,0x42); w(0xEC,0x42)
    if ENTRY == 'mode3' then
        w(0x13,2); w(0x12,3); w(0x11,0)
    else
        w(0x13,0); w(0x12,4)
    end
    w(0x66F,0xFF); w(0x670,0xFF)
    state('room-request')
    local seen=false
    local entered=false
    for _=1,650 do
        tick(1)
        if not entered and r(0x12)==5 and r(0xEB)==0x42 then
            entered=true
            state('room42-first-play')
            dump_ciram('room42_first_play')
        end
        if r(0x350)==0x3E and r(0x445)==2 then seen=true; break end
    end
    assert(seen,'Ganon combat phase not reached')
    tick(2)
    state('combat')
    dump_ciram('combat')
    dump_pal('combat')
    client.screenshot(OUT..'_combat.png')
end)
if not ok then f:write('ERROR '..tostring(err)..'\n') end
f:close()
client.exit()
