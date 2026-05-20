-- Skip title, enter gameplay, screenshot for enemy visibility check.
local OUT = (os.getenv("CODEX_BIZHAWK_ROOT") or "C:\\tmp") .. "/enemies_check"
os.execute('mkdir "' .. OUT:gsub("/","\\") .. '" 2>nul')

local function idle(n) for _=1,n do emu.frameadvance() end end

-- Boot title
idle(180)
-- ABC chord to enter debug gameplay (per memory project_debug_enter_stress_harness)
joypad.set({A=true, B=true, C=true}, 1)
for _=1,8 do emu.frameadvance() end
joypad.set({}, 1)
idle(120)  -- settle, enemies spawn

client.screenshot(OUT .. "/enemies_post_abc.png")

-- Also try Start-only (normal title -> gameplay path)
idle(60)
client.screenshot(OUT .. "/enemies_step2.png")

-- Wait more frames + screenshot to see motion
idle(120)
client.screenshot(OUT .. "/enemies_step3.png")

print("enemies probe done")
client.exit()
