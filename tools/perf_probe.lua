-- perf_probe.lua — per-frame performance breakdown overlay for Genplus-gx.
--
-- Genplus-gx does NOT expose TotalExecutedCycles or "System Bus". We use:
--   * emu FPS + game logic FPS (FrameCounter @ $FF0015) — both drop when
--     the 68K over-runs frame time, so gap-from-60 proxies CPU usage.
--   * event.onmemoryexecute on "M68K BUS" to count hot-function hits
--     per frame. The function with a huge calls/frame count is the
--     offender.

-- Symbol addresses from builds/whatif.lst. These are 68K PC addresses,
-- NOT NES-RAM offsets — they go through "M68K BUS" at their direct addr.
local SYM = {
    transfer_tilebuf_fast = 0x2B2C8,
    chr_convert_upload    = 0x0E8DE,
    chr_upload_sprite_4x  = 0x0E97E,
    transfer_chr_block    = 0x2B176,
    compose_bg_tile_word  = 0x0EAC0,
    attr_write_2x2        = 0x0EAD8,
    TransferCurTileBuf    = 0x481D4,
    UpdatePlayer          = 0x4C336,
    RunGame               = 0x4B2DA,
    VBlankISR             = 0x00422,
}

local FRAME_COUNTER = 0xFF0015
local GAME_MODE     = 0xFF0012
local ROOM_ID       = 0xFF00EB

local function u8(a) memory.usememorydomain("M68K BUS"); return memory.read_u8(a) end

-- Per-frame counters (reset each frame).
local hit = {}
for name, _ in pairs(SYM) do hit[name] = 0 end

-- Register memoryexecute on M68K BUS (only scope that works on Genplus-gx).
for name, addr in pairs(SYM) do
    local ok, err = pcall(function()
        event.onmemoryexecute(function() hit[name] = hit[name] + 1 end,
                              addr, "perf_" .. name, "M68K BUS")
    end)
    if not ok then print("hook fail " .. name .. ": " .. tostring(err)) end
end

-- Rolling 2-second stats.
local window_start = os.clock()
local window_emu = 0
local window_game_ticks = 0
local last_game_fc = u8(FRAME_COUNTER)
local window_hits = {}
for name, _ in pairs(SYM) do window_hits[name] = 0 end

local disp = {
    emu_fps = 0, game_fps = 0,
    hits = {},
}
for name, _ in pairs(SYM) do disp.hits[name] = 0 end

local last_console_dump = os.clock()

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
    local elapsed = now - window_start
    if elapsed >= 2.0 then
        disp.emu_fps  = window_emu / elapsed
        disp.game_fps = window_game_ticks / elapsed
        for name, count in pairs(window_hits) do
            disp.hits[name] = count / window_emu
        end
        window_start = now
        window_emu = 0
        window_game_ticks = 0
        for name, _ in pairs(window_hits) do window_hits[name] = 0 end
    end

    gui.text(10, 10, string.format("emu=%.1f game=%.1f mode=$%02X room=$%02X",
        disp.emu_fps, disp.game_fps, u8(GAME_MODE), u8(ROOM_ID)))
    gui.text(10, 20, string.format("ttf=%.0f chr_conv=%.0f chr_4x=%.0f",
        disp.hits.transfer_tilebuf_fast, disp.hits.chr_convert_upload, disp.hits.chr_upload_sprite_4x))
    gui.text(10, 30, string.format("compose=%.0f attr=%.0f xfrblk=%.0f",
        disp.hits.compose_bg_tile_word, disp.hits.attr_write_2x2, disp.hits.transfer_chr_block))
    gui.text(10, 40, string.format("UpdPly=%.0f RunGm=%.0f VBlk=%.0f TxCur=%.0f",
        disp.hits.UpdatePlayer, disp.hits.RunGame, disp.hits.VBlankISR, disp.hits.TransferCurTileBuf))

    if now - last_console_dump >= 2.0 then
        last_console_dump = now
        -- Sort by hit count and dump top callers.
        local pairs_list = {}
        for name, n in pairs(disp.hits) do pairs_list[#pairs_list+1] = {name=name, n=n} end
        table.sort(pairs_list, function(a, b) return a.n > b.n end)
        -- Console print.
        print(string.format("--- perf emu=%.1f game=%.1f mode=$%02X room=$%02X ---",
            disp.emu_fps, disp.game_fps, u8(GAME_MODE), u8(ROOM_ID)))
        for i = 1, #pairs_list do
            local e = pairs_list[i]
            print(string.format("  %-25s %8.1f calls/frame", e.name, e.n))
        end
        -- Append to log file so Claude can read it back.
        local fh = io.open("C:\\tmp\\perf_log.txt", "a")
        if fh then
            fh:write(string.format("[%s] emu=%.1f game=%.1f mode=$%02X room=$%02X\n",
                os.date("%H:%M:%S"), disp.emu_fps, disp.game_fps, u8(GAME_MODE), u8(ROOM_ID)))
            for i = 1, #pairs_list do
                local e = pairs_list[i]
                fh:write(string.format("  %-25s %8.1f calls/frame\n", e.name, e.n))
            end
            fh:write("\n")
            fh:close()
        end
    end
end
