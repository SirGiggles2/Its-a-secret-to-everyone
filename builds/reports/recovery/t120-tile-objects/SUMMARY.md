# T-120 Link blocked by tile objects / people

NES source: Z_07.asm Walker_Move (Link: CheckTileObjectsBlocking, then
CheckPersonBlocking when slot 1 is $36 or $4B-$52), Z_05.asm CheckSubroom
@InCave (CheckPersonBlocking in caves), Z_01.asm CheckTileObjectsBlocking /
CheckPersonBlocking. Drained C: progress_check_tile_objects_blocking,
uw_person_check_person_blocking (both existed, never called by Genesis
Link movement). Genesis: RoomRom/src/main.c NES movement path.

- t120_rock_block (push the $79 rock up, enemies cleared by stage): Link
  X/Y/Grid/InputDir and rock slot 11 equal to NES every frame f518-650,
  including the stop-and-go while Link follows the moving rock.
- t120_cave_person (walk into the $77 sword cave, hold up): Link stops at
  Y $8D under the old man like NES (Genesis walked up to $6A before).
  GameMode differs ($0B vs $05: T-096); Genesis enters the cave 23 frames
  earlier with 7 extra lag frames during the load (T-125).
- Suite: no regressions (Link cells, slots, lag within +-1).
