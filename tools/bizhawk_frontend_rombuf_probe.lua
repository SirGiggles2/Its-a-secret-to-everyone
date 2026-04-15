local env_root = os.getenv("CODEX_BIZHAWK_ROOT")
local ROOT = (env_root and env_root ~= "" and env_root:gsub("/", "\\")) or "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY"
local OUT_TXT = ROOT .. "\\builds\\reports\\frontend_rombuf_probe.txt"

local M68K = "M68K BUS"
local ADDR_TRANSFER_CUR_TILEBUF = 0x000189FE
local ADDR_TRANSFER_TILEBUF = 0x00018A56
local EXPECT_MODE1 = 0x00018A5C

local function bus_u8(addr)
    return memory.read_u8(addr, M68K)
end

local function ram_u8(bus_addr)
    return memory.read_u8(bus_addr - 0xFF0000, "68K RAM")
end

local function ram_w8(bus_addr, value)
    memory.write_u8(bus_addr - 0xFF0000, value, "68K RAM")
end

local lines = {}
local function log(s)
    lines[#lines + 1] = s
    print(s)
end

local hook_hits = 0
local cur_hits = 0
event.onmemoryexecute(function()
    cur_hits = cur_hits + 1
    log(string.format("cur_hit=%d mode=%02X sub=%02X last=%02X sel=%02X dyn0=%02X",
        cur_hits,
        ram_u8(0xFF0012),
        ram_u8(0xFF0013),
        ram_u8(0xFF083E),
        ram_u8(0xFF0014),
        ram_u8(0xFF0302)))
end, ADDR_TRANSFER_CUR_TILEBUF, "frontend_curbuf_probe", M68K)

event.onmemoryexecute(function()
    hook_hits = hook_hits + 1
    local a0 = emu.getregister("M68K A0") or 0
    local sel = ram_u8(0xFF0014)
    local bytes = {}
    for i = 0, 7 do
        bytes[#bytes + 1] = string.format("%02X", bus_u8(a0 + i))
    end
    log(string.format("hit=%d sel=%02X A0=%08X expected=%08X bytes=%s",
        hook_hits, sel, a0, EXPECT_MODE1, table.concat(bytes, " ")))
end, ADDR_TRANSFER_TILEBUF, "frontend_rombuf_probe", M68K)

for frame = 1, 220 do
    if frame >= 90 and frame <= 110 then
        joypad.set({["P1 Start"] = true})
    end
    emu.frameadvance()
    if frame == 121 then
        ram_w8(0xFF0014, 0x14)
        log("forced selector 14 at frame 121")
    end
end

local fh = assert(io.open(OUT_TXT, "w"))
fh:write(table.concat(lines, "\n") .. "\n")
fh:close()
client.exit()
