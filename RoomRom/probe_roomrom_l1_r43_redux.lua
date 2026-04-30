-- probe_roomrom_l1_r43_redux.lua
-- Genesis-side probe: boots RoomRom, toggles to UW + redux map,
-- navigates D-pad to L1 room $43, captures PNG to verify Redux UW
-- CHR shows bombable-wall crack pattern.

local OUT_PNG = os.getenv("CODEX_ROOMROM_OUT_PNG")
    or "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\RoomRom\\out\\roomrom_l1_r43_redux.png"

local function safe_set(pad)
    local ok = pcall(function() joypad.set(pad or {}, 1) end)
    if not ok then joypad.set(pad or {}) end
end

local function press(button, hold, release)
    hold = hold or 2
    release = release or 8
    for _ = 1, hold do
        safe_set({[button] = true, ["P1 " .. button] = true})
        emu.frameadvance()
    end
    for _ = 1, release do
        safe_set({})
        emu.frameadvance()
    end
end

local function settle(frames)
    for _ = 1, (frames or 30) do
        safe_set({})
        emu.frameadvance()
    end
end

-- Boot warm-up (Genesis takes time to clear screen and run main()).
settle(120)

-- B: SCENE_OW -> SCENE_UW (resets s_room_id to 0x00).
press("B", 2, 30)

-- C: map ORIG -> REDUX. (Reuploads redux_uw_bg_chr.)
press("C", 2, 30)

-- D-pad to row=4 col=3 ($43). Currently at row=0 col=0.
press("Right", 2, 12)  -- col=1
press("Right", 2, 12)  -- col=2
press("Right", 2, 12)  -- col=3
press("Down",  2, 12)  -- row=1
press("Down",  2, 12)  -- row=2
press("Down",  2, 12)  -- row=3
press("Down",  2, 12)  -- row=4

-- Settle, then dump state + screenshot.
settle(60)

-- Read Genesis 68K RAM statics (offsets per nm.exe rom.out):
--   s_room_id   $00FF0000
--   s_uw_quest  $00FF0001
--   s_uw_level  $00FF0002
--   s_scene     $00FF0048
--   s_uw_map_id $00FF004D
local function read_ram(addr)
    local domains = {"68K RAM", "M68K BUS", "M68K RAM", "Main RAM", "Work RAM", "RAM"}
    for _, d in ipairs(domains) do
        local ok, v = pcall(function()
            memory.usememorydomain(d)
            return memory.read_u8(addr)
        end)
        if ok then return v end
    end
    return -1
end

local rid = read_ram(0x0000)
local q   = read_ram(0x0001)
local lvl = read_ram(0x0002)
local scn = read_ram(0x0048)
local map = read_ram(0x004D)

local f = assert(io.open(OUT_PNG .. ".state.txt", "w"))
f:write(string.format("scene=%d level=%d quest=%d map=%d room_id=0x%02X\n",
    scn, lvl, q, map, rid))
f:close()

client.screenshot(OUT_PNG)
client.exit()
