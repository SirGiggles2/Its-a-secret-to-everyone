-- ym_trace.lua
-- Traces every YM2612 write by hooking execute at the entry of ym_write1 /
-- ym_write2 and reading D0 (register address) / D1 (data value) from the M68K
-- register file.  This bypasses Genplus-gx's lack of bus-write hooks.
--
-- Addresses are extracted from builds/whatif.lst:
--   ym_write1 = $454   (Part I, reg + data to $A04000 / $A04001)
--   ym_write2 = $470   (Part II, reg + data to $A04002 / $A04003)
--
-- At frame 240 (~4s) we dump the reconstructed YM register state to
-- C:\tmp\ym_state.txt and the full write sequence to C:\tmp\ym_writes.log.

local YM_WRITE1 = 0x454
local YM_WRITE2 = 0x470
local LOAD_FM_PATCH = 0x4CC
local AUDIO_INIT = 0x4EA
local EMIT_SQ1 = 0xB26
local EMIT_SQ0 = 0xB84
local EMIT_TRG = 0xBE2

local ym_state = {}     -- [reg] = last value (P1: 0-$FF, P2: $100-$1FF)
local writes = {}
local frame = 0
local dumped = false
local hook_scope = nil
local hit_count1 = 0
local hit_count2 = 0

-- Print available scopes so we know what we can use.
if event.availableScopes then
    print("available scopes:")
    for _, s in ipairs(event.availableScopes()) do print("  " .. s) end
end

local function read_d0()
    -- Try multiple register-name conventions used by different BizHawk versions.
    local names = {"M68K D0", "D0", "m68k D0", "MainCPU D0"}
    for _, n in ipairs(names) do
        local ok, v = pcall(emu.getregister, n)
        if ok and v then return v end
    end
    return nil
end

local function read_d1()
    local names = {"M68K D1", "D1", "m68k D1", "MainCPU D1"}
    for _, n in ipairs(names) do
        local ok, v = pcall(emu.getregister, n)
        if ok and v then return v end
    end
    return nil
end

local function on_ym1()
    hit_count1 = hit_count1 + 1
    local d0 = read_d0()
    local d1 = read_d1()
    if d0 and d1 then
        local reg = d0 % 0x100
        local val = d1 % 0x100
        ym_state[reg] = val
        table.insert(writes, {frame=frame, part=1, reg=reg, val=val})
    end
end

local function on_ym2()
    hit_count2 = hit_count2 + 1
    local d0 = read_d0()
    local d1 = read_d1()
    if d0 and d1 then
        local reg = d0 % 0x100
        local val = d1 % 0x100
        ym_state[0x100 + reg] = val
        table.insert(writes, {frame=frame, part=2, reg=reg, val=val})
    end
end

-- Genplus-gx exposes "M68K BUS" as a memory domain and memory-callback scope.
-- Hook writes to the four YM2612 port addresses directly.
local function on_w_a04000(addr, val) on_ym1_write(0, val) end
local function on_w_a04001(addr, val) on_ym1_write(1, val) end
local function on_w_a04002(addr, val) on_ym1_write(2, val) end
local function on_w_a04003(addr, val) on_ym1_write(3, val) end

-- Redefine on_ym1 / on_ym2 handlers using value from the write hook.
local ym_part1_sel = 0
local ym_part2_sel = 0
function on_ym1_write(port_idx, val)
    val = val % 0x100
    if port_idx == 0 then
        ym_part1_sel = val
        table.insert(writes, {frame=frame, part=1, reg=-1, val=val})
    elseif port_idx == 1 then
        ym_state[ym_part1_sel] = val
        table.insert(writes, {frame=frame, part=1, reg=ym_part1_sel, val=val})
        hit_count1 = hit_count1 + 1
    elseif port_idx == 2 then
        ym_part2_sel = val
        table.insert(writes, {frame=frame, part=2, reg=-1, val=val})
    elseif port_idx == 3 then
        ym_state[0x100 + ym_part2_sel] = val
        table.insert(writes, {frame=frame, part=2, reg=ym_part2_sel, val=val})
        hit_count2 = hit_count2 + 1
    end
end

local installed = false
local ok = pcall(function()
    event.onmemorywrite(on_w_a04000, 0xA04000, "ym00", "M68K BUS")
    event.onmemorywrite(on_w_a04001, 0xA04001, "ym01", "M68K BUS")
    event.onmemorywrite(on_w_a04002, 0xA04002, "ym02", "M68K BUS")
    event.onmemorywrite(on_w_a04003, 0xA04003, "ym03", "M68K BUS")
end)
if ok then
    hook_scope = "M68K BUS"
    installed = true
end

print("ym_trace hook scope:", hook_scope or "FAILED")
if memory.getmemorydomainlist then
    print("memory domains:")
    for _, d in ipairs(memory.getmemorydomainlist()) do print("  " .. d) end
end

