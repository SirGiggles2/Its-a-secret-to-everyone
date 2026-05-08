-- pr4_state_machine.lua
-- PR-4a CHR-TRANSIENT-SCENE state machine probe (CombinedDebug).
-- Boots CombinedDebug, holds A+B+C chord to transition title -> RoomRom.
-- Then drives multiple scene_load events via START toggles (OW <-> UW).
-- Samples level_chr_swap state from RAM mirror at $FF7270..$FF7277.
-- Confirms IDLE -> REQUESTED -> READY collapse + request_count climb.

local OUT_DIR = "C:\\tmp\\pr4_state_machine"
os.execute("mkdir " .. OUT_DIR .. " 2>nul")

do
    local ok = pcall(function() memory.usememorydomain("68K RAM") end)
    if not ok then memory.usememorydomain("Main RAM") end
end

local STATE_MIRROR = 0x7200
local PROBE_BASE   = 0x7000  -- combined_debug a4 probe block ($FF7000)

local STATE_NAMES = {
    [0] = "IDLE",       [1] = "REQUESTED", [2] = "BLANK",
    [3] = "DMA_SCENE_A",[4] = "DMA_SCENE_B",[5] = "READY",
}

local SCENE_NAMES = {
    [0] = "BOOT", [1] = "TITLE", [2] = "FILESELECT", [3] = "OW",
    [4] = "UW_L1", [5] = "UW_L2", [6] = "UW_L3", [7] = "UW_L4",
    [8] = "UW_L5", [9] = "UW_L6", [10] = "UW_L7", [11] = "UW_L8",
    [12] = "UW_L9",
}

local function read_u8(off)  return memory.read_u8(STATE_MIRROR + off) end
local function read_u16(off) return read_u8(off) * 256 + read_u8(off + 1) end
local function read_u32(off)
    return read_u8(off) * 16777216 +
           read_u8(off + 1) * 65536 +
           read_u8(off + 2) * 256 +
           read_u8(off + 3)
end

-- combined_debug state byte at PROBE_BASE+13 (0=TITLE, 1=ROOMROM).
local function read_cd_state()
    return memory.read_u8(PROBE_BASE + 13)
end

local snaps = {}
local function snap(name, fcount)
    local s  = read_u8(112)
    local sc = read_u8(113)
    local rc = read_u16(114)
    local bd = read_u32(116)
    local rid = read_u8(5)
    local cd = read_cd_state()
    snaps[#snaps + 1] = {
        name = name, frame = fcount,
        state = s, state_name = STATE_NAMES[s] or "?",
        scene = sc, scene_name = SCENE_NAMES[sc] or "?",
        request_count = rc, total_bytes_dma = bd, room_id = rid,
        cd_state = cd,
    }
    print(string.format(
        "[pr4] %-18s f=%-3d  cd=%d  state=%-12s scene=%-10s reqs=%-3d  bytes_dma=%-6d  rid=$%02X",
        name, fcount, cd, STATE_NAMES[s] or "?", SCENE_NAMES[sc] or "?",
        rc, bd, rid))
end

-- Hold A+B+C chord across frames 60..65 to drive transition title -> RoomRom.
-- combined_debug needs an EDGE: prev_joy chord != current chord, so press
-- briefly then release then press again.
local CHORD_FRAMES = {}
for f = 60, 64 do CHORD_FRAMES[f] = true end

-- After RoomRom enters (~frame 70), exercise scene_load via:
--   frame 200: press C (map toggle, RoomRom main.c:1426 -> roomrom_scene_load)
--   frame 240: press Start (scene toggle, main.c:1410 -> roomrom_scene_load)
--   frame 280: press C again (map toggle back)
local C_FRAMES     = { [200] = true, [201] = true, [280] = true, [281] = true }
local START_FRAMES = { [240] = true, [241] = true }

local fcount = 0
local TOTAL = 340
while fcount < TOTAL do
    local input = {}
    if CHORD_FRAMES[fcount] then
        input.A = true
        input.B = true
        input.C = true
    end
    if START_FRAMES[fcount] then
        input.Start = true
        input["P1 Start"] = true
    end
    if C_FRAMES[fcount] then input.C = true end
    joypad.set(input, 1)

    if fcount == 30  then snap("boot_t30",     fcount) end
    if fcount == 50  then snap("pre_chord",    fcount) end
    if fcount == 70  then snap("post_chord",   fcount) end
    if fcount == 100 then snap("settle_t100",  fcount) end
    if fcount == 150 then snap("steady_t150",  fcount) end
    if fcount == 199 then snap("pre_swap1",    fcount) end
    if fcount == 205 then snap("post_swap1",   fcount) end
    if fcount == 215 then snap("settle1_t215", fcount) end
    if fcount == 245 then snap("post_swap2",   fcount) end
    if fcount == 285 then snap("post_swap3",   fcount) end
    if fcount == 320 then snap("steady_t320",  fcount) end

    fcount = fcount + 1
    emu.frameadvance()
end

client.screenshot(OUT_DIR .. "\\stable.png")

local rep = io.open(OUT_DIR .. "\\report.json", "w")
if rep then
    rep:write("{\n  \"snapshots\": [\n")
    for i, s in ipairs(snaps) do
        rep:write(string.format(
            "    {\"name\":\"%s\",\"frame\":%d,\"cd_state\":%d,\"state\":%d," ..
            "\"state_name\":\"%s\",\"scene\":%d,\"scene_name\":\"%s\"," ..
            "\"request_count\":%d,\"total_bytes_dma\":%d," ..
            "\"room_id\":%d}%s\n",
            s.name, s.frame, s.cd_state, s.state, s.state_name,
            s.scene, s.scene_name, s.request_count, s.total_bytes_dma,
            s.room_id,
            i == #snaps and "" or ","))
    end
    rep:write("  ]\n}\n")
    rep:close()
end

print("[pr4] DONE -> " .. OUT_DIR)
client.exit()
