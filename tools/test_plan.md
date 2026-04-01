# Overworld Map Debug Test Plan

## Current State
- **P3.93**: Reverted to P3.88 state (checksum $E120)
- **Status**: User says this is now worse
- **Problem**: My random changes broke the "king" status

## Systematic Test Plan

### Phase 1: Baseline Verification
1. **Test P3.93 in emulator**
   - Launch P3.93 
   - Document what works vs what doesn't
   - Compare to user's memory of P3.88 "king" status
   - Take screenshots of key rooms

2. **Key Rooms to Test**
   - Starting room 0x77 (should be unique ID 0x22, extracted 0x32)
   - Room 0x03 (correct - unique ID 0x03)
   - Room 0x5F (correct - unique ID 0x0B)
   - Room 0x47 (4 rooms above start - should be unique ID 0x03)

### Phase 2: Data Analysis
1. **Create visual comparison tool**
   - Side-by-side room comparison
   - Show extracted unique ID vs expected
   - Show actual rendered room vs expected

2. **Pattern Analysis**
   - Map out which rooms work vs don't
   - Look for patterns in the +16 offset group
   - Identify if there's a systematic fix

### Phase 3: Hypothesis Testing
1. **Test Simple Offset Fix**
   - Apply +16 offset compensation in Genesis code
   - Test if this fixes the 43.8% group

2. **Test Room-Specific Fix**
   - Understand why rooms 0x03 and 0x5F work
   - See if that pattern can be applied

3. **Test Data Structure Fix**
   - Investigate if RoomAttrsOW_D is at wrong offset
   - Test different extraction offsets systematically

### Phase 4: Decision Making
1. **If P3.93 works**: Accept current extraction as baseline
2. **If P3.93 fails**: Investigate what changed from P3.88
3. **If extraction is wrong**: Fix it systematically
4. **If extraction is right**: Fix Genesis interpretation

## Rules
- **NO MORE RANDOM CHANGES**
- **Test one hypothesis at a time**
- **Document everything**
- **Revert between tests**
- **Focus on functional correctness**

## Success Criteria
- Overworld map matches NES reference
- Starting room (0x77) is correct
- Room transitions work properly
- Build maintains stability
