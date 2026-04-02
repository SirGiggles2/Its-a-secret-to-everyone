-- bizhawk_palette_d0_trace_probe.lua
-- Hooks exec at ROM $5EE (lsl.w #1,D0 before palette table lookup)
-- and $5F4 (move.w D2,(VDP_DATA)) to capture NES color index + Genesis color.
-- Runs frames 85-105, then exits.

local ROOT     = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\"
local OUT_DIR  = ROOT .. "builds\\reports\\"
local OUT_PATH = OUT_DIR .. "bizhawk_palette_d0_trace_probe.txt"
os.execute('if not exist "' .. OUT_DIR .. '" mkdir "' .. OUT_DIR .. '"')
local f = assert(io.open(OUT_PATH, "w"))
local function log(msg) f:write(msg.."\n") f:flush() print(msg) end

log("=================================================================")
log("Palette D0 Trace Probe  -- frames 85-105")
log("  Hook at $5EE: lsl.w #1,D0  (D0 = NES color index before shift)")
log("  Hook at $5F4: move.w D2,(VDP_DATA)  (D2 = Genesis color written)")
log("=================================================================")
log("")

local frame_count = 0
local CAPTURE_START = 85
local CAPTURE_END   = 105
local call_count = 0
local active = false

-- Try to read a named register, return nil on failure
local function getreg(name)
    local ok, v = pcall(function() return emu.getregister(name) end)
    if ok and v ~= nil then return v end
    return nil
end

-- Detect which register name scheme this BizHawk build uses
local reg_prefix = ""
local function probe_reg_names()
    local candidates = {"D0","d0","M68K D0","68K D0","CPU D0"}
    for _,n in ipairs(candidates) do
        local v = getreg(n)
        if v ~= nil then
            reg_prefix = n:sub(1, #n-2)  -- strip "D0" to get prefix
            log("Register prefix detected: '" .. reg_prefix .. "' (tested: " .. n .. "=" .. v .. ")")
            return true
        end
    end
    log("WARNING: Could not read any CPU register. Falling back to memory polling only.")
    return false
end

local reg_ok = false

-- Hook at $5EE: before lsl.w #1,D0 — D0 has raw NES color index
local function on_d0_read()
    if not active then return end
    local d0 = getreg(reg_prefix .. "D0") or getreg("D0") or 0xDEAD
    local d0_masked = d0 & 0x3F
    log(string.format("  [frame %d call %d] D0=$%04X  NES_color_idx=$%02X  (PPU entry: %d)",
        frame_count, call_count, d0, d0_masked, d0_masked))
    call_count = call_count + 1
end

-- Hook at $5F4: D2 = Genesis color word about to be written to CRAM
local function on_vdp_write()
    if not active then return end
    local d2 = getreg(reg_prefix .. "D2") or getreg("D2") or 0xDEAD
    local r = (d2 >> 1) & 7
    local g = (d2 >> 5) & 7
    local b = (d2 >> 9) & 7
    log(string.format("    -> Genesis color=$%04X  R=%d G=%d B=%d",
        d2, r, g, b))
end

-- Also read D0 directly from NES RAM: the data byte in DynTileBuf that
-- was just loaded before _ppu_write_7. We can poll NES_RAM to verify.
local function read_bus_u8(addr)
    local ok, v = pcall(function()
        memory.usememorydomain("M68K BUS")
        return memory.read_u8(addr)
    end)
    return ok and v or 0xFF
end

local hooks_registered = false

event.onframeend(function()
    frame_count = frame_count + 1

    if frame_count == CAPTURE_START then
        -- Detect register scheme
        reg_ok = probe_reg_names()

        -- Register exec hooks
        local ok1 = pcall(function()
            memory.registerexec(0x0005EE, on_d0_read, "M68K BUS")
        end)
        local ok2 = pcall(function()
            memory.registerexec(0x0005F4, on_vdp_write, "M68K BUS")
        end)
        if ok1 and ok2 then
            log("Exec hooks registered at $5EE and $5F4 on M68K BUS domain.")
        else
            log("WARNING: registerexec failed on 'M68K BUS'. Trying default domain...")
            pcall(function()
                memory.registerexec(0x0005EE, on_d0_read)
                memory.registerexec(0x0005F4, on_vdp_write)
            end)
        end
        hooks_registered = true
        active = true
    end

    if frame_count >= CAPTURE_START and frame_count <= CAPTURE_END then
        if frame_count ~= CAPTURE_START then
            -- Per-frame header
            log(string.format("-- frame %d: ptr=$%02X/$%02X (NES $%04X) PPU_VADDR=$%04X ppuCtrl=$%02X",
                frame_count,
                read_bus_u8(0xFF0000), read_bus_u8(0xFF0001),
                read_bus_u8(0xFF0001)*256 + read_bus_u8(0xFF0000),
                read_bus_u8(0xFF0802)*256 + read_bus_u8(0xFF0803),
                read_bus_u8(0xFF00FF)))
        end
        call_count = 0
    end

    if frame_count == CAPTURE_END then
        active = false
        log("")
        log("=================================================================")
        log("PALETTE D0 TRACE PROBE COMPLETE")
        log("=================================================================")
        f:close()
        client.exit()
    end
end)

while true do
    emu.frameadvance()
end
