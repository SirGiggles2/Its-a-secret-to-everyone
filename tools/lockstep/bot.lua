-- tools/lockstep/bot.lua — NES-only route bot for lockstep presets (T-013).
--
-- The bot plays after PRESET.script ends, on the NES capture only. Each
-- new game tick it reads NES work RAM and returns one button string
-- ("U", "LA", "" ...). capture.lua logs every choice to <OUT>.botin; the
-- log becomes plain script steps (tools/lockstep/bot_merge.py), so the
-- Genesis replays the same buttons and the diff stays a byte-for-byte
-- comparison. The bot never writes RAM.
--
-- Tasks (PRESET.bot.tasks, run in order):
--   {"kill"}              until no monster in slots 1..11 (spawn clouds
--                         and edge monsters still waiting count; fires,
--                         people and grumble $36 do not)
--   {"goto", x, y}        walk Link to (x, y) (NES ObjX/ObjY)
--   {"take"}              wait for the room item to show, walk to it
--                         until it is taken (shown $BF = 0, then not)
--   {"wait", n}           n ticks of no input
--   {"exit", "L"}         hold a direction until RoomId ($EB) changes
-- A task that runs past its budget (PRESET.bot.max) stops the bot; the
-- capture then ends (BOT.done) and the log shows where.
--
-- NES cells (reference/aldonunez/Variables.inc): ObjX $70, ObjY $84,
-- ObjDir $98, ObjState $AC, ObjType $34F, ObjMetastate $405,
-- ObjUninitialized $492, ObjHP $485, ObjInvincibilityTimer $4F0,
-- ObjGridOffset $394. Room item = slot $13 (state $BF, 0 = shown).

BOT = {}

local DIR_R, DIR_L, DIR_D, DIR_U = 0x01, 0x02, 0x04, 0x08
local BTN = { [DIR_R] = "R", [DIR_L] = "L", [DIR_D] = "D", [DIR_U] = "U" }

local tasks = {}
local ti = 1
local stuck_n, last_x, last_y, detour, detour_n = 0, -1, -1, nil, 0
BOT.done = false
BOT.why = ""

function BOT.init(spec)
    tasks = spec.tasks or {}
    ti = 1
end

local function not_monster(t)
    return t == 0 or t >= 0x53 or t == 0x40 or t == 0x36 or (t >= 0x4B and t <= 0x52)
end

-- Monsters in slots 1..11: `alive` counts spawning (metastate 1..$F) and
-- uninitialized ones; `targets` only the spawned, initialized ones
-- (metastate 0, $492 = 0). Metastate >= $10 is the death spark.
local function monsters(rd)
    local targets, alive = {}, 0
    for k = 1, 11 do
        local t = rd(0x34F + k)
        local ms = rd(0x405 + k)
        if not not_monster(t) and ms < 0x10 then
            alive = alive + 1
            if ms == 0 and rd(0x492 + k) == 0 then
                targets[#targets + 1] = { k = k, x = rd(0x70 + k), y = rd(0x84 + k) }
            end
        end
    end
    return targets, alive
end

local function busy(rd)
    local st = rd(0xAC)
    return (st & 0x30) ~= 0 or (st & 0xC0) == 0x40
end

-- One step toward (tx, ty). The walking axis is kept until its gap is
-- closed (Link turns only on 8-px grid points; switching axis every tick
-- ping-pongs him around a grid point): first the axis `prefer` names,
-- else the larger gap. Detours sideways for 16 ticks when Link has not
-- moved for 10 ticks of input.
local axis = nil
local function step_to(rd, tx, ty, prefer)
    local lx, ly = rd(0x70), rd(0x84)
    if lx == last_x and ly == last_y then stuck_n = stuck_n + 1 else stuck_n = 0 end
    last_x, last_y = lx, ly
    if detour and detour_n > 0 then detour_n = detour_n - 1; return detour end
    local dx, dy = tx - lx, ty - ly
    local h = (dx > 0) and "R" or "L"
    local v = (dy > 0) and "D" or "U"
    if axis == "x" and dx == 0 then axis = nil end
    if axis == "y" and dy == 0 then axis = nil end
    if prefer == "x" and dx ~= 0 then axis = "x"
    elseif prefer == "y" and dy ~= 0 then axis = "y"
    elseif axis == nil then
        if math.abs(dx) >= math.abs(dy) then axis = (dx ~= 0) and "x" or "y"
        else axis = (dy ~= 0) and "y" or "x" end
    end
    local choice = (axis == "x") and h or v
    if stuck_n >= 10 then
        stuck_n = 0
        axis = nil
        if choice == "L" or choice == "R" then detour = (dy >= 0) and "D" or "U"
        else detour = (dx >= 0) and "R" or "L" end
        detour_n = 16
        return detour
    end
    return choice
end

local function facing_to(dx, dy)
    if math.abs(dx) >= math.abs(dy) then return (dx > 0) and DIR_R or DIR_L end
    return (dy > 0) and DIR_D or DIR_U
end

local last_a = false

local function kill(rd)
    local mons, alive = monsters(rd)
    if alive == 0 then return nil end
    if #mons == 0 or busy(rd) then return "" end
    local lx, ly, ld = rd(0x70), rd(0x84), rd(0x98)
    table.sort(mons, function(a, b)
        return math.abs(a.x - lx) + math.abs(a.y - ly) < math.abs(b.x - lx) + math.abs(b.y - ly)
    end)
    local m = mons[1]
    local dx, dy = m.x - lx, m.y - ly
    local adx, ady = math.abs(dx), math.abs(dy)
    -- In reach on a line: face it, swing.
    if (ady <= 6 and adx <= 28) or (adx <= 6 and ady <= 28) then
        local want = facing_to(dx, dy)
        if ld == want then
            -- A is edge-triggered (ButtonsPressed): release between swings.
            if last_a then last_a = false; return "" end
            last_a = true
            return "A"
        end
        return BTN[want]
    end
    -- Too close off the line: back away on the larger axis.
    if adx < 16 and ady < 16 then
        if adx >= ady then return (dx > 0) and "L" or "R" end
        return (dy > 0) and "U" or "D"
    end
    -- Line up on the axis already nearest to aligned, keeping distance.
    if adx <= ady then return step_to(rd, m.x, ly, "x") end
    return step_to(rd, lx, m.y, "y")
end

function BOT.decide(rd)
    while ti <= #tasks do
        local t = tasks[ti]
        local r
        if t[1] == "kill" then
            r = kill(rd)
        elseif t[1] == "goto" then
            local lx, ly = rd(0x70), rd(0x84)
            if math.abs(lx - t[2]) <= 1 and math.abs(ly - t[3]) <= 1 then r = nil
            else r = step_to(rd, t[2], t[3], t[4]) end
        elseif t[1] == "take" then
            if rd(0xBF) == 0 then
                t.seen = true
                r = step_to(rd, rd(0x83), rd(0x97) - 3)
            elseif t.seen then r = nil
            else r = "" end
        elseif t[1] == "exit" then
            t.room = t.room or rd(0xEB)
            if rd(0xEB) ~= t.room then r = nil else r = t[2] end
        elseif t[1] == "wait" then
            t.left = (t.left or t[2]) - 1
            if t.left < 0 then r = nil else r = "" end
        else
            BOT.done = true; BOT.why = "unknown task " .. tostring(t[1]); return ""
        end
        if r ~= nil then return r end
        ti = ti + 1
        stuck_n, detour, detour_n, axis = 0, nil, 0, nil
    end
    BOT.done = true
    BOT.why = "all tasks done"
    return ""
end
