-- probe_music_sram_overlap.lua — do the NES save-image cells and the
-- 68K music driver state occupy the same Genesis RAM?
--
-- Static claim under test (T-094):
--   audio_driver.asm: MUSIC_BASE = $FFE000 (m_song +$00, m_song_req +$01,
--   xgm_owns_chip +$2C), DMC_BASE = $FFE100.
--   platform_abi.h: nes_ram A4 base = $FF8000, NES_SRAM_BASE = $6000,
--   so save_serializer slot 0 (SAVE_BYTE(0..$2A)) = $FFE000..$FFE02A.
-- If both are true, Mode $0D save writes magic $5A/$A5 into m_song /
-- m_song_req.
--
-- Method: proven entry (arm $FF73F8 'R','P',1; pulse A+B+C; wait for
-- mirror 'W','P' at $FF7200) -> 90 idle frames -> snapshot $FFE000..$FFE03F
-- -> poke GameMode $0D -> snapshot every frame for 6 frames.
-- Verdict = byte evidence only. RULE V3: domains enumerated live.

local OUT = "C:\\tmp\\music_sram_overlap.txt"
os.execute('mkdir "C:\\tmp" 2>NUL')

local NAMES = {}
do
    local ok, list = pcall(memory.getmemorydomainlist)
    if ok and type(list) == "table" then
        for _, d in ipairs(list) do NAMES[tostring(d)] = true end
    end
end
local WORK, BUS_BASE
for _, cand in ipairs({ "M68K BUS", "68K RAM", "Main RAM" }) do
    if NAMES[cand] then
        WORK = cand
        BUS_BASE = (cand == "M68K BUS") and 0xFF0000 or 0x000000
        break
    end
end

local f = io.open(OUT, "w")
local function done(msg)
    if msg then f:write("VERDICT: UNVERIFIED — " .. msg .. "\n") end
    f:close()
    client.exit()
end
if WORK == nil then done("no usable 68K domain") return end
f:write("domain " .. WORK .. "\n")

local function rc(a) local ok, v = pcall(memory.read_u8, BUS_BASE + a, WORK); return ok and v or nil end
local function wc(a, v) pcall(memory.write_u8, BUS_BASE + a, v, WORK) end
local function arm() wc(0x73F8, 0x52); wc(0x73F9, 0x50); wc(0x73FA, 1) end

local function dump(label)
    f:write(label .. "\n")
    for row = 0, 3 do
        local base = 0xE000 + row * 16
        f:write(string.format("  $FF%04X:", base))
        for i = 0, 15 do
            local v = rc(base + i)
            f:write(v and string.format(" %02X", v) or " ??")
        end
        f:write("\n")
    end
    f:write(string.format("  m_song=$%02X m_song_req=$%02X xgm_owns_chip=$%02X GameMode(nes $12)=$%02X\n",
        rc(0xE000) or 0xFF, rc(0xE001) or 0xFF, rc(0xE02C) or 0xFF, rc(0x8012) or 0xFF))
end

for _ = 1, 30 do emu.frameadvance() end
local ready = -1
for i = 1, 1500 do
    arm()
    joypad.set((i % 30 < 4) and { A = true, B = true, C = true } or {}, 1)
    emu.frameadvance()
    if rc(0x7200) == 0x57 and rc(0x7201) == 0x50 and (rc(0x7203) or 0) > 5 then ready = i; break end
end
joypad.set({}, 1)
if ready < 0 then done("gameplay mirror never published") return end
for _ = 1, 90 do emu.frameadvance() end

dump("before save (gameplay +90f)")
wc(0x8012, 0x0D)
for k = 1, 6 do
    emu.frameadvance()
    dump(string.format("after GameMode=$0D poke +%df", k))
end
f:write("VERDICT: see bytes; overlap confirmed iff $FFE000/$FFE001 become $5A/$A5 after save\n")
done()
