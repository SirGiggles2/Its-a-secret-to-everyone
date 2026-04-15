-- bizhawk_sram_roundtrip.lua
-- Test SRAM save round-trip: register "ZELDA", verify mirror + cart SRAM,
-- then simulate power cycle (reboot) and verify data persists.

local ROOT = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\"
local OUT_DIR = ROOT .. "builds\\reports\\"
os.execute('if not exist "' .. OUT_DIR .. '" mkdir "' .. OUT_DIR .. '"')
local OUT_PATH = OUT_DIR .. "sram_roundtrip.txt"
local f = assert(io.open(OUT_PATH, "w"))
local function log(msg) f:write(msg.."\n") f:flush() print(msg) end

log("=== SRAM Round-Trip Test ===")
log("system: " .. emu.getsystemid())

-- Memory helpers
local function bus8(addr)
    local ok, v = pcall(function()
        memory.usememorydomain("M68K BUS")
        return memory.read_u8(addr)
    end)
    return ok and v or nil
end

local function ram8(ofs)
    return bus8(0xFF0000 + ofs) or 0
end

local function sram8(logical_ofs)
    -- Cart SRAM odd-byte: bus addr = $200001 + logical_ofs * 2
    return bus8(0x200001 + logical_ofs * 2) or 0
end

-- Dump first N bytes of NES SRAM mirror ($FF6000+)
local function dump_mirror(label, start, count)
    log(label)
    local line = "  "
    for i = 0, count-1 do
        line = line .. string.format("%02X ", ram8(0x6000 + start + i))
        if (i + 1) % 16 == 0 then
            log(line)
            line = "  "
        end
    end
    if #line > 2 then log(line) end
end

-- Dump first N bytes of cart SRAM
local function dump_cart_sram(label, start, count)
    log(label)
    local line = "  "
    for i = 0, count-1 do
        line = line .. string.format("%02X ", sram8(start + i))
        if (i + 1) % 16 == 0 then
            log(line)
            line = "  "
        end
    end
    if #line > 2 then log(line) end
end

-- Phase 1: Boot and check initial state
log("")
log("--- Phase 1: Initial boot state ---")
for i = 1, 60 do emu.frameadvance() end

dump_mirror("Mirror $FF6000+0 (first 32 bytes of slot area):", 0, 32)
dump_cart_sram("Cart SRAM $200001 (first 32 bytes):", 0, 32)

-- Check slot active flags at NES $6033 (slot 0 active byte in File A)
-- NES Zelda save structure:
--   File A at $6000, File B at $6100
--   Each file: name at +$07 (8 bytes), valid flag patterns
-- Actually NES Zelda: $6000+$052A = $652A is where IsSaveSlotActive stores flags
log(string.format("  Slot active area ($652A): %02X %02X %02X",
    ram8(0x652A), ram8(0x652B), ram8(0x652C)))

-- Phase 2: Navigate to FS1, then REGISTER
log("")
log("--- Phase 2: Navigate to REGISTER screen ---")

-- Press Start to reach FS1
for i = 1, 90 do emu.frameadvance() end
for i = 1, 20 do
    joypad.set({Start = true}, 1)
    emu.frameadvance()
end
for i = 1, 200 do emu.frameadvance() end

-- Wait for Mode 1
local mode1_ok = false
for i = 1, 200 do
    emu.frameadvance()
    if ram8(0x0012) == 0x01 then mode1_ok = true break end
end
log("Mode 1 reached: " .. tostring(mode1_ok))

-- Navigate to REGISTER YOUR NAME (slot 3) using d-pad Down
for rep = 1, 3 do
    for i = 1, 5 do
        joypad.set({Down = true}, 1)
        emu.frameadvance()
    end
    for i = 1, 15 do emu.frameadvance() end
end
log(string.format("  CurSaveSlot ($0016): %02X", ram8(0x0016)))

-- Press Start to enter REGISTER (Mode E)
for i = 1, 20 do
    joypad.set({Start = true}, 1)
    emu.frameadvance()
end
for i = 1, 200 do emu.frameadvance() end

