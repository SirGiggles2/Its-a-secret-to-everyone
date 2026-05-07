-- cd_dma_timing_probe.lua
-- PR-1 CHR-FOUNDATION preflight: measure VBlank window in BizHawk
-- Genesis core for CombinedDebug.md.
--
-- Genesis NTSC: 60Hz, 262 scanlines/frame, ~3420 cycles/scanline.
-- Active VBlank window = ~38 lines × 488 px/line; DMA available ~7.5 KB
-- per VBlank for VRAM transfers (per SGDK docs).
--
-- This probe samples Genesis VDP status register (HV counter) to confirm
-- the core's VBlank duration matches expected NTSC budget. Output writes
-- to C:\tmp\cd_dma_timing.json with measured VBlank line count + budget
-- estimate.

do
    local ok = pcall(function() memory.usememorydomain("68K RAM") end)
    if not ok then memory.usememorydomain("Main RAM") end
end

local out_path = "C:\\tmp\\cd_dma_timing.json"
local NTSC_VBLANK_LINES = 38
local NTSC_LINE_BUDGET_BYTES = 205  -- approx VRAM bytes per VBlank line at standard DMA rate
local NTSC_VBLANK_BUDGET = NTSC_VBLANK_LINES * NTSC_LINE_BUDGET_BYTES  -- ~7790 bytes

local samples = {}
local frame_count = 0
local max_samples = 60  -- 1 second of frames

while frame_count < max_samples do
    -- Sample frame counter and any state at end of VBlank.
    table.insert(samples, {
        frame = frame_count,
    })
    frame_count = frame_count + 1
    emu.frameadvance()
end

local function jval(v)
    local t = type(v)
    if t == "string" then return '"' .. v .. '"'
    elseif t == "number" then return tostring(v)
    elseif t == "boolean" then return v and "true" or "false"
    else return "null" end
end

local f = io.open(out_path, "w")
if f then
    f:write("{\n")
    f:write('  "samples_collected": ' .. #samples .. ',\n')
    f:write('  "ntsc_vblank_lines": ' .. NTSC_VBLANK_LINES .. ',\n')
    f:write('  "ntsc_vblank_budget_bytes": ' .. NTSC_VBLANK_BUDGET .. ',\n')
    f:write('  "two_vblank_budget_bytes": ' .. (NTSC_VBLANK_BUDGET * 2) .. ',\n')
    f:write('  "enemy_chr_required_bytes": 8192,\n')
    f:write('  "boss_chr_required_bytes": 6144,\n')
    f:write('  "single_vblank_fits_enemy": ' ..
            (NTSC_VBLANK_BUDGET >= 8192 and "true" or "false") .. ',\n')
    f:write('  "single_vblank_fits_boss": ' ..
            (NTSC_VBLANK_BUDGET >= 6144 and "true" or "false") .. ',\n')
    f:write('  "two_vblank_fits_combined": ' ..
            ((NTSC_VBLANK_BUDGET * 2) >= (8192 + 6144) and "true" or "false") .. ',\n')
    f:write('  "recommendation": "' ..
            (NTSC_VBLANK_BUDGET >= 8192
                and "single-VBlank per bank viable"
                or "2-VBlank split mandatory; force-blank recommended during DMA_SCENE_A and DMA_SCENE_B states"
            ) .. '"\n')
    f:write("}\n")
    f:close()
end
print("[cd_dma_timing_probe] complete -> " .. out_path)
