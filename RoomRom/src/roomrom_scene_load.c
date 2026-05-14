#include <genesis.h>
#include "roomrom_scene_load.h"
#include "roomrom_sprites.h"
#include "atlas/level_chr_swap.h"
/* roomrom_bg_palette.h included for future per-room BG palette loads;
 * not called at scene-load granularity yet (BG palette is per-room). */
#include "../../src/game/world/bg_palette.h"  /* Phase 12.2 promoted */

void roomrom_scene_load(roomrom_scene_id_t scene_id, unsigned char variant)
{
    /* Variant flows through to each category's redux flag. */
    roomrom_sprites_set_redux(variant);

    /* PR-4a: enqueue scene-bank DMA. Empty contracts (PR-4a default)
     * collapse REQUESTED → READY in one tick. PR-4b populates content. */
    level_chr_swap_request(scene_id);

    switch (scene_id) {
    case ROOMROM_SCENE_OVERWORLD:
    case ROOMROM_SCENE_UW_L1:
    case ROOMROM_SCENE_UW_L2:
    case ROOMROM_SCENE_UW_L3:
    case ROOMROM_SCENE_UW_L4:
    case ROOMROM_SCENE_UW_L5:
    case ROOMROM_SCENE_UW_L6:
    case ROOMROM_SCENE_UW_L7:
    case ROOMROM_SCENE_UW_L8:
    case ROOMROM_SCENE_UW_L9:
        /* Active gameplay scenes: re-upload variant-dependent items
         * atlas (4x sub-pal). Persistent CHR (common + Link walk/attack)
         * stays at boot upload — re-uploading clobbers SCENE_OBJ region
         * (1069..1204) populated by level_chr_swap. PR-4 fix. */
        roomrom_sprites_upload_items_chr();
        break;

    case ROOMROM_SCENE_BOOT:
    case ROOMROM_SCENE_TITLE:
    case ROOMROM_SCENE_FILESELECT:
        /* Aspirational scenes: not yet implemented in RoomRom.
         * RoomRom boots directly into a UW room without title or FS.
         * No-op until those scenes get hand-written renderers. */
        break;

    default:
        break;
    }
}
