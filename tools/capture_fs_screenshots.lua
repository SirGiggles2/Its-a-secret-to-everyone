-- capture_fs_screenshots.lua
-- Boots whichever ROM is loaded (NES or Genesis), navigates to File Select 1
-- and File Select 2 (REGISTER YOUR NAME), captures a screenshot at each.
--
-- Output files (saved to BizHawk working directory, then expected to be
-- hand-moved / copied by the driver):
--   fs1_<sys>.png   File Select 1, cursor on slot 0
--   fs2_<sys>.png   File Select 2, REGISTER YOUR NAME keyboard
-- where <sys> = nes or gen.

local sys = emu.getsystemid()
local TAG
if sys == "NES" then
    TAG = "nes"
elseif sys == "GEN" or sys == "GEN_MD" or sys == "SMD" then
    TAG = "gen"
else
    TAG = "unk"
end

print("capture_fs_screenshots: system="..tostring(sys).." tag="..TAG)

local frame = 0
local function adv(n)
    n = n or 1
    for i = 1, n do
        frame = frame + 1
        emu.frameadvance()
    end
end

local function press_only(btn, n)
    n = n or 1
    for i = 1, n do
        joypad.set({[btn]=true})
        frame = frame + 1
        emu.frameadvance()
    end
end

local function tap(btn)
    -- 1 frame pressed, then release for 4 frames so auto-repeat doesn't fire
    press_only(btn, 1)
    adv(4)
end

-- ------------------------------------------------------------------
-- 1. Boot to title screen and advance past title → File Select 1
-- ------------------------------------------------------------------
-- Advance ~200 frames until title is up, then Start-tap to go to FS1.
-- Both NES and the Genesis port use Start to leave title.
for f = 1, 240 do
    if f >= 90 and f <= 110 then
        joypad.set({["P1 Start"]=true})
    end
    frame = f
    emu.frameadvance()
end
adv(40)  -- settle

-- On Gen, CurSaveSlot may persist at $FF0016 from a previous run.
-- To force cursor to slot 0, press Up 4 times.
for i = 1, 4 do tap("P1 Up") end
adv(15)

-- Screenshot FS1
client.screenshot("fs1_"..TAG..".png")
print("  saved fs1_"..TAG..".png at frame "..frame)
adv(5)

-- ------------------------------------------------------------------
-- 2. Navigate down to slot 3 (REGISTER YOUR NAME), Start → FS2
-- ------------------------------------------------------------------
for i = 1, 3 do tap("P1 Down") end
adv(10)
tap("P1 Start")
adv(60)

-- Screenshot FS2 (REGISTER keyboard)
client.screenshot("fs2_"..TAG..".png")
print("  saved fs2_"..TAG..".png at frame "..frame)
adv(5)

client.exit()
