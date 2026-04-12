-- probe_addresses.lua
-- Reads builds/whatif.lst to resolve current symbol addresses automatically.
--
-- Usage in any probe script (after ROOT is defined):
--   dofile(ROOT .. "tools/probe_addresses.lua")
--
-- Provides globals after loading:
--   LOOPFOREVER, EXC_BUS, EXC_ADDR, EXC_DEF
--
-- Addresses are re-read from the listing on every probe run, so they
-- automatically track address changes as code is added each milestone.

local function read_listing_addrs(lst_path)
    local addrs = {}
    local f = io.open(lst_path, "r")
    if not f then return addrs end
    for line in f:lines() do
        -- Format 1 (symbol table): "00000670 LoopForever"
        local hex1, name1 = line:match("^(%x%x%x%x%x%x%x%x) (%w+)$")
        if hex1 and name1 then
            addrs[name1] = tonumber(hex1, 16)
        end
        -- Format 2 (cross-reference): "LoopForever                 A:00000670"
        local name2, hex2 = line:match("^(%w+)%s+A:(%x+)$")
        if name2 and hex2 then
            addrs[name2] = tonumber(hex2, 16)
        end
    end
    f:close()
    return addrs
end

do
    local source = debug.getinfo(1, "S").source
    if source:sub(1, 1) == "@" then
        source = source:sub(2)
    end
    source = source:gsub("/", "\\")
    local tools_dir = source:match("^(.*)\\[^\\]+$")
    if not tools_dir then
        error("probe_addresses.lua: unable to resolve helper path from '" .. source .. "'")
    end
    dofile(tools_dir .. "\\probe_root.lua")
end

local _a = read_listing_addrs(repo_path("builds\\whatif.lst"))

-- Fail loudly if a required symbol is missing — means listing is stale or
-- the symbol was renamed.  Probes must not run silently against wrong addresses.
local function require_sym(name)
    local v = _a[name]
    if not v then
        error("probe_addresses.lua: symbol '" .. name .. "' not found in " .. repo_path("builds\\whatif.lst") .. " -- rebuild first")
    end
    return v
end

LOOPFOREVER = require_sym("LoopForever")
EXC_BUS     = require_sym("ExcBusError")
EXC_ADDR    = require_sym("ExcAddrError")
EXC_DEF     = require_sym("DefaultException")
ISRRESET    = require_sym("IsrReset")
RUNGAME     = require_sym("RunGame")
ISRNMI      = require_sym("IsrNmi")
