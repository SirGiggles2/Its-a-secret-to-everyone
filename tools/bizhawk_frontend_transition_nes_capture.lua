-- Capture title -> file-select transfer-stream lifetime on NES.

dofile((function()
    local env_root = os.getenv("CODEX_BIZHAWK_ROOT")
    if env_root and env_root ~= "" then
        env_root = env_root:gsub("/", "\\")
        return env_root .. "\\tools\\probe_root.lua"
    end
    local source = debug.getinfo(1, "S").source
    if source:sub(1, 1) == "@" then
        source = source:sub(2)
    end
    source = source:gsub("/", "\\")
    local tools_dir = source:match("^(.*)\\[^\\]+$")
    return tools_dir .. "\\probe_root.lua"
end)())

local OUT_DIR = repo_path("builds\\reports")
local OUT_JSON = repo_path("builds\\reports\\frontend_transition_nes_capture.json")
local OUT_TXT = repo_path("builds\\reports\\frontend_transition_nes_capture.txt")
local BANK6_BIN_PATH = repo_path("reference\\aldonunez\\dat\\nes_bank_06.bin")

os.execute('if not exist "' .. OUT_DIR .. '" mkdir "' .. OUT_DIR .. '"')

local MAX_FRAMES = 320
local TRANSFER_STREAM_MAX_BYTES = 256
local TRANSFER_STREAM_MAX_RECORDS = 64
local TRANSFER_STREAM_MAX_EVENTS = 128
local TRANSFER_BUF_ADDRS_ADDR = 0xA000
local ISRNMI_ADDR = 0xE484

local NES_BANK6_BYTES = nil
do
    local f = io.open(BANK6_BIN_PATH, "rb")
    if f then NES_BANK6_BYTES = f:read("*all") f:close() end
end

local function cpu_bus_u8(addr)
    memory.usememorydomain("System Bus")
    return memory.read_u8(addr % 0x10000)
end

local function ram_u8(addr)
    memory.usememorydomain("System Bus")
    return memory.read_u8(addr % 0x10000)
end

local function bank6_u8(cpu_addr)
    if NES_BANK6_BYTES == nil then return nil end
    local addr = cpu_addr % 0x10000
    if addr < 0x8000 or addr >= 0xC000 then return nil end
    local index = (addr - 0x8000) + 1
    if index < 1 or index > #NES_BANK6_BYTES then return nil end
    return string.byte(NES_BANK6_BYTES, index)
end

local function transfer_source_u8(addr)
    local v = bank6_u8(addr)
    if v ~= nil then return v end
    return cpu_bus_u8(addr)
end

local function safe_set(pad)
    local ok = pcall(function() joypad.set(pad or {}, 1) end)
    if not ok then joypad.set(pad or {}) end
end

local function json_escape(s)
    s = tostring(s):gsub("\\", "\\\\")
    s = s:gsub('"', '\\"'):gsub("\n", "\\n")
    return s
end

