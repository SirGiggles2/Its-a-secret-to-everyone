-- SAT DMA Lag Fix verification probe.
-- Boots Debug.md, presses A+B+C at title, runs gameplay, captures screenshot
-- + SAT contents to verify Plan A (single VDP_updateSprites(10, DMA_QUEUE)
-- in roomrom_debug_tick) renders correctly.

local OUTPUT_DIR = os.getenv("CODEX_PROBE_OUT") or "."
local STAGE1_FRAMES = 60      -- boot + title
local CHORD_FRAMES = 30       -- hold A+B+C
local STAGE2_FRAMES = 90      -- post-debug-enter

local function press(buttons, frames)
    for _ = 1, frames do
        joypad.set(buttons, 1)
        emu.frameadvance()
    end
end

local function read16(addr)
    local hi = mainmemory.read_u8(addr - 0xFF0000)
    local lo = mainmemory.read_u8(addr - 0xFF0000 + 1)
    return (hi * 256) + lo
end

-- Stage 1: boot to title
press({}, STAGE1_FRAMES)

-- Stage 2: A+B+C chord to enter debug mode
press({A=true, B=true, C=true}, CHORD_FRAMES)

-- Stage 3: release + run gameplay
press({}, STAGE2_FRAMES)

-- Capture screenshot
client.screenshot(OUTPUT_DIR .. "/sat_dma_lag_verify.png")

-- Sample SAT contents from VRAM ($F800 default SAT location, 4 bytes/sprite x 80)
-- SGDK relocates SAT via VDP_setSpriteListAddress; default Debug = $F800
local sat_sample = {}
for slot = 0, 9 do
    -- VDP register read via vdp domain — slot * 8 bytes since vdpSpriteCache is 8B/sprite
    -- (SGDK shadow SAT is 8B; VRAM SAT is 8B compacted: y_y_size_link, x_x_attr_attr)
    local base = 0xF800 + slot * 8
    local b0 = memory.read_u8(base, "VRAM")
    local b1 = memory.read_u8(base + 1, "VRAM")
    local b2 = memory.read_u8(base + 2, "VRAM")
    local b3 = memory.read_u8(base + 3, "VRAM")
    local b4 = memory.read_u8(base + 4, "VRAM")
    local b5 = memory.read_u8(base + 5, "VRAM")
    local b6 = memory.read_u8(base + 6, "VRAM")
    local b7 = memory.read_u8(base + 7, "VRAM")
    sat_sample[slot] = string.format(
        "slot %d: %02X %02X %02X %02X %02X %02X %02X %02X",
        slot, b0, b1, b2, b3, b4, b5, b6, b7)
end

-- Sample state mirror at $FF0xxx (publish_state_mirror writes 120B)
-- The mirror is at a fixed location — let's just dump first 16 bytes from common spots
local mirror_dump = {}
for i = 0, 31 do
    mirror_dump[i] = string.format("%02X", mainmemory.read_u8(i))
end

-- Write summary file
local f = io.open(OUTPUT_DIR .. "/sat_dma_lag_verify.txt", "w")
f:write("SAT DMA Lag Fix Verification\n")
f:write("============================\n\n")
f:write("Frames advanced: " .. (STAGE1_FRAMES + CHORD_FRAMES + STAGE2_FRAMES) .. "\n\n")
f:write("SAT VRAM contents (slots 0..9):\n")
for slot = 0, 9 do
    f:write("  " .. sat_sample[slot] .. "\n")
end
f:write("\nMirror first 32B at $FF0000: " .. table.concat(mirror_dump, " ") .. "\n")
f:close()

print("SAT DMA Lag Fix probe complete. Screenshot + dump written.")
client.exit()
