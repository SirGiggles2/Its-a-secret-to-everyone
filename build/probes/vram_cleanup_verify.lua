-- VRAM cleanup verification probe — post-Phase B/F.
-- Boot ROM, advance past intro/title/file-select to overworld, take
-- screenshot. Validates: build runs; CRAM PAL1/PAL2/PAL3 routing
-- renders Link + items + enemies with correct sub-pal colors.

local OUT = os.getenv("CODEX_BIZHAWK_ROOT") or "."
local SHOTS = OUT .. "/shots"
os.execute('mkdir "' .. SHOTS:gsub("/", "\\") .. '" 2>nul')

local function shot(name)
    client.screenshot(SHOTS .. "/" .. name)
end

local function dump_cram(name)
    local f = io.open(SHOTS .. "/" .. name, "w")
    for i = 0, 63 do
        local lo = memory.read_u8(0xC00000 + i*2 + 1, "VRAM")  -- placeholder; CRAM access differs
        local hi = memory.read_u8(0xC00000 + i*2, "VRAM")
        f:write(string.format("CRAM[%2d] = $%02X%02X\n", i, hi, lo))
    end
    f:close()
end

-- Reset + boot
emu.frameadvance()
for i = 1, 60 do emu.frameadvance() end
shot("01_boot.png")

-- Press Start to advance through title screens
joypad.set({Start = true}, 1)
for i = 1, 4 do emu.frameadvance() end
joypad.set({Start = false}, 1)
for i = 1, 60 do emu.frameadvance() end
shot("02_post_start1.png")

joypad.set({Start = true}, 1)
for i = 1, 4 do emu.frameadvance() end
joypad.set({Start = false}, 1)
for i = 1, 90 do emu.frameadvance() end
shot("03_post_start2.png")

-- Press A on file select to choose file 1
joypad.set({A = true}, 1)
for i = 1, 4 do emu.frameadvance() end
joypad.set({A = false}, 1)
for i = 1, 120 do emu.frameadvance() end
shot("04_post_a.png")

-- More Starts in case more menus
for k = 1, 3 do
    joypad.set({Start = true}, 1)
    for i = 1, 4 do emu.frameadvance() end
    joypad.set({Start = false}, 1)
    for i = 1, 60 do emu.frameadvance() end
end
shot("05_overworld.png")

-- Try to swing sword to test sub-pal 0 colors
joypad.set({B = true}, 1)
for i = 1, 4 do emu.frameadvance() end
joypad.set({B = false}, 1)
for i = 1, 8 do emu.frameadvance() end
shot("06_sword_swing.png")

print("vram_cleanup_verify: 6 screenshots in " .. SHOTS)
client.exitemulator()
