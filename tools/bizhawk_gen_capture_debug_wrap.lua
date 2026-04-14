-- Debug wrapper to surface Lua errors from the Genesis room capture.

local function normalize_path(path)
    path = (path or ""):gsub("/", "\\")
    path = path:gsub("\\+", "\\")
    return path
end

local function dirname(path)
    return path:match("^(.*)\\[^\\]+$")
end

local function has_repo_marker(dir)
    local fh = io.open(dir .. "\\src\\genesis_shell.asm", "r")
    if fh then
        fh:close()
        return true
    end
    return false
end

local function resolve_root()
    local env_root = os.getenv("CODEX_BIZHAWK_ROOT")
    if env_root and env_root ~= "" then
        env_root = normalize_path(env_root)
        if has_repo_marker(env_root) then
            return env_root
        end
    end

    local source = debug.getinfo(1, "S").source or ""
    if source:sub(1, 1) == "@" then
        source = source:sub(2)
    end
    source = normalize_path(source)
    local current = dirname(source)
    while current and current ~= "" do
        if current:match("\\tools$") then
            local root = current:sub(1, #current - #"\\tools")
            if has_repo_marker(root) then
                return root
            end
        end
        if has_repo_marker(current) then
            return current
        end
        local parent = dirname(current)
        if not parent or parent == current then
            break
        end
        current = parent
    end
    error("unable to resolve repo root from '" .. source .. "'")
end

local ROOT = _G.ROOT or resolve_root()

local function local_repo_path(relative_path)
    return ROOT .. "\\" .. normalize_path(relative_path)
end

_G.ROOT = ROOT
if type(_G.repo_path) ~= "function" then
    function _G.repo_path(relative_path)
        return local_repo_path(relative_path)
    end
end

local target_room_id = tonumber(os.getenv("CODEX_TARGET_ROOM_ID") or "0x77") or 0x77
target_room_id = target_room_id % 0x100
local out_path = local_repo_path(string.format("builds\\reports\\room%02X_gen_capture_debug.txt", target_room_id))
local target_lua = local_repo_path("tools\\bizhawk_room77_gen_capture.lua")

local ok, err = xpcall(function()
    dofile(target_lua)
end, debug.traceback)

if not ok then
    local fh = io.open(out_path, "w")
    if fh then
        fh:write(tostring(err), "\n")
        fh:close()
    end
    print(tostring(err))
    client.exit()
end
