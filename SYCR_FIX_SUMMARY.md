# SYCR Reactor Display Fix

**Date:** October 19, 2025  
**Issue:** Dashboard showing 0 SYCR reactors  
**Status:** ✅ Fixed

## Problem

The dashboard was displaying **0 SYCR reactors** even though SYCR is listed as one of the reactor types in the UI.

## Root Cause

The production database (`mesprod`) does not have a tool family named "SYCR". The query was looking for:
```sql
WHERE tf.family_name IN ('AMT', 'ADE', 'AIX', 'VIS', 'SYCR')
```

But "SYCR" doesn't exist in `mes.gt_tool_family`.

## Investigation

Searched for similar family names and found:
- **SYS** family exists in the database
- **SYS101** tool exists (Silane Pyrolysis CVD Reactor)
- SYS is the production database equivalent of SYCR

## Solution

### 1. Updated WHERE Clause
Changed from:
```sql
WHERE tf.family_name IN ('AMT', 'ADE', 'AIX', 'VIS', 'SYCR')
```

To:
```sql
WHERE tf.family_name IN ('AMT', 'ADE', 'AIX', 'VIS', 'SYS')
```

### 2. Added SYS to SYCR Mapping
Updated CASE statement in 3 locations:
```sql
CASE 
    WHEN tf.family_name = 'AMT' THEN 'AMT'
    WHEN tf.family_name = 'ADE' THEN 'ADE'
    WHEN tf.family_name = 'AIX' THEN 'AIX'
    WHEN tf.family_name = 'VIS' THEN 'VIS'
    WHEN tf.family_name = 'SYS' THEN 'SYCR'  -- NEW MAPPING
    ELSE 'SYCR'
END as reactor_type
```

### 3. Affected Endpoints
Updated 3 API endpoints:
1. `/api/reactors` - GET all reactors
2. `/api/reactors/<id>` - GET single reactor
3. `/api/reactor-assignment` - Reactor assignment analysis

## Results

### Before Fix
- **Total Reactors:** 68
- **SYCR Count:** 0
- **Dashboard Display:** "0 reactors"

### After Fix
- **Total Reactors:** 69
- **SYCR Count:** 1
- **SYCR Reactor:** SYS101
- **Dashboard Display:** "1 reactor"

## Reactor Breakdown

| Type | Count | Change |
|------|-------|--------|
| ADE  | 7     | No change |
| AIX  | 7     | No change |
| AMT  | 46    | No change |
| **SYCR** | **1** | **+1** (was 0) |
| VIS  | 8     | No change |
| **Total** | **69** | **+1** (was 68) |

## Technical Details

### SYCR Definition
**SYCR** = Silane Pyrolysis CVD Reactor
- Used for chemical vapor deposition processes
- Utilizes silane pyrolysis for thin film deposition
- Production database family: **SYS**

### SYS101 Reactor
- **Tool Name:** SYS101
- **Family:** SYS (mapped to SYCR)
- **Type:** SYCR (Silane Pyrolysis CVD)
- **Location:** Clean Room Production
- **Pocket Count:** 4 (default)
- **Max Temperature:** 1100.00°C
- **Max Pressure:** 2.00 atm

## Files Modified

1. `/home/dbadmin/app.py`
   - Line 326: Added SYS → SYCR mapping (get_reactors)
   - Line 356: Changed WHERE clause to include 'SYS'
   - Line 393: Added SYS → SYCR mapping (get_reactor by id)
   - Line 666: Added SYS → SYCR mapping (reactor_assignment)

## Validation

```bash
# Test API endpoint
curl -s http://localhost:5000/api/reactors | grep -c "SYCR"
# Result: 1 (was 0)

# Verify reactor details
curl -s http://localhost:5000/api/reactors | jq '.reactors[] | select(.reactor_type=="SYCR")'
# Result: Shows SYS101 reactor
```

## Dashboard Impact

The dashboard home page now correctly displays:
- **SYCR Section:** "1 reactor" (was "0 reactors")
- **Total Reactor Count:** 69 (was 68)
- **Reactor List:** Includes SYS101 in SYCR category

## Summary

✅ **Fixed:** SYCR reactor count now shows 1 instead of 0  
✅ **Mapped:** SYS family → SYCR reactor type  
✅ **Added:** SYS101 reactor to production display  
✅ **Total:** 69 reactors now displayed (was 68)

The dashboard now accurately reflects all production reactors including the SYCR type.
