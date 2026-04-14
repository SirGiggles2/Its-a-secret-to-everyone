-- bizhawk_room77_nes_capture.lua
-- Capture deterministic NES room-target artifacts for strict BG-only parity.
--
-- Outputs:
--   builds/reports/roomXX_nes_capture.txt
--   builds/reports/roomXX_nes_capture.json
--   builds/reports/roomXX_nes_capture.png
--   builds/reports/roomXX_nes_chr_0000_1fff.bin
--
-- Capture gate:
--   GameMode ($0012) == $05 and RoomId ($00EB) == target.
--   Then dump CIRAM nametable+attribute data for rows 6..27 cols 0..31,
--   PALRAM (32 bytes), CHR (8KB), and screenshot.

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
    if not tools_dir then
        error("unable to resolve tools directory from '" .. source .. "'")
    end
    return tools_dir .. "\\probe_root.lua"
end)())

local TARGET_ROOM_ID = tonumber(os.getenv("CODEX_TARGET_ROOM_ID") or "0x77") or 0x77
TARGET_ROOM_ID = TARGET_ROOM_ID % 0x100
local ROOM_TAG = string.format("room%02X", TARGET_ROOM_ID)
local TARGET_WALK_PATH = (os.getenv("CODEX_ROOM_WALK_PATH") or ""):upper():gsub("[^LRUD]", "")

local OUT_DIR = repo_path("builds\\reports")
local OUT_TXT = repo_path("builds\\reports\\" .. ROOM_TAG .. "_nes_capture.txt")
local OUT_JSON = repo_path("builds\\reports\\" .. ROOM_TAG .. "_nes_capture.json")
local OUT_PNG = repo_path("builds\\reports\\" .. ROOM_TAG .. "_nes_capture.png")
local OUT_CHR = repo_path("builds\\reports\\" .. ROOM_TAG .. "_nes_chr_0000_1fff.bin")

os.execute('if not exist "' .. OUT_DIR .. '" mkdir "' .. OUT_DIR .. '"')

local SYSTEM_ID = emu.getsystemid() or "?"
local AVAILABLE_DOMAIN_SET = {}
do
    local ok, domains = pcall(memory.getmemorydomainlist)
    if ok and type(domains) == "table" then
        for _, name in ipairs(domains) do
            AVAILABLE_DOMAIN_SET[name] = true
        end
    end
end

local function domain_available(name)
    return AVAILABLE_DOMAIN_SET[name] == true
end

