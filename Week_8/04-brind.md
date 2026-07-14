# Week 8 · Module 4 — BRIND

`fetch3` already routes `OP_BRIND` to `brind1` (Week 7 Module 6 Stage A —
same dispatch table as the other branches). This module fills in the
three-state sequence `brind1 → brind2 → brind3`.

---

## 1. BRANCH vs. BRIND — one level of indirection

`BRANCH 0x004` (Module 3) jumps straight to address `0x004` — the
instruction *is* the target.

`BRIND 0x010` is different: `0x010` is not the target — it's the
address of a memory cell that **holds** the target. The CPU has to read
memory once to find out where to actually go:

```
BRANCH addr:  PC ← addr
BRIND  addr:  PC ← mem[addr]
```

This is exactly the same "address of an address" idea used later in
Module 5 for ILOAD/ISTORE — BRIND is the simplest possible case of it,
with only one memory read instead of two.

---

## 2. Register transfer sequence

```
brind1:  MAR ← IR[11:0]     (the address written IN the instruction)
brind2:  MBR ← mem[MAR]     (read the cell — this is the real target)
brind3:  PC  ← MBR          (jump)
```

Three states, three cycles of execute (plus the 3-cycle fetch = 6 total),
matching the `brind1`/`brind2`/`brind3` control table in `01-overview.md`
§5.

---

## 3. FSM addition

Remove `brind1 | brind2 | brind3` from the Week 7 placeholder group and
add:

```vhdl
            -- ====================================================
            -- brind1: MAR ← IR[11:0]
            -- The address field of the instruction — NOT the jump
            -- target itself, but the address OF the jump target.
            -- ====================================================
            when brind1 =>
                bus_ir_lower <= '1';
                mar_ld       <= '1';
                next_state   <= brind2;

            -- ====================================================
            -- brind2: MBR ← mem[MAR]
            -- Read the cell MAR points to. This value IS the target.
            -- ====================================================
            when brind2 =>
                bus_mem    <= '1';
                mbr_ld     <= '1';
                next_state <= brind3;

            -- ====================================================
            -- brind3: PC ← MBR
            -- The target address latches into PC — next fetch reads
            -- from there.
            -- ====================================================
            when brind3 =>
                bus_mbr    <= '1';
                pc_ld      <= '1';
                next_state <= fetch1;
```

Unlike the conditional branches in Module 3, `BRIND` has no flag check —
`pc_ld` is unconditionally `'1'` in `brind3`.

---

## 4. Test program

`BRIND` opcode is `1101 = 0xD`. Address `0x010` is the pointer cell;
it holds `0x0006`, the real jump target.

```vhdl
0  => x"2005",   -- CLOAD 5        acc ← 0x0005 (proves later CLOAD ran)
1  => x"D010",   -- BRIND 0x010    PC ← mem[0x010] = 0x0006
2  => x"2001",   -- (skipped)
3  => x"0000",   -- (skipped)
4  => x"2002",   -- (skipped)
5  => x"0000",   -- (skipped)
6  => x"2009",   -- CLOAD 9        acc ← 0x0009  (landed here via double hop)
7  => x"0000",   -- HALT
16 => x"0006",   -- pointer cell (address 0x010 = 16): jump target
```

Expected after `HALT`: `acc = 0x0009`, and — critically — `mem[0x010]`
itself is never modified; the instruction only reads it. If you set a
breakpoint (or just watch the waveform) on `current_state`, you should
see `brind1 → brind2 → brind3` execute between the fetch of instruction
1 and the fetch of instruction 6, with `mar = 0x010` during `brind1` and
`mbr = 0x0006` from `brind2` onward.

Encoding check: `BRIND 0x010` → `1101 000000010000 = 0xD010` ✓

---

## 5. Self-check

Before moving on, make sure you can answer this without looking back:

- If instruction `1` above were `BRANCH 0x010` instead of `BRIND 0x010`,
  where would execution land, and what would `acc` be after `HALT`?
  (Compare against Module 3 §2 — absolute addressing.)
- `brind2` and `direct2` (Week 7) both do `bus_mem='1'; mbr_ld='1'`. Are
  they interchangeable states, or does something about the surrounding
  sequence make them distinct?

---

## 6. Compile checkpoint

- No latch warnings.
- BRIND test produces `acc = 0x0009` and reaches `HALT`.
- All Week 7 and Module 3 tests still pass.

---

Next: **Module 5 — ILOAD and ISTORE**