local function json_num_array(values)
    local parts = {}
    for i = 1, #values do
        parts[#parts + 1] = tostring(values[i])
    end
    return "[" .. table.concat(parts, ",") .. "]"
end

local function decode_transfer_stream_from_ptr(ptr)
    local raw, records = {}, {}
    local cursor = ptr % 0x10000
    for _ = 1, TRANSFER_STREAM_MAX_RECORDS do
        if #raw >= TRANSFER_STREAM_MAX_BYTES then break end
        local hi = transfer_source_u8(cursor) % 0x100
        raw[#raw + 1] = hi
        if hi == 0xFF then break end
        local lo = transfer_source_u8((cursor + 1) % 0x10000) % 0x100
        local control = transfer_source_u8((cursor + 2) % 0x10000) % 0x100
        raw[#raw + 1] = lo
        raw[#raw + 1] = control
        local count = control & 0x3F
        if count == 0 then count = 0x40 end
        local repeat_mode = (control & 0x40) ~= 0
        local vertical_increment = (control & 0x80) ~= 0
        local payload_len = repeat_mode and 1 or count
        local payload = {}
        for i = 0, payload_len - 1 do
            local v = transfer_source_u8((cursor + 3 + i) % 0x10000) % 0x100
            raw[#raw + 1] = v
            payload[#payload + 1] = v
        end
        records[#records + 1] = {
            vram_addr = ((hi * 0x100) + lo) % 0x10000,
            control = control,
            count = count,
            vertical_increment = vertical_increment and 1 or 0,
            repeat_mode = repeat_mode and 1 or 0,
            payload_bytes = payload,
        }
        cursor = (cursor + 3 + payload_len) % 0x10000
    end
    return {
        raw_stream_bytes = raw,
        decoded_records = records,
        empty = (#raw == 1 and raw[1] == 0xFF) or (#raw == 0),
    }
end

local function resolve_transfer_source_ptr(selector)
    local base = (TRANSFER_BUF_ADDRS_ADDR + (selector % 0x100)) % 0x10000
    local lo = bank6_u8(base)
    local hi = bank6_u8(base + 1)
    if lo == nil or hi == nil then
        lo = cpu_bus_u8(base) % 0x100
        hi = cpu_bus_u8((base + 1) % 0x10000) % 0x100
    end
    return ((hi * 0x100) + lo) % 0x10000
end

local transfer_stream_events = {}
local transfer_exec_samples = {}
local mode_changes = {}
local transfer_exec_hook_hits = 0
local transfer_exec_hook_armed = false
local last_sig = nil
local lines = {}

local function record(s)
    lines[#lines + 1] = s
    print(s)
end

local function capture_event(frame)
    local mode = ram_u8(0x0012) % 0x100
    local sub = ram_u8(0x0013) % 0x100
    if mode ~= 0x00 and mode ~= 0x01 then
        return
    end
    local selector = ram_u8(0x0014) % 0x100
    local dyn_len = ram_u8(0x0301) % 0x100
    local source_ptr = resolve_transfer_source_ptr(selector)
    local source_kind = (source_ptr == 0x0302) and "dyn" or "static"
    local parsed = decode_transfer_stream_from_ptr(source_ptr)
    local bytes_head = {}
    for i = 1, math.min(8, #parsed.raw_stream_bytes) do
        bytes_head[#bytes_head + 1] = parsed.raw_stream_bytes[i]
    end
    if #transfer_exec_samples < TRANSFER_STREAM_MAX_EVENTS then
        transfer_exec_samples[#transfer_exec_samples + 1] = {
            frame = frame, mode = mode, submode = sub,
            tile_buf_selector = selector, dyn_tile_buf_len = dyn_len,
            source_kind = source_kind, source_ptr = source_ptr, bytes_head = bytes_head,
        }
    end
    if parsed.empty then
        return
    end
    local sig = string.format("%02X:%02X:%02X:%04X:%s", frame % 0x100, mode, sub, source_ptr, table.concat(parsed.raw_stream_bytes, ","))
    if sig == last_sig then return end
    last_sig = sig
    transfer_stream_events[#transfer_stream_events + 1] = {
        seq = #transfer_stream_events + 1,
        frame = frame, mode = mode, submode = sub,
        tile_buf_selector = selector, dyn_tile_buf_len = dyn_len,
        source_kind = source_kind, source_ptr = source_ptr,
        raw_stream_bytes = parsed.raw_stream_bytes,
        decoded_records = parsed.decoded_records,
    }
end

local function add_exec_hook_variants(addr, cb, tag)
    local ids = {}
    local attempts = {
        function() return event.onmemoryexecute(cb, addr, tag, "System Bus") end,
        function() return event.onmemoryexecute(cb, addr, tag) end,
        function() return event.onmemoryexecute(cb, addr) end,
    }
    for i = 1, #attempts do
        local ok, id = pcall(attempts[i])
        if ok and id ~= nil then ids[#ids + 1] = id end
    end
    return ids
end

local ids = add_exec_hook_variants(ISRNMI_ADDR, function()
    transfer_exec_hook_hits = transfer_exec_hook_hits + 1
    capture_event(emu.framecount())
end, "frontend_transition_isrnmi")
transfer_exec_hook_armed = #ids > 0

record("FRONTEND NES TRANSITION CAPTURE")
local prev_mode = -1
for frame = 1, MAX_FRAMES do
    if frame >= 90 and frame <= 110 then
        safe_set({Start = true})
    else
        safe_set({})
    end
    emu.frameadvance()
    local mode = ram_u8(0x0012) % 0x100
    local sub = ram_u8(0x0013) % 0x100
    if mode ~= prev_mode then
        mode_changes[#mode_changes + 1] = {frame = frame, mode = mode, submode = sub}
        prev_mode = mode
    end
end

local final_mode = ram_u8(0x0012) % 0x100
local final_sub = ram_u8(0x0013) % 0x100
local reached_target = final_mode == 0x01

local function json_records(entries)
    local out = {}
    for i = 1, #entries do
        local e = entries[i]
        out[#out + 1] = string.format(
            '{"seq":%d,"frame":%d,"mode":%d,"submode":%d,"tile_buf_selector":%d,"dyn_tile_buf_len":%d,"source_kind":"%s","source_ptr":%d,"raw_stream_bytes":%s}',
            e.seq or 0, e.frame or 0, e.mode or 0, e.submode or 0,
            e.tile_buf_selector or 0, e.dyn_tile_buf_len or 0,
            json_escape(e.source_kind or ""), e.source_ptr or 0,
            json_num_array(e.raw_stream_bytes or {})
        )
    end
    return "[" .. table.concat(out, ",") .. "]"
end

local function json_samples(entries)
    local out = {}
    for i = 1, #entries do
        local e = entries[i]
        out[#out + 1] = string.format(
            '{"frame":%d,"mode":%d,"submode":%d,"tile_buf_selector":%d,"dyn_tile_buf_len":%d,"source_kind":"%s","source_ptr":%d,"bytes_head":%s}',
            e.frame or 0, e.mode or 0, e.submode or 0,
            e.tile_buf_selector or 0, e.dyn_tile_buf_len or 0,
            json_escape(e.source_kind or ""), e.source_ptr or 0,
            json_num_array(e.bytes_head or {})
        )
    end
    return "[" .. table.concat(out, ",") .. "]"
end

local function json_modes(entries)
    local out = {}
    for i = 1, #entries do
        local e = entries[i]
        out[#out + 1] = string.format('{"frame":%d,"mode":%d,"submode":%d}', e.frame or 0, e.mode or 0, e.submode or 0)
    end
    return "[" .. table.concat(out, ",") .. "]"
end

local jf = assert(io.open(OUT_JSON, "w"))
jf:write("{\n")
jf:write('  "target_reached": ', reached_target and "true" or "false", ",\n")
jf:write('  "final_mode": ', tostring(final_mode), ",\n")
jf:write('  "final_submode": ', tostring(final_sub), ",\n")
jf:write('  "transfer_exec_hook_armed": ', transfer_exec_hook_armed and "true" or "false", ",\n")
jf:write('  "transfer_exec_hook_hits": ', tostring(transfer_exec_hook_hits), ",\n")
jf:write('  "mode_changes": ', json_modes(mode_changes), ",\n")
jf:write('  "transfer_exec_samples": ', json_samples(transfer_exec_samples), ",\n")
jf:write('  "transfer_stream_events": ', json_records(transfer_stream_events), ",\n")
jf:write('  "transfer_stream_capture_valid": ', (#transfer_stream_events > 0) and "true" or "false", "\n")
jf:write("}\n")
jf:close()

local tf = assert(io.open(OUT_TXT, "w"))
tf:write(table.concat(lines, "\n") .. "\n")
tf:close()
client.exit()
