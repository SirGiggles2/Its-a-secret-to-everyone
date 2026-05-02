-- tools/parity/genesis_probe.lua
-- ─────────────────────────────────────────────────────────────────────────────
-- Parity Oracle Schema — Genesis BizHawk Probe (skeleton)
--
-- Emits a parity-oracle-schema-conformant JSON instance from a Genesis run.
-- Writes to the path in env var GEN_PROBE_OUT (required).
--
-- Usage (via bizhawkScript skill):
--   Set GEN_PROBE_OUT=<absolute path to output .json>
--   Launch BizHawk with this script via the bizhawkScript skill pattern.
--
-- State address placeholders:
--   All "TODO: src/state/*_state.h" comments reference typed C struct fields
--   as defined in docs/audit/state_contract.md. When the struct headers are
--   promoted at the relevant phase, replace the placeholder addresses with
--   the actual M68K addresses produced by SGDK's linker map.
--
-- One-probe rule: bundle screenshot + CRAM + SAT + planes + state in one run.
-- Memory rule: feedback_one_big_probe
-- ─────────────────────────────────────────────────────────────────────────────

-- ── Output path ──────────────────────────────────────────────────────────────

local out_path = os.getenv("GEN_PROBE_OUT")
if not out_path or out_path == "" then
    error("GEN_PROBE_OUT environment variable is not set. "
          .. "Set it to the desired output JSON path before launching BizHawk.")
end

-- ── Wait for stable frame ─────────────────────────────────────────────────────
-- Allow the ROM to run N frames before capturing. Override via
-- GEN_PROBE_FRAME env var (defaults to 0 = capture at current frame).

local target_frame = tonumber(os.getenv("GEN_PROBE_FRAME") or "0") or 0
if emu.framecount() < target_frame then
    -- Register a callback that fires once we reach the target frame.
    local function on_frame()
        if emu.framecount() >= target_frame then
            event.unregisterbyname("parity_probe_wait")
            capture_and_write()
        end
    end
    event.onframestart(on_frame, "parity_probe_wait")
else
    -- Already at or past target — capture immediately after this script loads.
    -- BizHawk executes Lua on frame start; we register a one-shot callback.
    local fired = false
    local function on_frame_once()
        if not fired then
            fired = true
            event.unregisterbyname("parity_probe_once")
            capture_and_write()
        end
    end
    event.onframestart(on_frame_once, "parity_probe_once")
end

-- ── Memory domain helpers ─────────────────────────────────────────────────────
-- Genesis BizHawk domains: "68K RAM", "VRAM", "CRAM", "VSRAM", "MD CART"

local function read_u8(domain, addr)
    return memory.read_u8(addr, domain)
end

local function read_u16be(domain, addr)
    return memory.read_u16_be(addr, domain)
end

