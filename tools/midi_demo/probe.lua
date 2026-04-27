-- midi_demo/probe.lua — boot ROM, screenshot, dump CRAM/VRAM/SAT.

local out_dir = os.getenv("MIDI_DEMO_OUT") or "."
local function fpath(name) return out_dir .. "/" .. name end

for i = 1, 60 do emu.frameadvance() end
client.screenshot(fpath("probe_1s.png"))

for i = 1, 540 do emu.frameadvance() end
client.screenshot(fpath("probe_10s.png"))

local f = io.open(fpath("probe.txt"), "w")
f:write(string.format("frame=%d\n", emu.framecount()))

f:write("\n-- CRAM (palette 0, 16 entries x 2 bytes BE) --\n")
for i = 0, 31, 2 do
    local hi = memory.read_u8(i, "CRAM")
    local lo = memory.read_u8(i + 1, "CRAM")
    f:write(string.format("  CRAM $%02X = $%02X%02X\n", i, hi, lo))
end

f:write("\n-- VRAM tile 1 ($0020-$003F) — Link top-left tile --\n")
for i = 0x20, 0x3F do
    f:write(string.format(" %02X", memory.read_u8(i, "VRAM")))
    if (i % 8) == 7 then f:write("\n") end
end

f:write("\n-- VRAM SAT entry 0 ($F800-$F807) --\n")
for i = 0xF800, 0xF807 do
    f:write(string.format(" %02X", memory.read_u8(i, "VRAM")))
end
f:write("\n")

f:write("\n-- Player state via M68K BUS at $FFE000..$FFE013 --\n")
for i = 0xFFE000, 0xFFE013 do
    f:write(string.format(" %02X", memory.read_u8(i, "M68K BUS")))
end
f:write("\n")

-- Audio sample probe: pull recent sound buffer; report peak amplitude.
-- BizHawk: client.getsamples() is GPGX-specific in some versions; use pcall.
local ok, samples = pcall(function() return sound and sound.get and sound.get() end)
if ok and samples then
    local peak = 0
    for _, s in ipairs(samples) do
        local a = s; if a < 0 then a = -a end
        if a > peak then peak = a end
    end
    f:write(string.format("audio_peak=%d (samples=%d)\n", peak, #samples))
else
    -- Fall back: scan first 4 ch of YM2612 via memdomain (not exposed) —
    -- instead, just print "no sound API"
    f:write("audio: no sample API available\n")
end

f:close()

if client.exit then client.exit() else client.pause() end