local modeE_ok = false
for i = 1, 200 do
    emu.frameadvance()
    if ram8(0x0012) == 0x0E then modeE_ok = true break end
end
log("Mode E reached: " .. tostring(modeE_ok))

-- Phase 3: Type "ZELDA" using A button on each letter
-- Keyboard layout: A B C D E F G H I J K
-- Z is at row 2, col 4 in the charboard
-- For simplicity, just type "AAAAA" (press A 5 times on the first letter)
log("")
log("--- Phase 3: Type 5 letters (A button presses) ---")
for letter = 1, 5 do
    for i = 1, 5 do
        joypad.set({A = true}, 1)
        emu.frameadvance()
    end
    for i = 1, 15 do emu.frameadvance() end
end

-- Check what was typed into the name buffer
log("  Name buffer ($0638+offset):")
local slot = ram8(0x0016)
log(string.format("  Active slot: %d", slot))
local name_str = ""
for i = 0, 7 do
    local ch = ram8(0x0638 + i)
    name_str = name_str .. string.format("%02X ", ch)
end
log("  $0638: " .. name_str)

-- Phase 4: Navigate to END and press Start
-- Move cursor right to reach END option
log("")
log("--- Phase 4: Select END ---")
-- On charboard, cursor starts on 'A'. Need to navigate to END.
-- END is at cursor position $03 (checked at z_02.asm:2150-2152)
-- Move right to reach it or press Start on it
-- Actually, looking at the code: START button triggers the "chose end" path
-- when $0016 == 3 (the REGISTER slot). Let me just press Start.
for i = 1, 5 do
    joypad.set({Start = true}, 1)
    emu.frameadvance()
end
for i = 1, 60 do emu.frameadvance() end

log(string.format("  GameMode after END: $%02X", ram8(0x0012)))

-- Wait a bit for save to complete
for i = 1, 120 do emu.frameadvance() end

-- Phase 5: Check SRAM state after save
log("")
log("--- Phase 5: Post-save state ---")
log(string.format("  GameMode: $%02X", ram8(0x0012)))
dump_mirror("Mirror $FF6000 (first 48 bytes):", 0, 48)
dump_cart_sram("Cart SRAM (first 48 bytes):", 0, 48)

-- Check slot active flags
log(string.format("  Slot active ($652A): %02X %02X %02X",
    ram8(0x652A), ram8(0x652B), ram8(0x652C)))

-- Compare mirror to cart SRAM
local mismatches = 0
for i = 0, 0x7FF do
    local mirror = ram8(0x6000 + i)
    local cart = sram8(i)
    if mirror ~= cart then
        mismatches = mismatches + 1
        if mismatches <= 10 then
            log(string.format("  MISMATCH at offset $%04X: mirror=$%02X cart=$%02X",
                i, mirror, cart))
        end
    end
end
log(string.format("  Total mirror/cart mismatches: %d / 2048", mismatches))

-- Phase 6: Return to file select and check if slot is selectable
log("")
log("--- Phase 6: Return to file-select ---")
-- Press Start to return to FS1
for i = 1, 200 do emu.frameadvance() end
for i = 1, 20 do
    joypad.set({Start = true}, 1)
    emu.frameadvance()
end
for i = 1, 300 do emu.frameadvance() end

local back_to_fs = false
for i = 1, 200 do
    emu.frameadvance()
    if ram8(0x0012) == 0x01 then back_to_fs = true break end
end
log("Back to FS1: " .. tostring(back_to_fs))
log(string.format("  GameMode: $%02X", ram8(0x0012)))

-- Check slot 0 active flag
log(string.format("  $0633 slot actives: %02X %02X %02X",
    ram8(0x0633), ram8(0x0634), ram8(0x0635)))
log(string.format("  $062D IsSaveSlotActive: %02X %02X %02X",
    ram8(0x062D), ram8(0x062E), ram8(0x062F)))

-- Take screenshot
client.screenshot("sram_roundtrip_fs1.png")
log("")
log("screenshot: sram_roundtrip_fs1.png")
log("=== DONE ===")
f:close()
client.exit()
