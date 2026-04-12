-- bizhawk_sram_verify.lua
-- Verify SRAM save round-trip after P31 (FileBChecksums relocated to RAM).
-- Flow: boot → FS1 → REGISTER → type name → cycle SELECT to end → START → verify FS1.

local ROOT = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\"
local OUT_DIR = ROOT .. "builds\\reports\\"
os.execute('if not exist "' .. OUT_DIR .. '" mkdir "' .. OUT_DIR .. '"')
local OUT_PATH = OUT_DIR .. "sram_verify.txt"
local f = assert(io.open(OUT_PATH, "w"))
local function log(msg) f:write(msg.."\n") f:flush() print(msg) end

log("=== SRAM Verify (P31: FileBChecksums in RAM) ===")
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

local function wait_frames(n)
    for i = 1, n do emu.frameadvance() end
end

local function press(btn, dur, gap)
    dur = dur or 5
    gap = gap or 10
    for i = 1, dur do
        joypad.set({[btn] = true}, 1)
        emu.frameadvance()
    end
    wait_frames(gap)
end

local function wait_for_mode(target_mode, max_frames)
    max_frames = max_frames or 500
    for i = 1, max_frames do
        emu.frameadvance()
        if ram8(0x0012) == target_mode then
            return true, i
        end
    end
    return false, max_frames
end

-- ====================================================================
-- Phase 1: Boot, reach FS1
-- ====================================================================
log("")
log("--- Phase 1: Boot to FS1 ---")
wait_frames(120)
press("Start", 10, 10)
local ok, fr = wait_for_mode(0x01, 400)
log("FS1 reached: " .. tostring(ok) .. " (frame " .. fr .. ")")
log(string.format("  GameMode: $%02X  CurSaveSlot: $%02X",
    ram8(0x0012), ram8(0x0016)))

-- Check initial slot active flags
log(string.format("  IsSaveSlotActive: $0633[0..2] = %02X %02X %02X",
    ram8(0x0633), ram8(0x0634), ram8(0x0635)))
log(string.format("  IsSaveSlotActive: $0633[3..4] = %02X %02X (register/eliminate)",
    ram8(0x0636), ram8(0x0637)))

