-- Intro handoff state capture probe.
-- Boots ROM, pulses Start repeatedly from frame 90-260 (matching T29 probe
-- cadence) to bypass story-scroll crash, polls MODE_VALUE / SUBMODE_VALUE
-- each frame, and dumps 10 named RAM addresses when the frontend enters
-- file-select (MODE_VALUE==0x01, SUBMODE_VALUE==0x00).
-- Optional INTRO_CHR_DUMP / INTRO_CRAM_DUMP envs add VRAM + CRAM dumps.
--
-- Evidence from frontend_baseline_trace.txt:
--   f100  mode=$00 sub=$02  (title -> story-scroll transition)
--   f120  mode=$01 sub=$00  (file-select entered after Start press)
-- So Start must arrive ~f90-f110 to be effective.

local out_json  = os.getenv("INTRO_STATE_DUMP")  or error("INTRO_STATE_DUMP env required")
local addrs_env = os.getenv("INTRO_STATE_ADDRS") or error("INTRO_STATE_ADDRS env required")
local out_chr   = os.getenv("INTRO_CHR_DUMP")
local out_cram  = os.getenv("INTRO_CRAM_DUMP")

-- Debug: log env vars to JSON for verification
if out_chr or out_cram then
  local dbg_fh = io.open(out_json:gsub("%.json$", "-debug.json"), "w")
  if dbg_fh then
    dbg_fh:write('{"out_chr":"' .. tostring(out_chr) .. '","out_cram":"' .. tostring(out_cram) .. '"}\n')
    dbg_fh:close()
  end
end

-- parse "name1:addr1,name2:addr2,..."
local addrs = {}
for pair in string.gmatch(addrs_env, "([^,]+)") do
  local name, hex = string.match(pair, "([^:]+):([0-9A-Fa-f]+)")
  table.insert(addrs, {name = name, addr = tonumber(hex, 16)})
end

if #addrs == 0 then
  error("no addresses parsed from INTRO_STATE_ADDRS env var")
end

-- ram_u8: tries "68K RAM" domain (offset 0-0xFFFF) then falls back to
-- "M68K BUS" at 0xFF0000+offset.  Mirrors the T29 probe's try_read pattern.
local function ram_u8(ofs)
  local ok, v = pcall(function()
    return memory.read_u8(ofs, "68K RAM")
  end)
  if ok then return v end
  local ok2, v2 = pcall(function()
    return memory.read_u8(0xFF0000 + ofs, "M68K BUS")
  end)
  if ok2 then return v2 end
  return 0
end

-- Start pulse cadence from T29: hold 2 frames, release 4 frames, repeat.
-- Active window: frames 90-260.
local START_FROM    = 90
local START_TO      = 260
local START_HOLD    = 2
local START_RELEASE = 4

local hold_left    = 0
local release_left = 0

local function safe_set(pad)
  local ok = pcall(function() joypad.set(pad or {}, 1) end)
  if not ok then
    pcall(function() joypad.set(pad or {}) end)
  end
end

local captured = false
local max_frames = 1500   -- well past file-select (confirmed at ~f120)

while emu.framecount() < max_frames and not captured do
  local f = emu.framecount()

  -- manage Start pulse within window
  if f >= START_FROM and f <= START_TO then
    if hold_left == 0 and release_left == 0 then
      hold_left    = START_HOLD
      release_left = START_RELEASE
    end
  end

  local pad = {}
  if hold_left > 0 then
    pad = {Start = true, ["P1 Start"] = true}
    hold_left = hold_left - 1
  elseif release_left > 0 then
    release_left = release_left - 1
  end
  safe_set(pad)

  emu.frameadvance()

  local mode    = ram_u8(0x0012)
  local submode = ram_u8(0x0013)

  -- Capture at first entry into file-select (mode $01, sub $00).
  -- Also accept mode $0E/$0F in case firmware skips $01 on this build.
  local is_fileselect = (mode == 0x01 and submode == 0x00)
                     or (mode == 0x0E and submode == 0x00)
  if is_fileselect then
    local fh, err = io.open(out_json, "w")
    if not fh then error("cannot open output: " .. tostring(err)) end
    fh:write("{\n")
    fh:write(string.format('  "capture_frame": %d,\n', f))
    fh:write(string.format('  "mode_at_capture": "0x%02X",\n', mode))
    fh:write(string.format('  "submode_at_capture": "0x%02X",\n', submode))
    for i, a in ipairs(addrs) do
      local v = ram_u8(a.addr)
      local comma = (i < #addrs) and "," or ""
      fh:write(string.format('  "%s": { "addr": "0x%04X", "value": "0x%02X" }%s\n',
                              a.name, a.addr, v, comma))
    end
    fh:write("}\n")
    fh:close()

    if out_chr then
      local ok, err = pcall(function()
        local bf, ioerr = io.open(out_chr, "wb")
        if not bf then error("cannot open VRAM output: " .. tostring(ioerr)) end

        -- Read VRAM in 256-byte chunks to avoid slow byte-by-byte I/O
        local bytes_written = 0
        local function write_chunk(start_addr, chunk_size)
          local chunk = {}
          memory.usememorydomain("VRAM")
          for i = start_addr, start_addr + chunk_size - 1 do
            local b = memory.read_u8(i)
            chunk[#chunk + 1] = string.char(b)
          end
          bf:write(table.concat(chunk))
          bytes_written = bytes_written + chunk_size
        end

        -- Write VRAM in 1KB chunks
        for chunk_start = 0, 0x3FFF, 1024 do
          local remaining = 0x4000 - chunk_start
          local to_read = math.min(1024, remaining)
          write_chunk(chunk_start, to_read)
        end

        bf:close()
      end)
      if not ok then
        -- Silently continue on VRAM read error
      end
    end
    if out_cram then
      local ok, err = pcall(function()
        local bf, ioerr = io.open(out_cram, "wb")
        if not bf then error("cannot open CRAM output: " .. tostring(ioerr)) end

        memory.usememorydomain("CRAM")
        local chunk = {}
        for i = 0, 127 do
          local b = memory.read_u8(i)
          chunk[#chunk + 1] = string.char(b)
        end
        bf:write(table.concat(chunk))
        bf:close()
      end)
      if not ok then
        -- Silently continue on CRAM read error
      end
    end
    captured = true
  end
end

if not captured then
  local fh, err = io.open(out_json, "w")
  if not fh then error("cannot open error output: " .. tostring(err)) end
  fh:write('{ "error": "file-select never reached", "max_frames": ' .. max_frames .. ' }\n')
  fh:close()
end

client.exit()
