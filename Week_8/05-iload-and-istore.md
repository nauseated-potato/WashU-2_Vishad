# Week 8 · Module 5 — ILOAD and ISTORE

ILOAD and ISTORE reuse the shared `direct1`/`direct2` states from Week 7
(`direct2`'s dispatch already routes `OP_ILOAD` and `OP_ISTORE` to
`indirect1` — see Week 7 Module 6 Stage C, and confirm it in your own
file before continuing). This module adds `indirect1`, `indirect2`,
`iload1`, and `istore1`.

---

## 1. Two levels of indirection

BRIND (Module 4) read memory once to find its target. ILOAD/ISTORE read
memory **twice**: the instruction's address field points to a cell that
holds a *pointer*, and that pointer is the address of the actual data.

```
ILOAD  addr:  ACC        ← mem[ mem[addr] ]
ISTORE addr:  mem[ mem[addr] ] ← ACC
```

Concretely: `addr` is a fixed "slot" whose contents can change at
runtime to point anywhere in memory — this is how the WashU-2 supports
data-dependent addressing (arrays, pointers) despite having no index
registers.

---

## 2. Register transfer sequences

**ILOAD addr:**
```
direct1:    MAR ← IR[11:0]     (MAR = slot address)
direct2:    MBR ← mem[MAR]     (MBR = pointer value = real target address)
indirect1:  MAR ← MBR          (MAR = real target address)
indirect2:  MBR ← mem[MAR]     (MBR = the actual data)
iload1:     ACC ← MBR
```

**ISTORE addr:**
```
direct1:    MAR ← IR[11:0]     (MAR = slot address)
direct2:    MBR ← mem[MAR]     (MBR = pointer value = real target address)
indirect1:  MAR ← MBR          (MAR = real target address)
indirect2:  MBR ← mem[MAR]     (wasted read — see §4)
istore1:    mem[MAR] ← ACC
```

Both instructions follow the *identical* four-state path up through
`indirect2` — they only diverge in the final state, exactly like
DLOAD/DSTORE diverging after `direct2` in Week 7.

---

## 3. FSM additions

Remove `indirect1 | indirect2 | iload1 | istore1` from the Week 7
placeholder group and add:

```vhdl
            -- ====================================================
            -- indirect1: MAR ← MBR
            -- MBR (from direct2) holds the pointer value read out of
            -- the instruction's address slot. That pointer becomes
            -- the new memory address.
            -- Shared by ILOAD and ISTORE.
            -- ====================================================
            when indirect1 =>
                bus_mbr    <= '1';
                mar_ld     <= '1';
                next_state <= indirect2;

            -- ====================================================
            -- indirect2: MBR ← mem[MAR]
            -- Read the cell the pointer refers to. For ILOAD this is
            -- the data itself; for ISTORE this read is unused but
            -- harmless (see §4).
            -- ====================================================
            when indirect2 =>
                bus_mem    <= '1';
                mbr_ld     <= '1';
                case ir_opcode is
                    when OP_ILOAD  => next_state <= iload1;
                    when OP_ISTORE => next_state <= istore1;
                    when others    => next_state <= fetch1;   -- safety
                end case;

            -- ====================================================
            -- iload1: ACC ← MBR
            -- ====================================================
            when iload1 =>
                bus_mbr    <= '1';
                acc_ld     <= '1';
                next_state <= fetch1;

            -- ====================================================
            -- istore1: mem[MAR] ← ACC
            -- MAR still holds the real target address, latched back
            -- in indirect1 — the indirect2 read never touched MAR.
            -- Same bus_acc / mem_we pattern as Week 7's store1.
            -- ====================================================
            when istore1 =>
                bus_acc    <= '1';
                mbr_ld     <= '1';
                mem_we     <= '1';
                next_state <= fetch1;
```

---

## 4. Why `indirect2`'s read is harmless for ISTORE

ISTORE never uses the value `indirect2` loads into `MBR` — it overwrites
`MBR` again in `istore1` via `mbr_ld='1'` as a side-effect of driving
`bus_acc` onto the bus. The only register ISTORE actually depends on
from `indirect2` is `MAR`, and `indirect2` never touches `MAR` — it only
reads `mem[MAR]` into `MBR`. This is the same reasoning Week 7 Module 6
gives for `direct2`'s "wasted" read before `DSTORE`'s `store1`.

---

## 5. Test programs

`ILOAD = 0101 = 0x5`, `ISTORE = 0110 = 0x6`. Address `0x020` is the
pointer slot; it holds `0x030`, the real data address.

### ILOAD — expect `acc = 0x002A` (42)

```vhdl
0  => x"5020",   -- ILOAD 0x020    acc ← mem[mem[0x020]]
1  => x"0000",   -- HALT
32 => x"0030",   -- (addr 0x020) pointer cell → real target 0x030
48 => x"002A",   -- (addr 0x030) data: 42
```
Encoding check: `0101 000000100000 = 0x5020` ✓

### ISTORE — expect `mem[0x030] = 0x0007`

```vhdl
0  => x"2007",   -- CLOAD 7        acc ← 0x0007
1  => x"6020",   -- ISTORE 0x020   mem[mem[0x020]] ← acc
2  => x"0000",   -- HALT
32 => x"0030",   -- (addr 0x020) pointer cell → real target 0x030
48 => x"0000",   -- (addr 0x030) initial data — should become 0x0007
```
Encoding check: `0110 000000100000 = 0x6020` ✓

After simulation, check `mem[0x030]` directly in the RAM signal — `acc`
itself doesn't change, so this test only passes if you inspect memory,
not just the accumulator.

---

## 6. Self-check

- ILOAD and DLOAD both end by driving `bus_mbr` into `ACC`
  (`iload1` vs. `load1`). Why can't they share the *same* final state,
  given `direct2` already distinguishes them?
- If you swapped `bus_mbr` for `bus_ir_lower` in `indirect1` by
  mistake, what address would `MAR` end up holding, and what would
  the ILOAD test above load into `ACC` instead?

---

## 7. Compile checkpoint

- No latch warnings — `indirect2`'s `case ir_opcode` must cover
  `when others`.
- ILOAD test: `acc = 0x002A`.
- ISTORE test: `mem[0x030] = 0x0007` (inspect memory, not `acc`).
- All Week 7, Module 3, and Module 4 tests still pass.

---

Next: **Module 6 — Completion, Testbench, and Exercises**
