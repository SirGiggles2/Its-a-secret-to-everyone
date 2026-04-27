-- probe_start_handoff.lua
-- Runs ROM, injects Start press at the frame specified by scenario.idx,
-- runs 120 more frames, samples handoff state to CSV.
--
-- Wrapper batch (run_full.bat) writes scenario.idx then launches BizHawk
-- once per scenario. Each scenario covers a different intro phase.
--
-- Memory domain detection mirrors probe_phase_sequence.lua.

local SCENARIOS = {
    {name="title_display", press_frame=120},   -- ~2s into title
    {name="fadeout",       press_frame=480},   -- mid 14-cycle fade
    {name="story_run",     press_frame=900},   -- mid story scroll
    {name="late_story",    press_frame=2400},  -- late in story+items scroll
}

local REPO_ROOT = os.getenv("CODEX_BIZHAWK_ROOT") or "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY"
local OUT_DIR   = REPO_ROOT .. "\\tools\\intro_test\\out"
os.execute('mkdir "' .. OUT_DIR .. '" 2>nul')

-- Read which scenario to run from a sentinel file (each BizHawk launch
-- runs one scenario). The wrapper batch file writes the index.
local idx_file = io.open(OUT_DIR .. "\\scenario.idx", "r")
if not idx_file then
    -- Fallback: look in current dir (when BizHawk cd'd to its own dir)
    idx_file = io.open("scenario.idx", "r")
end
if not idx_file then
    print("FAIL: scenario.idx missing")
    client.exit()
    return
end
-- Strip BOM and whitespace before converting to number.
local raw = idx_file:read("*l") or ""
idx_file:close()
-- Remove UTF-8 BOM (0xEF 0xBB 0xBF) if present.
raw = raw:gsub("^\xEF\xBB\xBF", "")
-- Strip all non-digit characters (spaces, CR, etc.).
raw = raw:match("(%d+)") or ""
local idx = tonumber(raw)
local scn = SCENARIOS[idx]
if not scn then
    print("FAIL: bad scenario idx '" .. raw .. "' (raw='" .. tostring(raw) .. "')")
    client.exit()
    return
end

-- Detect memory domain (same probe pattern as probe_phase_sequence.lua).
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
local function rb(addr)
    if not ram_domain then return 0xFF end
    if ram_domain == "M68K BUS" then
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

-- Safe joypad.set: try with player index first, fall back to no index.
local function safe_set(pad)
    local ok = pcall(function() joypad.set(pad or {}, 1) end)
    if not ok then joypad.set(pad or {}) end
end

local function fc()
    local ok, v = pcall(function() return emu.framecount() end)
    return ok and v or 0
end

local TOTAL = scn.press_frame + 120
local press_done = false

while fc() <= TOTAL do
    local frame = fc()
    if frame == scn.press_frame and not press_done then
        safe_set({Start=true})
        press_done = true
    elseif frame == scn.press_frame + 1 then
        safe_set({Start=false})
    end
    emu.frameadvance()
end

-- Sample handoff state.
-- - $FF07F2 should be $BB (trampoline ran — handoff marker written by trampoline)
-- - $FF0FFC should be $01 (vblank_mode flipped to transpiled)
-- - $FF0804 bit 7 should be set (PPUCTRL NMI enable)
-- - $FF0012 should be $01 (GameMode = file-select)
-- - $FF083D should be $01 (VRamForceBlankGate seeded)
-- - $FF042B should be $01 (FrontendStartReleaseGate consumed)
local csv_name = "handoff_" .. scn.name .. ".csv"
local csv_path = OUT_DIR .. "\\" .. csv_name

local out_csv = io.open(csv_path, "w")
if not out_csv then
    -- Fallback: write to current dir (BizHawk working dir)
    out_csv = io.open(csv_name, "w")
end
if out_csv then
    out_csv:write("name,handoff_marker,vblank_mode,ppuctrl,gamemode,vram_force_blank,front_start_gate\n")
    out_csv:write(string.format("%s,%d,%d,%d,%d,%d,%d\n",
        scn.name,
        rb(0xFF07F2),   -- handoff_marker: $BB when trampoline ran
        rb(0xFF0FFC),   -- vblank_mode: 1 = transpiled dispatcher active
        rb(0xFF0804),   -- ppuctrl: bit 7 = NMI enable
        rb(0xFF0012),   -- gamemode: $01 = MODE_FILESELECT
        rb(0xFF083D),   -- vram_force_blank: VRamForceBlankGate
        rb(0xFF042B)    -- front_start_gate: FrontendStartReleaseGate
    ))
    out_csv:close()
end

local done_name = "handoff_" .. scn.name .. ".done"
local done_path = OUT_DIR .. "\\" .. done_name
local d = io.open(done_path, "w")
if not d then
    d = io.open(done_name, "w")
end
if d then
    d:write("ok\n")
    d:close()
end

client.exit()
