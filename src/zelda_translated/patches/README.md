# Hand-Edit Patches

This directory tracks deliberate hand-edits to generated code in `src/zelda_translated/`.

Generated files should not be hand-edited. When an exception is genuinely required, it must be documented here so it can survive a transpiler regeneration.

## Convention

For each hand-edit:

1. In the source file, add a comment immediately above the edit:
   ```asm
   ; HAND-EDIT: <reason> — auto-overwrite risk. See patches/<filename>.md
   ```

2. Add a `.md` file here named `z_XX_patch_NNN.md` where `XX` is the bank number and `NNN` is a sequential index.

## Patch file format

```markdown
# z_XX patch NNN — <short description>

**File:** src/zelda_translated/z_XX.asm
**Approx line:** NNN
**Reason:** Why the transpiler output is wrong or untranslatable.

## What the transpiler emits

(paste the generated output)

## What the patch changes it to

(paste the corrected code)

## Re-apply recipe

1. Run transpiler: `python tools/transpile_6502.py --all --no-stubs`
2. Locate the section (search for the label or comment anchor)
3. Apply the replacement above
4. Re-run build to confirm it assembles
```

## Current patches

*(none yet)*
