-- walker_perf.lua — hooks enemy/walker/arrow update paths to find
-- per-frame cost per function at $73.

local SYM = {
    UpdateMoblin         = 0x3A6FA,
    UpdateArrow          = 0x4D1AA,  -- UpdateArrowOrBoomerang
    MoveObject           = 0x4C8E4,
    Walker_Move          = 0x4C7BA,
    Walker_CheckTile     = 0x4C99A,
    TryNextDir           = 0x4CA26,
    FindNextEdgeSpawn    = 0x4250C,
    transfer_tilebuf     = 0x2B2C8,
    TransferCurTileBuf   = 0x481D4,
    UpdatePlayer         = 0x4C336,
    VBlankISR            = 0x00422,
    -- CHR-path hooks: ppu_write_7 is the SLOW per-byte path, should be
    -- bypassed by _transfer_tilebuf_fast. If it's hit at high rate the
    -- fast interpreter is missing a case. chr_convert/sprite_4x are the
    -- 2BPP->4BPP converters. sprite_4x does 4 VRAM copies per tile.
    ppu_write_7          = 0x0E54E,
    chr_convert_upload   = 0x0E8DE,
    chr_upload_sprite_4x = 0x0E97E,
    transfer_chr_block   = 0x2B176,
}

local FRAME_COUNTER = 0xFF0015
local GAME_MODE     = 0xFF0012
local ROOM_ID       = 0xFF00EB

local function u8(a) memory.usememorydomain("M68K BUS"); return memory.read_u8(a) end

local hit = {}
for name, _ in pairs(SYM) do hit[name] = 0 end

for name, addr in pairs(SYM) do
    pcall(function()
        event.onmemoryexecute(function() hit[name] = hit[name] + 1 end,
                              addr, "wp_" .. name, "M68K BUS")
    end)
end

local start_time = os.clock()
local last_dump = os.clock()
local window_start = os.clock()
local window_emu = 0
local window_game_ticks = 0
local last_game_fc = u8(FRAME_COUNTER)
local window_hits = {}
for name, _ in pairs(SYM) do window_hits[name] = 0 end

while true do
    emu.frameadvance()
    window_emu = window_emu + 1
    local fc = u8(FRAME_COUNTER)
    local delta = (fc - last_game_fc) & 0xFF
    window_game_ticks = window_game_ticks + delta
    last_game_fc = fc
    for name, count in pairs(hit) do
        window_hits[name] = window_hits[name] + count
        hit[name] = 0
    end

    local now = os.clock()
    if now - last_dump >= 1.0 then
        last_dump = now
        local elapsed = now - window_start
        local emu_fps = window_emu / elapsed
        local game_fps = window_game_ticks / elapsed
        local per_frame = {}
        for name, count in pairs(window_hits) do
            per_frame[name] = count / window_emu
        end
        window_start = now
        window_emu = 0
        window_game_ticks = 0
        for name, _ in pairs(window_hits) do window_hits[name] = 0 end

        local fh = io.open("C:\\tmp\\walker_log.txt", "a")
        if fh then
            fh:write(string.format("[t=%.1fs] emu=%.1f game=%.1f mode=$%02X room=$%02X\n",
                now - start_time, emu_fps, game_fps, u8(GAME_MODE), u8(ROOM_ID)))
            local sorted = {}
            for name, n in pairs(per_frame) do sorted[#sorted+1] = {name=name, n=n} end
            table.sort(sorted, function(a, b) return a.n > b.n end)
            for i = 1, #sorted do
                if sorted[i].n > 0.01 then
                    fh:write(string.format("  %-22s %9.2f /frame\n", sorted[i].name, sorted[i].n))
                end
            end
            fh:write("\n")
            fh:close()
        end

        gui.text(10, 10, string.format("emu=%.1f game=%.1f", emu_fps, game_fps))
    end
end
