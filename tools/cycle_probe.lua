-- cycle_probe.lua — curated call-count profiler for room $73.
--
-- BizHawk's Genesis Plus GX core does not implement TotalExecutedCycles(),
-- so direct cycle measurement is unavailable. This probe instead captures:
--
--   (a) call counts per bucket per logical tick ($FF0015 edge), and
--   (b) emu-frame count per logical tick (tick duration proxy).
--
-- cycle_profile_report.py converts (a) into approximate cycle cost using
-- static instruction counts from the .lst × 8 cyc/inst, and uses (b) to
-- anchor total cycles per tick (emu_frames × 127_841 cyc @ 60 Hz NTSC).
--
-- Output CSV schema (backwards compatible with the cycle-based design):
--   tick,bucket,calls,total_cyc,max_cyc,tick_cyc
--   total_cyc / max_cyc are ESTIMATES (static_insts * 8 * calls).
--   tick_cyc is DERIVED from emu_frames_in_tick × 127_841.
--
-- Aggregation is PER-TICK: one row per (tick, bucket) emitted at tick edge.
-- Plus one `_tick` row per tick with emu_frames_in_tick as tick_cyc/127_841.

-- ------------------------------------------------------------------
-- Config
-- ------------------------------------------------------------------
local PROJECT_ROOT    = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY"
local BUCKET_LUA_PATH = "C:\\tmp\\cycle_profile_buckets.lua"
local BOOT_SEQ_PATH   = "C:\\tmp\\boot_sequence.lua"
local SAVESTATE_PATH  = "C:\\tmp\\_gen_73_profile.State"
local CSV_PATH        = PROJECT_ROOT .. "\\builds\\reports\\cycle_profile_73.csv"
local TARGET_ROOM     = 0x73
local CAPTURE_TICKS   = 300

-- NTSC M68K clock: 7,670,454 Hz ÷ 60 Hz ≈ 127,841 cycles per emu frame.
local CYCLES_PER_EMU_FRAME = 127841

-- NES RAM shadow addresses on Gen
local BUS           = 0xFF0000
local FRAME_COUNTER = BUS + 0x15
local GAME_MODE     = BUS + 0x12
local CUR_LEVEL     = BUS + 0x10
local ROOM_ID       = BUS + 0xEB

-- Tag override via CSV_TAG variable (set via Lua console before run if needed).
-- Simpler than env-var poking, which is unreliable in BizHawk Lua.
if CSV_TAG and #CSV_TAG > 0 then
    CSV_PATH = string.format(
        "%s\\builds\\reports\\cycle_profile_73_%s.csv",
        PROJECT_ROOT, CSV_TAG)
end

-- ------------------------------------------------------------------
-- Helpers
-- ------------------------------------------------------------------
local function u8(a)
    memory.usememorydomain("M68K BUS")
    return memory.read_u8(a)
end

local function log(fmt, ...)
    local msg = string.format(fmt, ...)
    io.write("[cycle_probe] ", msg, "\n")
    pcall(function() gui.text(10, 10, msg) end)
end

-- ------------------------------------------------------------------
-- Load bucket config
-- ------------------------------------------------------------------
local ok_buckets = pcall(dofile, BUCKET_LUA_PATH)
if not ok_buckets or type(cycle_profile_buckets) ~= "table" then
    log("FATAL: could not load %s — run parse_lst.py first", BUCKET_LUA_PATH)
    return
end

-- Per-bucket runtime state.
local state = {}
for _, b in ipairs(cycle_profile_buckets) do
    state[b.name] = { calls = 0, max_tick_calls = 0 }
end

local function make_entry_cb(bname)
    return function()
        state[bname].calls = state[bname].calls + 1
    end
end

-- ------------------------------------------------------------------
-- Register hooks (entry only)
-- ------------------------------------------------------------------
local hooks_ok = 0
for _, b in ipairs(cycle_profile_buckets) do
    local ok = pcall(function()
        event.onmemoryexecute(make_entry_cb(b.name), b.entry_addr,
                              "cyc_in_" .. b.name, "M68K BUS")
    end)
    if ok then hooks_ok = hooks_ok + 1 end
