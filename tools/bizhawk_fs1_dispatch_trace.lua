-- bizhawk_fs1_dispatch_trace.lua
-- Phase 9.2 — definitive trace of the Mode 1 init dispatch chain.
--
-- Goal: answer "does InitMode1_Sub2 actually run, write $0014=$14, and have
--       that selector survive until the next NMI's TransferCurTileBuf?"
--
-- We hook EXECUTE on each landmark and WRITE on $FF0014 / $FF0302, logging
-- the call site PC plus mode/sub/sel/dyn0 at every event.
--
-- Addresses pulled from builds/whatif.lst (Zelda27.66 build):
--   _mode_transition_check entry  $0000071A
--   _mode_transition_check clr14  $00000746
--   InitMode1_Sub1 entry          $0000A586
--   InitMode1_Sub2 entry          $0000A61C
--   InitMode1_Sub2 sel write      $0000A61E
--   InitMode1_FillAndTransferSlotTiles entry $0000A628
--   TransferCurTileBuf entry      $000189FE
--   TransferTileBuf  entry        $00018A56
--   Mode1TileTransferBuf data     $00018A5C

local env_root = os.getenv("CODEX_BIZHAWK_ROOT")
local ROOT = (env_root and env_root ~= "" and env_root:gsub("/", "\\"))
    or "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\.claude\\worktrees\\nifty-chandrasekhar"
local OUT_TXT = ROOT .. "\\builds\\reports\\fs1_dispatch_trace.txt"

local M68K = "M68K BUS"
local RAM68K = "68K RAM"

local A_MTC                = 0x0000071A
local A_MTC_CLR14          = 0x00000746
local A_INIT_SUB1          = 0x0000A586
local A_INIT_SUB2          = 0x0000A61C
local A_INIT_SUB2_SEL      = 0x0000A61E
local A_INIT_FILL          = 0x0000A628
local A_TRANSFER_CUR       = 0x000189FE
local A_TRANSFER_BUF       = 0x00018A56
local A_MODE1_TILE_BUF     = 0x00018A5C

local lines = {}
local function log(s)
    lines[#lines + 1] = s
end

local function bus_u8(addr)
    return memory.read_u8(addr, M68K)
end
local function ram_u8(bus_addr)
    return memory.read_u8(bus_addr - 0xFF0000, RAM68K)
end

local function snap()
    return string.format("mode=%02X sub=%02X last=%02X sel=%02X dyn0=%02X",
        ram_u8(0xFF0012),
        ram_u8(0xFF0013),
        ram_u8(0xFF083E),
        ram_u8(0xFF0014),
        ram_u8(0xFF0302))
end

local frame_no = 0
local hits = {mtc=0, mtc_clr=0, sub1=0, sub2=0, sub2_sel=0, fill=0, cur=0, buf=0}

event.onmemoryexecute(function()
    hits.mtc = hits.mtc + 1
    if hits.mtc <= 80 then
        log(string.format("f=%4d MTC#%d %s", frame_no, hits.mtc, snap()))
    end
end, A_MTC, "p9_mtc", M68K)

event.onmemoryexecute(function()
    hits.mtc_clr = hits.mtc_clr + 1
    log(string.format("f=%4d MTC_CLR14#%d %s (about to clr $0014)",
        frame_no, hits.mtc_clr, snap()))
end, A_MTC_CLR14, "p9_mtc_clr", M68K)

event.onmemoryexecute(function()
    hits.sub1 = hits.sub1 + 1
    log(string.format("f=%4d SUB1#%d %s", frame_no, hits.sub1, snap()))
end, A_INIT_SUB1, "p9_sub1", M68K)

event.onmemoryexecute(function()
    hits.sub2 = hits.sub2 + 1
    log(string.format("f=%4d SUB2#%d %s", frame_no, hits.sub2, snap()))
end, A_INIT_SUB2, "p9_sub2", M68K)

event.onmemoryexecute(function()
    hits.sub2_sel = hits.sub2_sel + 1
    log(string.format("f=%4d SUB2_SEL#%d %s D0=%08X (about to MOVE.B D0,$14)",
        frame_no, hits.sub2_sel, snap(), emu.getregister("M68K D0") or 0))
end, A_INIT_SUB2_SEL, "p9_sub2_sel", M68K)

event.onmemoryexecute(function()
    hits.fill = hits.fill + 1
    log(string.format("f=%4d FILL#%d %s", frame_no, hits.fill, snap()))
end, A_INIT_FILL, "p9_fill", M68K)

event.onmemoryexecute(function()
    hits.cur = hits.cur + 1
    if hits.cur <= 80 then
        log(string.format("f=%4d TCB#%d %s", frame_no, hits.cur, snap()))
    end
end, A_TRANSFER_CUR, "p9_cur", M68K)

event.onmemoryexecute(function()
    hits.buf = hits.buf + 1
    local a0 = emu.getregister("M68K A0") or 0
    local b = {}
    for i = 0, 7 do b[#b+1] = string.format("%02X", bus_u8(a0 + i)) end
    log(string.format("f=%4d TBUF#%d %s A0=%08X expect=%08X bytes=%s",
        frame_no, hits.buf, snap(), a0, A_MODE1_TILE_BUF, table.concat(b, " ")))
end, A_TRANSFER_BUF, "p9_buf", M68K)

-- Watch every write to $FF0014 (selector) — log who wrote it.
local sel_writes = 0
event.onmemorywrite(function(addr, value)
    sel_writes = sel_writes + 1
    if sel_writes > 200 then return end
    local pc = emu.getregister("M68K PC") or 0
    log(string.format("f=%4d SEL_W#%d val=%02X PC=%08X %s",
        frame_no, sel_writes, value or 0, pc, snap()))
end, 0x14, "p9_sel_w", RAM68K)

-- Watch writes to $FF0302 (DynTileBuf[0])
local dyn_writes = 0
event.onmemorywrite(function(addr, value)
    dyn_writes = dyn_writes + 1
    if dyn_writes > 200 then return end
    local pc = emu.getregister("M68K PC") or 0
    log(string.format("f=%4d DYN_W#%d val=%02X PC=%08X %s",
        frame_no, dyn_writes, value or 0, pc, snap()))
end, 0x302, "p9_dyn_w", RAM68K)

log("=== fs1_dispatch_trace start ===")
for i = 1, 260 do
    frame_no = i
    if i >= 90 and i <= 110 then
        joypad.set({["P1 Start"] = true})
    end
    emu.frameadvance()
end
log(string.format("=== fs1_dispatch_trace end frame=%d ===", frame_no))
log(string.format("totals mtc=%d mtc_clr=%d sub1=%d sub2=%d sub2_sel=%d fill=%d cur=%d buf=%d sel_w=%d dyn_w=%d",
    hits.mtc, hits.mtc_clr, hits.sub1, hits.sub2, hits.sub2_sel, hits.fill, hits.cur, hits.buf, sel_writes, dyn_writes))
log(string.format("final %s", snap()))

local fh = assert(io.open(OUT_TXT, "w"))
fh:write(table.concat(lines, "\n") .. "\n")
fh:close()
client.exit()