local function available_domains_csv()
    local keys = {}
    for k, _ in pairs(AVAILABLE_DOMAIN_SET) do
        keys[#keys + 1] = k
    end
    table.sort(keys)
    return table.concat(keys, ", ")
end

local MAX_FRAMES = 7000
local MODE0_BOOT_TIMEOUT = 1200
local TARGET_NAME_PROGRESS = 5

local FLOW_BOOT_TO_FS1 = "BOOT_TO_FS1"
local FLOW_FS1_SELECT_REGISTER = "FS1_SELECT_REGISTER"
local FLOW_FS1_ENTER_REGISTER = "FS1_ENTER_REGISTER"
local FLOW_MODEE_TYPE_NAME = "MODEE_TYPE_NAME"
local FLOW_MODEE_FINISH = "MODEE_FINISH"
local FLOW_FS1_START_GAME = "FS1_START_GAME"
local FLOW_WAIT_GAMEPLAY = "WAIT_GAMEPLAY"

local ROOM_TOP_ROW = 6
local ROOM_ROWS = 22
local ROOM_COLS = 32
local MODE5_STABLE_FRAMES = 10
local SOURCE_SAMPLE_BYTES = 16
local PLAYMAP_BASE = 0x6530
local WORKBUF_LOOP_ADVANCE = 0x02C0 -- 16 columns * (11 squares * 2 tiles + 0x16 wrap)
local TRACE_WRITE_COUNT = 64
local TRACE_RT_MAX_WRITES = 128
local TRACE_RT_MIN_VALID = 32
local TRANSFER_STREAM_MAX_BYTES = 1024
local TRANSFER_STREAM_MAX_EVENTS = 128
local TRANSFER_STREAM_MAX_RECORDS = 128
local TRANSITION_STATE_MAX_FRAMES = 1024
local TRANSFER_EXEC_HIT_LOG_MAX = 1024
local TRANSFER_EXEC_ERROR_MAX = 32
local EDGE_TRACE_TOP_PPU = 0x2100
local EDGE_TRACE_TOP_CIRAM = 0x0100
local EDGE_TRACE_ROWS = 22
local EDGE_TRACE_MAX_ENTRIES = 256
local TRANSFER_BUF_ADDRS_ADDR = 0xA000 -- ROM-validated bank 6 TransferBufAddrs
local ISRNMI_ADDR = 0xE484 -- strict NES prepass: bank 7 IsrNmi
local RAM_DOMAIN = (domain_available("RAM") and "RAM")
    or (domain_available("WRAM") and "WRAM")
    or (domain_available("Main RAM") and "Main RAM")
    or nil
local HAS_MAINMEMORY = type(mainmemory) == "table" and type(mainmemory.read_u8) == "function"
local RAM_READ_DOMAIN = (domain_available("System Bus") and "System Bus")
    or (domain_available("CPU Bus") and "CPU Bus")
    or (domain_available("RAM") and "RAM")
    or (domain_available("Main RAM") and "Main RAM")
    or (domain_available("WRAM") and "WRAM")
    or "none"
local BANK6_BIN_PATH = repo_path("reference\\aldonunez\\dat\\nes_bank_06.bin")

local OW_COLUMN_HEAP_BASES = {
    0x9BD8, 0x9C0D, 0x9C3E, 0x9C80,
    0x9CC4, 0x9CF6, 0x9D32, 0x9D6D,
    0x9DA8, 0x9DE6, 0x9E27, 0x9E6C,
    0x9EA9, 0x9EDF, 0x9F21, 0x9F55,
}

local NES_BANK6_BYTES = nil
do
    local f = io.open(BANK6_BIN_PATH, "rb")
    if f then
        NES_BANK6_BYTES = f:read("*all")
        f:close()
    end
end

local function try_read(domain, addr)
    if not domain_available(domain) then
        return nil
    end
    local ok, value = pcall(function()
        memory.usememorydomain(domain)
        return memory.read_u8(addr)
    end)
    if ok then
        return value
    end
    return nil
end

local function mainmem_u8(addr)
    if not HAS_MAINMEMORY then
        return nil
    end
    local ok, value = pcall(function()
        return mainmemory.read_u8(addr % 0x0800)
    end)
    if ok then
        return value
    end
    return nil
end

local function ram_u8(addr)
    local cpu_addr = addr % 0x10000
    local domains
    if cpu_addr < 0x0800 then
        domains = {"System Bus", "CPU Bus", "RAM", "Main RAM", "WRAM"}
    else
        domains = {"System Bus", "CPU Bus", "RAM", "Main RAM", "WRAM"}
    end
    for i = 1, #domains do
        local read_addr = cpu_addr
        if domains[i] ~= "System Bus" and domains[i] ~= "CPU Bus" and cpu_addr < 0x2000 then
            read_addr = cpu_addr % 0x0800
        end
        local v = try_read(domains[i], read_addr)
        if v ~= nil then
            return v
        end
    end
    return 0
end

local function ciram_u8(addr)
    local domains = {"CIRAM (nametables)", "CIRAM", "Nametable RAM"}
    for i = 1, #domains do
        local v = try_read(domains[i], addr)
        if v ~= nil then
            return v
        end
    end
    return 0
end

local function palram_u8(addr)
    local domains = {"PALRAM", "Palette RAM", "PPU PALRAM"}
    for i = 1, #domains do
        local v = try_read(domains[i], addr)
        if v ~= nil then
            return v
        end
    end
    return 0
end

local function chr_u8(addr)
    local domains = {"CHR", "CHR VROM"}
    for i = 1, #domains do
        local v = try_read(domains[i], addr)
        if v ~= nil then
            return v
        end
    end
    return nil
end

local function cpu_bus_u8(addr)
    local domains = {"System Bus", "CPU Bus"}
    for i = 1, #domains do
        local v = try_read(domains[i], addr % 0x10000)
        if v ~= nil then
            return v
        end
    end
    return 0
end

local function bank6_u8(cpu_addr)
    if NES_BANK6_BYTES == nil then
        return nil
    end
    local addr = cpu_addr % 0x10000
    if addr < 0x8000 or addr >= 0xC000 then
        return nil
    end
    local index = (addr - 0x8000) + 1
    if index < 1 or index > #NES_BANK6_BYTES then
        return nil
    end
    return string.byte(NES_BANK6_BYTES, index)
end

local function transfer_source_u8(addr)
    local cpu_addr = addr % 0x10000
    local v = bank6_u8(cpu_addr)
    if v ~= nil then
        return v
    end
    return cpu_bus_u8(cpu_addr)
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
        if ok and id ~= nil then
            ids[#ids + 1] = id
        end
    end
    return ids
end

local function safe_set(pad)
    local ok = pcall(function()
        joypad.set(pad or {}, 1)
    end)
    if not ok then
        joypad.set(pad or {})
    end
end

local function record(lines, text)
    lines[#lines + 1] = text
    print(text)
end

local function schedule_input(state, button, hold_frames, release_frames, frame, why, lines)
    if state.hold_left > 0 or state.release_left > 0 then
        return false
    end
    state.button = button
    state.hold_left = hold_frames or 1
    state.release_left = 0
    state.release_after = release_frames or 8
    record(lines, string.format(
        "f%04d input %-9s hold=%d release=%d (%s)",
        frame, button, state.hold_left, state.release_after, why or "n/a"
    ))
    return true
end

local function build_pad_for_frame(state)
    local pad = {}
    if state.hold_left > 0 and state.button then
        pad[state.button] = true
        state.hold_left = state.hold_left - 1
        if state.hold_left == 0 then
            state.release_left = state.release_after
        end
    elseif state.release_left > 0 then
        state.release_left = state.release_left - 1
    end
    return pad
end

local function json_escape(s)
    s = s:gsub("\\", "\\\\")
    s = s:gsub('"', '\\"')
    s = s:gsub("\n", "\\n")
    return s
end

local function json_num_array(values)
    local parts = {}
    for i = 1, #values do
        parts[#parts + 1] = tostring(values[i])
    end
    return "[" .. table.concat(parts, ",") .. "]"
end

local function json_matrix(matrix)
    local rows = {}
    for i = 1, #matrix do
        rows[#rows + 1] = json_num_array(matrix[i])
    end
    return "[" .. table.concat(rows, ",") .. "]"
end

local function dump_workbuf_rows(base_ptr)
    local out = {}
    local base = base_ptr % 0x10000
    for row = 0, ROOM_ROWS - 1 do
        local row_vals = {}
        for col = 0, ROOM_COLS - 1 do
            local addr = (base + row + (col * ROOM_ROWS)) % 0x10000
            row_vals[#row_vals + 1] = cpu_bus_u8(addr)
        end
        out[#out + 1] = row_vals
    end
    return out
end

local function dump_playmap_rows()
    return dump_workbuf_rows(PLAYMAP_BASE)
end

local function build_decode_write_trace(layout_ptr_effective, workbuf_base_ptr, workbuf_rows)
    local trace = {}
    local writes = 0
    local work_ptr = workbuf_base_ptr % 0x10000
    local layout_ptr = layout_ptr_effective

    for col = 0, 15 do
        if writes >= TRACE_WRITE_COUNT then
            break
        end
        local descriptor = cpu_bus_u8(layout_ptr + col) % 0x100
        local table_idx = math.floor(descriptor / 16) % 16
        local column_idx = descriptor % 16
        local col_base = OW_COLUMN_HEAP_BASES[table_idx + 1] or OW_COLUMN_HEAP_BASES[1]

        local scan_ofs = 0xFF
        local remaining = column_idx
        while true do
            scan_ofs = (scan_ofs + 1) % 0x100
            local b = cpu_bus_u8(col_base + scan_ofs) % 0x100
            if b < 0x80 then
                -- keep scanning within current column blob
            else
                remaining = (remaining - 1) % 0x100
                if remaining >= 0x80 then
                    break
                end
            end
        end

        local ptr04 = (col_base + scan_ofs) % 0x10000
        local repeat_state = 0
        for row = 0, 10 do
            if writes >= TRACE_WRITE_COUNT then
                break
            end

            local ptr04_before = ptr04
            local desc = cpu_bus_u8(ptr04_before) % 0x100
            local repeat_flag = (math.floor(desc / 0x40) % 2) == 1
            local square_index = desc % 0x40
            local ptr00_before = work_ptr

            local r0 = row * 2
            local c0 = col * 2
            local tile0 = ((workbuf_rows[r0 + 1] or {})[c0 + 1] or 0) % 0x100
            local tile1 = ((workbuf_rows[r0 + 2] or {})[c0 + 1] or 0) % 0x100
            local tile2 = ((workbuf_rows[r0 + 1] or {})[c0 + 2] or 0) % 0x100
            local tile3 = ((workbuf_rows[r0 + 2] or {})[c0 + 2] or 0) % 0x100
            local ptr00_after = (work_ptr + 2) % 0x10000

            if repeat_flag then
                local v = 0
                if repeat_state == 0 then
                    v = 0x40
                end
                repeat_state = v
                if v == 0 then
                    ptr04 = (ptr04 + 1) % 0x10000
                end
            else
                ptr04 = (ptr04 + 1) % 0x10000
            end
            local ptr04_after = ptr04
            work_ptr = ptr00_after

            trace[#trace + 1] = {
                col = col,
                row = row,
                descriptor_raw = descriptor,
                repeat_flag = repeat_flag and 1 or 0,
                square_index = square_index,
                primary_tile = tile0,
                tile_write_seq = {tile0, tile1, tile2, tile3},
                ptr04_before = ptr04_before,
                ptr04_after = ptr04_after,
                ptr00_before = ptr00_before,
                ptr00_after = ptr00_after,
            }
            writes = writes + 1
        end
        work_ptr = (work_ptr + 0x16) % 0x10000
    end
    return trace
end

local function read_source_bytes_from_ptr(ptr, count)
    local bytes = {}
    for i = 0, count - 1 do
        bytes[#bytes + 1] = cpu_bus_u8(ptr + i)
    end
    return bytes
end

local function read_transfer_bytes_from_ptr(ptr, count)
    local bytes = {}
    for i = 0, count - 1 do
        bytes[#bytes + 1] = transfer_source_u8(ptr + i)
    end
    return bytes
end

local function build_trace_snapshot(name, frame, mode, sub, room_id)
    local ptr_inputs = {}
    for ofs = 0, 9 do
        ptr_inputs[#ptr_inputs + 1] = ram_u8(ofs)
    end

    local source_samples = {}
    local ptr_pairs = {
        {"ptr_00_01", 1, 2},
        {"ptr_02_03", 3, 4},
        {"ptr_04_05", 5, 6},
        {"ptr_06_07", 7, 8},
        {"ptr_08_09", 9, 10},
    }
    for i = 1, #ptr_pairs do
        local pair = ptr_pairs[i]
        local lo = ptr_inputs[pair[2]] or 0
        local hi = ptr_inputs[pair[3]] or 0
        local ptr = (hi * 256 + lo) % 0x10000
        source_samples[#source_samples + 1] = {
            label = pair[1],
            ptr = ptr,
            bytes = read_source_bytes_from_ptr(ptr, SOURCE_SAMPLE_BYTES),
        }
    end

    return {
        name = name,
        frame = frame,
        mode = mode,
        submode = sub,
        room_id = room_id,
        ptr_inputs = ptr_inputs,
        source_samples = source_samples,
        ppu_ctrl_shadow = ram_u8(0x00FF),
    }
end

local function build_layoutroomow_exit_snapshot(frame, mode, sub, room_id)
    local snap = build_trace_snapshot("layoutroomow_exit_snapshot", frame, mode, sub, room_id)
    local p = snap.ptr_inputs
    local ptr_00_01 = ((p[2] or 0) * 256 + (p[1] or 0)) % 0x10000
    local ptr_02_03 = ((p[4] or 0) * 256 + (p[3] or 0)) % 0x10000
    local ptr_04_05 = ((p[6] or 0) * 256 + (p[5] or 0)) % 0x10000
    local ptr_06_09 = ((p[10] or 0) * 256 + (p[7] or 0)) % 0x10000
    local workbuf_base_ptr = (ptr_00_01 - WORKBUF_LOOP_ADVANCE) % 0x10000
    if workbuf_base_ptr < 0x6400 or workbuf_base_ptr > 0x6BFF then
        workbuf_base_ptr = PLAYMAP_BASE
    end
    snap.ptr_00_01 = ptr_00_01
    snap.ptr_02_03 = ptr_02_03
    snap.ptr_04_05 = ptr_04_05
    snap.ptr_06_09 = ptr_06_09
    snap.workbuf_base_ptr = workbuf_base_ptr
    snap.layout_ptr_effective = ptr_02_03
    local raw_est = math.floor(((ptr_02_03 - 0x9818) % 0x10000) / 0x10) % 0x100
    snap.room_attr_raw = raw_est
    snap.room_attr_masked = raw_est % 0x40
    snap.layout_bytes = read_source_bytes_from_ptr(ptr_02_03, SOURCE_SAMPLE_BYTES)
    snap.column_bytes = read_source_bytes_from_ptr(ptr_04_05, SOURCE_SAMPLE_BYTES)
    return snap
end

local function json_source_samples(samples)
    local out = {}
    for i = 1, #samples do
        local s = samples[i]
        out[#out + 1] = string.format(
            '{"label":"%s","ptr":%d,"bytes":%s}',
            json_escape(s.label),
            s.ptr,
            json_num_array(s.bytes)
        )
    end
    return "[" .. table.concat(out, ",") .. "]"
end

local function json_trace_snapshots(traces)
    local out = {}
    for i = 1, #traces do
        local t = traces[i]
        local ptr_00_01 = t.ptr_00_01 or -1
        local ptr_02_03 = t.ptr_02_03 or -1
        local ptr_04_05 = t.ptr_04_05 or -1
        local ptr_06_09 = t.ptr_06_09 or -1
        local workbuf_base_ptr = t.workbuf_base_ptr or -1
        local room_attr_raw = t.room_attr_raw or -1
        local room_attr_masked = t.room_attr_masked or -1
        local layout_ptr_effective = t.layout_ptr_effective or -1
        local layout_bytes = t.layout_bytes or {}
        local column_bytes = t.column_bytes or {}
        out[#out + 1] = string.format(
            '{"name":"%s","frame":%d,"mode":%d,"submode":%d,"room_id":%d,' ..
            '"ptr_inputs":%s,"source_samples":%s,"ppu_ctrl_shadow":%d,' ..
            '"ptr_00_01":%d,"ptr_02_03":%d,"ptr_04_05":%d,"ptr_06_09":%d,"workbuf_base_ptr":%d,' ..
            '"room_attr_raw":%d,"room_attr_masked":%d,"layout_ptr_effective":%d,' ..
            '"layout_bytes":%s,"column_bytes":%s}',
            json_escape(t.name),
            t.frame,
            t.mode,
            t.submode,
            t.room_id,
            json_num_array(t.ptr_inputs),
            json_source_samples(t.source_samples),
            t.ppu_ctrl_shadow,
            ptr_00_01,
            ptr_02_03,
            ptr_04_05,
            ptr_06_09,
            workbuf_base_ptr,
            room_attr_raw,
            room_attr_masked,
            layout_ptr_effective,
            json_num_array(layout_bytes),
            json_num_array(column_bytes)
        )
    end
    return "[" .. table.concat(out, ",") .. "]"
end

local function json_decode_write_trace(entries)
    local out = {}
    for i = 1, #entries do
        local e = entries[i]
        out[#out + 1] = string.format(
            '{"col":%d,"row":%d,"descriptor_raw":%d,"repeat_flag":%d,"square_index":%d,' ..
            '"primary_tile":%d,"tile_write_seq":%s,"ptr04_before":%d,"ptr04_after":%d,' ..
            '"ptr00_before":%d,"ptr00_after":%d}',
            e.col or 0,
            e.row or 0,
            e.descriptor_raw or 0,
            e.repeat_flag or 0,
            e.square_index or 0,
            e.primary_tile or 0,
            json_num_array(e.tile_write_seq or {}),
            e.ptr04_before or 0,
            e.ptr04_after or 0,
            e.ptr00_before or 0,
            e.ptr00_after or 0
        )
    end
    return "[" .. table.concat(out, ",") .. "]"
end

local function json_decode_write_trace_rt(entries)
    local out = {}
    for i = 1, #entries do
        local e = entries[i]
        out[#out + 1] = string.format(
            '{"seq":%d,"frame":%d,"addr":%d,"value":%d,"mode":%d,"submode":%d,' ..
            '"ptr00_01":%d,"ptr04_05":%d,"room_attr_raw":%d,"room_attr_masked":%d,' ..
            '"repeat_state":%d,"square_index":%d}',
            e.seq or 0,
            e.frame or 0,
            e.addr or 0,
            e.value or 0,
            e.mode or 0,
            e.submode or 0,
            e.ptr00_01 or 0,
            e.ptr04_05 or 0,
            e.room_attr_raw or 0,
            e.room_attr_masked or 0,
            e.repeat_state or 0,
            e.square_index or 0
        )
    end
    return "[" .. table.concat(out, ",") .. "]"
end

local function read_status_inputs()
    return {
        inv_bombs = ram_u8(0x0658) % 0x100,
        inv_magic_key = ram_u8(0x0664) % 0x100,
        inv_rupees = ram_u8(0x066D) % 0x100,
        inv_keys = ram_u8(0x066E) % 0x100,
        heart_values = ram_u8(0x066F) % 0x100,
        heart_partial = ram_u8(0x0670) % 0x100,
    }
end

local function json_transfer_records(entries)
    local out = {}
    for i = 1, #entries do
        local e = entries[i]
        out[#out + 1] = string.format(
            '{"seq":%d,"frame":%d,"mode":%d,"submode":%d,"cur_row":%d,"tile_buf_selector":%d,' ..
            '"dyn_tile_buf_len":%d,"vram_addr":%d,"control":%d,"bytes":%s}',
            e.seq or 0,
            e.frame or 0,
            e.mode or 0,
            e.submode or 0,
            e.cur_row or 0,
            e.tile_buf_selector or 0,
            e.dyn_tile_buf_len or 0,
            e.vram_addr or 0,
            e.control or 0,
            json_num_array(e.bytes or {})
        )
    end
    return "[" .. table.concat(out, ",") .. "]"
end

local function json_string_array(values)
    local out = {}
    for i = 1, #values do
        out[#out + 1] = string.format('"%s"', json_escape(values[i]))
    end
    return "[" .. table.concat(out, ",") .. "]"
end

local function json_edge_owner_trace(entries)
    local out = {}
    for i = 1, #entries do
        local e = entries[i]
        out[#out + 1] = string.format(
            '{"seq":%d,"frame":%d,"mode":%d,"submode":%d,"addr":%d,"value":%d,"writer_class":"%s","pc":%d}',
            e.seq or 0,
            e.frame or 0,
            e.mode or 0,
            e.submode or 0,
            e.addr or 0,
            e.value or 0,
            json_escape(e.writer_class or ""),
            e.pc or -1
        )
    end
    return "[" .. table.concat(out, ",") .. "]"
end

local function json_edge_owner_point(e)
    if e == nil then
        return "null"
    end
    return string.format(
        '{"seq":%d,"frame":%d,"mode":%d,"submode":%d,"addr":%d,"value":%d,"writer_class":"%s","pc":%d}',
        e.seq or 0,
        e.frame or 0,
        e.mode or 0,
        e.submode or 0,
        e.addr or 0,
        e.value or 0,
        json_escape(e.writer_class or ""),
        e.pc or -1
    )
end

local function attr_palette(attr_byte, row, col)
    local quad_row = math.floor((row % 4) / 2)
    local quad_col = math.floor((col % 4) / 2)
    local quadrant = quad_row * 2 + quad_col
    local shift = quadrant * 2
    return math.floor(attr_byte / (2 ^ shift)) % 4
end

local lines = {}
record(lines, "system_id=" .. SYSTEM_ID)
record(lines, "available_memory_domains=" .. available_domains_csv())
record(lines, "selected_ram_domain=" .. RAM_READ_DOMAIN)
record(lines, string.format(
    "bank6_bin_loaded=%s bytes_a000=%s",
    (NES_BANK6_BYTES ~= nil) and "yes" or "no",
    (function()
        if NES_BANK6_BYTES == nil then
            return "n/a"
        end
        local bytes = {}
        for i = 0, 7 do
            bytes[#bytes + 1] = string.format("%02X", bank6_u8(0xA000 + i) or 0xFF)
        end
        return table.concat(bytes, " ")
    end)()
))

local function write_fatal_capture(reason)
    record(lines, "fatal_error=" .. reason)
    local out = assert(io.open(OUT_TXT, "w"))
    out:write(table.concat(lines, "\n"))
    out:write("\n")
    out:close()

    local jf = assert(io.open(OUT_JSON, "w"))
    jf:write("{\n")
    jf:write('  "capture_valid": false,\n')
    jf:write('  "fatal_error": "', json_escape(reason), '",\n')
    jf:write('  "system_id": "', json_escape(SYSTEM_ID), '",\n')
    jf:write('  "available_memory_domains": "', json_escape(available_domains_csv()), '",\n')
    jf:write('  "target_room_id": ', tostring(TARGET_ROOM_ID), "\n")
    jf:write("}\n")
    jf:close()
    client.exit()
end

if SYSTEM_ID ~= "NES" then
    write_fatal_capture("wrong_system_loaded_expected_NES")
    return
end

if (not domain_available("RAM") and not domain_available("WRAM") and not domain_available("Main RAM"))
    or (not domain_available("CIRAM (nametables)") and not domain_available("CIRAM") and not domain_available("Nametable RAM"))
    or (not domain_available("PALRAM") and not domain_available("Palette RAM") and not domain_available("PPU PALRAM")) then
    write_fatal_capture("required_nes_memory_domains_missing")
    return
end

local mode_changes = {}
local flow_state = FLOW_BOOT_TO_FS1
local flow_state_frame = 1
local current_frame = 0

local input_state = {
    button = nil,
    hold_left = 0,
    release_left = 0,
    release_after = 0,
}

local CAPTURE = {
    register_mode_seen = false,
    name_progress_events = 0,
    last_name_offset = 0,
    last_cur_slot = 0xFF,
    reached_target = false,
    target_frame = nil,
    mode3_sub8_snapshot = nil,
    mode5_stable_snapshot = nil,
    layoutroomow_exit_snapshot = nil,
    layoutroomow_exit_workbuf_rows = nil,
    mode3_sub8_workbuf_rows = nil,
    mode5_stable_count = 0,
    trace_snapshots = {},
    prev_mode = nil,
    prev_sub = nil,
}

local RUNTIME = {
    trace_rt_active = false,
    trace_rt_started = false,
    decode_write_trace_rt = {},
    runtime_trace_summary = nil,
    runtime_write_hooks_enabled = false,
    transfer_stream_events = {},
    last_transfer_stream_sig = nil,
    transfer_exec_hook_armed = false,
    transfer_exec_hook_hits = 0,
    transfer_exec_samples = {},
    transfer_exec_hits_by_frame = {},
    transfer_exec_callback_errors = {},
    transfer_parse_consistency_errors = {},
    edge_owner_trace = {},
    edge_trace_started = false,
    edge_trace_active = false,
    edge_trace_prev_window = nil,
    edge_writer_frame_classes = {},
    edge_writer_last_pc = -1,
    transition_trace_start_frame = nil,
    transition_state_frames = {},
}

local WALK = {
    started = false,
    index = 1,
    prev_room = 0x77,
    step_room = nil,
    step_mode5_stable_count = 0,
    start_room_stable_count = 0,
}

local function reset_target_transition_capture(frame, lines)
    CAPTURE.reached_target = false
    CAPTURE.target_frame = nil
    CAPTURE.mode3_sub8_snapshot = nil
    CAPTURE.mode5_stable_snapshot = nil
    CAPTURE.layoutroomow_exit_snapshot = nil
    CAPTURE.layoutroomow_exit_workbuf_rows = nil
    CAPTURE.mode3_sub8_workbuf_rows = nil
    CAPTURE.mode5_stable_count = 0
    CAPTURE.trace_snapshots = {}
    mode_changes = {}
    CAPTURE.prev_mode = nil
    CAPTURE.prev_sub = nil
    RUNTIME.decode_write_trace_rt = {}
    RUNTIME.runtime_trace_summary = nil
    RUNTIME.transfer_stream_events = {}
    RUNTIME.last_transfer_stream_sig = nil
    RUNTIME.transfer_exec_hook_hits = 0
    RUNTIME.transfer_exec_samples = {}
    RUNTIME.transfer_exec_hits_by_frame = {}
    RUNTIME.transfer_exec_callback_errors = {}
    RUNTIME.transfer_parse_consistency_errors = {}
    RUNTIME.edge_owner_trace = {}
    RUNTIME.edge_trace_started = false
    RUNTIME.edge_trace_active = false
    RUNTIME.edge_trace_prev_window = nil
    RUNTIME.edge_writer_frame_classes = {}
    RUNTIME.edge_writer_last_pc = -1
    WALK.step_room = nil
    WALK.step_mode5_stable_count = 0
    RUNTIME.transition_trace_start_frame = frame
    RUNTIME.transition_state_frames = {}
    record(lines, string.format("f%04d reset capture state for target-room transition path=%s", frame, TARGET_WALK_PATH))
end

local function apply_walk_pad(pad)
    if not WALK.started or WALK.index > #TARGET_WALK_PATH then
        return pad
    end
    local d = TARGET_WALK_PATH:sub(WALK.index, WALK.index)
    if d == "L" then
        pad["Left"] = true
        pad["P1 Left"] = true
    elseif d == "R" then
        pad["Right"] = true
        pad["P1 Right"] = true
    elseif d == "U" then
        pad["Up"] = true
        pad["P1 Up"] = true
    elseif d == "D" then
        pad["Down"] = true
        pad["P1 Down"] = true
    end
    return pad
end

local function read_transfer_state()
    return {
        cur_column = ram_u8(0x00E8) % 0x100,
        cur_row = ram_u8(0x00E9) % 0x100,
        prev_column = ram_u8(0x00EC) % 0x100,
        prev_row = ram_u8(0x00ED) % 0x100,
    }
end

local function read_transition_state(frame, mode, sub, room_id)
    return {
        frame = frame,
        transition_frame = (RUNTIME.transition_trace_start_frame and (frame - RUNTIME.transition_trace_start_frame)) or -1,
        mode = mode % 0x100,
        submode = sub % 0x100,
        cur_level = ram_u8(0x0010) % 0x100,
        is_updating_mode = ram_u8(0x0011) % 0x100,
        room_id = room_id % 0x100,
        next_room_id = ram_u8(0x00EC) % 0x100,
        obj_dir = ram_u8(0x0098) % 0x100,
        tile_buf_selector = ram_u8(0x0014) % 0x100,
        ppu_update_0017 = ram_u8(0x0017) % 0x100,
        dyn_tile_buf_len = ram_u8(0x0301) % 0x100,
        dyn_tile_buf_head = ram_u8(0x0302) % 0x100,
        sprite0_check_active = ram_u8(0x00E3) % 0x100,
        shadow_f3 = ram_u8(0x00F3) % 0x100,
        switch_nametables_req = ram_u8(0x005C) % 0x100,
        vscroll_addr_hi = ram_u8(0x0058) % 0x100,
        vscroll_start_frame = ram_u8(0x00E6) % 0x100,
        cur_column = ram_u8(0x00E8) % 0x100,
        cur_row = ram_u8(0x00E9) % 0x100,
        prev_row = ram_u8(0x00ED) % 0x100,
        cur_hscroll = ram_u8(0x00FD) % 0x100,
        cur_vscroll = ram_u8(0x00FC) % 0x100,
    }
end

local function capture_transition_state(frame, mode, sub, room_id)
    if RUNTIME.transition_trace_start_frame == nil or #RUNTIME.transition_state_frames >= TRANSITION_STATE_MAX_FRAMES then
        return
    end
    RUNTIME.transition_state_frames[#RUNTIME.transition_state_frames + 1] = read_transition_state(frame, mode, sub, room_id)
end

local function note_transfer_exec_hit(frame)
    if frame == nil or frame <= 0 then
        return
    end
    local last = RUNTIME.transfer_exec_hits_by_frame[#RUNTIME.transfer_exec_hits_by_frame]
    if last and last.frame == frame then
        last.hits = last.hits + 1
        return
    end
    if #RUNTIME.transfer_exec_hits_by_frame >= TRANSFER_EXEC_HIT_LOG_MAX then
        return
    end
    RUNTIME.transfer_exec_hits_by_frame[#RUNTIME.transfer_exec_hits_by_frame + 1] = {frame = frame, hits = 1}
end

local function note_transfer_exec_error(frame, err)
    if #RUNTIME.transfer_exec_callback_errors >= TRANSFER_EXEC_ERROR_MAX then
        return
    end
    RUNTIME.transfer_exec_callback_errors[#RUNTIME.transfer_exec_callback_errors + 1] = {
        frame = frame or -1,
        error = tostring(err or "unknown"),
    }
end

local function read_ptr00_01()
    return ((ram_u8(0x0001) % 0x100) * 0x100 + (ram_u8(0x0000) % 0x100)) % 0x10000
end

local function read_ptr04_05()
    return ((ram_u8(0x0005) % 0x100) * 0x100 + (ram_u8(0x0004) % 0x100)) % 0x10000
end

local function reset_edge_writer_activity()
    RUNTIME.edge_writer_frame_classes = {}
    RUNTIME.edge_writer_last_pc = -1
end

local function mark_edge_writer_activity(writer_class, pc)
    if writer_class == nil or writer_class == "" then
        return
    end
    RUNTIME.edge_writer_frame_classes[writer_class] = true
    if pc ~= nil then
        RUNTIME.edge_writer_last_pc = pc
    end
end

local function edge_writer_summary()
    local classes = {}
    for k, _ in pairs(RUNTIME.edge_writer_frame_classes) do
        classes[#classes + 1] = k
    end
    table.sort(classes)
    if #classes == 0 then
        return "direct_ntcache_or_external", RUNTIME.edge_writer_last_pc
    end
    return table.concat(classes, "|"), RUNTIME.edge_writer_last_pc
end

local function dump_edge_owner_window()
    local out = {}
    for row = 0, EDGE_TRACE_ROWS - 1 do
        local ciram_base = EDGE_TRACE_TOP_CIRAM + row * 0x20
        local ppu_base = EDGE_TRACE_TOP_PPU + row * 0x20
        out[#out + 1] = {addr = ppu_base, value = ciram_u8(ciram_base) % 0x100}
        out[#out + 1] = {addr = ppu_base + 0x1F, value = ciram_u8(ciram_base + 0x1F) % 0x100}
    end
    return out
end

local function append_edge_owner_trace(addr, value)
    if not RUNTIME.edge_trace_active then
        return
    end
    if #RUNTIME.edge_owner_trace >= EDGE_TRACE_MAX_ENTRIES then
        return
    end
    local writer_class, pc = edge_writer_summary()
    RUNTIME.edge_owner_trace[#RUNTIME.edge_owner_trace + 1] = {
        seq = #RUNTIME.edge_owner_trace + 1,
        frame = current_frame,
        mode = ram_u8(0x0012) % 0x100,
        submode = ram_u8(0x0013) % 0x100,
        addr = addr % 0x10000,
        value = value % 0x100,
        writer_class = writer_class,
        pc = pc or -1,
    }
end

local function capture_edge_owner_deltas()
    if not RUNTIME.edge_trace_active then
        return
    end
    local cur = dump_edge_owner_window()
    if RUNTIME.edge_trace_prev_window == nil then
        RUNTIME.edge_trace_prev_window = cur
        return
    end
    for i = 1, #cur do
        if cur[i].value ~= RUNTIME.edge_trace_prev_window[i].value then
            append_edge_owner_trace(cur[i].addr, cur[i].value)
        end
    end
    RUNTIME.edge_trace_prev_window = cur
end

local function build_edge_owner_summary(entries, valid)
    local class_set = {}
    for i = 1, #entries do
        local cls = entries[i].writer_class or ""
        if cls ~= "" then
            class_set[cls] = true
        end
    end
    local classes = {}
    for cls, _ in pairs(class_set) do
        classes[#classes + 1] = cls
    end
    table.sort(classes)
    return {
        valid = valid and true or false,
        entries = #entries,
        writer_classes = classes,
        first_write = (#entries > 0) and entries[1] or nil,
        last_write = (#entries > 0) and entries[#entries] or nil,
    }
end

local function append_runtime_trace(addr, value)
    if not RUNTIME.trace_rt_active then
        return
    end
    if #RUNTIME.decode_write_trace_rt >= TRACE_RT_MAX_WRITES then
        return
    end
    local mode = ram_u8(0x0012)
    local sub = ram_u8(0x0013)
    local room_id = ram_u8(0x00EB) % 0x100
    local room_attr_raw = cpu_bus_u8((0x09FE + room_id) % 0x10000) % 0x100
    RUNTIME.decode_write_trace_rt[#RUNTIME.decode_write_trace_rt + 1] = {
        seq = #RUNTIME.decode_write_trace_rt + 1,
        frame = current_frame,
        addr = addr % 0x10000,
        value = value % 0x100,
        mode = mode % 0x100,
        submode = sub % 0x100,
        ptr00_01 = read_ptr00_01(),
        ptr04_05 = read_ptr04_05(),
        room_attr_raw = room_attr_raw,
        room_attr_masked = room_attr_raw % 0x40,
        repeat_state = ram_u8(0x000C) % 0x100,
        square_index = ram_u8(0x000D) % 0x100,
    }
end

local function register_runtime_trace_hooks()
    -- quickerNES does not reliably support memory callbacks; use deterministic
    -- delta-trace fallback to avoid callback warning spam.
    RUNTIME.runtime_write_hooks_enabled = false
    record(lines, "runtime write hooks disabled on NES core; using delta trace fallback")
end

register_runtime_trace_hooks()
local trace_rt_prev_window = nil

local function dump_playmap_linear()
    local out = {}
    for col = 0, ROOM_COLS - 1 do
        for row = 0, ROOM_ROWS - 1 do
            local addr = (PLAYMAP_BASE + row + (col * ROOM_ROWS)) % 0x10000
            out[#out + 1] = ram_u8(addr) % 0x100
        end
    end
    return out
end

local function capture_runtime_trace_deltas()
    local cur = dump_playmap_linear()
    if trace_rt_prev_window == nil then
        trace_rt_prev_window = cur
        return
    end
    for i = 1, #cur do
        if #RUNTIME.decode_write_trace_rt >= TRACE_RT_MAX_WRITES then
            break
        end
        if cur[i] ~= trace_rt_prev_window[i] then
            local idx = i - 1
            local col = math.floor(idx / ROOM_ROWS)
            local row = idx % ROOM_ROWS
            local addr = (PLAYMAP_BASE + row + (col * ROOM_ROWS)) % 0x10000
            append_runtime_trace(addr, cur[i])
        end
    end
    trace_rt_prev_window = cur
end

local function decode_transfer_stream_from_ptr(ptr)
    local raw = {}
    local records = {}
    local cursor = ptr % 0x10000
    local terminated = false
    local truncated = false

    for _ = 1, TRANSFER_STREAM_MAX_RECORDS do
        if #raw >= TRANSFER_STREAM_MAX_BYTES then
            truncated = true
            break
        end

        local hi = transfer_source_u8(cursor) % 0x100
        raw[#raw + 1] = hi
        if hi == 0xFF then
            terminated = true
            break
        end

        local lo = transfer_source_u8((cursor + 1) % 0x10000) % 0x100
        local control = transfer_source_u8((cursor + 2) % 0x10000) % 0x100
        raw[#raw + 1] = lo
        raw[#raw + 1] = control

        local count = control & 0x3F
        if count == 0 then
            count = 0x40
        end
        local repeat_mode = (control & 0x40) ~= 0
        local vertical_increment = (control & 0x80) ~= 0
        local payload_len = repeat_mode and 1 or count
        local payload = {}
        for i = 0, payload_len - 1 do
            if #raw >= TRANSFER_STREAM_MAX_BYTES then
                truncated = true
                break
            end
            local v = transfer_source_u8((cursor + 3 + i) % 0x10000) % 0x100
            payload[#payload + 1] = v
            raw[#raw + 1] = v
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
        if truncated then
            break
        end
    end

    return {
        raw_stream_bytes = raw,
        decoded_records = records,
        terminated = terminated,
        truncated = truncated,
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

local function capture_transfer_stream_event(frame, mode, sub, selector, dyn_len, source_ptr, source_kind, dispatch_role, parsed)
    if #RUNTIME.transfer_stream_events >= TRANSFER_STREAM_MAX_EVENTS then
        return
    end
    if mode ~= 0x03 and mode ~= 0x04 and mode ~= 0x05 and mode ~= 0x06 and mode ~= 0x07 then
        return
    end
    parsed = parsed or decode_transfer_stream_from_ptr(source_ptr)
    if parsed.empty then
        return
    end

    local sig = string.format(
        "%02X:%02X:%02X:%s:%s:%04X:%s",
        frame % 0x100,
        mode % 0x100,
        sub % 0x100,
        dispatch_role or "transfer",
        source_kind or "static",
        source_ptr % 0x10000,
        table.concat(parsed.raw_stream_bytes, ",")
    )
    if sig == RUNTIME.last_transfer_stream_sig then
        return
    end
    RUNTIME.last_transfer_stream_sig = sig
    local state = read_transfer_state()
    local status = read_status_inputs()

    RUNTIME.transfer_stream_events[#RUNTIME.transfer_stream_events + 1] = {
        seq = #RUNTIME.transfer_stream_events + 1,
        frame = frame,
        mode = mode % 0x100,
        submode = sub % 0x100,
        tile_buf_selector = selector,
        dyn_tile_buf_len = dyn_len,
        source_kind = source_kind or "static",
        dispatch_role = dispatch_role or "transfer",
        source_ptr = source_ptr,
        cur_column = state.cur_column,
        cur_row = state.cur_row,
        prev_column = state.prev_column,
        prev_row = state.prev_row,
        raw_stream_bytes = parsed.raw_stream_bytes,
        decoded_records = parsed.decoded_records,
        terminated = parsed.terminated and 1 or 0,
        truncated = parsed.truncated and 1 or 0,
        inv_bombs = status.inv_bombs,
        inv_magic_key = status.inv_magic_key,
        inv_rupees = status.inv_rupees,
        inv_keys = status.inv_keys,
        heart_values = status.heart_values,
        heart_partial = status.heart_partial,
    }
end

local function register_transfer_exec_hook()
    local ids = add_exec_hook_variants(ISRNMI_ADDR, function()
        local ok, err = pcall(function()
            local mode = ram_u8(0x0012)
            local sub = ram_u8(0x0013)
            RUNTIME.transfer_exec_hook_hits = RUNTIME.transfer_exec_hook_hits + 1
            note_transfer_exec_hit(current_frame)
            mark_edge_writer_activity("isr_nmi", ISRNMI_ADDR)
            local selector = ram_u8(0x0014) % 0x100
            local dyn_len = ram_u8(0x0301) % 0x100
            local source_ptr = resolve_transfer_source_ptr(selector)
            local source_kind = (source_ptr == 0x0302) and "dyn" or "static"
            local bytes_head = read_transfer_bytes_from_ptr(source_ptr, 8)
            local state = read_transfer_state()
            local parsed = nil
            if source_ptr > 0 then
                parsed = decode_transfer_stream_from_ptr(source_ptr)
                if #RUNTIME.transfer_parse_consistency_errors < 8 then
                    local mismatch = false
                    for i = 1, math.min(#bytes_head, #parsed.raw_stream_bytes) do
                        if bytes_head[i] ~= parsed.raw_stream_bytes[i] then
                            mismatch = true
                            break
                        end
                    end
                    if mismatch then
                        RUNTIME.transfer_parse_consistency_errors[#RUNTIME.transfer_parse_consistency_errors + 1] = {
                            frame = current_frame,
                            mode = mode,
                            submode = sub,
                            tile_buf_selector = selector,
                            source_ptr = source_ptr,
                            bytes_head = bytes_head,
                            parsed_head = {table.unpack(parsed.raw_stream_bytes, 1, math.min(8, #parsed.raw_stream_bytes))},
                        }
                    end
                end
            end
            if #RUNTIME.transfer_exec_samples < 256
                and (mode == 0x03 or mode == 0x04 or mode == 0x05 or mode == 0x06 or mode == 0x07 or RUNTIME.transition_trace_start_frame ~= nil) then
                RUNTIME.transfer_exec_samples[#RUNTIME.transfer_exec_samples + 1] = {
                    frame = current_frame,
                    mode = mode,
                    submode = sub,
                    dyn_tile_buf_len = dyn_len,
                    tile_buf_selector = selector,
                    source_kind = source_kind,
                    dispatch_role = "transfer",
                    source_ptr = source_ptr,
                    cur_column = state.cur_column,
                    cur_row = state.cur_row,
                    prev_column = state.prev_column,
                    prev_row = state.prev_row,
                    bytes_head = bytes_head,
                }
            end
            if source_ptr > 0 then
                capture_transfer_stream_event(current_frame, mode, sub, selector, dyn_len, source_ptr, source_kind, "transfer", parsed)
            end
        end)
        if not ok then
            note_transfer_exec_error(current_frame, err)
        end
    end, ROOM_TAG .. "_transfercurtilebuf")
    if #ids > 0 then
        RUNTIME.transfer_exec_hook_armed = true
        record(lines, string.format("transfer exec hook armed at IsrNmi $%04X (%d variants)", ISRNMI_ADDR, #ids))
    else
        record(lines, string.format("transfer exec hook failed at IsrNmi $%04X; polling fallback only", ISRNMI_ADDR))
    end
end

local function json_transfer_exec_samples(entries)
    local out = {}
    for i = 1, #entries do
        local e = entries[i]
        out[#out + 1] = string.format(
            '{"frame":%d,"mode":%d,"submode":%d,"dyn_tile_buf_len":%d,"tile_buf_selector":%d,' ..
            '"source_kind":"%s","dispatch_role":"%s","source_ptr":%d,' ..
            '"cur_column":%d,"cur_row":%d,"prev_column":%d,"prev_row":%d,"bytes_head":%s}',
            e.frame or 0,
            e.mode or 0,
            e.submode or 0,
            e.dyn_tile_buf_len or 0,
            e.tile_buf_selector or 0,
            json_escape(e.source_kind or ""),
            json_escape(e.dispatch_role or ""),
            e.source_ptr or 0,
            e.cur_column or 0,
            e.cur_row or 0,
            e.prev_column or 0,
            e.prev_row or 0,
            json_num_array(e.bytes_head or {})
        )
    end
    return "[" .. table.concat(out, ",") .. "]"
end

local function json_transfer_exec_hits(entries)
    local out = {}
    for i = 1, #entries do
        local e = entries[i]
        out[#out + 1] = string.format('{"frame":%d,"hits":%d}', e.frame or 0, e.hits or 0)
    end
    return "[" .. table.concat(out, ",") .. "]"
end

local function json_transfer_exec_errors(entries)
    local out = {}
    for i = 1, #entries do
        local e = entries[i]
        out[#out + 1] = string.format('{"frame":%d,"error":"%s"}', e.frame or -1, json_escape(e.error or ""))
    end
    return "[" .. table.concat(out, ",") .. "]"
end

local function json_transition_state_frames(entries)
    local out = {}
    for i = 1, #entries do
        local e = entries[i]
        out[#out + 1] = string.format(
            '{"frame":%d,"transition_frame":%d,"mode":%d,"submode":%d,"cur_level":%d,"is_updating_mode":%d,' ..
            '"room_id":%d,"next_room_id":%d,"obj_dir":%d,"tile_buf_selector":%d,"ppu_update_0017":%d,' ..
            '"dyn_tile_buf_len":%d,"dyn_tile_buf_head":%d,"sprite0_check_active":%d,"shadow_f3":%d,' ..
            '"switch_nametables_req":%d,"vscroll_addr_hi":%d,"vscroll_start_frame":%d,' ..
            '"cur_column":%d,"cur_row":%d,"prev_row":%d,"cur_hscroll":%d,"cur_vscroll":%d}',
            e.frame or 0,
            e.transition_frame or -1,
            e.mode or 0,
            e.submode or 0,
            e.cur_level or 0,
            e.is_updating_mode or 0,
            e.room_id or 0,
            e.next_room_id or 0,
            e.obj_dir or 0,
            e.tile_buf_selector or 0,
            e.ppu_update_0017 or 0,
            e.dyn_tile_buf_len or 0,
            e.dyn_tile_buf_head or 0,
            e.sprite0_check_active or 0,
            e.shadow_f3 or 0,
            e.switch_nametables_req or 0,
            e.vscroll_addr_hi or 0,
            e.vscroll_start_frame or 0,
            e.cur_column or 0,
            e.cur_row or 0,
            e.prev_row or 0,
            e.cur_hscroll or 0,
            e.cur_vscroll or 0
        )
    end
    return "[" .. table.concat(out, ",") .. "]"
end

local function json_transfer_decoded_records(records)
    local out = {}
    for i = 1, #records do
        local r = records[i]
        out[#out + 1] = string.format(
            '{"vram_addr":%d,"control":%d,"count":%d,"vertical_increment":%d,' ..
            '"repeat_mode":%d,"payload_bytes":%s}',
            r.vram_addr or 0,
            r.control or 0,
            r.count or 0,
            r.vertical_increment or 0,
            r.repeat_mode or 0,
            json_num_array(r.payload_bytes or {})
        )
    end
    return "[" .. table.concat(out, ",") .. "]"
end

local function json_transfer_stream_events(entries)
    local out = {}
    for i = 1, #entries do
        local e = entries[i]
        out[#out + 1] = string.format(
            '{"seq":%d,"frame":%d,"mode":%d,"submode":%d,"tile_buf_selector":%d,"dyn_tile_buf_len":%d,' ..
            '"source_kind":"%s","dispatch_role":"%s","source_ptr":%d,' ..
            '"cur_column":%d,"cur_row":%d,"prev_column":%d,"prev_row":%d,' ..
            '"terminated":%d,"truncated":%d,"inv_bombs":%d,"inv_magic_key":%d,"inv_rupees":%d,' ..
            '"inv_keys":%d,"heart_values":%d,"heart_partial":%d,' ..
            '"raw_stream_bytes":%s,"decoded_records":%s}',
            e.seq or 0,
            e.frame or 0,
            e.mode or 0,
            e.submode or 0,
            e.tile_buf_selector or 0,
            e.dyn_tile_buf_len or 0,
            json_escape(e.source_kind or ""),
            json_escape(e.dispatch_role or ""),
            e.source_ptr or 0,
            e.cur_column or 0,
            e.cur_row or 0,
            e.prev_column or 0,
            e.prev_row or 0,
            e.terminated or 0,
            e.truncated or 0,
            e.inv_bombs or 0,
            e.inv_magic_key or 0,
            e.inv_rupees or 0,
            e.inv_keys or 0,
            e.heart_values or 0,
            e.heart_partial or 0,
            json_num_array(e.raw_stream_bytes or {}),
            json_transfer_decoded_records(e.decoded_records or {})
        )
    end
    return "[" .. table.concat(out, ",") .. "]"
end

local function json_mode_changes(entries)
    local out = {}
    for i = 1, #entries do
        local e = entries[i]
        out[#out + 1] = string.format(
            '{"frame":%d,"mode":%d,"submode":%d,"room":%d}',
            e.frame or 0,
            e.mode or 0,
            e.sub or 0,
            e.room or 0
        )
    end
    return "[" .. table.concat(out, ",") .. "]"
end

local function json_transfer_parse_consistency_errors(entries)
    local out = {}
    for i = 1, #entries do
        local e = entries[i]
        out[#out + 1] = string.format(
            '{"frame":%d,"mode":%d,"submode":%d,"tile_buf_selector":%d,"source_ptr":%d,' ..
            '"bytes_head":%s,"parsed_head":%s}',
            e.frame or 0,
            e.mode or 0,
            e.submode or 0,
            e.tile_buf_selector or 0,
            e.source_ptr or 0,
            json_num_array(e.bytes_head or {}),
            json_num_array(e.parsed_head or {})
        )
    end
    return "[" .. table.concat(out, ",") .. "]"
end

register_transfer_exec_hook()

local function set_flow_state(new_state, frame, reason)
    if flow_state ~= new_state then
        record(lines, string.format(
            "f%04d flow %s -> %s (%s)",
            frame, flow_state, new_state, reason or "n/a"
        ))
        flow_state = new_state
        flow_state_frame = frame
    end
end

record(lines, "==============================================================")
record(lines, string.format("ROOM %02X NES CAPTURE: natural path -> mode=$05 roomId=$%02X", TARGET_ROOM_ID, TARGET_ROOM_ID))
record(lines, string.format("target_walk_path=%s", TARGET_WALK_PATH ~= "" and TARGET_WALK_PATH or "<none>"))
record(lines, "==============================================================")

for frame = 1, MAX_FRAMES do
    current_frame = frame
    reset_edge_writer_activity()
    local mode = ram_u8(0x0012)
    local sub = ram_u8(0x0013)
    local room_id = ram_u8(0x00EB)
    local cur_slot = ram_u8(0x0016)
    local name_ofs = ram_u8(0x0421)
    local slot_active0 = ram_u8(0x0633)
    local slot_active1 = ram_u8(0x0634)
    local slot_active2 = ram_u8(0x0635)
    local pre_window_for_rt = nil
    if not RUNTIME.trace_rt_started then
        pre_window_for_rt = dump_playmap_linear()
    end

    if cur_slot ~= CAPTURE.last_cur_slot then
        record(lines, string.format(
            "f%04d CurSaveSlot=$%02X active=%02X/%02X/%02X",
            frame, cur_slot, slot_active0, slot_active1, slot_active2
        ))
        CAPTURE.last_cur_slot = cur_slot
    end

    if mode ~= (mode_changes[#mode_changes] and mode_changes[#mode_changes].mode or nil)
        or sub ~= (mode_changes[#mode_changes] and mode_changes[#mode_changes].sub or nil) then
        mode_changes[#mode_changes + 1] = {frame = frame, mode = mode, sub = sub, room = room_id}
    end

    if not RUNTIME.trace_rt_started and mode == 0x03 then
        RUNTIME.trace_rt_started = true
        RUNTIME.trace_rt_active = true
        trace_rt_prev_window = dump_playmap_linear()
        record(lines, string.format("f%04d runtime decode trace armed (Mode3 entry)", frame))
    end

    if flow_state == FLOW_BOOT_TO_FS1 then
        if mode == 0x01 then
            set_flow_state(FLOW_FS1_SELECT_REGISTER, frame, "entered Mode1")
        elseif frame > MODE0_BOOT_TIMEOUT then
            record(lines, string.format("f%04d timeout waiting for Mode1 (mode=$%02X sub=$%02X)", frame, mode, sub))
            break
        else
            schedule_input(input_state, "Start", 2, 3, frame, "fast title->file-select", lines)
        end

    elseif flow_state == FLOW_FS1_SELECT_REGISTER then
        if mode == 0x01 then
            if cur_slot == 0x03 then
                set_flow_state(FLOW_FS1_ENTER_REGISTER, frame, "CurSaveSlot reached 3")
            else
                schedule_input(input_state, "Down", 1, 10, frame, "move to REGISTER (slot 3)", lines)
            end
        end

    elseif flow_state == FLOW_FS1_ENTER_REGISTER then
        if mode == 0x0E then
            set_flow_state(FLOW_MODEE_TYPE_NAME, frame, "entered ModeE")
            CAPTURE.register_mode_seen = true
            CAPTURE.last_name_offset = name_ofs
        elseif mode == 0x01 then
            schedule_input(input_state, "Start", 2, 14, frame, "enter register mode", lines)
        end

    elseif flow_state == FLOW_MODEE_TYPE_NAME then
        CAPTURE.register_mode_seen = true
        if name_ofs ~= CAPTURE.last_name_offset then
            CAPTURE.name_progress_events = CAPTURE.name_progress_events + 1
            record(lines, string.format("f%04d name progress $0421 %02X -> %02X", frame, CAPTURE.last_name_offset, name_ofs))
            CAPTURE.last_name_offset = name_ofs
        end
        if CAPTURE.name_progress_events >= TARGET_NAME_PROGRESS then
            set_flow_state(FLOW_MODEE_FINISH, frame, "name progress target reached")
        else
            schedule_input(input_state, "A", 1, 10, frame, "ModeE char pulse", lines)
        end

    elseif flow_state == FLOW_MODEE_FINISH then
        if mode ~= 0x0E then
            set_flow_state(FLOW_WAIT_GAMEPLAY, frame, "left ModeE")
        else
            if cur_slot ~= 0x03 then
                schedule_input(input_state, "Select", 1, 10, frame, "cycle to END slot", lines)
            else
                schedule_input(input_state, "Start", 2, 14, frame, "confirm END", lines)
            end
        end

    elseif flow_state == FLOW_WAIT_GAMEPLAY then
        if mode == 0x01 then
            set_flow_state(FLOW_FS1_START_GAME, frame, "back to Mode1 after register")
        end

    elseif flow_state == FLOW_FS1_START_GAME then
        if mode ~= 0x01 then
            set_flow_state(FLOW_WAIT_GAMEPLAY, frame, "left Mode1")
        else
            local target_slot = 0x00
            if slot_active0 == 0 and slot_active1 ~= 0 then
                target_slot = 0x01
            elseif slot_active0 == 0 and slot_active1 == 0 and slot_active2 ~= 0 then
                target_slot = 0x02
            end

            if cur_slot ~= target_slot then
                local move_btn = "Up"
                if target_slot > cur_slot then
                    move_btn = "Down"
                end
                schedule_input(input_state, move_btn, 1, 10, frame, "move to active save slot", lines)
            else
                schedule_input(input_state, "Start", 2, 14, frame, "start game", lines)
            end
        end
    end

    if not RUNTIME.trace_rt_started and mode == 0x03 and sub == 0x08 then
        RUNTIME.trace_rt_started = true
        RUNTIME.trace_rt_active = true
        trace_rt_prev_window = dump_playmap_linear()
        record(lines, string.format("f%04d runtime decode trace armed (Mode3/Sub8 pre-frame)", frame))
    end
    if not RUNTIME.edge_trace_started and mode == 0x03 then
        RUNTIME.edge_trace_started = true
        RUNTIME.edge_trace_active = true
        RUNTIME.edge_trace_prev_window = dump_edge_owner_window()
        record(lines, string.format("f%04d edge owner trace armed (Mode3 entry)", frame))
    end

    if TARGET_WALK_PATH ~= "" and not WALK.started and mode == 0x05 and room_id == 0x77 then
        WALK.start_room_stable_count = WALK.start_room_stable_count + 1
        if WALK.start_room_stable_count == MODE5_STABLE_FRAMES then
            WALK.started = true
            WALK.index = 1
            WALK.prev_room = room_id
            WALK.step_room = nil
            WALK.step_mode5_stable_count = 0
            reset_target_transition_capture(frame, lines)
        end
    else
        WALK.start_room_stable_count = 0
    end

    local pad = build_pad_for_frame(input_state)
    pad = apply_walk_pad(pad)
    safe_set(pad)
    emu.frameadvance()

    mode = ram_u8(0x0012)
    sub = ram_u8(0x0013)
    room_id = ram_u8(0x00EB)
    capture_transition_state(frame, mode, sub, room_id)
    if WALK.started and WALK.index <= #TARGET_WALK_PATH then
        if room_id ~= WALK.prev_room and WALK.step_room ~= room_id then
            WALK.step_room = room_id
            WALK.step_mode5_stable_count = 0
            record(lines, string.format("f%04d walk step %d entered roomId=$%02X", frame, WALK.index, room_id))
        end
        if WALK.step_room ~= nil and room_id == WALK.step_room and mode == 0x05 then
            WALK.step_mode5_stable_count = WALK.step_mode5_stable_count + 1
            if WALK.step_mode5_stable_count == MODE5_STABLE_FRAMES then
                record(lines, string.format("f%04d walk step %d settled roomId=$%02X", frame, WALK.index, room_id))
                WALK.prev_room = room_id
                WALK.step_room = nil
                WALK.step_mode5_stable_count = 0
                WALK.index = WALK.index + 1
            end
        else
            WALK.step_mode5_stable_count = 0
        end
    end
    if not RUNTIME.trace_rt_started and mode == 0x03 then
        RUNTIME.trace_rt_started = true
        RUNTIME.trace_rt_active = true
        trace_rt_prev_window = pre_window_for_rt or dump_playmap_linear()
        record(lines, string.format("f%04d runtime decode trace armed (Mode3 post-frame)", frame))
    end
    if not RUNTIME.edge_trace_started and mode == 0x03 then
        RUNTIME.edge_trace_started = true
        RUNTIME.edge_trace_active = true
        RUNTIME.edge_trace_prev_window = dump_edge_owner_window()
        record(lines, string.format("f%04d edge owner trace armed (Mode3 post-frame)", frame))
    end

    if RUNTIME.trace_rt_active then
        capture_runtime_trace_deltas()
    end
    if RUNTIME.edge_trace_active then
        capture_edge_owner_deltas()
    end

    if not CAPTURE.mode3_sub8_snapshot and mode == 0x03 and sub == 0x08 then
        if not RUNTIME.trace_rt_started then
            RUNTIME.trace_rt_started = true
            RUNTIME.trace_rt_active = true
            trace_rt_prev_window = dump_playmap_linear()
            record(lines, string.format("f%04d runtime decode trace armed (Mode3 first observed)", frame))
        end
        CAPTURE.mode3_sub8_snapshot = build_trace_snapshot("mode3_sub8_first", frame, mode, sub, room_id)
        CAPTURE.trace_snapshots[#CAPTURE.trace_snapshots + 1] = CAPTURE.mode3_sub8_snapshot
        local sub8_workbuf_base = CAPTURE.mode3_sub8_snapshot.workbuf_base_ptr or PLAYMAP_BASE
        CAPTURE.mode3_sub8_workbuf_rows = dump_workbuf_rows(sub8_workbuf_base)
        record(lines, string.format("f%04d trace captured: mode3/sub8 first", frame))
    end

    if not CAPTURE.layoutroomow_exit_snapshot and CAPTURE.prev_mode == 0x03 and CAPTURE.prev_sub == 0x08 and not (mode == 0x03 and sub == 0x08) then
        RUNTIME.trace_rt_active = false
        trace_rt_prev_window = nil
        CAPTURE.layoutroomow_exit_snapshot = build_layoutroomow_exit_snapshot(frame, mode, sub, room_id)
        CAPTURE.trace_snapshots[#CAPTURE.trace_snapshots + 1] = CAPTURE.layoutroomow_exit_snapshot
        local exit_workbuf_base = CAPTURE.layoutroomow_exit_snapshot.workbuf_base_ptr or PLAYMAP_BASE
        CAPTURE.layoutroomow_exit_workbuf_rows = dump_workbuf_rows(exit_workbuf_base)
        record(lines, string.format(
            "f%04d trace captured: LayoutRoomOW exit ptr02_03=$%04X ptr04_05=$%04X",
            frame,
            CAPTURE.layoutroomow_exit_snapshot.ptr_02_03 or 0,
            CAPTURE.layoutroomow_exit_snapshot.ptr_04_05 or 0
        ))
    end

    if mode == 0x05 and room_id == TARGET_ROOM_ID then
        CAPTURE.mode5_stable_count = CAPTURE.mode5_stable_count + 1
        if CAPTURE.mode5_stable_count == MODE5_STABLE_FRAMES and not CAPTURE.mode5_stable_snapshot then
            CAPTURE.reached_target = true
            CAPTURE.target_frame = frame
            CAPTURE.mode5_stable_snapshot = build_trace_snapshot("mode5_room_stable", frame, mode, sub, room_id)
            CAPTURE.trace_snapshots[#CAPTURE.trace_snapshots + 1] = CAPTURE.mode5_stable_snapshot
            record(lines, string.format("f%04d reached stable target: mode=$%02X sub=$%02X roomId=$%02X", frame, mode, sub, room_id))
            break
        end
    else
        CAPTURE.mode5_stable_count = 0
    end
    CAPTURE.prev_mode = mode
    CAPTURE.prev_sub = sub
end

if CAPTURE.reached_target then
    for _ = 1, 20 do
        safe_set({})
        emu.frameadvance()
    end
end

local final_mode = ram_u8(0x0012)
local final_sub = ram_u8(0x0013)
local final_room = ram_u8(0x00EB)
local final_room_diag = ram_u8(0x003C)
local ppu_ctrl_shadow = ram_u8(0x00FF)
local ppu_mask_shadow = ram_u8(0x00FE)
local nt_index = ppu_ctrl_shadow % 4
local bg_pattern_table = math.floor(ppu_ctrl_shadow / 16) % 2
local nt_base = nt_index * 0x400
local final_transition_diag_004C = ram_u8(0x004C)
local final_cur_vscroll = ram_u8(0x00FC)
local final_cur_hscroll = ram_u8(0x00FD)
local final_switch_nt_req = ram_u8(0x005C)
local final_cur_column = ram_u8(0x00E8)
local final_cur_row = ram_u8(0x00E9)

if CAPTURE.reached_target then
    client.screenshot(OUT_PNG)
end

local tile_rows = {}
local palette_rows = {}
local attr_rows = {}

for row = 0, ROOM_ROWS - 1 do
    local tile_row = {}
    local pal_row = {}
    local attr_row = {}
    local nt_row = ROOM_TOP_ROW + row
    for col = 0, ROOM_COLS - 1 do
        local tile_addr = nt_base + nt_row * 32 + col
        local tile = ciram_u8(tile_addr)
        tile_row[#tile_row + 1] = tile

        local attr_addr = nt_base + 0x03C0 + math.floor(nt_row / 4) * 8 + math.floor(col / 4)
        local attr = ciram_u8(attr_addr)
        attr_row[#attr_row + 1] = attr
        pal_row[#pal_row + 1] = attr_palette(attr, nt_row, col)
    end
    tile_rows[#tile_rows + 1] = tile_row
    palette_rows[#palette_rows + 1] = pal_row
    attr_rows[#attr_rows + 1] = attr_row
end

local palram = {}
for i = 0, 31 do
    palram[#palram + 1] = palram_u8(i)
end
local workbuf_base_ptr = PLAYMAP_BASE
if CAPTURE.layoutroomow_exit_snapshot and (CAPTURE.layoutroomow_exit_snapshot.workbuf_base_ptr or -1) >= 0 then
    workbuf_base_ptr = CAPTURE.layoutroomow_exit_snapshot.workbuf_base_ptr
end
local workbuf_rows = dump_workbuf_rows(workbuf_base_ptr)
local decode_write_trace = {}
if CAPTURE.layoutroomow_exit_snapshot then
    decode_write_trace = build_decode_write_trace(
        CAPTURE.layoutroomow_exit_snapshot.layout_ptr_effective or 0,
        workbuf_base_ptr,
        workbuf_rows
    )
end
local playmap_rows = dump_playmap_rows()

local chr_available = true
local chr_bytes = {}
for i = 0, 0x1FFF do
    local b = chr_u8(i)
    if b == nil then
        chr_available = false
        break
    end
    chr_bytes[#chr_bytes + 1] = b
end

if chr_available then
    local cf = assert(io.open(OUT_CHR, "wb"))
    for i = 1, #chr_bytes do
        cf:write(string.char(chr_bytes[i]))
    end
    cf:close()
end
local edge_owner_summary = build_edge_owner_summary(RUNTIME.edge_owner_trace, RUNTIME.edge_trace_started and CAPTURE.reached_target)

record(lines, "")
record(lines, string.format("register_mode_seen=%s name_progress_events=%d", CAPTURE.register_mode_seen and "yes" or "no", CAPTURE.name_progress_events))
record(lines, string.format("final mode=$%02X sub=$%02X roomId=$%02X room03C=$%02X", final_mode, final_sub, final_room, final_room_diag))
record(lines, string.format("PPUCTRL(shadow $00FF)=$%02X PPUMASK(shadow $00FE)=$%02X", ppu_ctrl_shadow, ppu_mask_shadow))
record(lines, string.format("active_nt_index=%d nt_base=$%03X bg_pattern_table=%d", nt_index, nt_base, bg_pattern_table))
record(lines, string.format(
    "final diag004C=$%02X curV=$%02X curH=$%02X switchNT=$%02X curCol=$%02X curRow=$%02X",
    final_transition_diag_004C, final_cur_vscroll, final_cur_hscroll, final_switch_nt_req, final_cur_column, final_cur_row
))
record(lines, string.format("workbuf_base_ptr=$%04X", workbuf_base_ptr))
record(lines, string.format("decode_write_trace_entries=%d", #decode_write_trace))
record(lines, string.format("decode_write_trace_rt_entries=%d", #RUNTIME.decode_write_trace_rt))
record(lines, string.format("decode_write_trace_rt_valid=%s", (#RUNTIME.decode_write_trace_rt >= TRACE_RT_MIN_VALID) and "yes" or "no"))
record(lines, string.format("decode_write_trace_rt_hooks=%s", RUNTIME.runtime_write_hooks_enabled and "enabled" or "fallback"))
record(lines, string.format("transfer_exec_hook=%s", RUNTIME.transfer_exec_hook_armed and "armed" or "off"))
record(lines, string.format("transfer_exec_hook_hits=%d", RUNTIME.transfer_exec_hook_hits))
record(lines, string.format("transfer_exec_hit_frames=%d", #RUNTIME.transfer_exec_hits_by_frame))
record(lines, string.format("transfer_exec_callback_errors=%d", #RUNTIME.transfer_exec_callback_errors))
record(lines, string.format("transfer_stream_events=%d", #RUNTIME.transfer_stream_events))
record(lines, string.format("transfer_stream_capture_valid=%s", (#RUNTIME.transfer_stream_events > 0) and "yes" or "no"))
record(lines, string.format("edge_owner_trace_entries=%d", edge_owner_summary.entries or 0))
record(lines, string.format("edge_owner_trace_valid=%s", edge_owner_summary.valid and "yes" or "no"))
record(lines, string.format("edge_owner_writer_classes=%s", table.concat(edge_owner_summary.writer_classes or {}, ",")))
record(lines, string.format("transfer_parse_consistency_errors=%d", #RUNTIME.transfer_parse_consistency_errors))
record(lines, string.format("target_reached=%s frame=%s", CAPTURE.reached_target and "yes" or "no", tostring(CAPTURE.target_frame or -1)))
record(lines, string.format("chr_dump_available=%s", chr_available and "yes" or "no"))
record(lines, string.format("transition_state_frames=%d", #RUNTIME.transition_state_frames))
record(lines, string.format("trace_snapshots=%d", #CAPTURE.trace_snapshots))

local out = assert(io.open(OUT_TXT, "w"))
out:write(table.concat(lines, "\n"))
out:write("\n")
out:close()

local jf = assert(io.open(OUT_JSON, "w"))
jf:write("{\n")
jf:write('  "target_reached": ', CAPTURE.reached_target and "true" or "false", ",\n")
jf:write('  "target_room_id": ', tostring(TARGET_ROOM_ID), ",\n")
jf:write('  "target_frame": ', tostring(CAPTURE.target_frame or -1), ",\n")
jf:write('  "final_mode": ', tostring(final_mode), ",\n")
jf:write('  "final_submode": ', tostring(final_sub), ",\n")
jf:write('  "room_id": ', tostring(final_room), ",\n")
jf:write('  "room_diag_003C": ', tostring(final_room_diag), ",\n")
jf:write('  "final_transition_active": ', tostring(final_transition_diag_004C), ",\n")
jf:write('  "final_transition_diag_004C": ', tostring(final_transition_diag_004C), ",\n")
jf:write('  "final_cur_vscroll": ', tostring(final_cur_vscroll), ",\n")
jf:write('  "final_cur_hscroll": ', tostring(final_cur_hscroll), ",\n")
jf:write('  "final_switch_nametables_req": ', tostring(final_switch_nt_req), ",\n")
jf:write('  "final_cur_column": ', tostring(final_cur_column), ",\n")
jf:write('  "final_cur_row": ', tostring(final_cur_row), ",\n")
jf:write('  "ppu_ctrl_shadow": ', tostring(ppu_ctrl_shadow), ",\n")
jf:write('  "ppu_mask_shadow": ', tostring(ppu_mask_shadow), ",\n")
jf:write('  "active_nametable_index": ', tostring(nt_index), ",\n")
jf:write('  "active_nametable_base": ', tostring(nt_base), ",\n")
jf:write('  "bg_pattern_table_half": ', tostring(bg_pattern_table), ",\n")
jf:write('  "workbuf_base_ptr": ', tostring(workbuf_base_ptr), ",\n")
jf:write('  "room_top_row": ', tostring(ROOM_TOP_ROW), ",\n")
jf:write('  "room_rows": ', tostring(ROOM_ROWS), ",\n")
jf:write('  "room_cols": ', tostring(ROOM_COLS), ",\n")
jf:write('  "screenshot_path": "', json_escape(OUT_PNG), '",\n')
jf:write('  "chr_dump_path": "', json_escape(OUT_CHR), '",\n')
jf:write('  "chr_dump_available": ', chr_available and "true" or "false", ",\n")
jf:write('  "tile_rows": ', json_matrix(tile_rows), ",\n")
jf:write('  "palette_rows": ', json_matrix(palette_rows), ",\n")
jf:write('  "layoutroomow_exit_workbuf_rows": ', json_matrix(CAPTURE.layoutroomow_exit_workbuf_rows or {}), ",\n")
jf:write('  "mode3_sub8_workbuf_rows": ', json_matrix(CAPTURE.mode3_sub8_workbuf_rows or {}), ",\n")
jf:write('  "workbuf_rows": ', json_matrix(workbuf_rows), ",\n")
jf:write('  "decode_write_trace": ', json_decode_write_trace(decode_write_trace), ",\n")
jf:write('  "decode_write_trace_rt": ', json_decode_write_trace_rt(RUNTIME.decode_write_trace_rt), ",\n")
jf:write('  "decode_write_trace_rt_entries": ', tostring(#RUNTIME.decode_write_trace_rt), ",\n")
jf:write('  "decode_write_trace_rt_valid": ', (#RUNTIME.decode_write_trace_rt >= TRACE_RT_MIN_VALID) and "true" or "false", ",\n")
jf:write('  "decode_write_trace_rt_hooks": "', RUNTIME.runtime_write_hooks_enabled and "enabled" or "fallback", '",\n')
jf:write('  "transfer_exec_hook_armed": ', RUNTIME.transfer_exec_hook_armed and "true" or "false", ",\n")
jf:write('  "transfer_exec_hook_hits": ', tostring(RUNTIME.transfer_exec_hook_hits), ",\n")
jf:write('  "transfer_exec_samples": ', json_transfer_exec_samples(RUNTIME.transfer_exec_samples), ",\n")
jf:write('  "transfer_exec_hits_by_frame": ', json_transfer_exec_hits(RUNTIME.transfer_exec_hits_by_frame), ",\n")
jf:write('  "transfer_exec_callback_errors": ', json_transfer_exec_errors(RUNTIME.transfer_exec_callback_errors), ",\n")
jf:write('  "transfer_stream_events": ', json_transfer_stream_events(RUNTIME.transfer_stream_events), ",\n")
jf:write('  "transfer_stream_event_entries": ', tostring(#RUNTIME.transfer_stream_events), ",\n")
jf:write('  "transfer_stream_capture_valid": ', (#RUNTIME.transfer_stream_events > 0) and "true" or "false", ",\n")
jf:write('  "edge_owner_trace": ', json_edge_owner_trace(RUNTIME.edge_owner_trace), ",\n")
jf:write('  "edge_owner_trace_entries": ', tostring(edge_owner_summary.entries or 0), ",\n")
jf:write('  "edge_owner_trace_valid": ', edge_owner_summary.valid and "true" or "false", ",\n")
jf:write('  "edge_owner_writer_classes": ', json_string_array(edge_owner_summary.writer_classes or {}), ",\n")
jf:write('  "edge_owner_first_write": ', json_edge_owner_point(edge_owner_summary.first_write), ",\n")
jf:write('  "edge_owner_last_write": ', json_edge_owner_point(edge_owner_summary.last_write), ",\n")
jf:write('  "transfer_parse_consistency_errors": ', json_transfer_parse_consistency_errors(RUNTIME.transfer_parse_consistency_errors), ",\n")
jf:write('  "transfer_parse_consistency_error_count": ', tostring(#RUNTIME.transfer_parse_consistency_errors), ",\n")
jf:write('  "playmap_rows": ', json_matrix(playmap_rows), ",\n")
jf:write('  "mode_changes": ', json_mode_changes(mode_changes), ",\n")
jf:write('  "transition_state_frames": ', json_transition_state_frames(RUNTIME.transition_state_frames), ",\n")
jf:write('  "attribute_rows_raw": ', json_matrix(attr_rows), ",\n")
jf:write('  "palram_bytes": ', json_num_array(palram), ",\n")
jf:write('  "trace_snapshots": ', json_trace_snapshots(CAPTURE.trace_snapshots), "\n")
jf:write("}\n")
jf:close()

client.exit()
