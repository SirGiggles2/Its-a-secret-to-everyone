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
--   {"kill"[, x, y, r]}   until no monster in slots 1..11 (spawn clouds
--                         and edge monsters still waiting count; fires,
--                         people and grumble $36 do not). With an
--                         anchor (x, y, r) Link guards: he never steps
--                         more than r px from it, he turns to face the
--                         nearest monster and swings when it is in reach.
--   {"goto", x, y}        walk Link to (x, y) (NES ObjX/ObjY)
--   {"take"}              wait for the room item to show, walk to it
--                         until it is taken (shown $BF = 0, then not)
--   {"wait", n}           n ticks of no input
--   {"exit", "L"}         hold a direction until RoomId ($EB) changes
--   {"loot"}              walk onto every dropped item ($60 in slots 1..11)
-- A task that runs past its budget (PRESET.bot.max) stops the bot; the
-- capture then ends (BOT.done) and the log shows where.
--
-- NES cells (reference/aldonunez/Variables.inc): ObjX $70, ObjY $84,
-- ObjDir $98, ObjState $AC, ObjType $34F, ObjMetastate $405,
-- ObjUninitialized $492, ObjHP $485, ObjInvincibilityTimer $4F0,
-- ObjGridOffset $394. Room item = slot $13 (state $BF, 0 = shown).
-- decide(rd, wrd): rd reads NES work RAM $0000-$07FF, wrd reads the
-- cartridge WRAM by CPU address ($6000-$7FFF: PlayAreaTiles $6530).

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

-- Path step (goto/take): breadth-first search over Link's 8-px grid
-- points (X multiple of 8, Y = 8k + 5) on the NES play-area tile map
-- (PlayAreaTiles $6530, 22 rows per column; walkable < $34A
-- ObjectFirstUnwalkableTile). Link at (x, y) stands on tile columns x/8
-- and x/8 + 1 of row (y - $35) / 8 (checked on L1 $52/$63/$73 captures).
-- Falls back to step_to when no path exists (doors, moving targets).
local wrd = nil
local function node_ok(rd, x, y)
    if x < 0x10 or x > 0xE0 or y < 0x3D or y > 0xCD then return false end
    local row = (y - 0x35) // 8
    local c = x // 8
    local lim = rd(0x34A)
    return wrd(0x6530 + c * 0x16 + row) < lim and wrd(0x6530 + (c + 1) * 0x16 + row) < lim
end

