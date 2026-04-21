-- probe_root.lua
-- Resolve the active repo root from the calling script's own path so probes
-- work from the main checkout and from nested worktrees.

local function _normalize_path(path)
    path = path:gsub("/", "\\")
    path = path:gsub("\\+", "\\")
    return path
end

local function _dirname(path)
    return path:match("^(.*)\\[^\\]+$")
end

local function _current_script_path(stack_level)
    local info = debug.getinfo(stack_level or 1, "S")
    local source = info and info.source or ""
    if source:sub(1, 1) == "@" then
        source = source:sub(2)
    end
    return _normalize_path(source)
end

local function _has_repo_marker(dir)
    local fh = io.open(dir .. "\\src\\genesis_shell.asm", "r")
    if fh then
        fh:close()
        return true
    end
    return false
end

local function resolve_repo_root(stack_level)
    local env_root = os.getenv("CODEX_BIZHAWK_ROOT")
    if env_root then
        env_root = _normalize_path(env_root)
        if _has_repo_marker(env_root) then
            return env_root
        end
    end

    local script_path = _current_script_path((stack_level or 1) + 1)
    local current = _dirname(script_path)
    while current and current ~= "" do
        if current:match("\\tools$") then
            local root = current:sub(1, #current - #"\\tools")
            if _has_repo_marker(root) then
                return root
            end
        end
        if _has_repo_marker(current) then
            return current
        end
        local parent = _dirname(current)
        if not parent or parent == current then
            break
        end
        current = parent
    end
    error("probe_root.lua: unable to resolve repo root from '" .. script_path .. "'")
end

ROOT = ROOT or resolve_repo_root(1)

function repo_path(relative_path)
    return ROOT .. "\\" .. _normalize_path(relative_path)
end
