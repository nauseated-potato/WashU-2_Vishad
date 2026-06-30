# Week 6 · Trace Worksheet — Deliverable 1

**Instructions:** Print this page landscape on A4. Fill in every cell.
Use hex for all register values. Write register values **before** the
cycle's update. Circle each row where ACC changes.

**Program to trace:**
```
0x000: CLOAD 10    (0x200A)    ACC ← 10
0x001: DSTORE 0x100 (0x4100)  mem[0x100] ← ACC
0x002: DLOAD  0x100 (0x3100)  ACC ← mem[0x100]
0x003: ADD    0x101 (0x7101)  ACC ← ACC + mem[0x101]
0x004: HALT        (0x0000)   stop
```
**Data:** `mem[0x100] = 0x0000`, `mem[0x101] = 0x0005`

---

| Cycle | State | PC | MAR | MBR | IR | ACC | Bus driver | Active loads/enables | Notes |
|---|---|---|---|---|---|---|---|---|---|
| 1 | | | | | | | | | |
| 2 | | | | | | | | | |
| 3 | | | | | | | | | |
| 4 | | | | | | | | | |
| 5 | | | | | | | | | |
| 6 | | | | | | | | | |
| ← | ← CLOAD done (cycle 4) | | | | | | | | |
| 7 | | | | | | | | | |
| 8 | | | | | | | | | |
| 9 | | | | | | | | | |
| 10 | | | | | | | | | |
| 11 | | | | | | | | | |
| ← | ← DSTORE done (cycle 10) | | | | | | | | |
| 12 | | | | | | | | | |
| 13 | | | | | | | | | |
| 14 | | | | | | | | | |
| 15 | | | | | | | | | |
| 16 | | | | | | | | | |
| 17 | | | | | | | | | |
| ← | ← DLOAD done (cycle 16) | | | | | | | | |
| 18 | | | | | | | | | |
| 19 | | | | | | | | | |
| 20 | | | | | | | | | |
| 21 | | | | | | | | | |
| 22 | | | | | | | | | |
| 23 | | | | | | | | | |
| ← | ← ADD done (cycle 22) | | | | | | | | |
| 24 | | | | | | | | | |
| 25 | | | | | | | | | |
| 26 | | | | | | | | | |
| ← | ← HALT done (cycle 26) — done='1' | | | | | | | | |

---

**Final values (fill in after completing the trace):**

| Register/Memory | Expected | Your answer | Match? |
|---|---|---|---|
| `ACC` | `0x000F` (15) | | |
| `PC` | `0x005` | | |
| `mem[0x100]` | `0x000A` (10) | | |
| Total cycles | count yours | | |

---

**State name reference** (use these exact names):
`resetState` · `fetch1` · `fetch2` · `fetch3` ·
`halt1` · `neg1` · `neg2` · `cload1` ·
`direct1` · `direct2` · `load1` · `add1` · `and1` · `store1` ·
`branch1` · `indirect1` · `indirect2` · `iload1` · `istore1` ·
`brind1` · `brind2`

**Bus driver reference:**
`bus_pc` · `bus_mbr` · `bus_acc` · `bus_mem` · `bus_ir_lower` · `bus_ir_se` · `bus_alu`

**Load/enable reference:**
`mar_ld` · `mbr_ld` · `ir_ld` · `acc_ld` · `pc_ld` · `pc_inc` · `mem_we`
