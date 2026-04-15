-- bizhawk_record_bootflow.lua
--
-- Records per-frame joypad input while the user plays from boot into
-- gameplay (Mode 5 / room $77 / Link visible). Writes a text log that the
-- T35 capture probes replay verbatim instead of running their own boot-time
-- state machine. One recording per system: NES or Genesis.
--
-- Usage (Genesis):
--   tools\bizhawk_record_bootflow.lua (via EmuHawk --lua=) on ROM builds/whatif.md
--   1. Press buttons to boot into gameplay (title → FS1 → register → start)
--   2. Probe auto-stops when Mode=$05 + room=$77 + Link stable 60 frames
--   3. Output: tools/bootflow_gen.txt
--
-- Usage (NES):
--   Same script on the NES ROM. Output: tools/bootflow_nes.txt
--
-- File format (one line per frame, each col space-separated):
--   frame_num U D L R A B C S
-- where each column is 0 or 1 (pressed). C is only meaningful on Genesis;
-- on NES the "C" column is always 0 (NES has no C; NES Select is logged
-- in a separate 'Select' slot recorded as column C=2 sentinel? — actually
-- simpler: NES ends up saving a row with S=Select, and the replay maps
-- column positions back to the correct system's button names).
--
-- Replay contract:
--   The replayer (bootflow_replay.lua) maps column → native button name per
--   system, using explicit mappings in the file header.

local SYSTEM = emu.getsystemid and emu.getsystemid() or "UNKNOWN"
-- Normalize common returns: "NES", "GEN" or "Genesis"
local is_nes = (SYSTEM == "NES")
local is_gen = (SYSTEM == "GEN") or (SYSTEM == "Genesis") or (SYSTEM == "MD")

local OUT_DIR  = (function()
    local src = debug.getinfo(1, "S").source
    if src:sub(1, 1) == "@" then src = src:sub(2) end
    src = src:gsub("/", "\\")
    return src:match("^(.*)\\[^\\]+$") or "."
end)()

local OUT_PATH = OUT_DIR .. (is_nes and "\\bootflow_nes.txt" or "\\bootflow_gen.txt")

-- Button column order (same for both systems; meaning differs per system).
-- Columns: U D L R A B C S
-- NES:     U D L R A B - Select/Start (C always 0, S = Start)
-- Gen:     U D L R A B C Start
local COL_BUTTONS = { "Up", "Down", "Left", "Right", "A", "B", "C", "Start" }

-- Per-system read mapping: given joypad.get table, return 0/1 per column
local function read_cols(j)
    local vals = {}
    if is_nes then
        vals[1] = j["Up"]     and 1 or 0
        vals[2] = j["Down"]   and 1 or 0
        vals[3] = j["Left"]   and 1 or 0
        vals[4] = j["Right"]  and 1 or 0
        vals[5] = j["A"]      and 1 or 0
        vals[6] = j["B"]      and 1 or 0
        vals[7] = (j["Select"] and 1 or 0)   -- NES "Select" stored in column C slot
        vals[8] = j["Start"]  and 1 or 0
    else
        vals[1] = (j["Up"]    or j["P1 Up"])    and 1 or 0
        vals[2] = (j["Down"]  or j["P1 Down"])  and 1 or 0
        vals[3] = (j["Left"]  or j["P1 Left"])  and 1 or 0
        vals[4] = (j["Right"] or j["P1 Right"]) and 1 or 0
        vals[5] = (j["A"]     or j["P1 A"])     and 1 or 0
        vals[6] = (j["B"]     or j["P1 B"])     and 1 or 0
        vals[7] = (j["C"]     or j["P1 C"])     and 1 or 0
        vals[8] = (j["Start"] or j["P1 Start"]) and 1 or 0
    end
    return vals
end

-- Gameplay-reached detection reuses T35's stability gate.
local AVAILABLE = {}
do
    local ok, lst = pcall(memory.getmemorydomainlist)
    if ok and type(lst) == "table" then
        for _, n in ipairs(lst) do AVAILABLE[n] = true end
    end
end

local function ram_u8(addr_bus_or_cpu)
    -- NES: cpu addr. Gen: bus addr $FF00xx.
    if is_nes then
        local candidates = { "System Bus", "RAM", "Main RAM", "WRAM" }
        for _, dn in ipairs(candidates) do
            if AVAILABLE[dn] then
                local ok, v = pcall(function()
                    memory.usememorydomain(dn)
                    local a = addr_bus_or_cpu
                    if dn ~= "System Bus" and a < 0x2000 then a = a % 0x0800 end
                    return memory.read_u8(a)
                end)
                if ok then return v end
            end
        end
        return 0
    else
        local ofs = addr_bus_or_cpu - 0xFF0000
        for _, dn in ipairs({ "68K RAM", "Main RAM" }) do
            if AVAILABLE[dn] then
                local ok, v = pcall(function()
                    memory.usememorydomain(dn)
                    return memory.read_u8(ofs)
                end)
                if ok then return v end
            end
        end
        if AVAILABLE["M68K BUS"] then
            local ok, v = pcall(function()
                memory.usememorydomain("M68K BUS")
                local even = addr_bus_or_cpu - (addr_bus_or_cpu % 2)
                local w = memory.read_u16_be(even)
                if (addr_bus_or_cpu % 2) == 0 then return math.floor(w / 256) % 256 end
                return w % 256
            end)
            if ok then return v end
        end
        return 0
    end
end

local ADDR_MODE    = is_nes and 0x0012 or 0xFF0012
local ADDR_ROOM    = is_nes and 0x00EB or 0xFF00EB
local ADDR_OBJ_X   = is_nes and 0x0070 or 0xFF0070
local ADDR_OBJ_Y   = is_nes and 0x0084 or 0xFF0084

local TARGET_MODE  = 0x05
local TARGET_ROOM  = 0x77
local STABLE_FRAMES = 60
local MAX_FRAMES   = 20000

local rows = {}
local stable_count = 0
local prev_x, prev_y = nil, nil

-- Header
local header = {
    "# bootflow recording",
    string.format("# system=%s", SYSTEM),
    "# columns: frame U D L R A B C S",
    "# NES: column-C slot stores Select (no C button on NES)",
    "# Gen: column-S = Start",
    string.format("# target: Mode=$%02X room=$%02X Link stable %d frames",
        TARGET_MODE, TARGET_ROOM, STABLE_FRAMES),
}

local function flush()
    local f = io.open(OUT_PATH, "w")
    if not f then return end
    f:write(table.concat(header, "\n") .. "\n")
    for _, r in ipairs(rows) do f:write(r .. "\n") end
    f:close()
end

print("=================================================================")
print("bizhawk_record_bootflow: recording to " .. OUT_PATH)
print("Play from boot into Mode=$05 room=$" .. string.format("%02X", TARGET_ROOM))
print("Recording stops automatically after Link stable 60 frames.")
print("=================================================================")

for frame = 1, MAX_FRAMES do
    local j = joypad.get(1) or {}
    local cols = read_cols(j)
    rows[#rows + 1] = string.format("%d %d %d %d %d %d %d %d %d",
        frame, cols[1], cols[2], cols[3], cols[4], cols[5], cols[6], cols[7], cols[8])

    if frame % 60 == 0 then flush() end

    emu.frameadvance()

    local mode = ram_u8(ADDR_MODE)
    local room = ram_u8(ADDR_ROOM)
    if mode == TARGET_MODE and room == TARGET_ROOM then
        local x = ram_u8(ADDR_OBJ_X)
        local y = ram_u8(ADDR_OBJ_Y)
        if x == prev_x and y == prev_y then
            stable_count = stable_count + 1
        else
            stable_count = 0
            prev_x = x
            prev_y = y
        end
        if stable_count >= STABLE_FRAMES then
            print(string.format("f%04d target reached (Mode=$%02X room=$%02X, Link stable)", frame, mode, room))
            break
        end
    else
        stable_count = 0
    end
end

flush()
print("Wrote " .. #rows .. " frames to " .. OUT_PATH)
pcall(function() client.pause() end)
pcall(function() client.exit() end)