local function dump_state_to_file(path)
    local f = io.open(path, "w")
    if not f then print("ERROR: could not open " .. path); return end
    f:write(string.format("=== YM2612 reconstructed state at frame %d ===\n", frame))
    f:write(string.format("hook scope:     %s\n", hook_scope or "NONE"))
    f:write(string.format("ym_write1 hits: %d\n", hit_count1))
    f:write(string.format("ym_write2 hits: %d\n", hit_count2))
    f:write(string.format("total writes:   %d\n\n", #writes))

    f:write("PART I registers (all non-nil):\n")
    for reg = 0, 0xFF do
        local v = ym_state[reg]
        if v then f:write(string.format("  $%02X = $%02X\n", reg, v)) end
    end
    f:write("\nPART II registers (all non-nil):\n")
    for reg = 0, 0xFF do
        local v = ym_state[0x100 + reg]
        if v then f:write(string.format("  $%02X = $%02X\n", reg, v)) end
    end

    local function rg(r)
        local v = ym_state[r]
        return v and string.format("$%02X", v) or "--"
    end
    local function decode_voice(label, ch, expect_fbalg, expect_dtmul, expect_rsar,
                                 expect_d1r, expect_d2r, expect_dlrr, expect_tl)
        f:write(string.format("\n-- %s (ch %d) --\n", label, ch))
        f:write(string.format("  $B%X FB/ALG  = %s  (expect %s)\n", ch, rg(0xB0+ch), expect_fbalg))
        f:write(string.format("  $3x DT/MUL  = %s %s %s %s (expect %s)\n",
            rg(0x30+ch), rg(0x34+ch), rg(0x38+ch), rg(0x3C+ch), expect_dtmul))
        f:write(string.format("  $5x RS/AR   = %s %s %s %s (expect %s)\n",
            rg(0x50+ch), rg(0x54+ch), rg(0x58+ch), rg(0x5C+ch), expect_rsar))
        f:write(string.format("  $6x AM/D1R  = %s %s %s %s (expect %s)\n",
            rg(0x60+ch), rg(0x64+ch), rg(0x68+ch), rg(0x6C+ch), expect_d1r))
        f:write(string.format("  $7x D2R     = %s %s %s %s (expect %s)\n",
            rg(0x70+ch), rg(0x74+ch), rg(0x78+ch), rg(0x7C+ch), expect_d2r))
        f:write(string.format("  $8x DL/RR   = %s %s %s %s (expect %s)\n",
            rg(0x80+ch), rg(0x84+ch), rg(0x88+ch), rg(0x8C+ch), expect_dlrr))
        f:write(string.format("  $4x TL      = %s %s %s %s (expect %s)\n",
            rg(0x40+ch), rg(0x44+ch), rg(0x48+ch), rg(0x4C+ch), expect_tl))
        f:write(string.format("  $9x SSG-EG  = %s %s %s %s (expect $00 x4)\n",
            rg(0x90+ch), rg(0x94+ch), rg(0x98+ch), rg(0x9C+ch)))
        f:write(string.format("  $B%X pan/AMS/PMS = %s\n", 4+ch, rg(0xB4+ch)))
    end

    decode_voice("Voice $03 lead (CLEAN)", 0,
        "$3D", "$01 $51 $21 $01", "$1F $1F $1F $1F",
        "$0A $05 $05 $05", "$00 $00 $00 $00", "$2B $2B $2B $1B", "$19 $18 $18 $18")
    decode_voice("Voice $00 pad (BUZZY)", 1,
        "$07", "$05 $01 $00 $02", "$1F $1F $1F $1F",
        "$0E $0E $0E $0E", "$02 $02 $02 $02", "$55 $55 $55 $54", "$18 $18 $18 $18")
    decode_voice("Voice $07 bass (BUZZY)", 2,
        "$08", "$0A $30 $70 $00", "$1F $5F $1F $5F",
        "$12 $0A $0E $0A", "$00 $04 $04 $03", "$2F $2F $2F $2F", "$24 $13 $2D $20")

    f:close()
    print("dumped YM state to " .. path)
end

local function dump_writes_to_file(path)
    local f = io.open(path, "w")
    if not f then return end
    f:write(string.format("=== %d writes up to frame %d ===\n", #writes, frame))
    for _, w in ipairs(writes) do
        f:write(string.format("[%04d] P%d reg=$%02X val=$%02X\n",
            w.frame, w.part, w.reg, w.val))
    end
    f:close()
    print("dumped " .. #writes .. " writes to " .. path)
end

while true do
    frame = frame + 1
    if frame == 240 and not dumped then
        dump_state_to_file("C:\\tmp\\ym_state.txt")
        dump_writes_to_file("C:\\tmp\\ym_writes.log")
        dumped = true
    end
    gui.text(4, 4, string.format("YM f=%d w=%d h1=%d h2=%d scope=%s",
        frame, #writes, hit_count1, hit_count2, hook_scope or "NONE"))
    emu.frameadvance()
end
