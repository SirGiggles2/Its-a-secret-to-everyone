local function probe_dir()
    local src = debug.getinfo(1, "S").source
    if src:sub(1, 1) == "@" then src = src:sub(2) end
    return src:match("^(.*)[/\\][^/\\]+$") or "."
end

local DIR = probe_dir()
local M = dofile(DIR .. "\\debug_postfix_common.lua")

local ok, detail = M.boot_debug()
M.clear_probe_control()
M.advance(30, {})

if ok then
    print("Debug ROM visible boot: entered debug gameplay")
else
    print("Debug ROM visible boot failed: " .. tostring(detail))
end