-- ====================================================================
-- Phase 2: Navigate to REGISTER YOUR NAME (FS1 slot 3)
-- ====================================================================
log("")
log("--- Phase 2: Navigate to REGISTER ---")
-- Need to navigate cursor down to position 3 (REGISTER YOUR NAME)
-- $0016 cycles 0..4, skipping inactive slots. Press Down (Select in NES
-- terms but it's D-pad Down on FS1) to reach slot 3.
-- Actually on FS1, the Select button ($20 in $F8) changes cursor.
-- Wait - FS1 uses Down ($04 in $00FA), not Select.
-- Let me check: FS1 Sub0 line 3813: andi.b #$20,D0 → this is NES SELECT.
-- NES SELECT = Genesis C.

-- On fresh game, slots 0/1/2 are inactive so ChangeSelection skips them.
-- Slot 3 = REGISTER and slot 4 = ELIMINATE have active flags.
-- Let me just press C (Genesis = NES Select) to change selection.
for rep = 1, 6 do
    press("C", 5, 15)
    log(string.format("  After C press %d: CurSaveSlot=$%02X", rep, ram8(0x0016)))
    if ram8(0x0016) == 3 then break end
end

log(string.format("  Final CurSaveSlot: $%02X", ram8(0x0016)))

-- Press Start to enter Mode E (REGISTER)
press("Start", 10, 10)
ok, fr = wait_for_mode(0x0E, 600)
log("Mode E reached: " .. tostring(ok) .. " (frame " .. fr .. ")")
log(string.format("  GameMode: $%02X  CurSaveSlot: $%02X",
    ram8(0x0012), ram8(0x0016)))

-- Wait for init to complete (submodes cycle through)
wait_frames(120)

log(string.format("  After init settle: GameMode=$%02X CurSaveSlot=$%02X",
    ram8(0x0012), ram8(0x0016)))
log(string.format("  CharBoardIndex ($041F): $%02X", ram8(0x041F)))
log(string.format("  InitializedNameField ($0420): $%02X", ram8(0x0420)))
log(string.format("  NameCharOffset ($0421): $%02X", ram8(0x0421)))

-- ====================================================================
-- Phase 3: Type a name (press Genesis A = NES B = letter write via P29)
-- ====================================================================
log("")
log("--- Phase 3: Type 5 letters ---")
-- Genesis A maps to NES B ($40), which P29 swaps to trigger the letter write path.
for letter = 1, 5 do
    press("A", 3, 12)
    local ch = ram8(0x0638 + letter - 1)
    log(string.format("  Letter %d: $0638+%d = $%02X  CharBoardIdx=$%02X  NameCharOfs=$%02X",
        letter, letter-1, ch, ram8(0x041F), ram8(0x0421)))
end

-- Dump name buffer
local name = ""
for i = 0, 7 do
    name = name .. string.format("%02X ", ram8(0x0638 + i))
end
log("  Name buffer $0638: " .. name)

-- ====================================================================
-- Phase 4: Cycle SELECT (Genesis C) to advance $0016 past all slots
-- ====================================================================
log("")
log("--- Phase 4: Cycle SELECT to reach $0016=3 ---")
-- UpdateModeEandF_Idle checks SELECT ($20 in $F8) → increments $0016.
-- We need $0016 to reach 3 so START triggers ChoseEnd.
for rep = 1, 5 do
    press("C", 3, 15)
    local slot = ram8(0x0016)
    log(string.format("  After C press %d: CurSaveSlot=$%02X", rep, slot))
    if slot == 3 then break end
end

local final_slot = ram8(0x0016)
log(string.format("  Final CurSaveSlot: $%02X (need 3)", final_slot))

-- ====================================================================
-- Phase 5: Press Start to trigger ChoseEnd
-- ====================================================================
log("")
log("--- Phase 5: Press Start → ChoseEnd ---")
press("Start", 10, 10)
wait_frames(30)
log(string.format("  GameMode after Start: $%02X", ram8(0x0012)))

-- Wait for mode transitions: $0E → $0D (save) → $00 (demo)
-- ChoseEnd jumps to UpdateModeDSave_Sub2 which sets Mode=$00 SubMode=$01
ok, fr = wait_for_mode(0x00, 600)
log(string.format("  Mode 0 reached: %s (frame %d)", tostring(ok), fr))
log(string.format("  GameMode=$%02X SubMode=$%02X", ram8(0x0012), ram8(0x0013)))

-- ====================================================================
-- Phase 6: Check FileBChecksums in RAM ($FF1200)
-- ====================================================================
log("")
log("--- Phase 6: FileBChecksums RAM check ---")
log(string.format("  FileBChecksums $FF1200: %02X %02X %02X %02X %02X %02X",
    bus8(0xFF1200) or 0xFF, bus8(0xFF1201) or 0xFF,
    bus8(0xFF1202) or 0xFF, bus8(0xFF1203) or 0xFF,
    bus8(0xFF1204) or 0xFF, bus8(0xFF1205) or 0xFF))

-- Check $652A flags (File B uncommitted markers)
log(string.format("  $652A uncommitted flags: %02X %02X %02X",
    ram8(0x652A), ram8(0x652B), ram8(0x652C)))

-- ====================================================================
-- Phase 7: Wait for Mode 0 Sub 1 to run (validates File B → File A)
-- ====================================================================
log("")
log("--- Phase 7: Wait for File B → File A validation ---")
-- Mode 0 Sub 1 should run immediately after Sub 0.
-- Let's wait a bit and check the results.
wait_frames(120)

log(string.format("  GameMode=$%02X SubMode=$%02X", ram8(0x0012), ram8(0x0013)))
log(string.format("  IsSaveSlotActive $0633[0..2]: %02X %02X %02X",
    ram8(0x0633), ram8(0x0634), ram8(0x0635)))

-- Check File A markers (valid save has $5A and $A5)
log(string.format("  File A marker $651E[0..2]: %02X %02X %02X",
    ram8(0x651E), ram8(0x651F), ram8(0x6520)))
log(string.format("  File A marker $6521[0..2]: %02X %02X %02X",
    ram8(0x6521), ram8(0x6522), ram8(0x6523)))

-- ====================================================================
-- Phase 8: Press Start → reach FS1, check slot visibility
-- ====================================================================
log("")
log("--- Phase 8: Return to FS1 ---")
press("Start", 10, 10)
ok, fr = wait_for_mode(0x01, 600)
log(string.format("  FS1 reached: %s (frame %d)", tostring(ok), fr))
log(string.format("  GameMode=$%02X SubMode=$%02X CurSaveSlot=$%02X",
    ram8(0x0012), ram8(0x0013), ram8(0x0016)))

-- Check slot active flags - THIS IS THE KEY CHECK
log(string.format("  IsSaveSlotActive $0633[0..4]: %02X %02X %02X %02X %02X",
    ram8(0x0633), ram8(0x0634), ram8(0x0635), ram8(0x0636), ram8(0x0637)))

-- Check the name in File A SRAM mirror
local nameA = ""
for i = 0, 7 do
    nameA = nameA .. string.format("%02X ", ram8(0x6007 + i))
end
log("  File A slot 0 name ($6007): " .. nameA)

-- Check SRAM mirror vs cart SRAM
local mismatches = 0
for i = 0, 0x7FF do
    local mirror = ram8(0x6000 + i)
    local cart = bus8(0x200001 + i * 2) or 0xFF
    if mirror ~= cart then
        mismatches = mismatches + 1
        if mismatches <= 5 then
            log(string.format("  MISMATCH ofs=$%04X mirror=$%02X cart=$%02X",
                i, mirror, cart))
        end
    end
end
log(string.format("  Mirror/cart SRAM mismatches: %d / 2048", mismatches))

-- ====================================================================
-- Summary
-- ====================================================================
log("")
log("=== SUMMARY ===")
local slot0_active = ram8(0x0633)
if slot0_active ~= 0 then
    log("  [PASS] Slot 0 is active ($0633 = $" .. string.format("%02X", slot0_active) .. ")")
else
    log("  [FAIL] Slot 0 is NOT active ($0633 = $00)")
end

if mismatches == 0 then
    log("  [PASS] Mirror/cart SRAM match (0 mismatches)")
elseif mismatches < 10 then
    log("  [WARN] Minor SRAM mismatches (" .. mismatches .. ")")
else
    log("  [FAIL] Many SRAM mismatches (" .. mismatches .. ")")
end

log("=== DONE ===")
f:close()

-- Take screenshot
client.screenshot("sram_verify_fs1.png")
client.exit()
