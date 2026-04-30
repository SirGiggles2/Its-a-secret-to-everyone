-- probe_roomrom_link_visible.lua: verify S3 walk anim across 4 facings.

local OUT = os.getenv("CODEX_BIZHAWK_ROOT") or ""
if OUT == "" or OUT == nil then OUT = "." end
local OUTDIR = OUT .. "/RoomRom/out"

local function wait(n) for _=1,n do emu.frameadvance() end end
local function hold(btn, frames)
    for _=1,frames do joypad.set({[btn]=true},1); emu.frameadvance() end
    joypad.set({},1); wait(10)
end
local function press(btn)
    for _=1,3 do joypad.set({[btn]=true},1); emu.frameadvance() end
    joypad.set({},1); wait(60)
end

wait(180)
client.screenshot(OUTDIR .. "/probe_s3_00_idle_down.png")

hold("Right", 24); client.screenshot(OUTDIR .. "/probe_s3_01_walk_right_a.png")
hold("Right",  8); client.screenshot(OUTDIR .. "/probe_s3_02_walk_right_b.png")
wait(40);          client.screenshot(OUTDIR .. "/probe_s3_03_idle_right.png")

hold("Down",  24); client.screenshot(OUTDIR .. "/probe_s3_04_walk_down.png")
hold("Up",    24); client.screenshot(OUTDIR .. "/probe_s3_05_walk_up.png")
hold("Left",  24); client.screenshot(OUTDIR .. "/probe_s3_06_walk_left.png")
wait(40);          client.screenshot(OUTDIR .. "/probe_s3_07_idle_left.png")

press("X")
press("Right");    client.screenshot(OUTDIR .. "/probe_s3_08_teleport.png")

print("S3 probe done")
client.exit()
