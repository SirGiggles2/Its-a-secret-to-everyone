-- probe_item_pickup.lua — Plan v5c verify item_object_update + item_take_item.
-- Strategy: boot to Mode 5, synthetically inject a $60 drop into slot 1
-- adjacent to Link, idle frames, snapshot inventory before/after.
--
-- Output: C:\tmp\probe_item_pickup.txt + screenshot.

local BASE = 0x8000
local function R(off)   return memory.read_u8(BASE + off, "68K RAM") end
local function W(off,v) memory.write_u8(BASE + off, v, "68K RAM") end
local function idle(n)  for _=1,n do emu.frameadvance() end end
local function press(b,n) for _=1,n do joypad.set(b,1); emu.frameadvance() end end

local OUT  = "C:\\tmp\\probe_item_pickup.txt"
local SHOT = "C:\\tmp\\probe_item_pickup.png"

-- Boot + enter debug-mode gameplay.
idle(60)
press({A=true,B=true,C=true}, 30)
idle(120)

local link_x = R(0x0070); local link_y = R(0x0084)
local gm     = R(0x0012)

-- Snapshot inventory $0657..$067F.
local inv_before = {}
for off=0x0657, 0x067F do inv_before[off] = R(off) end

-- INJECT drop into slot 1 — type=$60, lifetime=$30 (out of grace),
-- item_id=$06 (5-rupee), positioned ON Link.
local SLOT = 1
W(0x0492 + SLOT, 0x01)  -- ALIVE_FLAG
W(0x034F + SLOT, 0x60)  -- ENEMY_TYPE = DroppedItem
W(0x0405 + SLOT, 0x00)  -- ENEMY_METASTATE
W(0x03A8 + SLOT, 0x30)  -- ITEM_LIFETIME
W(0x00AC + SLOT, 0x06)  -- ITEM_ID = 5-rupee   (also = OBJ_STATE alias)
W(0x0070 + SLOT, link_x)
W(0x0084 + SLOT, link_y + 3)

-- Snapshot slot before tick.
local f = io.open(OUT, "w")
f:write("probe_item_pickup — Plan v5c (verify item_object_update + take_item)\n")
f:write("====================================================================\n\n")
f:write(string.format("GameMode=$%02X Link=($%02X,$%02X)\n", gm, link_x, link_y))
f:write(string.format("INJECTED slot=%d type=$60 lt=$30 id=$06 (5-rupee) on Link\n", SLOT))
f:write(string.format("PRE  slot=%d: alive=$%02X type=$%02X lt=$%02X id=$%02X x=$%02X y=$%02X\n",
    SLOT, R(0x0492+SLOT), R(0x034F+SLOT), R(0x03A8+SLOT), R(0x00AC+SLOT),
    R(0x0070+SLOT), R(0x0084+SLOT)))

-- Let item_object_update fire — enemy_loop ticks once per frame.
idle(8)

f:write(string.format("POST slot=%d: alive=$%02X type=$%02X lt=$%02X id=$%02X x=$%02X y=$%02X\n",
    SLOT, R(0x0492+SLOT), R(0x034F+SLOT), R(0x03A8+SLOT), R(0x00AC+SLOT),
    R(0x0070+SLOT), R(0x0084+SLOT)))

-- Snapshot inventory after.
local inv_after = {}
for off=0x0657, 0x067F do inv_after[off] = R(off) end

local diffs = {}
for off=0x0657, 0x067F do
    if inv_before[off] ~= inv_after[off] then
        diffs[#diffs+1] = {off=off, b=inv_before[off], a=inv_after[off]}
    end
end

f:write(string.format("\nINVENTORY DIFFS: %d cell(s)\n", #diffs))
for _, d in ipairs(diffs) do
    f:write(string.format("  $%04X: $%02X -> $%02X  (delta=%+d)\n",
        d.off, d.b, d.a, d.a - d.b))
end

-- Also probe pickup-side flags written by item_take_item.
f:write(string.format("\nITEM_SFX_PRIMARY $00A2 = $%02X  (8 expected)\n", R(0x00A2)))
f:write(string.format("ITEM_PICKUP_ID   $00AB = $%02X  (6 expected if not Mode 5 path)\n", R(0x00AB)))
f:write(string.format("ITEM_FREEZE_FLAG $00E0 = $%02X\n", R(0x00E0)))

local post_alive = R(0x0492 + SLOT)
local post_type  = R(0x034F + SLOT)

if #diffs == 0 and post_type == 0x60 then
    f:write("\nVERDICT: RED — item_object_update never fired (drop frozen)\n")
elseif #diffs == 0 then
    f:write("\nVERDICT: YELLOW — slot decayed but no inventory write\n")
elseif post_alive ~= 0 or post_type ~= 0 then
    f:write("\nVERDICT: YELLOW — inv changed but slot not destroyed\n")
else
    f:write("\nVERDICT: GREEN — Link pickup -> item_take_item -> inventory updated + slot cleared\n")
end

f:close()
client.screenshot(SHOT)
gui.text(8, 8, string.format("pickup probe done diffs=%d", #diffs))
client.exit()
