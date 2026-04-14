-- bizhawk_room77_gen_capture.lua
-- Capture deterministic room-target Genesis artifacts for strict BG-only parity.
--
-- Outputs:
--   builds/reports/roomXX_gen_capture.txt
--   builds/reports/roomXX_gen_capture.json
--   builds/reports/roomXX_gen_capture.png
--
-- Capture gate:
--   Mode $05 with RoomId ($00EB) == target.
--   Then dump Plane A rows 6..27 cols 0..31, full CRAM (64 words), screenshot.

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

dofile(repo_path("tools\\probe_addresses.lua"))

local TARGET_ROOM_ID = tonumber(os.getenv("CODEX_TARGET_ROOM_ID") or "0x77") or 0x77
TARGET_ROOM_ID = TARGET_ROOM_ID % 0x100
local ROOM_TAG = string.format("room%02X", TARGET_ROOM_ID)
local TARGET_WALK_PATH = (os.getenv("CODEX_ROOM_WALK_PATH") or ""):upper():gsub("[^LRUD]", "")

local OUT_DIR = repo_path("builds\\reports")
local OUT_TXT = repo_path("builds\\reports\\" .. ROOM_TAG .. "_gen_capture.txt")
local OUT_JSON = repo_path("builds\\reports\\" .. ROOM_TAG .. "_gen_capture.json")
local OUT_PNG = repo_path("builds\\reports\\" .. ROOM_TAG .. "_gen_capture.png")

os.execute('if not exist "' .. OUT_DIR .. '" mkdir "' .. OUT_DIR .. '"')

local MAX_FRAMES = 7000
local MODE0_BOOT_TIMEOUT = 900
local TARGET_NAME_PROGRESS = 5

local FLOW_BOOT_TO_FS1 = "BOOT_TO_FS1"
local FLOW_FS1_SELECT_REGISTER = "FS1_SELECT_REGISTER"
local FLOW_FS1_ENTER_REGISTER = "FS1_ENTER_REGISTER"
local FLOW_MODEE_TYPE_NAME = "MODEE_TYPE_NAME"
local FLOW_MODEE_FINISH = "MODEE_FINISH"
local FLOW_FS1_START_GAME = "FS1_START_GAME"
local FLOW_WAIT_GAMEPLAY = "WAIT_GAMEPLAY"

local PLANE_A_BASE = 0xC000
local PLANE_A_ROW_STRIDE = 0x80
local PLANE_A_TOP_ROW = 6
local ROOM_ROWS = 22
local ROOM_COLS = 32
local MODE5_STABLE_FRAMES = 10
local SOURCE_SAMPLE_BYTES = 16
local PLAYMAP_BASE = 0x6530
local WORKBUF_LOOP_ADVANCE = 0x02C0 -- 16 columns * (11 squares * 2 tiles + 0x16 wrap)
local TRACE_WRITE_COUNT = 64
local TRACE_RT_MAX_WRITES = ROOM_ROWS * ROOM_COLS
local TRACE_RT_MIN_VALID = 32
local TRANSFER_STREAM_MAX_BYTES = 1024
local TRANSFER_STREAM_MAX_EVENTS = 128
local TRANSFER_STREAM_MAX_RECORDS = 128
local EDGE_TRACE_TOP_PPU = 0x2100
local EDGE_TRACE_TOP_NT_ROW = 8
local EDGE_TRACE_ROWS = 22
local EDGE_TRACE_MAX_ENTRIES = 256
local ROOM_TRANSITION_ACTIVE = 0xFF004C

local function read_listing_addr(symbol)
    local f = io.open(repo_path("builds\\whatif.lst"), "r")
    if not f then
        return nil
    end
    for line in f:lines() do
        local name, hex = line:match("^(%w+)%s+A:(%x+)$")
        if name == symbol and hex then
            f:close()
            return tonumber(hex, 16)
        end
    end
    f:close()
    return nil
end

local TRANSFER_CUR_TILEBUF_ADDR = read_listing_addr("TransferCurTileBuf")
local TRANSFER_BUF_PTRS_ADDR = read_listing_addr("TransferBufPtrs")
local PPU_WRITE_7_ADDR = read_listing_addr("_ppu_write_7")
local CLEAR_NAMETABLE_FAST_ADDR = read_listing_addr("_clear_nametable_fast")
local TRANSFER_TILEBUF_FAST_ADDR = read_listing_addr("_transfer_tilebuf_fast")

local AVAILABLE_DOMAIN_SET = {}
do
    local ok, domains = pcall(memory.getmemorydomainlist)
    if ok and type(domains) == "table" then
        for _, d in ipairs(domains) do
            AVAILABLE_DOMAIN_SET[d] = true
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

-- Only use direct RAM domains for write hooks; bus domains vary by core and
-- can produce noisy/unsupported callbacks.
local RAM_DOMAIN = (domain_available("68K RAM") and "68K RAM")
    or (domain_available("Main RAM") and "Main RAM")
    or nil

local OW_COLUMN_HEAP_BASES = {
    0x9BD8, 0x9C0D, 0x9C3E, 0x9C80,
    0x9CC4, 0x9CF6, 0x9D32, 0x9D6D,
    0x9DA8, 0x9DE6, 0x9E27, 0x9E6C,
    0x9EA9, 0x9EDF, 0x9F21, 0x9F55,
}

local function try_read(domain, addr, width)
    if not domain_available(domain) then
        return nil
    end
    local ok, value = pcall(function()
        memory.usememorydomain(domain)
        if width == 1 then
            return memory.read_u8(addr)
        end
        return memory.read_u16_be(addr)
    end)
    if ok then
        return value
    end
    return nil
end

local function m68k_bus_u8(addr)
    if not domain_available("M68K BUS") then
        return nil
    end
    local even_addr = addr - (addr % 2)
    local ok, value = pcall(function()
        memory.usememorydomain("M68K BUS")
        local w = memory.read_u16_be(even_addr)
        if (addr % 2) == 0 then
            return math.floor(w / 256) % 256
        end
        return w % 256
    end)
    if ok then
        return value
    end
    return nil
end

