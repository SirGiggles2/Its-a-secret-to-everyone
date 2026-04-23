#include "object_runtime.h"

/* Compatibility entry point preserved for asm shims and generated callers.
 * Real implementation lives in object_runtime.c.
 */
void c_move_object(unsigned short slot) {
    objrt_move_object(slot);
}