local function read_bytes_hex(domain, addr, count)
    -- Returns lowercase hex string of 'count' bytes from domain at addr.
    local out = {}
    for i = 0, count - 1 do
        local b = memory.read_u8(addr + i, domain)
        out[#out + 1] = string.format("%02x", b)
    end
    return table.concat(out)
end

-- ── NES RAM mirror address helpers ───────────────────────────────────────────
-- Genesis "NES RAM mirror" lives at a fixed M68K base address.
-- TODO: confirm base address from linker map once SGDK build is stable.
-- Placeholder: NES_RAM_BASE = 0xFF0100 (example; update from linker map).
-- The nes_ram[] array is pointed to by A4 in transpiled code.

local NES_RAM_BASE = 0xFF0100  -- PLACEHOLDER: update from SGDK linker map

local function nes_ram_u8(nes_offset)
    -- Read a byte from the Genesis NES RAM mirror at nes_offset.
    -- TODO: validate NES_RAM_BASE against linker .map output.
    return read_u8("68K RAM", NES_RAM_BASE + nes_offset)
end

-- ── Typed struct field readers ────────────────────────────────────────────────
-- When src/state/*_state.h structs are promoted, replace these placeholder
-- reads with direct struct field addresses from the linker map.
--
-- Convention: STRUCT_BASE_<NAME> = linker address of the struct instance.
-- e.g., STRUCT_BASE_LINK = address of g_link_state in 68K RAM.

-- TODO: Phase 6 — replace with g_link_state struct field addresses.
local STRUCT_BASE_LINK = nil  -- PLACEHOLDER: set from linker .map

-- TODO: Phase 7 — replace with g_enemy_state[16] struct field addresses.
local STRUCT_BASE_ENEMIES = nil  -- PLACEHOLDER: set from linker .map

-- TODO: Phase 6 — replace with g_item_state[8] struct field addresses.
local STRUCT_BASE_ITEMS = nil  -- PLACEHOLDER: set from linker .map

-- ── Link state reader ─────────────────────────────────────────────────────────

local function read_link_state()
    -- NES RAM offsets for Link state (fallback while transpiled code is active).
    -- Source: reference/aldonunez/data.asm, NES RAM map.
    -- TODO Phase 6: switch to STRUCT_BASE_LINK typed field reads.
    local x           = nes_ram_u8(0x0070)  -- NES $70: Link screen X
    local y           = nes_ram_u8(0x0084)  -- NES $84: Link screen Y
    local dir         = nes_ram_u8(0x0098)  -- NES $98: facing direction
    local action      = nes_ram_u8(0x0641 - 0x0000)  -- NES $0641: action state
    -- anim_frame: derived from frame counter + action; use NES $10 directly.
    local frame_ctr   = nes_ram_u8(0x0010)  -- NES $10: frame counter
    local anim_frame  = frame_ctr % 16      -- simplified; real derivation TBD
    local hp          = nes_ram_u8(0x066F - 0x0000)  -- NES $066F: HP half-hearts
    local invuln      = nes_ram_u8(0x0627 - 0x0000)  -- NES $0627: invuln timer
    local b_item      = nes_ram_u8(0x0657 - 0x0000)  -- NES $0657: B-button item

    return {
        x = x, y = y, dir = dir, action = action,
        anim_frame = anim_frame, hp = hp,
        invuln_timer = invuln, b_item = b_item
    }
end

-- ── Enemy state reader ────────────────────────────────────────────────────────

local function read_enemy_state()
    -- NES RAM offset bases for enemy arrays (16 slots each).
    -- Source: reference/aldonunez/data.asm enemy object tables.
    -- TODO Phase 7: switch to STRUCT_BASE_ENEMIES typed field reads.
    local BASE_TYPE        = 0x0340  -- $0340[16]: enemy type
    local BASE_ACTION      = 0x0420  -- $0420[16]: action/AI state
    local BASE_Y           = 0x0460  -- $0460[16]: Y coordinate
    local BASE_X           = 0x0470  -- $0470[16]: X coordinate
    local BASE_DIR         = 0x04B0  -- $04B0[16]: direction
    local BASE_HP          = 0x06B0  -- $06B0[16]: HP (nibble-packed for some)
    local BASE_ANIM        = 0x0560  -- $0560[16]: animation frame
    local BASE_PROJECTILE  = 0x04C0  -- $04C0[16]: projectile slot reference

    local enemies = {}
    for slot = 0, 15 do
        enemies[slot + 1] = {
            type         = nes_ram_u8(BASE_TYPE       + slot),
            x            = nes_ram_u8(BASE_X          + slot),
            y            = nes_ram_u8(BASE_Y          + slot),
            dir          = nes_ram_u8(BASE_DIR        + slot) % 4,
            action       = nes_ram_u8(BASE_ACTION     + slot),
            hp           = nes_ram_u8(BASE_HP         + slot),
            anim_frame   = nes_ram_u8(BASE_ANIM       + slot),
            projectile_id = nes_ram_u8(BASE_PROJECTILE + slot),
        }
    end
    return enemies
end

-- ── Item state reader ─────────────────────────────────────────────────────────

local function read_item_state()
    -- NES RAM offset bases for floor item arrays (8 slots).
    -- TODO Phase 6: switch to STRUCT_BASE_ITEMS typed field reads.
    local BASE_TYPE  = 0x0410  -- $0410[8]: item type
    local BASE_Y     = 0x0480  -- $0480[8]: Y coordinate
    local BASE_X     = 0x0490  -- $0490[8]: X coordinate
    local BASE_STATE = 0x05B0  -- $05B0[8]: pickup state

    local items = {}
    for slot = 0, 7 do
        items[slot + 1] = {
            type  = nes_ram_u8(BASE_TYPE  + slot),
            x     = nes_ram_u8(BASE_X     + slot),
            y     = nes_ram_u8(BASE_Y     + slot),
            state = nes_ram_u8(BASE_STATE + slot),
        }
    end
    return items
end

-- ── RAM bucket readers ────────────────────────────────────────────────────────

local function read_ram_bytes()
    -- Globals: NES $0000-$00FF (zero page)
    local globals = read_bytes_hex("68K RAM", NES_RAM_BASE + 0x0000, 256)

    -- Link state block: NES $0620-$067F (96 bytes)
    local link_block = read_bytes_hex("68K RAM", NES_RAM_BASE + 0x0620, 96)

    -- Enemy state block: NES $0340-$05FF (480 bytes)
    local enemy_block = read_bytes_hex("68K RAM", NES_RAM_BASE + 0x0340, 480)

    -- Save buffer: NES SRAM $6000-$68FF (2304 bytes)
    -- Note: on Genesis this may be in a different domain (e.g., backup RAM).
    -- TODO: confirm save buffer location when SRAM subsystem is promoted (Phase 9).
    -- Fallback: read from 68K RAM at the save buffer mirror address.
    local SAVE_BUFFER_BASE = 0xFF8000  -- PLACEHOLDER: update from Phase 9 SRAM map
    local save_buf = read_bytes_hex("68K RAM", SAVE_BUFFER_BASE, 2304)

    return {
        globals = globals,
        link_state_block = link_block,
        enemy_state_block = enemy_block,
        save_buffer = save_buf,
    }
end

-- ── CRAM reader ───────────────────────────────────────────────────────────────

local function read_cram()
    -- Genesis CRAM: 64 entries × 2 bytes = 128 bytes.
    -- BizHawk "CRAM" domain exposes raw CRAM bytes.
    -- Each entry is a 16-bit word; Genesis uses 0x0BGR nibble encoding (12-bit color).
    local cram = {}
    for i = 0, 63 do
        local word = read_u16be("CRAM", i * 2)
        -- Mask to 12 bits (0x0FFF) to match schema range [0, 4095].
        cram[i + 1] = word % 0x1000
    end
    return cram
end

-- ── SAT reader ────────────────────────────────────────────────────────────────

local function read_sat()
    -- Genesis SAT lives in VRAM. The SAT base address is set by VDP register 5.
    -- Default RoomRom SAT base: 0xB800 (can vary; read from VDP reg 5 if needed).
    -- Each SAT entry: 8 bytes total (Y=2, size_link=2, X=2, attr_tile=2).
    -- 80 entries maximum.
    --
    -- TODO: read VDP register 5 to get actual SAT base address.
    local SAT_VRAM_BASE = 0xB800  -- PLACEHOLDER: read from VDP reg 5 × 0x200

    local sat = {}
    for i = 0, 79 do
        local base = SAT_VRAM_BASE + i * 8
        local y          = read_u16be("VRAM", base + 0)
        local size_link  = read_u16be("VRAM", base + 2)
        local x          = read_u16be("VRAM", base + 4)
        local attr_tile  = read_u16be("VRAM", base + 6)
        sat[i + 1] = {
            y = y,
            size_link = size_link,
            x = x,
            attr_tile = attr_tile,
        }
    end
    return sat
end

-- ── Plane excerpt readers ─────────────────────────────────────────────────────

local function read_plane_excerpt(vram_base, scroll_x, scroll_y)
    -- Read 32×28 tile nametable entries from VRAM starting at vram_base.
    -- scroll_x, scroll_y: current VDP scroll registers (for excerpt alignment).
    -- Each entry is a 16-bit Genesis nametable word.
    -- Returns array of 896 integers.
    --
    -- TODO: read VDP registers 2 (Plane A base) and 4 (Plane B base) for
    --       actual VRAM addresses. Defaults below match RoomRom VDP init.
    local PLANE_WIDTH_TILES = 64   -- plane width in tiles (VDP reg 16)
    local entries = {}
    for row = 0, 27 do
        for col = 0, 31 do
            -- Account for scroll wrap-around.
            local tile_col = (col + math.floor(scroll_x / 8)) % PLANE_WIDTH_TILES
            local tile_row = (row + math.floor(scroll_y / 8)) % 32
            local addr = vram_base + (tile_row * PLANE_WIDTH_TILES + tile_col) * 2
            local word = read_u16be("VRAM", addr)
            entries[#entries + 1] = word
        end
    end
    return entries
end

-- ── OAM placeholder (NES-side only, Genesis emits zeros) ──────────────────────

local function make_null_oam()
    -- Genesis side: OAM is a NES-only concept.
    -- Populate with 64 zero-entries to satisfy schema.
    local oam = {}
    for i = 1, 64 do
        oam[i] = { y = 0, tile = 0, attr = 0, x = 0 }
    end
    return oam
end

-- ── Screenshot + SHA-256 ──────────────────────────────────────────────────────

local function capture_screenshot_and_hash(out_dir)
    -- Capture PNG screenshot via BizHawk's client.screenshot API.
    -- Returns sha256 hex string (lowercase).
    --
    -- BizHawk screenshot API:
    --   client.screenshot(path)  — saves PNG to path.
    -- SHA-256: compute via external Python or fallback placeholder hash.
    --
    -- NOTE: BizHawk Lua does not have native SHA-256. We write the PNG and
    -- run a Python helper to compute the hash. If Python is unavailable,
    -- a placeholder hash "0000...0000" is used (will cause screenshot diff failure).

    local png_path = out_dir .. "/screenshot.png"
    client.screenshot(png_path)

    -- Try Python SHA-256 computation
    local hash = "0000000000000000000000000000000000000000000000000000000000000000"
    local py_cmd = string.format(
        'python -c "import hashlib,sys; '
        .. 'h=hashlib.sha256(open(sys.argv[1],\'rb\').read()).hexdigest(); '
        .. 'print(h)" "%s"', png_path)
    local handle = io.popen(py_cmd)
    if handle then
        local result = handle:read("*l")
        handle:close()
        if result and #result == 64 then
            hash = result:lower()
        end
    end
    return hash
end

-- ── JSON serializer ───────────────────────────────────────────────────────────

local function json_encode(val, indent, depth)
    indent = indent or "  "
    depth = depth or 0
    local t = type(val)
    if t == "nil" then return "null"
    elseif t == "boolean" then return val and "true" or "false"
    elseif t == "number" then
        if val ~= val then return "null" end  -- NaN guard
        if val == math.floor(val) then return string.format("%d", val) end
        return string.format("%.6g", val)
    elseif t == "string" then
        -- Minimal JSON string escape
        local s = val:gsub('\\', '\\\\'):gsub('"', '\\"')
                     :gsub('\n', '\\n'):gsub('\r', '\\r')
                     :gsub('\t', '\\t')
        return '"' .. s .. '"'
    elseif t == "table" then
        -- Detect array vs object
        local is_array = (#val > 0)
        local pad = string.rep(indent, depth)
        local pad1 = string.rep(indent, depth + 1)
        if is_array then
            local parts = {}
            for i, v in ipairs(val) do
                parts[i] = pad1 .. json_encode(v, indent, depth + 1)
            end
            return "[\n" .. table.concat(parts, ",\n") .. "\n" .. pad .. "]"
        else
            local parts = {}
            local keys = {}
            for k in pairs(val) do keys[#keys + 1] = k end
            table.sort(keys)
            for _, k in ipairs(keys) do
                parts[#parts + 1] = pad1 .. '"' .. tostring(k) .. '": '
                    .. json_encode(val[k], indent, depth + 1)
            end
            return "{\n" .. table.concat(parts, ",\n") .. "\n" .. pad .. "}"
        end
    else
        return '"<' .. t .. '>"'
    end
end

-- ── Main capture function ─────────────────────────────────────────────────────

function capture_and_write()
    local frame = emu.framecount()

    -- Determine output directory from out_path
    local out_dir = out_path:match("^(.*)[/\\][^/\\]+$") or "."

    -- Read all state
    local link_state   = read_link_state()
    local enemy_state  = read_enemy_state()
    local item_state   = read_item_state()
    local ram_bytes    = read_ram_bytes()
    local cram         = read_cram()
    local sat          = read_sat()
    local oam          = make_null_oam()

    -- Read scroll registers for plane excerpt alignment
    -- TODO: read actual VDP scroll registers via memory.read_u16_be on VDP domain.
    local scroll_x = 0  -- PLACEHOLDER: read VDP HSCROLL table
    local scroll_y = 0  -- PLACEHOLDER: read VDP reg 15 (VSRAM[0])

    -- Plane A: VDP reg 2 × 0x2000 default = 0xC000
    -- TODO: read VDP reg 2 for actual base.
    local PLANE_A_BASE = 0xC000  -- PLACEHOLDER
    local PLANE_B_BASE = 0xE000  -- PLACEHOLDER (VDP reg 4 × 0x2000)

    local plane_a = read_plane_excerpt(PLANE_A_BASE, scroll_x, scroll_y)
    local plane_b = read_plane_excerpt(PLANE_B_BASE, scroll_x, scroll_y)

    -- Screenshot
    local screenshot_sha256 = capture_screenshot_and_hash(out_dir)

    -- NES state scalars (from NES RAM mirror)
    local input_bitmask = nes_ram_u8(0x00F6)  -- controller 1 latch; NES $F6
    local rng_seed      = 0x0000               -- PLACEHOLDER: injected seed (not readable back easily)
    local rng_current   = nes_ram_u8(0x0619) * 256 + nes_ram_u8(0x061A)
    local room_id       = nes_ram_u8(0x00EB)  -- NES $EB: current room
    local quest         = nes_ram_u8(0x010C) % 2  -- NES $10C: quest 0 or 1

    -- Assemble schema instance
    local instance = {
        frame           = frame,
        input_bitmask   = input_bitmask,
        rng_seed        = rng_seed,
        rng_current     = rng_current,
        room_id         = room_id,
        quest           = quest,
        link            = link_state,
        enemies         = enemy_state,
        items           = item_state,
        ram_bytes       = ram_bytes,
        cram            = cram,
        sat             = sat,
        oam             = oam,
        plane_a_excerpt = plane_a,
        plane_b_excerpt = plane_b,
        nametable_excerpt = {},  -- Genesis side: NES nametable N/A
        screenshot_sha256 = screenshot_sha256,
    }

    -- Write JSON
    local json_str = json_encode(instance)
    local f, err = io.open(out_path, "w")
    if not f then
        error("genesis_probe.lua: cannot write to " .. out_path .. ": " .. tostring(err))
    end
    f:write(json_str)
    f:close()

    print(string.format("[genesis_probe] frame=%d written to %s", frame, out_path))

    -- Signal completion to runner
    print("ALL PASS")
    client.pause()
end
