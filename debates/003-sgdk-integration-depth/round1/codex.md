1. **Boundary:** hard rule. `src/game/` + `src/frontend/` must not include `<genesis.h>` and must not poke VDP directly. They call `src/sgdk_adapter/`. Permissive SGDK-in-game looks cheap now, then spreads hardware policy everywhere.

2. **Version:** pin submodule SHA + audit doc. Source of truth becomes measured reality: `ef9292c03fe33a2f8af3a2589ab856a53dcef35c`, tag `v2.11`. Delete/override stale `v2.00` memory in plans. No rolling. No fork unless upstream breaks build or needed patch is rejected.

3. **Audio:** keep custom driver default, XGM2 fallback, but add migration trigger: move to XGM2 if custom path fails accuracy tests, exceeds CPU/audio budget, blocks tooling, or needs repeated hand-debugged fixes where XGM2 already solves equivalent flow. NES accuracy still wins; LLM comfort alone not enough.

4. **Phase 15:** hybrid. Default SGDK API. Hand-rolled VDP only for measured hot paths, boot/shim code, or correctness cases SGDK cannot express. Cost: raw VDP may save cycles/bytes, but burns reviewability, LLM accuracy, and late-night debug time.

5. **Phase 12 gate:** both. Grep `<genesis.h>` catches boundary leak. Grep raw VDP catches real hostile pattern. `src/frontend/intro/intro_title.c` is test case: even without `<genesis.h>`, `$C00000` write fails gate unless moved behind adapter or explicitly whitelisted.

6. **Phase 17:** yes. Build manifest records SGDK SHA/tag. Release/repro build refuses drift from pinned SHA unless pin file and audit note are intentionally updated.

7. **Copy-paste rules:**

`Master Plan / Execution Rules:`  
“SGDK is integrated through `src/sgdk_adapter/` only. Owned game and frontend code must not include `<genesis.h>` or write Genesis hardware registers directly. SGDK submodule SHA is pinned and recorded in build manifests; changing it requires updating the SGDK audit note and rerunning reproducibility checks.”

`Roadmap / Development Rules:`  
“Default to SGDK APIs for VDP/DMA/sprite/audio integration. Hand-written VDP/register code is exception-only: allowed in boot, shims, adapters, or documented measured hot paths. Promoted typed modules must pass adapter-boundary and raw-VDP scans.”

8. **Tools:**  
`tools/check_sgdk_boundary.py`: scan `src/game`, `src/frontend` for `<genesis.h>`; fail.  
`tools/check_raw_vdp.py`: scan for `$C00000`, `0xC00000`, `VDP_DATA`, `VDP_CTRL`; allowlist adapter/boot/shim.  
`tools/check_sgdk_pin.py`: compare submodule HEAD to `tools/sgdk_pin.json`; fail drift.

9. **Stance:** **YELLOW.** Current code is cleaner than plan. Plan lacks guardrails, pin, and gates.

10. **Top 5 changes:**  
1. Add SGDK pin manifest/checker.  
2. Add boundary + raw VDP CI gate.  
3. Move/fix `intro_title.c` VDP access.  
4. Add SGDK default / raw exception Phase 15 rule.  
5. Add audio migration measurements before Phase 10 locks.