local path_stuck = 0
local function path_step(rd, tx, ty)
    local lx, ly = rd(0x70), rd(0x84)
    -- The map test is an approximation of NES collision: if Link has not
    -- moved for 10 ticks, hand over to step_to and its sideways detour.
    if lx == last_x and ly == last_y then path_stuck = path_stuck + 1 else path_stuck = 0 end
    if path_stuck >= 10 then return step_to(rd, tx, ty) end
    last_x, last_y = lx, ly
    local gx, gy = (tx + 4) // 8 * 8, (ty - 5 + 4) // 8 * 8 + 5
    if not node_ok(rd, gx, gy) then return step_to(rd, tx, ty) end
    -- Distance map from the goal over walkable grid points.
    local key = function(x, y) return x * 256 + y end
    local dist = { [key(gx, gy)] = 0 }
    local q, qi = { { gx, gy } }, 1
    local moves = { { 8, 0 }, { -8, 0 }, { 0, 8 }, { 0, -8 } }
    while qi <= #q do
        local x, y = q[qi][1], q[qi][2]; qi = qi + 1
        local d = dist[key(x, y)]
        for _, m in ipairs(moves) do
            local nx, ny = x + m[1], y + m[2]
            local k = key(nx, ny)
            if dist[k] == nil and node_ok(rd, nx, ny) then
                dist[k] = d + 1; q[#q + 1] = { nx, ny }
            end
        end
    end
    -- Candidate grid points: Link's own when on the grid, else the two
    -- he is between (he can only turn on a grid point).
    local xs = (lx % 8 == 0) and { lx } or { lx // 8 * 8, lx // 8 * 8 + 8 }
    local ys = ((ly - 5) % 8 == 0) and { ly } or { (ly - 5) // 8 * 8 + 5, (ly - 5) // 8 * 8 + 13 }
    local best, bx, by = nil, nil, nil
    if #xs == 1 and #ys == 1 then
        -- On a grid point: step to the neighbour nearest the goal.
        if lx == gx and ly == gy then return step_to(rd, tx, ty) end
        for _, m in ipairs(moves) do
            local d = dist[key(lx + m[1], ly + m[2])]
            if d and (best == nil or d < best) then best, bx, by = d, lx + m[1], ly + m[2] end
        end
    else
        for _, x in ipairs(xs) do
            for _, y in ipairs(ys) do
                local d = dist[key(x, y)]
                if d and (best == nil or d < best) then best, bx, by = d, x, y end
            end
        end
    end
    if best == nil then return step_to(rd, tx, ty) end
    if bx > lx then return "R" elseif bx < lx then return "L"
    elseif by > ly then return "D" else return "U" end
end

local function facing_to(dx, dy)
    if math.abs(dx) >= math.abs(dy) then return (dx > 0) and DIR_R or DIR_L end
    return (dy > 0) and DIR_D or DIR_U
end

local last_a = false

-- Fighting never walks out through a doorway: a step past the room
-- interior (X $20..$D0, Y $5D..$C5) turns toward the room centre.
local function keep_in(rd, r)
    local lx, ly = rd(0x70), rd(0x84)
    if (r == "U" and ly <= 0x5D) or (r == "D" and ly >= 0xC5) then
        return (lx < 0x78) and "R" or "L"
    end
    if (r == "L" and lx <= 0x20) or (r == "R" and lx >= 0xD0) then
        return (ly < 0x8D) and "D" or "U"
    end
    return r
end

local function kill_raw(rd)
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
    -- Walk to the nearest walkable attack spot 20 px beside the target
    -- (grid-snapped), then the reach test above faces and swings.
    local spots = { { m.x - 20, m.y }, { m.x + 20, m.y }, { m.x, m.y - 20 }, { m.x, m.y + 20 } }
    local best, bx, by = nil, nil, nil
    for _, p in ipairs(spots) do
        local sx, sy = (p[1] + 4) // 8 * 8, (p[2] - 5 + 4) // 8 * 8 + 5
        if node_ok(rd, sx, sy) then
            local d = math.abs(sx - lx) + math.abs(sy - ly)
            if best == nil or d < best then best, bx, by = d, sx, sy end
        end
    end
    if best == nil then
        if adx <= ady then return step_to(rd, m.x, ly, "x") end
        return step_to(rd, lx, m.y, "y")
    end
    return path_step(rd, bx, by)
end

local function kill(rd, t)
    local r = kill_raw(rd)
    if t and t[2] and r ~= nil and r ~= "" and r ~= "A" then
        -- Guard: a step that leaves the anchor box only turns Link (one
        -- tick of input on the grid moves him at most 2 px back inside).
        local lx, ly = rd(0x70), rd(0x84)
        local ax, ay, rad = t[2], t[3], t[4]
        local out = (r == "L" and lx - 2 < ax - rad) or (r == "R" and lx + 2 > ax + rad)
            or (r == "U" and ly - 2 < ay - rad) or (r == "D" and ly + 2 > ay + rad)
        if out then
            local mons = monsters(rd)
            if #mons == 0 then return "" end
            table.sort(mons, function(p, q)
                return math.abs(p.x - lx) + math.abs(p.y - ly) < math.abs(q.x - lx) + math.abs(q.y - ly)
            end)
            local want = BTN[facing_to(mons[1].x - lx, mons[1].y - ly)]
            if rd(0x98) == facing_to(mons[1].x - lx, mons[1].y - ly) then return "" end
            return want
        end
    end
    if r == nil or r == "" or r == "A" then return r end
    -- In a doorway on entry: walk in first.
    local ly = rd(0x84)
    if ly > 0xC5 then return "U" elseif ly < 0x5D then return "D" end
    local lx = rd(0x70)
    if lx > 0xD0 then return "L" elseif lx < 0x20 then return "R" end
    return keep_in(rd, r)
end

function BOT.decide(rd, wram_rd)
    wrd = wram_rd
    while ti <= #tasks do
        local t = tasks[ti]
        local r
        if t[1] == "kill" then
            r = kill(rd, t)
        elseif t[1] == "goto" then
            local lx, ly = rd(0x70), rd(0x84)
            if math.abs(lx - t[2]) <= 1 and math.abs(ly - t[3]) <= 1 then r = nil
            else r = path_step(rd, t[2], t[3]) end
        elseif t[1] == "take" then
            if rd(0xBF) == 0 then
                t.seen = true
                r = path_step(rd, rd(0x83), rd(0x97) - 3)
            elseif t.seen then r = nil
            else r = "" end
        elseif t[1] == "loot" then
            local best, bx, by = nil, 0, 0
            local lx, ly = rd(0x70), rd(0x84)
            for k = 1, 11 do
                if rd(0x34F + k) == 0x60 then
                    local ix, iy = rd(0x70 + k), rd(0x84 + k)
                    local d = math.abs(ix - lx) + math.abs(iy - ly)
                    if best == nil or d < best then best, bx, by = d, ix, iy end
                end
            end
            if best == nil then r = nil else r = path_step(rd, bx, by) end
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
