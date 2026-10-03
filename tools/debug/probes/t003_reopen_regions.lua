-- T-003: fresh emulator process, actual prior SaveRAM, controller-only Continue.
-- Expected hex is the 384-byte file-A world image from the NES reference save.
local OUT = '@OUT@'
local EXPECTED = '@EXPECTED@'
local f = assert(io.open(OUT, 'w'))
local function log(s) f:write(s .. '\n'); f:flush() end
local ok, err = pcall(function()
    local ef = assert(io.open(EXPECTED, 'r'))
    local hex = ef:read('*a'):gsub('%s', '')
    ef:close()
    assert(#hex == 768 and not hex:find('[^%x]'), 'invalid expected world image')
    local expected = {}
    for i = 0, 383 do expected[i] = tonumber(hex:sub(2*i+1, 2*i+2), 16) end
    local names = {}
    for _, n in ipairs(memory.getmemorydomainlist()) do names[n] = true end
    assert(names['SRAM'], 'SRAM unavailable')
    local work = names['M68K BUS'] and 'M68K BUS' or
        (names['68K RAM'] and '68K RAM' or 'Main RAM')
    assert(names[work], '68K work RAM unavailable')
    local bus = work == 'M68K BUS' and 0xFF0000 or 0
    local function ram(a) return memory.read_u8(bus + 0x8000 + a, work) end
    local function saved(k) return memory.read_u8(2*k+1, 'SRAM') end
    local nonzero = 0
    for i = 0, 383 do
        assert(saved(0x92+i) == expected[i], string.format('disk world mismatch $%03X', 0x67F+i))
        if expected[i] ~= 0 then nonzero = nonzero + 1 end
    end
    assert(nonzero > 0, 'empty expected world image')
    assert(saved(0x512) == 1, 'file A not active')
    log(string.format('DISK: MATCH 384/384, nonzero=%d, file A active', nonzero))
    local function idle(n)
        joypad.set({}, 1)
        for _ = 1, n do emu.frameadvance() end
    end
    local function start()
        joypad.set({Start=true}, 1)
        for _ = 1, 6 do emu.frameadvance() end
        joypad.set({}, 1)
    end
    idle(150); start(); idle(90); start()
    local reached = false
    for _ = 1, 900 do
        idle(1)
        if ram(0x12) == 5 and ram(0xEB) == 0x77 then reached = true; break end
    end
    assert(reached and ram(0x16) == 0, 'Continue did not enter file-A overworld')
    local matched, mismatch = false, {}
    for wait = 0, 120 do
        mismatch = {}
        for i = 0, 383 do
            if ram(0x67F+i) ~= expected[i] then mismatch[#mismatch+1] = i end
        end
        if #mismatch == 0 then matched = true; log('restore wait=' .. wait); break end
        idle(1)
    end
    for k = 1, math.min(16, #mismatch) do
        local i = mismatch[k]
        log(string.format('DIFF $%03X expected=%02X live=%02X', 0x67F+i, expected[i], ram(0x67F+i)))
    end
    assert(matched, 'world restore differs in ' .. #mismatch .. ' bytes')
    for _, a in ipairs({0x6F5, 0x723, 0x795}) do
        log(string.format('live $%03X=%02X', a, ram(a)))
    end
    log('RESTORE: MATCH 384/384 (OW, L1-6, L7-9)')
    log('VERDICT: PASS')
end)
if not ok then log('VERDICT: FAIL -- ' .. tostring(err)) end
f:close()
client.exit()
