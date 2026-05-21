-- audit_drop_items.lua — capture which ITEM each enemy drops on kill.
-- 60-frame wait post-death lets drop spawn fully transition slot to $60.
-- Captures all 11 slots' type+state+anim_frame to identify dropped item.
--
-- NES drop dispatch: DropItemTable[row*8 + WorldKillCycle_col].
--   Row 0: $07/$08/$0E/$04/$0F/$23 (DropItemMonsterTypes0)
--   Row 1: $21/$22/$0D/$10/$13/$28/$2A/$27/$16
--   Row 2: $09/$0A/$03/$01/$12/$06/$0B/$24/$30
--   Row 3: default (rest including $02/$05/$0C/$1A/$1E/$2B/$2C/$2D/$3F/$40)
--
-- Item codes per NES Z_04.asm:11096+ DropItemTable:
--   $22=heart $18=5-rupee $23=10-rupee $0F=bombs $21=rupee $00=NONE

local function R(o) return memory.read_u8(o, "68K RAM") end
local function W(o,v) memory.write_u8(o, v, "68K RAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end

idle(60)
for _ = 1, 30 do joypad.set({A=true,B=true,C=true},1); emu.frameadvance() end
joypad.set({},1)
idle(60)

local f = io.open("C:/tmp/audit_drop_items.txt", "w")
f:write("# Drop-item audit | type kill_cycle slot_type slot_state slot_anim drop_item_id\n")

local IN_SCOPE = {
    0x01, 0x02, 0x03, 0x04, 0x05, 0x06,
    0x0B, 0x0C, 0x10, 0x12, 0x13, 0x14, 0x15,
    0x16, 0x17, 0x1A, 0x1B, 0x1C, 0x1D, 0x1E,
    0x21, 0x22, 0x27, 0x28, 0x2A,
    0x2B, 0x2C, 0x2D, 0x30, 0x3F, 0x40
}

for _, t in ipairs(IN_SCOPE) do
    -- Reset WorldKillCycle to deterministic value
    W(0x8627, 0x00)        -- WorldKillCycle col 0 (best guess address)

    -- Arm spawn slot 1
    W(0x77D0, 0x46) W(0x77D1, 0x58)
    W(0x77D2, t) W(0x77D3, 0x60) W(0x77D4, 0x78)
    W(0x77D5, 0x01) W(0x77D6, 0x01) W(0x77D7, 0x00) W(0x77D8, 0x77)
    emu.frameadvance()
    for _ = 1, 4 do emu.frameadvance() end

    W(0x8018, 0x40)
    for i = 1, 12 do W(0x8018 + i, 0x00) end

    -- Real death dispatch
    local s = 1
    W(0x77E0, 0x44) W(0x77E1, 0x44)
    W(0x77E2, s) W(0x77E3, 0x10) W(0x77E4, 0xFF)
    emu.frameadvance()

    -- 60-frame wait for drop spawn to fully transition
    for _ = 1, 60 do emu.frameadvance() end

    -- Scan all slots for drop indicator
    local drop_slot = -1
    local drop_type = 0
    local drop_state = 0
    local drop_anim = 0
    for ds = 1, 11 do
        local dt = R(0x834F+ds)
        if dt == 0x60 or (dt >= 0x61 and dt <= 0x66) then
            drop_slot = ds
            drop_type = dt
            drop_state = R(0x80AC+ds)
            drop_anim = R(0x83E4+ds)
            break
        end
    end

    f:write(string.format("T$%02X cycle=0 drop_slot=%d drop_type=$%02X state=$%02X anim=$%02X\n",
        t, drop_slot, drop_type, drop_state, drop_anim))

    W(0x77D0, 0) W(0x77D1, 0)
    W(0x77E0, 0) W(0x77E1, 0)
end

f:close()
client.exit()
