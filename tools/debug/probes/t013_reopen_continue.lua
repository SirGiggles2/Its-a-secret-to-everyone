-- T-013: fresh process + existing private SaveRAM, controller-only File Select
-- Continue. The prior save staged rupees and one OW flag on both consoles.
local OUT = os.getenv('T013_REOPEN_OUT') or 'C:/tmp/t013_reopen_continue.txt'
local WANT_RUPEES = tonumber(os.getenv('T013_EXPECT_RUPEES')) or 0x63
local FLAG_ADDR = tonumber(os.getenv('T013_EXPECT_FLAG_ADDR')) or 0x690
local WANT_FLAG = tonumber(os.getenv('T013_EXPECT_FLAG')) or 0x80
local WANT_TRIFORCE = tonumber(os.getenv('T013_EXPECT_TRIFORCE'))
local f = assert(io.open(OUT, 'w'))
local function log(s) f:write(s .. '\n'); f:flush() end
local ok, err = pcall(function()
    local names = {}
    for _, n in ipairs(memory.getmemorydomainlist()) do names[n] = true end
    assert(names['SRAM'], 'SRAM domain unavailable')
    local work = names['M68K BUS'] and 'M68K BUS' or
        (names['68K RAM'] and '68K RAM' or 'Main RAM')
    assert(names[work], '68K work RAM domain unavailable')
    local bus = (work == 'M68K BUS') and 0xFF0000 or 0
    local function ram(a) return memory.read_u8(bus + 0x8000 + a, work) end
    local function saved(k) return memory.read_u8(2 * k + 1, 'SRAM') end
    local function idle(n)
        joypad.set({}, 1)
        for _ = 1, n do emu.frameadvance() end
    end
    local function start()
        joypad.set({Start=true}, 1)
        for _ = 1, 6 do emu.frameadvance() end
        joypad.set({}, 1)
    end
    local save_rupees = saved(0x1A + (0x66D - 0x657))
    assert(FLAG_ADDR >= 0x67F and FLAG_ADDR <= 0x7FE, 'flag address outside profile')
    local save_flag = saved(0x92 + (FLAG_ADDR - 0x67F))
    local save_triforce = saved(0x34)
    log(string.format('on-disk SRAM logical rupees=%02X flag%03X=%02X triforce=%02X',
        save_rupees, FLAG_ADDR, save_flag, save_triforce))
    idle(150)
    log(string.format('title frame: mode=%02X room=%02X', ram(0x12), ram(0xEB)))
    start()
    idle(90)
    log(string.format('after title Start: mode=%02X room=%02X active=%02X save-ram-copy-rupees=%02X',
        ram(0x12), ram(0xEB), ram(0x633), ram(0x6030)))
    start()
    local reached = false
    local frame = -1
    for i = 1, 900 do
        idle(1)
        if i <= 45 and (i <= 8 or i % 4 == 0) then
            log(string.format('handoff f=%d mode=%02X room=%02X active=%02X slot=%02X rupees=%02X flag=%02X triforce=%02X',
                i, ram(0x12), ram(0xEB), ram(0x633), ram(0x16),
                ram(0x66D), ram(FLAG_ADDR), ram(0x671)))
        end
        if ram(0x12) == 0x05 and ram(0xEB) == 0x77 then
            reached = true
            frame = i
            break
        end
    end
    local restored_at = -1
    for i = 0, 120 do
        if ram(0x66D) == save_rupees and ram(FLAG_ADDR) == save_flag and
            ram(0x671) == save_triforce then
            restored_at = i
            break
        end
        idle(1)
    end
    local rupees = ram(0x66D)
    local flag = ram(FLAG_ADDR)
    local triforce = ram(0x671)
    local slot = ram(0x16)
    log(string.format('after File Select Start: reached=%s frame=%d restored_after=%d mode=%02X room=%02X slot=%02X rupees=%02X flag%03X=%02X triforce=%02X',
        tostring(reached), frame, restored_at, ram(0x12), ram(0xEB),
        slot, rupees, FLAG_ADDR, flag, triforce))
    assert(save_rupees == WANT_RUPEES and save_flag == WANT_FLAG and
        (WANT_TRIFORCE == nil or save_triforce == WANT_TRIFORCE), 'prior save marker missing')
    assert(reached and restored_at >= 0 and slot == 0 and rupees == save_rupees and
        flag == save_flag and triforce == save_triforce,
        'Continue did not restore the saved state')
    log('VERDICT: PASS')
end)
if not ok then log('VERDICT: FAIL — ' .. tostring(err)) end
f:close()
client.exit()
