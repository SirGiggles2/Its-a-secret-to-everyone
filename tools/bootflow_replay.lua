-- bootflow_replay.lua
--
-- Loads a bootflow recording produced by bizhawk_record_bootflow.lua and
-- exposes per-frame pad-table lookup. Column semantics (U D L R A B C S) map
-- back to native BizHawk button names per system.
--
-- Usage:
--   local replay = dofile(OUT_DIR .. "\\bootflow_replay.lua")
--   local r = replay.load(OUT_DIR .. "\\bootflow_gen.txt", "GEN")
--   -- In frame loop (frame = 1-based just like recorder):
--   local pad = r:pad_for_frame(frame)   -- or nil past end of recording
--   if pad then joypad.set(pad, 1) end
--
-- File format (one line per frame):
--   <frame> U D L R A B C S    (0/1 per col; '#'-prefixed header lines ignored)

local M = {}

-- Column → NES button
local NES_COL_NAMES = {
    [1] = "Up", [2] = "Down", [3] = "Left", [4] = "Right",
    [5] = "A",  [6] = "B",    [7] = "Select", -- column-C slot holds Select on NES
    [8] = "Start",
}

-- Column → Genesis button
local GEN_COL_NAMES = {
    [1] = "Up", [2] = "Down", [3] = "Left", [4] = "Right",
    [5] = "A",  [6] = "B",    [7] = "C",     [8] = "Start",
}

local function split_ws(s)
    local t = {}
    for w in string.gmatch(s, "%S+") do t[#t + 1] = w end
    return t
end

local Recording = {}
Recording.__index = Recording

function Recording:pad_for_frame(frame)
    local row = self.rows[frame]
    if not row then return nil end
    local pad = {}
    for col = 1, 8 do
        if row[col] == 1 then
            local name = self.names[col]
            if name then pad[name] = true end
        end
    end
    return pad
end

function Recording:length() return self.max_frame end

function M.load(path, system)
    local f = io.open(path, "r")
    if not f then return nil, "bootflow file not found: " .. tostring(path) end
    local rows = {}
    local max_frame = 0
    for line in f:lines() do
        if line:sub(1, 1) ~= "#" and line:match("%S") then
            local parts = split_ws(line)
            if #parts >= 9 then
                local fr = tonumber(parts[1])
                if fr then
                    rows[fr] = {
                        tonumber(parts[2]) or 0, tonumber(parts[3]) or 0,
                        tonumber(parts[4]) or 0, tonumber(parts[5]) or 0,
                        tonumber(parts[6]) or 0, tonumber(parts[7]) or 0,
                        tonumber(parts[8]) or 0, tonumber(parts[9]) or 0,
                    }
                    if fr > max_frame then max_frame = fr end
                end
            end
        end
    end
    f:close()
    local names
    if system == "NES" then
        names = NES_COL_NAMES
    else
        names = GEN_COL_NAMES
    end
    local r = setmetatable({
        rows = rows, max_frame = max_frame, names = names, system = system,
    }, Recording)
    return r
end

return M
