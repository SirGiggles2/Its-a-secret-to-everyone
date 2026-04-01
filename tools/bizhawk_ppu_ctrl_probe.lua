-- bizhawk_ppu_ctrl_probe.lua
-- T14: PPUCTRL / PPUMASK / PPUSTATUS semantics
--
-- Verifies that _ppu_write_0 ($2000), _ppu_write_1 ($2001), _ppu_read_2 ($2002)
-- and _ppu_write_2 ($2002) behave with the correct semantics for Zelda:
--
--   PPUCTRL ($2000) write → stored in PPU_CTRL shadow
--     bit 7 = NMI enable: must be set after RunGame
--     bit 2 = VRAM increment: must be 0 (horizontal) after ClearNameTable
--     bit 4 = BG pattern table: 1 after ClearAllAudioAndVideo sets it
--   PPUMASK ($2001) write → stored in PPU_MASK shadow
--     written by InitMode / UpdateMode game code
--   PPUSTATUS ($2002) read → clears w-latch (PPU_LATCH=0), returns $80
--     IsrReset warmup polls $2002 twice to sync with VBlank
--   PPUSTATUS ($2002) write → no effect (write-only on real NES)
--
-- Checks (T14):
--   T14_NO_EXCEPTION        — no exception hit
--   T14_LOOPFOREVER_HIT     — boot completes
--   T14_PPUCTRL_NMI_BIT     — PPU_CTRL bit7 = 1 (NMI enable set by RunGame)
--   T14_PPUCTRL_INC_BIT     — PPU_CTRL bit2 = 0 (+1 horizontal increment)
--   T14_PPUCTRL_BG_TABLE    — PPU_CTRL bit4 = 1 (BG at $1000, set by ClearAllAudioAndVideo)
--   T14_PPUCTRL_SHADOW_VAL  — PPU_CTRL shadow = $B0 exactly at LoopForever entry
--   T14_PPUMASK_STORED      — PPU_MASK shadow is readable (may be any value)
--   T14_PPULATCH_CLEARED    — PPU_LATCH = 0 (PPUSTATUS reads cleared w-register)
--   T14_PPUSTATUS_RETURNS   — _ppu_read_2 always returns bit 7 set ($80 or $C0)
--                             (verified indirectly: warmup loops exit → boot completes)

local ROOT     = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\"
local OUT_DIR  = ROOT .. "builds\\reports\\"
local OUT_PATH = OUT_DIR .. "bizhawk_ppu_ctrl_probe.txt"

dofile(ROOT .. "tools/probe_addresses.lua")  -- sets LOOPFOREVER, EXC_BUS, EXC_ADDR, EXC_DEF, ISRRESET, RUNGAME, ISRNMI

local PPU_LATCH  = 0xFF0800
local PPU_CTRL   = 0xFF0804
local PPU_MASK   = 0xFF0805

local FORENSICS_TYPE = 0xFF0900

os.execute('if not exist "' .. OUT_DIR .. '" mkdir "' .. OUT_DIR .. '"')
local f = assert(io.open(OUT_PATH, "w"))
local function log(msg) f:write(msg.."\n") f:flush() print(msg) end

