-- overlay_state.lua
-- BizHawk Lua overlay for RoomRom Genesis ROM. Reads file-static state
-- bytes from 68K RAM and renders a small HUD top-left every frame.
--
-- Usage (already wired into tools/launch_bizhawk.ps1):
--   powershell -File tools/launch_bizhawk.ps1 \
--     -RomPath  RoomRom/out/RoomRom.md \
--     -LuaPath  RoomRom/overlay_state.lua
--
-- Symbol addresses come from the most recent RoomRom build's ELF
-- symbol table (build/toolchain/sgdk_bin/bin/nm.exe rom.out):
--   s_room_id   $00FF0000
--   s_uw_quest  $00FF0001
--   s_uw_level  $00FF0002
--   s_scene     $00FF0048   (0=OW, 1=UW)
--   s_uw_map_id $00FF004D   (0=orig, 1=redux)

local ADDR_ROOM_ID  = 0x0000
local ADDR_UW_QUEST = 0x0001
local ADDR_UW_LEVEL = 0x0002
local ADDR_SCENE    = 0x0048
local ADDR_UW_MAP   = 0x004D

local RAM_DOMAIN = nil
do
    local ok, domains = pcall(memory.getmemorydomainlist)
    if ok and domains then
        for _, d in ipairs(domains) do
            local name = (type(d) == "table") and (d.Name or tostring(d)) or tostring(d)
            local lower = name:lower()
            if lower:find("68k") or lower:find("m68k") or lower == "main ram"
               or lower == "ram" or lower:find("work ram") then
                RAM_DOMAIN = name
                break
            end
        end
    end
end

local function u8(addr)
    if RAM_DOMAIN then
        local ok, v = pcall(function()
            memory.usememorydomain(RAM_DOMAIN)
            return memory.read_u8(addr)
        end)
        if ok then return v end
    end
    memory.usememorydomain("System Bus")
    return memory.read_u8(0xFF0000 + addr)
end

local SCENE_NAME = { [0] = "OW", [1] = "UW" }
local MAP_NAME   = { [0] = "ORIG", [1] = "REDUX" }

local function draw()
    local scene = u8(ADDR_SCENE)
    local rid   = u8(ADDR_ROOM_ID)
    local map   = u8(ADDR_UW_MAP)
    local lvl   = u8(ADDR_UW_LEVEL)
    local q     = u8(ADDR_UW_QUEST)

    local ow_map = "?"
    do
        -- OW shares its own static; for the overlay we report whichever
        -- map applies to the active scene. UW uses s_uw_map_id; OW uses
        -- the OW renderer's static (separate symbol). We only show UW
        -- map_id when UW is active; in OW, we just report scene+room.
        ow_map = ""
    end

    local lines
    if scene == 1 then
        lines = {
            string.format("RoomRom  [%s]", SCENE_NAME[scene] or "?"),
            string.format("level: %d", lvl),
            string.format("quest: %d", q),
            string.format("room:  $%02X", rid),
            string.format("rom:   %s", MAP_NAME[map] or "?"),
        }
    else
        lines = {
            string.format("RoomRom  [%s]", SCENE_NAME[scene] or "?"),
            string.format("room:  $%02X", rid),
        }
    end

    local x, y = 4, 4
    local pad = 2
    local line_h = 10
    local box_w = 96
    local box_h = (#lines * line_h) + (pad * 2)
    pcall(gui.drawBox, x - pad, y - pad,
          x + box_w, y + box_h - pad, 0xFF000000, 0xC0000000)
    for i, ln in ipairs(lines) do
        pcall(gui.text, x, y + (i - 1) * line_h, ln, 0xFFFFFFFF, 0x80000000)
    end
end

while true do
    draw()
    emu.frameadvance()
end
