-- probe_phase_sequence.lua
-- Boots ROM, runs 4000 frames, samples nes_ram[$07F0..$07FF] every 60
-- frames, writes CSV to tools/intro_test/out/phase_sequence.csv.
-- Outputs done marker so the harness can detect completion.
--
-- Memory domain handling follows bizhawk_capture_intro_sequence.lua:
--   Probe "68K RAM" first (offset = addr - 0xFF0000),
--   then "M68K BUS" (offset = full addr),
--   then "M68K RAM" as fallback.
-- Phase bytes live at NES_RAM[$07F0..$07FF] which maps to
-- Genesis 68K RAM $FF07F0..$FF07FF.

local REPO_ROOT = os.getenv("CODEX_BIZHAWK_ROOT") or "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY"
local OUT_DIR   = REPO_ROOT .. "\\tools\\intro_test\\out"
local OUT_PATH  = OUT_DIR .. "\\phase_sequence.csv"
local TOTAL_FRAMES = 8000
local SAMPLE_EVERY = 60

os.execute('mkdir "' .. OUT_DIR .. '" 2>nul')

-- Detect memory domain (same probe pattern as bizhawk_capture_intro_sequence.lua).
local ram_domain = nil
do
    local ok, domains = pcall(function() return memory.getmemorydomainlist() end)
    if ok and domains then
        local dm = {}
        for _, name in ipairs(domains) do
            dm[name] = true
        end
        if dm["68K RAM"] then
            ram_domain = "68K RAM"
        elseif dm["M68K RAM"] then
            ram_domain = "M68K RAM"
        elseif dm["M68K BUS"] then
            ram_domain = "M68K BUS"
        end
    end
end

-- Read a byte at a Genesis absolute address (0xFF????).
local function rd(addr)
    if not ram_domain then return 0xFF end
    if ram_domain == "M68K BUS" then
        -- M68K BUS uses the full address as offset.
        local ok, v = pcall(function() return memory.read_u8(addr, ram_domain) end)
        return ok and v or 0xFF
    else
        -- "68K RAM" / "M68K RAM" use offset from 0xFF0000.
        local off = addr - 0xFF0000
        if off < 0 or off > 0xFFFF then return 0xFF end
        local ok, v = pcall(function() return memory.read_u8(off, ram_domain) end)
        return ok and v or 0xFF
    end
end

local function fc()
    local ok, v = pcall(function() return emu.framecount() end)
    return ok and v or 0
end

local f = io.open(OUT_PATH, "w")
if not f then
    -- Fallback: try current dir (when launched from BizHawk working dir)
    OUT_PATH = "phase_sequence.csv"
    f = io.open(OUT_PATH, "w")
end
f:write("frame,phase,frame_lo,handoff,substate,sentinel\n")

while fc() <= TOTAL_FRAMES do
    local frame = fc()
    if (frame % SAMPLE_EVERY) == 0 then
        -- NES_RAM[$07F0..$07FF] = Genesis $FF07F0..$FF07FF
        local p  = rd(0xFF07F0)   -- phase
        local fr = rd(0xFF07F1)   -- frame_lo (frame counter low byte)
        local hf = rd(0xFF07F2)   -- handoff flag
        local ss = rd(0xFF07F3)   -- substate
        local sn = rd(0xFF07FF)   -- sentinel ($A1 when intro_main entered)
        f:write(string.format("%d,%d,%d,%d,%d,%d\n", frame, p, fr, hf, ss, sn))
    end
    emu.frameadvance()
end

f:close()

-- Done marker so the Python harness knows the run completed.
local done_path = OUT_DIR .. "\\phase_sequence.done"
local d = io.open(done_path, "w")
if not d then
    d = io.open("phase_sequence.done", "w")
end
if d then
    d:write("ok\n")
    d:close()
end

client.exit()
