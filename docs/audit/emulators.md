<!-- docs/audit/emulators.md -->
# Emulator Versions (locked at S0)

| Field | Value |
|---|---|
| BizHawk version | 2.11.0 (Windows x64) |
| Distribution path | `<sibling>/VDP rebirth tools and asms/WHAT IF/BizHawk-2.11-win-x64/` |
| NES core (preferred) | `quickerNES` |
| Genesis core (preferred) | `Genplus-gx` (GPGX) |
| NES palette | `quickerNES` built-in palette (192-byte RGB triplet table embedded in `BizHawk-2.11-win-x64/config.ini` under the QuickNES `Palette` key) |

## Resolution

Values read from `BizHawk-2.11-win-x64/config.ini`:

- `PreferredCores.NES` = `"quickerNES"` (newer-generation QuickNES fork; not the older
  `QuickNES` / `NesHawk` cores). The `quickerNES` core is the active runtime when
  parity probes load NES content.
- `PreferredCores.SMS` / `GG` / `SG` = `"Genplus-gx"`. Genesis (`GEN` / `MD`) is
  not listed in `PreferredCores`; BizHawk defaults Genesis content to the GPGX
  core (`BizHawk.Emulation.Cores.Consoles.Sega.gpgx.GPGX`), confirmed by the
  `CoreSettings` entry in the same config.

## NES palette stability

`quickerNES`'s palette table is captured verbatim in BizHawk's `config.ini`. As
long as that file is the configuration BizHawk loads, the palette is
deterministic. Parity probes that capture NES PPU output must read pixels via
the BizHawk core API (which already applies this palette) rather than mapping
PPU palette indices through an external table — that keeps "what BizHawk shows"
and "what the probe captures" identical.

If parity tooling needs the palette out-of-band (e.g. for offline
NES-to-Genesis CRAM mapping in `data/palettes/nes_to_genesis.c`), extract the
192-byte triplet table from `config.ini`'s `Palette` key as the canonical
source. Record the byte-level SHA at S1.

## BizHawk launch convention

Probes invoke BizHawk via the `bizhawkScript` skill pattern (memory:
`skill_bizhawk_script.md`):

```bash
cmd.exe /c cd /d "<BizHawk path>" "&&" set CODEX_BIZHAWK_ROOT=<path> "&&" EmuHawk.exe --lua="<lua path>"
```

The `CODEX_BIZHAWK_ROOT` env var is required; without it `probe_root.lua`
fails with `source 'main'` (memory: `feedback_bizhawk_lua_env.md`).

## Open issues

None. Both cores and the palette are deterministic given the locked BizHawk
distribution and the unmodified `config.ini`. Parity probes verify against
this exact configuration.
