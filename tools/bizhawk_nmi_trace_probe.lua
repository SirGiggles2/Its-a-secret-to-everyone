-- bizhawk_nmi_trace_probe.lua
-- Traces NMI entry/exit and game state at each NMI to find where the stall occurs.
-- Uses exec hook on IsrNmi for reliable NMI counting.

local ROOT     = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\"
local OUT_PATH = ROOT .. "builds\\reports\\bizhawk_nmi_trace_probe.txt"
local f = assert(io.open(OUT_PATH, "w"))
local function log(msg) f:write(msg.."\n") f:flush() print(msg) end

-- Load symbol addresses from listing
dofile(ROOT .. "tools/probe_addresses.lua")

local frame_count = 0
local CAPTURE_END = 300
local nmi_count = 0

local function rb(offset)
    local ok, v = pcall(function()
        memory.usememorydomain("M68K BUS")
        return memory.read_u8(0xFF0000 + offset)
    end)
    return ok and v or 0xFF
end

local function rw(addr)
    local ok, v = pcall(function()
        memory.usememorydomain("M68K BUS")
        return memory.read_u16_be(addr)
    end)
    return ok and v or 0
end

-- Helper for exec hooks (same pattern as boot probe)
local function add_exec_hook(addr, cb, tag)
    if addr == 0 then return nil end
    local ok, id = pcall(function()
        return event.onmemoryexecute(cb, addr, tag or "exec_hook")
    end)
    if not ok then
        local ok2, id2 = pcall(function()
            return event.onmemoryexecute(cb, addr)
        end)
        if ok2 then return id2 end
        return nil
    end
    return id
end

log("=================================================================")
log("NMI Trace Probe  --  frames 1-" .. CAPTURE_END)
log(string.format("  IsrNmi=$%06X", ISRNMI))
log("=================================================================")
log("")

-- Track NMI entries via exec hook on IsrNmi
local nmi_this_frame = 0
add_exec_hook(ISRNMI, function()
    nmi_count = nmi_count + 1
    nmi_this_frame = nmi_this_frame + 1
end, "NMI entry")

event.onframeend(function()
    frame_count = frame_count + 1
    if frame_count > CAPTURE_END then return end

    local ppuctrl = rb(0x00FF)
    local ppuctrl_hw = rb(0x0804)
    local initgame = rb(0x00F4)
    local f5 = rb(0x00F5)
    local f6 = rb(0x00F6)
    local mode = rb(0x0012)
    local subphase = rb(0x042D)
    local phase = rb(0x042C)
    local isupd = rb(0x0011)
    local tilebufsel = rb(0x0014)
    local block_idx = rb(0x051D)
    local vaddr = rw(0xFF0802)
    local dynbuf0 = rb(0x0302)

    local pc = 0
    local ok, v = pcall(function() return emu.getregister("M68K PC") end)
    if ok and v then pc = v end

    -- Log every frame for first 10 frames, then key frames, then every 10
    local should_log = false
    if frame_count <= 10 then should_log = true end
    if frame_count >= 20 and frame_count <= 50 then should_log = true end
    if frame_count > 50 and frame_count % 10 == 0 then should_log = true end
    if nmi_this_frame > 0 then should_log = true end

    if should_log then
        log(string.format(
            "f%03d: PC=$%06X ppuCtrl=$%02X hw=$%02X nmiThisFrame=%d initGame=$%02X F5=$%02X F6=$%02X mode=$%02X sub=$%02X phase=$%02X isUpd=$%02X tileBuf=%d blk=%d VADDR=$%04X dyn=$%02X nmi#=%d",
            frame_count, pc, ppuctrl, ppuctrl_hw,
            nmi_this_frame,
            initgame, f5, f6, mode, subphase, phase, isupd, tilebufsel, block_idx,
            vaddr, dynbuf0, nmi_count
        ))
    end

    nmi_this_frame = 0

    if frame_count == CAPTURE_END then
        log("")
        log(string.format("Total NMI entries (exec hook): %d  in %d frames = %.1f%%",
            nmi_count, CAPTURE_END, nmi_count / CAPTURE_END * 100))
        log("=================================================================")
        log("NMI TRACE PROBE COMPLETE")
        log("=================================================================")
        f:close()
        client.exit()
    end
end)

while true do
    emu.frameadvance()
end