local function ram_u8(bus_addr)
    local ofs = bus_addr - 0xFF0000
    local domains = {}
    if domain_available("68K RAM") then
        domains[#domains + 1] = {"68K RAM", ofs}
    end
    if domain_available("Main RAM") then
        domains[#domains + 1] = {"Main RAM", ofs}
    end
    local v_bus = m68k_bus_u8(bus_addr)
    if v_bus ~= nil then
        return v_bus
    end
    if domain_available("System Bus") then
        domains[#domains + 1] = {"System Bus", bus_addr}
    end
    for _, spec in ipairs(domains) do
        local v = try_read(spec[1], spec[2], 1)
        if v ~= nil then
            return v
        end
    end
    return 0
end

local function ram_u16(bus_addr)
    local ofs = bus_addr - 0xFF0000
    local domains = {}
    if domain_available("68K RAM") then
        domains[#domains + 1] = {"68K RAM", ofs}
    end
    if domain_available("Main RAM") then
        domains[#domains + 1] = {"Main RAM", ofs}
    end
    if domain_available("M68K BUS") then
        domains[#domains + 1] = {"M68K BUS", bus_addr}
    end
    if domain_available("System Bus") then
        domains[#domains + 1] = {"System Bus", bus_addr}
    end
    for _, spec in ipairs(domains) do
        local v = try_read(spec[1], spec[2], 2)
        if v ~= nil then
            return v
        end
    end
    return 0
end

local function vram_u16(addr)
    return try_read("VRAM", addr, 2) or 0
end

local function cram_u16(addr)
    return try_read("CRAM", addr, 2) or 0
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
        if state.button:sub(1, 3) == "P1 " then
            pad[state.button] = true
            pad[state.button:sub(4)] = true
        else
            pad[state.button] = true
            pad["P1 " .. state.button] = true
        end
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
            local addr = 0xFF0000 + ((base + row + (col * ROOM_ROWS)) % 0x10000)
            row_vals[#row_vals + 1] = ram_u8(addr)
        end
        out[#out + 1] = row_vals
    end
    return out
end

local function dump_playmap_rows()
    return dump_workbuf_rows(PLAYMAP_BASE)
end

local function read_nes_addr_byte_from_genesis(nes_addr)
    return ram_u8(0xFF0000 + (nes_addr % 0x10000))
end

local function build_decode_write_trace(layout_ptr_effective, workbuf_base_ptr, workbuf_rows)
    local trace = {}
    local writes = 0
    local work_ptr = workbuf_base_ptr % 0x10000
    local layout_ptr = layout_ptr_effective
    local function read_abs_byte(addr)
        local a = addr % 0x1000000
        local v = try_read("M68K BUS", a, 1)
        if v ~= nil then
            return v % 0x100
        end
        v = try_read("System Bus", a, 1)
        if v ~= nil then
            return v % 0x100
        end
        if a >= 0xFF0000 and a <= 0xFFFFFF then
            return ram_u8(a) % 0x100
        end
        return 0
    end

    for col = 0, 15 do
        if writes >= TRACE_WRITE_COUNT then
            break
        end
        local descriptor = read_abs_byte(layout_ptr + col) % 0x100
        local table_idx = math.floor(descriptor / 16) % 16
        local column_idx = descriptor % 16
        local col_base = OW_COLUMN_HEAP_BASES[table_idx + 1] or OW_COLUMN_HEAP_BASES[1]

        local scan_ofs = 0xFF
        local remaining = column_idx
        while true do
            scan_ofs = (scan_ofs + 1) % 0x100
            local b = read_nes_addr_byte_from_genesis(col_base + scan_ofs) % 0x100
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
            local desc = read_nes_addr_byte_from_genesis(ptr04_before) % 0x100
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
    local base = 0xFF0000 + (ptr % 0x10000)
    for i = 0, count - 1 do
        bytes[#bytes + 1] = ram_u8(base + i)
    end
    return bytes
end

local function bus_u8(bus_addr)
    local addr = bus_addr % 0x1000000
    local v_bus = m68k_bus_u8(addr)
    if v_bus ~= nil then
        return v_bus
    end
    local domains = {
        {"System Bus", addr},
    }
    for _, spec in ipairs(domains) do
        local v = try_read(spec[1], spec[2], 1)
        if v ~= nil then
            return v
        end
    end
    if addr >= 0xFF0000 and addr <= 0xFFFFFF then
        return ram_u8(addr)
    end
    return 0
end

local function read_source_bytes_from_abs(abs_addr, count)
    local bytes = {}
    for i = 0, count - 1 do
        bytes[#bytes + 1] = bus_u8(abs_addr + i)
    end
    return bytes
end

local function ram_u32_be(bus_addr)
    local b0 = ram_u8(bus_addr)
    local b1 = ram_u8(bus_addr + 1)
    local b2 = ram_u8(bus_addr + 2)
    local b3 = ram_u8(bus_addr + 3)
    return ((b0 * 256 + b1) * 256 + b2) * 256 + b3
end

local function bus_u32_be(bus_addr)
    local b0 = bus_u8(bus_addr)
    local b1 = bus_u8(bus_addr + 1)
    local b2 = bus_u8(bus_addr + 2)
    local b3 = bus_u8(bus_addr + 3)
    return ((b0 * 256 + b1) * 256 + b2) * 256 + b3
end

local function m68k_reg(name)
    local v = emu.getregister("M68K " .. name)
    if v == nil then
        v = emu.getregister(name)
    end
    if v == nil then
        return -1
    end
    if v < 0 then
        v = v + 0x100000000
    end
    return math.floor(v)
end

local function build_trace_snapshot(name, frame, mode, sub, room_id)
    local ptr_inputs = {}
    for ofs = 0, 9 do
        ptr_inputs[#ptr_inputs + 1] = ram_u8(0xFF0000 + ofs)
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

    local bank_window_head = {}
    for i = 0, 7 do
        bank_window_head[#bank_window_head + 1] = ram_u8(0xFF8000 + i)
    end

    return {
        name = name,
        frame = frame,
        mode = mode,
        submode = sub,
        room_id = room_id,
        mmc1_prg = ram_u8(0xFF0815),
        current_window_bank = ram_u8(0xFF083F),
        ptr_inputs = ptr_inputs,
        source_samples = source_samples,
        bank_window_head = bank_window_head,
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
    snap.a2_reg = m68k_reg("A2")
    snap.a3_reg = m68k_reg("A3")
    local cached_layout_ptr = ram_u32_be(0xFF1102)
    if cached_layout_ptr < 0x100 then
        cached_layout_ptr = 0
    end
    local cached_column_ptr = ram_u32_be(0xFF1106)
    if cached_column_ptr < 0x100 then
        cached_column_ptr = 0
    end
    local eff_a2 = snap.a2_reg
    if eff_a2 <= 0 and cached_layout_ptr > 0 then
        eff_a2 = cached_layout_ptr
    end
    local eff_a3 = cached_column_ptr
    if eff_a3 <= 0 then
        eff_a3 = snap.a3_reg
    end
    if eff_a3 <= 0 then
        eff_a3 = 0xFF0000 + ptr_04_05
    end
    snap.a2_effective = eff_a2
    snap.a3_effective = eff_a3
    local room_attr_raw = ram_u8(0xFF6000 + 0x09FE + (room_id % 0x100))
    snap.room_attr_raw = room_attr_raw
    snap.room_attr_masked = room_attr_raw % 0x40
    snap.layout_ptr_effective = eff_a2
    snap.layout_bytes = read_source_bytes_from_abs(eff_a2, SOURCE_SAMPLE_BYTES)
    snap.column_bytes = read_source_bytes_from_abs(eff_a3, SOURCE_SAMPLE_BYTES)
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
        local a2_reg = t.a2_reg or -1
        local a3_reg = t.a3_reg or -1
        local a2_effective = t.a2_effective or -1
        local a3_effective = t.a3_effective or -1
        local room_attr_raw = t.room_attr_raw or -1
        local room_attr_masked = t.room_attr_masked or -1
        local layout_ptr_effective = t.layout_ptr_effective or -1
        local layout_bytes = t.layout_bytes or {}
        local column_bytes = t.column_bytes or {}
        out[#out + 1] = string.format(
            '{"name":"%s","frame":%d,"mode":%d,"submode":%d,"room_id":%d,"mmc1_prg":%d,' ..
            '"current_window_bank":%d,"ptr_inputs":%s,"source_samples":%s,"bank_window_head":%s,' ..
            '"ptr_00_01":%d,"ptr_02_03":%d,"ptr_04_05":%d,"ptr_06_09":%d,"workbuf_base_ptr":%d,' ..
            '"a2_reg":%d,"a3_reg":%d,"a2_effective":%d,"a3_effective":%d,' ..
            '"room_attr_raw":%d,"room_attr_masked":%d,"layout_ptr_effective":%d,"layout_bytes":%s,"column_bytes":%s}',
            json_escape(t.name),
            t.frame,
            t.mode,
            t.submode,
            t.room_id,
            t.mmc1_prg,
            t.current_window_bank,
            json_num_array(t.ptr_inputs),
            json_source_samples(t.source_samples),
            json_num_array(t.bank_window_head),
            ptr_00_01,
            ptr_02_03,
            ptr_04_05,
            ptr_06_09,
            workbuf_base_ptr,
            a2_reg,
            a3_reg,
            a2_effective,
            a3_effective,
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
            '"repeat_state":%d,"square_index":%d,"mmc1_prg":%d,"current_window_bank":%d}',
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
            e.square_index or 0,
            e.mmc1_prg or 0,
            e.current_window_bank or 0
        )
    end
    return "[" .. table.concat(out, ",") .. "]"
end

local function read_status_inputs()
    return {
        inv_bombs = ram_u8(0xFF0658) % 0x100,
        inv_magic_key = ram_u8(0xFF0664) % 0x100,
        inv_rupees = ram_u8(0xFF066D) % 0x100,
        inv_keys = ram_u8(0xFF066E) % 0x100,
        heart_values = ram_u8(0xFF066F) % 0x100,
        heart_partial = ram_u8(0xFF0670) % 0x100,
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

local lines = {}
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

local register_mode_seen = false
local name_progress_events = 0
local last_name_offset = 0
local last_cur_slot = 0xFF
local exception_hit = false
local exception_name = ""
local exception_frame = -1
local reached_target = false
local target_frame = nil
local mode3_sub8_snapshot = nil
local mode5_stable_snapshot = nil
local layoutroomow_exit_snapshot = nil
local layoutroomow_exit_workbuf_rows = nil
local mode3_sub8_workbuf_rows = nil
local mode5_stable_count = 0
local trace_snapshots = {}
local prev_mode = nil
local prev_sub = nil
local trace_rt_active = false
local trace_rt_started = false
local decode_write_trace_rt = {}
local runtime_trace_summary = nil
local runtime_write_hooks_enabled = false
local transfer_stream_events = {}
local last_transfer_stream_sig = nil
local transfer_exec_hook_armed = false
local transfer_exec_hook_hits = 0
local transfer_exec_samples = {}
local edge_owner_trace = {}
local edge_trace_started = false
local edge_trace_active = false
local edge_trace_prev_window = nil
local edge_writer_frame_classes = {}
local edge_writer_last_pc = -1
local walk_started = false
local walk_index = 1
local walk_prev_room = 0x77
local start_room_stable_count = 0

local function reset_target_transition_capture(frame, lines)
    reached_target = false
    target_frame = nil
    mode3_sub8_snapshot = nil
    mode5_stable_snapshot = nil
    layoutroomow_exit_snapshot = nil
    layoutroomow_exit_workbuf_rows = nil
    mode3_sub8_workbuf_rows = nil
    mode5_stable_count = 0
    trace_snapshots = {}
    mode_changes = {}
    prev_mode = nil
    prev_sub = nil
    trace_rt_active = false
    trace_rt_started = false
    trace_rt_prev_window = nil
    decode_write_trace_rt = {}
    runtime_trace_summary = nil
    transfer_stream_events = {}
    last_transfer_stream_sig = nil
    transfer_exec_hook_hits = 0
    transfer_exec_samples = {}
    edge_owner_trace = {}
    edge_trace_started = false
    edge_trace_active = false
    edge_trace_prev_window = nil
    edge_writer_frame_classes = {}
    edge_writer_last_pc = -1
    record(lines, string.format("f%04d reset capture state for target-room transition path=%s", frame, TARGET_WALK_PATH))
end

local function apply_walk_pad(pad)
    if not walk_started or walk_index > #TARGET_WALK_PATH then
        return pad
    end
    local d = TARGET_WALK_PATH:sub(walk_index, walk_index)
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
        cur_column = ram_u8(0xFF00E8) % 0x100,
        cur_row = ram_u8(0xFF00E9) % 0x100,
        prev_column = ram_u8(0xFF00EC) % 0x100,
        prev_row = ram_u8(0xFF00ED) % 0x100,
    }
end

local function read_ptr00_01()
    return ((ram_u8(0xFF0001) % 0x100) * 0x100 + (ram_u8(0xFF0000) % 0x100)) % 0x10000
end

local function read_ptr04_05()
    return ((ram_u8(0xFF0005) % 0x100) * 0x100 + (ram_u8(0xFF0004) % 0x100)) % 0x10000
end

local function reset_edge_writer_activity()
    edge_writer_frame_classes = {}
    edge_writer_last_pc = -1
end

local function mark_edge_writer_activity(writer_class, pc)
    if writer_class == nil or writer_class == "" then
        return
    end
    edge_writer_frame_classes[writer_class] = true
    if pc ~= nil then
        edge_writer_last_pc = pc
    end
end

local function edge_writer_summary()
    local classes = {}
    for k, _ in pairs(edge_writer_frame_classes) do
        classes[#classes + 1] = k
    end
    table.sort(classes)
    if #classes == 0 then
        return "direct_ntcache_or_external", edge_writer_last_pc
    end
    return table.concat(classes, "|"), edge_writer_last_pc
end

local function dump_edge_owner_window()
    local out = {}
    for row = 0, EDGE_TRACE_ROWS - 1 do
        local ppu_base = EDGE_TRACE_TOP_PPU + row * 0x20
        local nt_row = EDGE_TRACE_TOP_NT_ROW + row
        local nt_base = 0xFF0840 + nt_row * 32
        out[#out + 1] = {addr = ppu_base, value = ram_u8(nt_base) % 0x100}
        out[#out + 1] = {addr = ppu_base + 0x1F, value = ram_u8(nt_base + 31) % 0x100}
    end
    return out
end

local function append_edge_owner_trace(addr, value)
    if not edge_trace_active then
        return
    end
    if #edge_owner_trace >= EDGE_TRACE_MAX_ENTRIES then
        return
    end
    local writer_class, pc = edge_writer_summary()
    edge_owner_trace[#edge_owner_trace + 1] = {
        seq = #edge_owner_trace + 1,
        frame = current_frame,
        mode = ram_u8(0xFF0012) % 0x100,
        submode = ram_u8(0xFF0013) % 0x100,
        addr = addr % 0x10000,
        value = value % 0x100,
        writer_class = writer_class,
        pc = pc or -1,
    }
end

local function capture_edge_owner_deltas()
    if not edge_trace_active then
        return
    end
    local cur = dump_edge_owner_window()
    if edge_trace_prev_window == nil then
        edge_trace_prev_window = cur
        return
    end
    for i = 1, #cur do
        if cur[i].value ~= edge_trace_prev_window[i].value then
            append_edge_owner_trace(cur[i].addr, cur[i].value)
        end
    end
    edge_trace_prev_window = cur
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
    if not trace_rt_active then
        return
    end
    if #decode_write_trace_rt >= TRACE_RT_MAX_WRITES then
        return
    end
    local mode = ram_u8(0xFF0012)
    local sub = ram_u8(0xFF0013)
    local room_id = ram_u8(0xFF00EB) % 0x100
    local room_attr_raw = ram_u8(0xFF6000 + 0x09FE + room_id) % 0x100
    decode_write_trace_rt[#decode_write_trace_rt + 1] = {
        seq = #decode_write_trace_rt + 1,
        frame = current_frame,
        addr = addr % 0x10000,
        value = value % 0x100,
        mode = mode % 0x100,
        submode = sub % 0x100,
        ptr00_01 = read_ptr00_01(),
        ptr04_05 = read_ptr04_05(),
        room_attr_raw = room_attr_raw,
        room_attr_masked = room_attr_raw % 0x40,
        repeat_state = ram_u8(0xFF000C) % 0x100,
        square_index = ram_u8(0xFF000D) % 0x100,
        mmc1_prg = ram_u8(0xFF0815) % 0x100,
        current_window_bank = ram_u8(0xFF083F) % 0x100,
    }
end

local function register_runtime_trace_hooks()
    if RAM_DOMAIN == nil then
        runtime_write_hooks_enabled = false
        record(lines, "runtime write hooks unavailable (no RAM domain); using delta trace fallback")
        return
    end
    local hook_count = 0
    local callbacks_supported = true
    for col = 0, ROOM_COLS - 1 do
        for row = 0, ROOM_ROWS - 1 do
            if not callbacks_supported then
                break
            end
            local addr = (PLAYMAP_BASE + row + (col * ROOM_ROWS)) % 0x10000
            local tag = string.format("r77_gen_rt_%04X", addr)
            local ok = pcall(function()
                event.onmemorywrite(function(cb_addr, cb_value)
                    local a = cb_addr or addr
                    local v = cb_value
                    if v == nil then
                        v = ram_u8(0xFF0000 + (a % 0x10000))
                    end
                    append_runtime_trace(a, v)
                end, addr, tag, RAM_DOMAIN)
            end)
            if ok then
                hook_count = hook_count + 1
            else
                callbacks_supported = false
            end
        end
        if not callbacks_supported then
            break
        end
    end
    if callbacks_supported and hook_count > 0 then
        runtime_write_hooks_enabled = true
        record(lines, string.format("runtime write hooks armed: %d (%s)", hook_count, RAM_DOMAIN))
    else
        runtime_write_hooks_enabled = false
        record(lines, "runtime write hooks unavailable on this core; using delta trace fallback")
    end
end

local function json_runtime_trace_summary(summary)
    summary = summary or {}
    local repeat_parts = {}
    local repeat_items = summary.repeat_count_by_addr or {}
    for i = 1, #repeat_items do
        local e = repeat_items[i]
        repeat_parts[#repeat_parts + 1] = string.format(
            '{"addr":%d,"writes":%d}',
            e.addr or 0,
            e.writes or 0
        )
    end
    return string.format(
        '{"first_repeated_write_addr":%d,"first_repeated_write_seq":%d,"first_repeated_write_prev_seq":%d,' ..
        '"first_final_diff_addr":%d,"first_final_diff_first_value":%d,"first_final_diff_final_value":%d,' ..
        '"first_final_diff_last_seq":%d,"repeat_count_by_addr":[%s]}',
        summary.first_repeated_write_addr or -1,
        summary.first_repeated_write_seq or -1,
        summary.first_repeated_write_prev_seq or -1,
        summary.first_final_diff_addr or -1,
        summary.first_final_diff_first_value or -1,
        summary.first_final_diff_final_value or -1,
        summary.first_final_diff_last_seq or -1,
        table.concat(repeat_parts, ",")
    )
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

register_runtime_trace_hooks()
trace_rt_prev_window = trace_rt_prev_window or nil

local function register_edge_exec_hooks()
    local specs = {
        {addr = PPU_WRITE_7_ADDR, tag = ROOM_TAG .. "_edge_ppu_write_7", class = "ppu_write_7"},
        {addr = CLEAR_NAMETABLE_FAST_ADDR, tag = ROOM_TAG .. "_edge_clear_nametable_fast", class = "clear_nametable_fast"},
        {addr = TRANSFER_TILEBUF_FAST_ADDR, tag = ROOM_TAG .. "_edge_transfer_tilebuf_fast", class = "transfer_tilebuf_fast"},
    }
    for i = 1, #specs do
        local spec = specs[i]
        if spec.addr ~= nil then
            pcall(function()
                event.onmemoryexecute(function()
                    mark_edge_writer_activity(spec.class, spec.addr)
                end, spec.addr, spec.tag, "M68K BUS")
            end)
        end
    end
end

local function dump_playmap_linear()
    local out = {}
    for col = 0, ROOM_COLS - 1 do
        for row = 0, ROOM_ROWS - 1 do
            local addr = (PLAYMAP_BASE + row + (col * ROOM_ROWS)) % 0x10000
            out[#out + 1] = ram_u8(0xFF0000 + addr) % 0x100
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
        if #decode_write_trace_rt >= TRACE_RT_MAX_WRITES then
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

local function analyze_runtime_trace_rt(entries, final_rows)
    local summary = {
        first_repeated_write_addr = -1,
        first_repeated_write_seq = -1,
        first_repeated_write_prev_seq = -1,
        first_final_diff_addr = -1,
        first_final_diff_first_value = -1,
        first_final_diff_final_value = -1,
        first_final_diff_last_seq = -1,
        repeat_count_by_addr = {},
    }
    if entries == nil or #entries == 0 or final_rows == nil then
        return summary
    end

    local first_by_addr = {}
    local last_by_addr = {}
    local writes_by_addr = {}

    for i = 1, #entries do
        local e = entries[i]
        local addr = e.addr or 0
        if first_by_addr[addr] == nil then
            first_by_addr[addr] = {seq = e.seq or i, value = e.value or 0}
            writes_by_addr[addr] = 1
        else
            writes_by_addr[addr] = (writes_by_addr[addr] or 1) + 1
            if summary.first_repeated_write_addr < 0 then
                summary.first_repeated_write_addr = addr
                summary.first_repeated_write_seq = e.seq or i
                summary.first_repeated_write_prev_seq = first_by_addr[addr].seq or -1
            end
        end
        last_by_addr[addr] = {seq = e.seq or i, value = e.value or 0}
    end

    for addr, count in pairs(writes_by_addr) do
        if count > 1 then
            summary.repeat_count_by_addr[#summary.repeat_count_by_addr + 1] = {
                addr = addr,
                writes = count,
            }
        end
    end
    table.sort(summary.repeat_count_by_addr, function(a, b)
        if a.writes == b.writes then
            return a.addr < b.addr
        end
        return a.writes > b.writes
    end)

    for i = 1, #entries do
        local e = entries[i]
        local addr = e.addr or 0
        local idx = addr - PLAYMAP_BASE
        if idx >= 0 and idx < (ROOM_ROWS * ROOM_COLS) then
            local col = math.floor(idx / ROOM_ROWS)
            local row = idx % ROOM_ROWS
            local final_value = (((final_rows[row + 1] or {})[col + 1] or 0) % 0x100)
            local first_value = (first_by_addr[addr] and first_by_addr[addr].value or 0) % 0x100
            if final_value ~= first_value then
                summary.first_final_diff_addr = addr
                summary.first_final_diff_first_value = first_value
                summary.first_final_diff_final_value = final_value
                summary.first_final_diff_last_seq = (last_by_addr[addr] and last_by_addr[addr].seq) or -1
                break
            end
        end
    end

    return summary
end

local function decode_transfer_stream_from_abs(abs_ptr)
    local raw = {}
    local records = {}
    local cursor = abs_ptr
    local terminated = false
    local truncated = false

    for _ = 1, TRANSFER_STREAM_MAX_RECORDS do
        if #raw >= TRANSFER_STREAM_MAX_BYTES then
            truncated = true
            break
        end

        local hi = bus_u8(cursor) % 0x100
        raw[#raw + 1] = hi
        if hi == 0xFF then
            terminated = true
            break
        end

        local lo = bus_u8(cursor + 1) % 0x100
        local control = bus_u8(cursor + 2) % 0x100
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
            local v = bus_u8(cursor + 3 + i) % 0x100
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

        cursor = cursor + 3 + payload_len
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

local function capture_transfer_stream_event(frame, mode, sub, selector, dyn_len, source_ptr, source_kind, dispatch_role)
    if #transfer_stream_events >= TRANSFER_STREAM_MAX_EVENTS then
        return
    end
    if mode ~= 0x03 and mode ~= 0x04 and mode ~= 0x05 then
        return
    end
    local parsed = decode_transfer_stream_from_abs(source_ptr)
    if parsed.empty then
        return
    end

    local sig = string.format(
        "%02X:%02X:%02X:%s:%s:%08X:%s",
        frame % 0x100,
        mode % 0x100,
        sub % 0x100,
        dispatch_role or "transfer",
        source_kind or "static",
        source_ptr % 0x100000000,
        table.concat(parsed.raw_stream_bytes, ",")
    )
    if sig == last_transfer_stream_sig then
        return
    end
    last_transfer_stream_sig = sig
    local state = read_transfer_state()
    local status = read_status_inputs()

    transfer_stream_events[#transfer_stream_events + 1] = {
        seq = #transfer_stream_events + 1,
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

local function resolve_transfer_source_ptr(selector)
    if not TRANSFER_BUF_PTRS_ADDR then
        return 0
    end
    local table_addr = TRANSFER_BUF_PTRS_ADDR + ((selector % 0x100) * 2)
    return bus_u32_be(table_addr)
end

local function register_transfer_exec_hook()
    if not TRANSFER_CUR_TILEBUF_ADDR then
        record(lines, "transfer exec hook unavailable (TransferCurTileBuf symbol missing)")
        return
    end
    local ok = pcall(function()
        event.onmemoryexecute(function()
            local mode = ram_u8(0xFF0012)
            local sub = ram_u8(0xFF0013)
            transfer_exec_hook_hits = transfer_exec_hook_hits + 1
            mark_edge_writer_activity("transfer_cur_tilebuf", TRANSFER_CUR_TILEBUF_ADDR)
            local selector = ram_u8(0xFF0014) % 0x100
            local dyn_len = ram_u8(0xFF0301) % 0x100
            local source_ptr = resolve_transfer_source_ptr(selector)
            local source_kind = (source_ptr == 0xFF0302) and "dyn" or "static"
            if #transfer_exec_samples < 192 and (mode == 0x03 or mode == 0x04 or mode == 0x05) then
                local state = read_transfer_state()
                transfer_exec_samples[#transfer_exec_samples + 1] = {
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
                    bytes_head = read_source_bytes_from_abs(source_ptr, 8),
                }
            end
            if source_ptr > 0 then
                capture_transfer_stream_event(current_frame, mode, sub, selector, dyn_len, source_ptr, source_kind, "transfer")
            end
        end, TRANSFER_CUR_TILEBUF_ADDR, ROOM_TAG .. "_transfercurtilebuf", "M68K BUS")
    end)
    if ok then
        transfer_exec_hook_armed = true
        record(lines, string.format("transfer exec hook armed at TransferCurTileBuf $%06X", TRANSFER_CUR_TILEBUF_ADDR))
    else
        record(lines, string.format("transfer exec hook failed at TransferCurTileBuf $%06X; polling fallback only", TRANSFER_CUR_TILEBUF_ADDR))
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

register_transfer_exec_hook()
register_edge_exec_hooks()

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
record(lines, string.format("ROOM %02X GEN CAPTURE: natural path -> Mode5 roomId=$%02X", TARGET_ROOM_ID, TARGET_ROOM_ID))
record(lines, string.format("target_walk_path=%s", TARGET_WALK_PATH ~= "" and TARGET_WALK_PATH or "<none>"))
record(lines, "==============================================================")
record(lines, string.format("LoopForever=$%06X IsrNmi=$%06X", LOOPFOREVER, ISRNMI))
record(lines, "available_memory_domains=" .. available_domains_csv())
record(lines, "selected_ram_domain=" .. (RAM_DOMAIN or "none"))

for frame = 1, MAX_FRAMES do
    current_frame = frame
    reset_edge_writer_activity()
    local mode = ram_u8(0xFF0012)
    local sub = ram_u8(0xFF0013)
    local room_id = ram_u8(0xFF00EB)
    local cur_slot = ram_u8(0xFF0016)
    local name_ofs = ram_u8(0xFF0421)
    local slot_active0 = ram_u8(0xFF0633)
    local slot_active1 = ram_u8(0xFF0634)
    local slot_active2 = ram_u8(0xFF0635)

    if cur_slot ~= last_cur_slot then
        record(lines, string.format(
            "f%04d CurSaveSlot=$%02X active=%02X/%02X/%02X",
            frame, cur_slot, slot_active0, slot_active1, slot_active2
        ))
        last_cur_slot = cur_slot
    end

    if mode ~= (mode_changes[#mode_changes] and mode_changes[#mode_changes].mode or nil)
        or sub ~= (mode_changes[#mode_changes] and mode_changes[#mode_changes].sub or nil) then
        mode_changes[#mode_changes + 1] = {frame = frame, mode = mode, sub = sub, room = room_id}
    end

    if not trace_rt_started and mode == 0x03 then
        trace_rt_started = true
        trace_rt_active = true
        trace_rt_prev_window = dump_playmap_linear()
        record(lines, string.format("f%04d runtime decode trace armed (Mode3 entry)", frame))
    end
    if not edge_trace_started and mode == 0x03 then
        edge_trace_started = true
        edge_trace_active = true
        edge_trace_prev_window = dump_edge_owner_window()
        record(lines, string.format("f%04d edge owner trace armed (Mode3 entry)", frame))
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
            register_mode_seen = true
            last_name_offset = name_ofs
        elseif mode == 0x01 then
            schedule_input(input_state, "Start", 2, 14, frame, "enter register mode", lines)
        end

    elseif flow_state == FLOW_MODEE_TYPE_NAME then
        register_mode_seen = true
        if name_ofs ~= last_name_offset then
            name_progress_events = name_progress_events + 1
            record(lines, string.format("f%04d name progress $0421 %02X -> %02X", frame, last_name_offset, name_ofs))
            last_name_offset = name_ofs
        end
        if name_progress_events >= TARGET_NAME_PROGRESS then
            set_flow_state(FLOW_MODEE_FINISH, frame, "name progress target reached")
        else
            schedule_input(input_state, "A", 1, 10, frame, "ModeE char pulse", lines)
        end

    elseif flow_state == FLOW_MODEE_FINISH then
        if mode ~= 0x0E then
            set_flow_state(FLOW_WAIT_GAMEPLAY, frame, "left ModeE")
        else
            if cur_slot ~= 0x03 then
                schedule_input(input_state, "C", 1, 10, frame, "cycle to END slot", lines)
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

    local transition_active = ram_u8(ROOM_TRANSITION_ACTIVE)
    if TARGET_WALK_PATH ~= "" and not walk_started and mode == 0x05 and room_id == 0x77 and transition_active == 0 then
        start_room_stable_count = start_room_stable_count + 1
        if start_room_stable_count == MODE5_STABLE_FRAMES then
            walk_started = true
            walk_index = 1
            walk_prev_room = room_id
            reset_target_transition_capture(frame, lines)
        end
    else
        start_room_stable_count = 0
    end

    local pad = build_pad_for_frame(input_state)
    pad = apply_walk_pad(pad)
    safe_set(pad)
    emu.frameadvance()

    local pc = emu.getregister("M68K PC") or 0
    if not exception_hit and (pc == EXC_BUS or pc == EXC_ADDR or pc == EXC_DEF) then
        exception_hit = true
        exception_frame = frame
        if pc == EXC_BUS then
            exception_name = "ExcBusError"
        elseif pc == EXC_ADDR then
            exception_name = "ExcAddrError"
        else
            exception_name = "DefaultException"
        end
        record(lines, string.format("f%04d EXCEPTION %s PC=$%06X", frame, exception_name, pc))
        break
    end

    mode = ram_u8(0xFF0012)
    sub = ram_u8(0xFF0013)
    room_id = ram_u8(0xFF00EB)
    transition_active = ram_u8(ROOM_TRANSITION_ACTIVE)
    if walk_started and walk_index <= #TARGET_WALK_PATH and transition_active == 0 and room_id ~= walk_prev_room then
        record(lines, string.format("f%04d walk step %d arrived roomId=$%02X", frame, walk_index, room_id))
        walk_prev_room = room_id
        walk_index = walk_index + 1
    end
    if not trace_rt_started and mode == 0x03 then
        trace_rt_started = true
        trace_rt_active = true
        trace_rt_prev_window = dump_playmap_linear()
        record(lines, string.format("f%04d runtime decode trace armed (Mode3 post-frame)", frame))
    end
    if not edge_trace_started and mode == 0x03 then
        edge_trace_started = true
        edge_trace_active = true
        edge_trace_prev_window = dump_edge_owner_window()
        record(lines, string.format("f%04d edge owner trace armed (Mode3 post-frame)", frame))
    end

    if trace_rt_active then
        capture_runtime_trace_deltas()
    end
    if edge_trace_active then
        capture_edge_owner_deltas()
    end

    if not mode3_sub8_snapshot and mode == 0x03 and sub == 0x08 then
        if not trace_rt_started then
            trace_rt_started = true
            trace_rt_active = true
            trace_rt_prev_window = dump_playmap_linear()
            record(lines, string.format("f%04d runtime decode trace armed (Mode3 first observed)", frame))
        end
        mode3_sub8_snapshot = build_trace_snapshot("mode3_sub8_first", frame, mode, sub, room_id)
        trace_snapshots[#trace_snapshots + 1] = mode3_sub8_snapshot
        local sub8_workbuf_base = mode3_sub8_snapshot.workbuf_base_ptr or PLAYMAP_BASE
        mode3_sub8_workbuf_rows = dump_workbuf_rows(sub8_workbuf_base)
        record(lines, string.format("f%04d trace captured: mode3/sub8 first", frame))
    end

    if not layoutroomow_exit_snapshot and prev_mode == 0x03 and prev_sub == 0x08 and not (mode == 0x03 and sub == 0x08) then
        trace_rt_active = false
        trace_rt_prev_window = nil
        layoutroomow_exit_snapshot = build_layoutroomow_exit_snapshot(frame, mode, sub, room_id)
        trace_snapshots[#trace_snapshots + 1] = layoutroomow_exit_snapshot
        local exit_workbuf_base = layoutroomow_exit_snapshot.workbuf_base_ptr or PLAYMAP_BASE
        layoutroomow_exit_workbuf_rows = dump_workbuf_rows(exit_workbuf_base)
        record(lines, string.format(
            "f%04d trace captured: LayoutRoomOW exit ptr02_03=$%04X ptr04_05=$%04X mmc1=$%02X win=$%02X",
            frame,
            layoutroomow_exit_snapshot.ptr_02_03 or 0,
            layoutroomow_exit_snapshot.ptr_04_05 or 0,
            layoutroomow_exit_snapshot.mmc1_prg or 0,
            layoutroomow_exit_snapshot.current_window_bank or 0
        ))
    end

    if mode == 0x05 and room_id == TARGET_ROOM_ID then
        mode5_stable_count = mode5_stable_count + 1
        if mode5_stable_count == MODE5_STABLE_FRAMES and not mode5_stable_snapshot then
            reached_target = true
            target_frame = frame
            mode5_stable_snapshot = build_trace_snapshot("mode5_room_stable", frame, mode, sub, room_id)
            trace_snapshots[#trace_snapshots + 1] = mode5_stable_snapshot
            record(lines, string.format("f%04d reached stable target: mode=$%02X sub=$%02X roomId=$%02X", frame, mode, sub, room_id))
            break
        end
    else
        mode5_stable_count = 0
    end
    prev_mode = mode
    prev_sub = sub
end

if reached_target then
    for _ = 1, 20 do
        safe_set({})
        emu.frameadvance()
    end
end

local final_mode = ram_u8(0xFF0012)
local final_sub = ram_u8(0xFF0013)
local final_room = ram_u8(0xFF00EB)
local final_room_diag = ram_u8(0xFF003C)
local final_mmc1 = ram_u8(0xFF0815)
local final_bank = ram_u8(0xFF083F)
local final_ppu_ctrl = ram_u8(0xFF00FF)
local final_bg_half = math.floor(final_ppu_ctrl / 16) % 2

if reached_target then
    client.screenshot(OUT_PNG)
end

local plane_words = {}
for row = 0, ROOM_ROWS - 1 do
    local row_words = {}
    local plane_row = PLANE_A_TOP_ROW + row
    local row_base = PLANE_A_BASE + plane_row * PLANE_A_ROW_STRIDE
    for col = 0, ROOM_COLS - 1 do
        row_words[#row_words + 1] = vram_u16(row_base + col * 2)
    end
    plane_words[#plane_words + 1] = row_words
end

local nt_cache_rows = {}
for row = 0, ROOM_ROWS - 1 do
    local row_bytes = {}
    local nt_row = PLANE_A_TOP_ROW + row
    local base = 0xFF0840 + nt_row * 32
    for col = 0, ROOM_COLS - 1 do
        row_bytes[#row_bytes + 1] = ram_u8(base + col)
    end
    nt_cache_rows[#nt_cache_rows + 1] = row_bytes
end

local workbuf_base_ptr = PLAYMAP_BASE
if layoutroomow_exit_snapshot and (layoutroomow_exit_snapshot.workbuf_base_ptr or -1) >= 0 then
    workbuf_base_ptr = layoutroomow_exit_snapshot.workbuf_base_ptr
end
local workbuf_rows = dump_workbuf_rows(workbuf_base_ptr)
local decode_write_trace = {}
if layoutroomow_exit_snapshot then
    decode_write_trace = build_decode_write_trace(
        layoutroomow_exit_snapshot.layout_ptr_effective or 0,
        workbuf_base_ptr,
        workbuf_rows
    )
end
local playmap_rows = dump_playmap_rows()

local cram_words = {}
for i = 0, 63 do
    cram_words[#cram_words + 1] = cram_u16(i * 2)
end
local edge_owner_summary = build_edge_owner_summary(edge_owner_trace, edge_trace_started and reached_target)

record(lines, "")
record(lines, string.format("register_mode_seen=%s name_progress_events=%d", register_mode_seen and "yes" or "no", name_progress_events))
record(lines, string.format("final mode=$%02X sub=$%02X roomId=$%02X room03C=$%02X", final_mode, final_sub, final_room, final_room_diag))
record(lines, string.format("final mmc1PRG=$%02X currentWindowBank=$%02X", final_mmc1, final_bank))
record(lines, string.format("final PPUCTRL=$%02X bgPatternHalf=%d", final_ppu_ctrl, final_bg_half))
record(lines, string.format("workbuf_base_ptr=$%04X", workbuf_base_ptr))
record(lines, string.format("decode_write_trace_entries=%d", #decode_write_trace))
record(lines, string.format("decode_write_trace_rt_entries=%d", #decode_write_trace_rt))
record(lines, string.format("decode_write_trace_rt_valid=%s", (#decode_write_trace_rt >= TRACE_RT_MIN_VALID) and "yes" or "no"))
record(lines, string.format("decode_write_trace_rt_hooks=%s", runtime_write_hooks_enabled and "enabled" or "fallback"))
record(lines, string.format("transfer_exec_hook=%s", transfer_exec_hook_armed and "armed" or "off"))
record(lines, string.format("transfer_exec_hook_hits=%d", transfer_exec_hook_hits))
record(lines, string.format("transfer_stream_events=%d", #transfer_stream_events))
record(lines, string.format("transfer_stream_capture_valid=%s", (#transfer_stream_events > 0) and "yes" or "no"))
record(lines, string.format("edge_owner_trace_entries=%d", edge_owner_summary.entries or 0))
record(lines, string.format("edge_owner_trace_valid=%s", edge_owner_summary.valid and "yes" or "no"))
record(lines, string.format("edge_owner_writer_classes=%s", table.concat(edge_owner_summary.writer_classes or {}, ",")))
runtime_trace_summary = analyze_runtime_trace_rt(decode_write_trace_rt, layoutroomow_exit_workbuf_rows)
record(lines, string.format(
    "rt_first_repeat addr=$%04X seq=%d prev=%d",
    runtime_trace_summary.first_repeated_write_addr >= 0 and runtime_trace_summary.first_repeated_write_addr or 0xFFFF,
    runtime_trace_summary.first_repeated_write_seq or -1,
    runtime_trace_summary.first_repeated_write_prev_seq or -1
))
record(lines, string.format(
    "rt_first_final_diff addr=$%04X first=$%02X final=$%02X lastSeq=%d",
    runtime_trace_summary.first_final_diff_addr >= 0 and runtime_trace_summary.first_final_diff_addr or 0xFFFF,
    runtime_trace_summary.first_final_diff_first_value >= 0 and runtime_trace_summary.first_final_diff_first_value or 0xFF,
    runtime_trace_summary.first_final_diff_final_value >= 0 and runtime_trace_summary.first_final_diff_final_value or 0xFF,
    runtime_trace_summary.first_final_diff_last_seq or -1
))
record(lines, string.format("target_reached=%s frame=%s", reached_target and "yes" or "no", tostring(target_frame or -1)))
record(lines, string.format("trace_snapshots=%d", #trace_snapshots))
if exception_hit then
    record(lines, string.format("exception=%s frame=%d", exception_name, exception_frame))
end

local out = assert(io.open(OUT_TXT, "w"))
out:write(table.concat(lines, "\n"))
out:write("\n")
out:close()

local jf = assert(io.open(OUT_JSON, "w"))
jf:write("{\n")
jf:write('  "target_reached": ', reached_target and "true" or "false", ",\n")
jf:write('  "target_room_id": ', tostring(TARGET_ROOM_ID), ",\n")
jf:write('  "target_frame": ', tostring(target_frame or -1), ",\n")
jf:write('  "final_mode": ', tostring(final_mode), ",\n")
jf:write('  "final_submode": ', tostring(final_sub), ",\n")
jf:write('  "room_id": ', tostring(final_room), ",\n")
jf:write('  "room_diag_003C": ', tostring(final_room_diag), ",\n")
jf:write('  "mmc1_prg": ', tostring(final_mmc1), ",\n")
jf:write('  "current_window_bank": ', tostring(final_bank), ",\n")
jf:write('  "ppu_ctrl_shadow": ', tostring(final_ppu_ctrl), ",\n")
jf:write('  "bg_pattern_table_half": ', tostring(final_bg_half), ",\n")
jf:write('  "workbuf_base_ptr": ', tostring(workbuf_base_ptr), ",\n")
jf:write('  "plane_a_base": ', tostring(PLANE_A_BASE), ",\n")
jf:write('  "plane_a_top_row": ', tostring(PLANE_A_TOP_ROW), ",\n")
jf:write('  "plane_a_rows": ', tostring(ROOM_ROWS), ",\n")
jf:write('  "plane_a_cols": ', tostring(ROOM_COLS), ",\n")
jf:write('  "screenshot_path": "', json_escape(OUT_PNG), '",\n')
jf:write('  "exception": "', json_escape(exception_name), '",\n')
jf:write('  "plane_words": ', json_matrix(plane_words), ",\n")
jf:write('  "layoutroomow_exit_workbuf_rows": ', json_matrix(layoutroomow_exit_workbuf_rows or {}), ",\n")
jf:write('  "mode3_sub8_workbuf_rows": ', json_matrix(mode3_sub8_workbuf_rows or {}), ",\n")
jf:write('  "workbuf_rows": ', json_matrix(workbuf_rows), ",\n")
jf:write('  "decode_write_trace": ', json_decode_write_trace(decode_write_trace), ",\n")
jf:write('  "decode_write_trace_rt": ', json_decode_write_trace_rt(decode_write_trace_rt), ",\n")
jf:write('  "decode_write_trace_rt_entries": ', tostring(#decode_write_trace_rt), ",\n")
jf:write('  "decode_write_trace_rt_valid": ', (#decode_write_trace_rt >= TRACE_RT_MIN_VALID) and "true" or "false", ",\n")
jf:write('  "decode_write_trace_rt_hooks": "', runtime_write_hooks_enabled and "enabled" or "fallback", '",\n')
jf:write('  "transfer_exec_hook_armed": ', transfer_exec_hook_armed and "true" or "false", ",\n")
jf:write('  "transfer_exec_hook_hits": ', tostring(transfer_exec_hook_hits), ",\n")
jf:write('  "transfer_exec_samples": ', json_transfer_exec_samples(transfer_exec_samples), ",\n")
jf:write('  "transfer_stream_events": ', json_transfer_stream_events(transfer_stream_events), ",\n")
jf:write('  "transfer_stream_event_entries": ', tostring(#transfer_stream_events), ",\n")
jf:write('  "transfer_stream_capture_valid": ', (#transfer_stream_events > 0) and "true" or "false", ",\n")
jf:write('  "edge_owner_trace": ', json_edge_owner_trace(edge_owner_trace), ",\n")
jf:write('  "edge_owner_trace_entries": ', tostring(edge_owner_summary.entries or 0), ",\n")
jf:write('  "edge_owner_trace_valid": ', edge_owner_summary.valid and "true" or "false", ",\n")
jf:write('  "edge_owner_writer_classes": ', json_string_array(edge_owner_summary.writer_classes or {}), ",\n")
jf:write('  "edge_owner_first_write": ', json_edge_owner_point(edge_owner_summary.first_write), ",\n")
jf:write('  "edge_owner_last_write": ', json_edge_owner_point(edge_owner_summary.last_write), ",\n")
jf:write('  "runtime_trace_summary": ', json_runtime_trace_summary(runtime_trace_summary), ",\n")
jf:write('  "nt_cache_rows": ', json_matrix(nt_cache_rows), ",\n")
jf:write('  "playmap_rows": ', json_matrix(playmap_rows), ",\n")
jf:write('  "trace_snapshots": ', json_trace_snapshots(trace_snapshots), ",\n")
jf:write('  "cram_words": ', json_num_array(cram_words), "\n")
jf:write("}\n")
jf:close()

client.exit()
