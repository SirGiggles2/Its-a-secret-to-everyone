-- diag_green.lua: diagnose green screen after z_06 C-mode port
-- Checks NMI cadence, game mode, tile buffer state, and TransferCurTileBuf entry

local REPORT = "C:\\tmp\\diag_green.txt"
local out = {}
local function log(s) out[#out+1] = s end

local function rd(addr)
    return memory.read_u8(addr, "M68K BUS")
end

local function rd16(addr)
    return memory.read_u16_be(addr, "M68K BUS")
end

local NES = 0xFF0000

log("=== Green Screen Diagnostic ===")
log("")

-- Let the game run for a few hundred frames and sample state
local nmi_count = 0
local last_mode = -1
local mode_changes = {}
local tilebuf_sel_samples = {}
local frame_pcs = {}

for f = 1, 300 do
    emu.frameadvance()

    local mode = rd(NES + 0x0012)
    local submode = rd(NES + 0x0013)
    local tilebuf_sel = rd(NES + 0x0014)
    local nmi_flag = rd(NES + 0x005C)
    local ppuctrl = rd(NES + 0x00FF)

    if f <= 10 or f % 30 == 0 then
        log(string.format("f%03d  mode=$%02X sub=$%02X tileSel=$%02X nmiFlag=$%02X ppuCtrl=$%02X",
            f, mode, submode, tilebuf_sel, nmi_flag, ppuctrl))
    end

    if mode ~= last_mode then
        mode_changes[#mode_changes+1] = string.format("f%03d: mode $%02X -> $%02X", f, last_mode, mode)
        last_mode = mode
    end

    if f <= 60 then
        tilebuf_sel_samples[#tilebuf_sel_samples+1] = tilebuf_sel
    end
end

log("")
log("--- Mode Changes ---")
for _, s in ipairs(mode_changes) do log(s) end

log("")
log("--- Tile Buffer Selector (first 60 frames) ---")
local sel_summary = {}
for _, v in ipairs(tilebuf_sel_samples) do
    sel_summary[v] = (sel_summary[v] or 0) + 1
end
for v, c in pairs(sel_summary) do
    log(string.format("  TileSel=$%02X seen %d times", v, c))
end

-- Check TransferCurTileBuf entry point
log("")
log("--- TransferCurTileBuf Sanity ---")
-- Read the first few bytes at the TransferCurTileBuf label in z_06
-- We need to find it in the listing; for now check tile buffer area
local buf302 = rd(NES + 0x0302)
local buf303 = rd(NES + 0x0303)
local buf301 = rd(NES + 0x0301)
local buf300 = rd(NES + 0x0300)
log(string.format("  RAM[$0300]=$%02X  RAM[$0301]=$%02X  RAM[$0302]=$%02X  RAM[$0303]=$%02X",
    buf300, buf301, buf302, buf303))

-- Check if DynTileBuf sentinel is intact
local dyntile = rd(NES + 0x0302)  -- DynTileBuf is at a different offset...
-- Actually DynTileBuf base depends on the project. Check NES_RAM+DynTileBuf.
-- Common: $0334 or similar. Let's read a few known spots.
log(string.format("  RAM[$0334]=$%02X  RAM[$0335]=$%02X", rd(NES + 0x0334), rd(NES + 0x0335)))

-- Check CRAM (palette) state
log("")
log("--- CRAM / Palette Check ---")
for i = 0, 15 do
    local cram = rd16(0xC00000)  -- can't direct-read CRAM easily; skip
end
log("  (CRAM direct read not available via bus; check visually)")

-- Check if InitializedGame flag is set
local init_game = rd(NES + 0x00F4)
local game_mode = rd(NES + 0x0012)
log("")
log(string.format("--- Final State: InitGame=$%02X  Mode=$%02X  Sub=$%02X ---",
    init_game, game_mode, rd(NES + 0x0013)))

-- Check if z_06 C functions are being reached
-- We can check if the level-load submode counter advances
log("")
log("--- Level Load State ---")
log(string.format("  CurLevel=$%02X  GameMode=$%02X", rd(NES + 0x0010), game_mode))
log(string.format("  IsUW=$%02X  Submode=$%02X", rd(NES + 0x0010), rd(NES + 0x0013)))

-- Write report
local f = io.open(REPORT, "w")
if f then
    f:write(table.concat(out, "\n") .. "\n")
    f:close()
end

-- Also print to console
for _, s in ipairs(out) do
    console.log(s)
end

client.exit()
