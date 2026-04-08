-- Capture EVERY frame during Phase 1 (story scroll + wait + item scroll + hold)
-- Captures screenshots + state variables for comparison against NES reference
local OUT_DIR = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/builds/reports/full_scroll"
os.execute('mkdir "' .. OUT_DIR:gsub("/", "\\") .. '" 2>nul')

local system = emu.getsystemid() or "?"
local is_genesis = (system == "GEN" or system == "SAT")

local domains = {}
for _, name in ipairs(memory.getmemorydomainlist()) do
    domains[name] = true
end
local ram_domain = nil
if is_genesis then
    for _, n in ipairs({"68K RAM", "M68K RAM", "M68K BUS"}) do
        if domains[n] then ram_domain = n; break end
    end
end

local function rd(addr)
    if is_genesis then
        local off = addr
        if ram_domain == "M68K BUS" then off = 0xFF0000 + addr end
        local ok, v = pcall(function() return memory.read_u8(off, ram_domain) end)
        return ok and v or 0xFF
    end
    local ok, v = pcall(function() return memory.read_u8(addr, "RAM") end)
    return ok and v or 0xFF
end

local log_file = io.open(OUT_DIR .. "/state_log.txt", "w")
log_file:write("frame,phase,subphase,curV,ntSel,timer,scrollPass,lineIdx,itemIdx,yDec\n")

local capture_count = 0
local prev_phase = 0xFF

while emu.framecount() < 5000 do
    emu.frameadvance()
    local fc = emu.framecount()
    local phase = rd(0x042C)
    local subphase = rd(0x042D)

    -- Capture during Phase 1 (all subphases: story=0, wait=1, items=2, hold=3, exit=4)
    if phase == 0x01 then
        local curV = rd(0x00FC)
        local ntSel = rd(0x005C)
        local timer = rd(0x041A)
        local scrollPass = rd(0x0415)
        local lineIdx = rd(0x0419)
        local itemIdx = rd(0x042F)
        local yDec = rd(0x041B)

        log_file:write(string.format("%d,%d,%d,%d,%d,%d,%d,%d,%d,%d\n",
            fc, phase, subphase, curV, ntSel, timer, scrollPass, lineIdx, itemIdx, yDec))

        -- Screenshot EVERY frame
        client.screenshot(string.format("%s/gen_f%05d_sp%d_v%02X.png",
            OUT_DIR, fc, subphase, curV))
        capture_count = capture_count + 1
    end

    -- Also detect Phase 1 start/end for timing
    if phase ~= prev_phase then
        log_file:write(string.format("-- PHASE CHANGE: %d -> %d at frame %d\n", prev_phase, phase, fc))
        prev_phase = phase
    end
end

log_file:close()
print(string.format("Full scroll probe: %d screenshots captured", capture_count))
client.exit()
