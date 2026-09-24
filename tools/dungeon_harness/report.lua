-- Shared report envelope supplied by run_all.py. No game-state assertions here.
local function quote(s)
    return '"' .. s:gsub('\\', '\\\\'):gsub('"', '\\"')
        :gsub('\n', '\\n'):gsub('\r', '\\r'):gsub('\t', '\\t') .. '"'
end
local function json(v)
    if type(v) == 'string' then return quote(v) end
    if type(v) == 'number' or type(v) == 'boolean' then return tostring(v) end
    if type(v) ~= 'table' then return 'null' end
    local out = {}
    for k, value in pairs(v) do out[#out + 1] = quote(tostring(k)) .. ':' .. json(value) end
    return '{' .. table.concat(out, ',') .. '}'
end
function HARNESS.finish(verdict, fields)
    local result = fields or {}
    result.run_id = HARNESS.run_id
    result.rom_sha256 = HARNESS.rom_sha256
    result.level = HARNESS.level
    result.quest = HARNESS.quest
    result.scope = HARNESS.scope
    result.verdict = verdict
    result.system = emu.getsystemid()
    result.bizhawk_version = client.getversion and client.getversion() or 'unavailable'
    local out = assert(io.open(HARNESS.out_path, 'w'))
    out:write(json(result)); out:close()
    joypad.set({}, 1)
    client.exit()
end