end
log("registered %d / %d entry hooks", hooks_ok, #cycle_profile_buckets)

-- ------------------------------------------------------------------
-- Boot drive + savestate bootstrap
-- ------------------------------------------------------------------
local saved_state_loaded = false
pcall(function()
    savestate.load(SAVESTATE_PATH)
    saved_state_loaded = true
end)

if saved_state_loaded then
    log("loaded savestate %s", SAVESTATE_PATH)
    for i = 1, 60 do emu.frameadvance() end
else
    log("no savestate — fresh boot via %s", BOOT_SEQ_PATH)
    local ok_boot = pcall(dofile, BOOT_SEQ_PATH)
    if not ok_boot or type(boot_sequence) ~= "table" then
        log("FATAL: could not dofile %s", BOOT_SEQ_PATH)
        return
    end
    local frame = 0
    local arrived_frame = -1
    while true do
        local status = boot_sequence.drive(frame, TARGET_ROOM)
        if status == "arrived" then
            if arrived_frame < 0 then
                arrived_frame = frame
                -- Save immediately — before settle/wait loops that might
                -- transition us back out of gameplay.
                pcall(function() savestate.save(SAVESTATE_PATH) end)
                log("arrived at room $%02X on frame %d, saved state",
                    TARGET_ROOM, frame)
            end
            break
        end
        emu.frameadvance()
        frame = frame + 1
        -- Every 120 frames, dump a debug line so we can see what state
        -- we're stuck in during a failing boot.
        if frame % 120 == 0 then
            log("boot frame %d status=%s mode=$%02X lvl=$%02X room=$%02X",
                frame, status, u8(GAME_MODE), u8(CUR_LEVEL), u8(ROOM_ID))
        end
        if frame > 4000 then
            log("FATAL: didn't reach room $%02X after %d frames (last mode=$%02X room=$%02X)",
                TARGET_ROOM, frame, u8(GAME_MODE), u8(ROOM_ID))
            return
        end
    end
    for i = 1, 60 do emu.frameadvance() end
end

-- Wait up to 600 extra frames for object slots to populate. Moblin spawn
-- happens over a few frames after room entry via edge-spawn.
local OBJ_TYPE_BASE = BUS + 0x034F
local function active_objs()
    local n = 0
    memory.usememorydomain("M68K BUS")
    for i = 0, 11 do
        if memory.read_u8(OBJ_TYPE_BASE + i) ~= 0 then n = n + 1 end
    end
    return n
end

local waited = 0
while active_objs() < 1 and waited < 600 do
    emu.frameadvance()
    waited = waited + 1
end
log("waited %d extra frames; %d active objects", waited, active_objs())

-- Reset per-bucket counters after boot so capture only covers gameplay.
for _, b in ipairs(cycle_profile_buckets) do state[b.name].calls = 0 end

-- Confirm we're actually at $73.
local mode = u8(GAME_MODE)
local lvl = u8(CUR_LEVEL)
local rid = u8(ROOM_ID)
log("entry: mode=$%02X lvl=$%02X room=$%02X objs=%d",
    mode, lvl, rid, active_objs())
if rid ~= TARGET_ROOM or mode ~= 0x05 then
    log("WARNING: not at target room $%02X (at $%02X mode $%02X)",
        TARGET_ROOM, rid, mode)
end

-- ------------------------------------------------------------------
-- Capture loop
-- ------------------------------------------------------------------
local fh = io.open(CSV_PATH, "w")
if not fh then
    log("FATAL: cannot open %s for write", CSV_PATH)
    return
end
fh:write(string.format("# room=$%02X mode=$%02X lvl=$%02X objs=%d\n",
    rid, mode, lvl, active_objs()))
fh:write("tick,bucket,calls,total_cyc,max_cyc,tick_cyc\n")

local tick_idx = 0
local last_fc = u8(FRAME_COUNTER)
local emu_frames_in_tick = 0

-- Hold no buttons during profile to avoid input-driven variance.
pcall(function() joypad.set({}, 1) end)

while tick_idx < CAPTURE_TICKS do
    emu.frameadvance()
    emu_frames_in_tick = emu_frames_in_tick + 1
    local fc = u8(FRAME_COUNTER)
    local delta = (fc - last_fc) & 0xFF
    if delta > 0 then
        -- Tick edge: flush per-bucket stats.
        local tick_cyc = emu_frames_in_tick * CYCLES_PER_EMU_FRAME
        for _, b in ipairs(cycle_profile_buckets) do
            local s = state[b.name]
            if s.calls > 0 then
                local est_per_call = b.static_insts * 8
                local est_total = s.calls * est_per_call
                fh:write(string.format("%d,%s,%d,%d,%d,%d\n",
                    tick_idx, b.name, s.calls,
                    est_total, est_per_call, tick_cyc))
            end
            s.calls = 0
        end
        fh:write(string.format("%d,_tick,%d,%d,%d,%d\n",
            tick_idx, emu_frames_in_tick, tick_cyc, tick_cyc, tick_cyc))
        tick_idx = tick_idx + delta
        emu_frames_in_tick = 0
        last_fc = fc
        if tick_idx % 30 == 0 then
            pcall(function()
                gui.text(10, 10,
                    string.format("tick %d/%d", tick_idx, CAPTURE_TICKS))
            end)
        end
    end
end

fh:close()
log("captured %d ticks -> %s", tick_idx, CSV_PATH)

for i = 1, 30 do emu.frameadvance() end
pcall(function() client.exit() end)