local PASS, FAIL = "PASS", "FAIL"
local results = {}
local function record(name, status, detail)
    log(string.format("[%s] %-26s  %s", status, name, detail))
    results[#results+1] = {name=name, status=status}
end

local function try_dom(dom, offset, width)
    local ok, v = pcall(function()
        memory.usememorydomain(dom)
        if width == 1 then return memory.read_u8(offset)
        else return memory.read_u16_be(offset) end
    end)
    return ok and v or nil
end

local function ram_read(bus_addr, width)
    local ofs = bus_addr - 0xFF0000
    for _, spec in ipairs({
        {"M68K BUS", bus_addr}, {"68K RAM", ofs},
        {"System Bus", bus_addr}, {"Main RAM", ofs},
    }) do
        local v = try_dom(spec[1], spec[2], width or 1)
        if v ~= nil then return v, spec[1] end
    end
    return nil, nil
end

local function ram_u8(a) local v,d = ram_read(a,1) return v,d end

local function add_exec_hook(addr, cb, tag)
    local ok, id = pcall(function() return event.onmemoryexecute(cb, addr, tag) end)
    return (ok and id) or nil
end

local function main()
    local FRAMES = 120
    log("=================================================================")
    log("PPU Ctrl probe  T14  —  " .. FRAMES .. " frames")
    log("=================================================================")
    log(string.format("  LoopForever=$%06X  ExcBus=$%06X  ExcAddr=$%06X  ExcDef=$%06X",
        LOOPFOREVER, EXC_BUS, EXC_ADDR, EXC_DEF))
    log("")

    local visit_frame   = {}
    local exception_hit = false
    local exception_name= nil
    local cur_frame     = 0
    local hook_ids      = {}
    local snap_ctrl     = nil
    local snap_mask     = nil
    local snap_latch    = nil

    local function mark(name)
        return function()
            if not visit_frame[name] then
                visit_frame[name] = cur_frame
                if name == "LoopForever" then
                    snap_ctrl,  _ = ram_u8(PPU_CTRL)
                    snap_mask,  _ = ram_u8(PPU_MASK)
                    snap_latch, _ = ram_u8(PPU_LATCH)
                end
            end
            if name == "ExcBusError" or name == "ExcAddrError" or name == "DefaultException" then
                if not exception_hit then
                    exception_hit = true
                    exception_name = name
                end
            end
        end
    end

    for _, lm in ipairs({
        {LOOPFOREVER, "LoopForever"},
        {EXC_BUS,     "ExcBusError"},
        {EXC_ADDR,    "ExcAddrError"},
        {EXC_DEF,     "DefaultException"},
    }) do
        local id = add_exec_hook(lm[1], mark(lm[2]), "t14_"..lm[2])
        if id then hook_ids[#hook_ids+1] = id end
    end

    for frame = 1, FRAMES do
        cur_frame = frame
        emu.frameadvance()
        local pc = emu.getregister("M68K PC") or 0
        if pc >= LOOPFOREVER and pc <= LOOPFOREVER+3 then
            if not visit_frame["LoopForever"] then
                visit_frame["LoopForever"] = frame
                snap_ctrl,  _ = ram_u8(PPU_CTRL)
                snap_mask,  _ = ram_u8(PPU_MASK)
                snap_latch, _ = ram_u8(PPU_LATCH)
            end
        end
        if pc == EXC_BUS or pc == EXC_ADDR or pc == EXC_DEF then
            if not exception_hit then
                exception_hit = true
                exception_name = (pc==EXC_BUS and "ExcBusError")
                              or (pc==EXC_ADDR and "ExcAddrError")
                              or "DefaultException"
            end
        end
        if frame <= 5 or frame % 30 == 0 then
            log(string.format("  f%03d pc=$%06X  forever=%s  exc=%s",
                frame, pc, tostring(visit_frame["LoopForever"] or "-"), tostring(exception_hit)))
        end
        if exception_hit and frame > 30 then break end
    end
    for _, id in ipairs(hook_ids) do pcall(function() event.unregisterbyid(id) end) end
    log("")

    log("─── T14: PPUCTRL / PPUMASK / PPUSTATUS Semantics ───────────────")

    if not exception_hit then
        record("T14_NO_EXCEPTION", PASS, "no exception handler hit")
    else
        local et = ram_u8(FORENSICS_TYPE) or 0
        record("T14_NO_EXCEPTION", FAIL, string.format("%s type=%d", exception_name, et))
    end

    local fl = visit_frame["LoopForever"]
    if fl then
        record("T14_LOOPFOREVER_HIT", PASS, "frame "..fl)
    else
        record("T14_LOOPFOREVER_HIT", FAIL, "never reached LoopForever")
    end

    log(string.format("  Snapshot at LoopForever (frame %s):", tostring(fl or "???")))
    log(string.format("    PPU_CTRL  ($FF0804) = %s",
        snap_ctrl  ~= nil and string.format("$%02X", snap_ctrl)  or "??"))
    log(string.format("    PPU_MASK  ($FF0805) = %s",
        snap_mask  ~= nil and string.format("$%02X", snap_mask)  or "??"))
    log(string.format("    PPU_LATCH ($FF0800) = %s",
        snap_latch ~= nil and string.format("$%02X", snap_latch) or "??"))

    -- T14_PPUCTRL_NMI_BIT — bit 7 set: NMI enable, required for VBlank
    if snap_ctrl == nil then
        record("T14_PPUCTRL_NMI_BIT", FAIL, "snapshot not captured")
    elseif (snap_ctrl & 0x80) ~= 0 then
        record("T14_PPUCTRL_NMI_BIT", PASS,
            string.format("PPU_CTRL=$%02X bit7=1 (NMI enable set by RunGame)", snap_ctrl))
    else
        record("T14_PPUCTRL_NMI_BIT", FAIL,
            string.format("PPU_CTRL=$%02X bit7=0 (NMI enable NOT set)", snap_ctrl))
    end

    -- T14_PPUCTRL_INC_BIT — bit 2 clear: +1 horizontal increment
    if snap_ctrl == nil then
        record("T14_PPUCTRL_INC_BIT", FAIL, "snapshot not captured")
    elseif (snap_ctrl & 0x04) == 0 then
        record("T14_PPUCTRL_INC_BIT", PASS,
            string.format("PPU_CTRL=$%02X bit2=0 (+1 horizontal increment)", snap_ctrl))
    else
        record("T14_PPUCTRL_INC_BIT", FAIL,
            string.format("PPU_CTRL=$%02X bit2=1 (unexpected +32 mode)", snap_ctrl))
    end

    -- T14_PPUCTRL_BG_TABLE — bit 4 set: BG pattern table at $1000
    -- ClearAllAudioAndVideo reads PPU_CTRL, sets bit 4, writes back.
    -- RunGame then ORs $A0 → $B0 (bit4 + bit7 + bit5/sprite-size).
    if snap_ctrl == nil then
        record("T14_PPUCTRL_BG_TABLE", FAIL, "snapshot not captured")
    elseif (snap_ctrl & 0x10) ~= 0 then
        record("T14_PPUCTRL_BG_TABLE", PASS,
            string.format("PPU_CTRL=$%02X bit4=1 (BG at $1000, set by ClearAllAudioAndVideo)", snap_ctrl))
    else
        record("T14_PPUCTRL_BG_TABLE", FAIL,
            string.format("PPU_CTRL=$%02X bit4=0 (BG table bit not set)", snap_ctrl))
    end

    -- T14_PPUCTRL_SHADOW_VAL — exact value $B0 at LoopForever entry
    -- $B0 = bit7(NMI)+bit5(8x16 sprites)+bit4(BG at $1000)
    if snap_ctrl == nil then
        record("T14_PPUCTRL_SHADOW_VAL", FAIL, "snapshot not captured")
    elseif snap_ctrl == 0xB0 then
        record("T14_PPUCTRL_SHADOW_VAL", PASS, "PPU_CTRL=$B0 matches expected boot value")
    else
        record("T14_PPUCTRL_SHADOW_VAL", FAIL,
            string.format("PPU_CTRL=$%02X expected $B0", snap_ctrl))
    end

    -- T14_PPUMASK_STORED — shadow is readable (value depends on game state)
    if snap_mask ~= nil then
        record("T14_PPUMASK_STORED", PASS,
            string.format("PPU_MASK=$%02X readable", snap_mask))
    else
        record("T14_PPUMASK_STORED", FAIL, "PPU_MASK not readable")
    end

    -- T14_PPULATCH_CLEARED — PPUSTATUS reads reset w-latch
    if snap_latch == nil then
        record("T14_PPULATCH_CLEARED", FAIL, "snapshot not captured")
    elseif snap_latch == 0 then
        record("T14_PPULATCH_CLEARED", PASS, "PPU_LATCH=0 (PPUSTATUS reads cleared w-register)")
    else
        record("T14_PPULATCH_CLEARED", FAIL,
            string.format("PPU_LATCH=$%02X expected $00", snap_latch))
    end

    -- T14_PPUSTATUS_RETURNS — verified indirectly: boot reached LoopForever,
    -- which requires IsrReset warmup loops to exit, which requires $2002
    -- reads to return bit 7 set ($80).
    if fl then
        record("T14_PPUSTATUS_RETURNS", PASS,
            "boot reached LoopForever — $2002 returned bit7 set (warmup loops exited)")
    else
        record("T14_PPUSTATUS_RETURNS", FAIL,
            "LoopForever not reached — $2002 read may not have returned VBlank bit")
    end

    log("")
    log("=================================================================")
    log("PPU CTRL PROBE SUMMARY  (T14)")
    log("=================================================================")
    local npass, nfail = 0, 0
    for _, r in ipairs(results) do
        log(string.format("  [%s] %s", r.status, r.name))
        if r.status == PASS then npass = npass+1 else nfail = nfail+1 end
    end
    log(string.format("\n  %d PASS  /  %d FAIL  /  %d total", npass, nfail, npass+nfail))
    log(nfail == 0 and "\nT14 PPU CTRL PROBE: ALL PASS" or "\nT14 PPU CTRL PROBE: FAIL")
end

local ok, err = pcall(main)
if not ok then log("PROBE CRASH: " .. tostring(err)) end
f:close()
client.exit()
