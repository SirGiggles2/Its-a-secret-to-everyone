-- tools/debug/probes/lib/enter_gameplay.lua — shared Debug.md gameplay entry.
--
-- Usage (after dofile):  probe_enter_gameplay(flags)
--   flags: byte for $FF73FA (RoomRom/src/roomrom_debug_runtime.h
--   ROOMROM_DEBUG_PROBE_*): $01 heavy mirror, $02 enemy stress,
--   $04 boss trigger, $08 boot self-tests.
--
-- Title START opens File Select, so a single Start+chord no longer reaches
-- gameplay. This is the entry used by the accepted Ganon/save probes:
-- re-arm $FF73F8 'R','P',flags every frame (SGDK startup clears RAM),
-- pulse A+B+C 4 of every 30 frames, and wait for the state-mirror
-- signature 'W','P' at $FF7200 with its frame counter ($FF7203) past 5.
-- The mirror is only published by the gameplay tick. Raises on timeout.

local function lib_domain()
    for _, d in ipairs(memory.getmemorydomainlist()) do
        local n = tostring(d)
        if n == "M68K BUS" then return n, 0xFF0000 end
    end
    for _, d in ipairs(memory.getmemorydomainlist()) do
        local n = tostring(d)
        if n == "68K RAM" then return n, 0x000000 end
    end
    error("enter_gameplay: no M68K BUS / 68K RAM domain")
end

function probe_enter_gameplay(flags)
    local dom, base = lib_domain()
    local function w(a, v) memory.write_u8(base + a, v, dom) end
    local function r(a) return memory.read_u8(base + a, dom) end
    event.onframestart(function()
        pcall(w, 0x73F8, 0x52); pcall(w, 0x73F9, 0x50); pcall(w, 0x73FA, flags or 0)
    end, "probe_enter_gameplay_arm")
    for _ = 1, 30 do joypad.set({}, 1); emu.frameadvance() end
    for i = 1, 1500 do
        joypad.set((i % 30 < 4) and { A = true, B = true, C = true } or {}, 1)
        emu.frameadvance()
        if r(0x7200) == 0x57 and r(0x7201) == 0x50 and r(0x7203) > 5 then
            joypad.set({}, 1)
            for _ = 1, 60 do emu.frameadvance() end
            return i
        end
    end
    error("enter_gameplay: state mirror never published (chord not accepted)")
end
