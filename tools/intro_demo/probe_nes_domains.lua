-- Probe BizHawk NES core memory domains; dump anything plausibly palette.
local OUT = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/tools/intro_demo/nes_dump/domain_probe.txt"

local function fc()
    local ok, v = pcall(function() return emu.framecount() end)
    return ok and v or 0
end

while fc() < 2200 do emu.frameadvance() end

local f = io.open(OUT, "w")
local domains = memory.getmemorydomainlist()
f:write("=== Memory domains ===\n")
for i, name in ipairs(domains) do
    local sz = -1
    local ok, v = pcall(function() return memory.getmemorydomainsize(name) end)
    if ok then sz = v end
    f:write(string.format("[%d] %-20s size=%d\n", i, name, sz))
end

f:write("\n=== First 32 bytes of each domain ===\n")
for _, name in ipairs(domains) do
    f:write("--- " .. name .. " ---\n")
    for off = 0, 31 do
        local ok, v = pcall(function() return memory.read_u8(off, name) end)
        f:write(string.format("%02X ", ok and (v or 0) or 0))
    end
    f:write("\n")
end

-- Likely palette domain is "PALRAM", "Palette RAM", "PPU", or "CIRAM/Palette"
-- Try reading 32 bytes from any domain whose name hints at palette.
f:write("\n=== Palette-y domains last 32 bytes ===\n")
for _, name in ipairs(domains) do
    if name:lower():find("pal") or name:lower():find("ciram") then
        f:write("--- " .. name .. " ---\n")
        local sz = memory.getmemorydomainsize(name)
        local start = math.max(0, sz - 32)
        for off = start, sz - 1 do
            local ok, v = pcall(function() return memory.read_u8(off, name) end)
            f:write(string.format("%02X ", ok and (v or 0) or 0))
        end
        f:write("\n")
    end
end

f:close()
print("wrote " .. OUT)
