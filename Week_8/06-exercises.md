# Week 8 · Module 6 — Exercises

By now Modules 2–5 should be fully implemented: `add1`, `and1`,
`branch1`, `brind1`–`brind3`, `indirect1`, `indirect2`, `iload1`,
`istore1` all have their own `when` arms. This module closes out the
FSM and gives you the exercises to work through before Module 7
(debugging) and Module 8 (report).

---

## 1. Remove the placeholder block entirely

Your FSM should no longer contain this (from `01-overview.md` §3):

```vhdl
when add1 | and1 | indirect1 | indirect2 |
     iload1 | istore1 | branch1 |
     brind1 | brind2 | brind3 =>
    next_state <= fetch1;
```

Every state named in it now has its own arm. Delete the block. The only
remaining safety net is:

```vhdl
when others =>
    next_state <= fetch1;
```

If you compile and get a "duplicate choice in case statement" error, a
state is still listed both in its own arm *and* in the old placeholder
group — see Module 7 Bug 5.

---

## 2. Final FSM shape (all 22 states)

```
resetState
fetch1, fetch2, fetch3                          (universal fetch — Week 7)
halt1                                           (Week 7)
neg1, neg2                                      (Week 7)
cload1                                          (Week 7)
direct1, direct2                                (Week 7, shared by 6 instrs)
load1, store1                                   (Week 7 — DLOAD, DSTORE)
add1, and1                                      (Module 2)
branch1                                         (Module 3 — shared by 4 instrs)
brind1, brind2, brind3                          (Module 4)
indirect1, indirect2                            (Module 5, shared by 2 instrs)
iload1, istore1                                 (Module 5)
```

22 states, 14 instructions, matching the Week 6 architecture study. If
your count differs, you've either merged two states that should stay
separate, or left a Week 7 state out.

---

## 3. Integration test — all instruction families in one program

This program touches CLOAD, DSTORE, DLOAD, ADD, AND, NEGATE, BRANCH,
BRIND, ILOAD, ISTORE, and BRZERO in sequence, so a bug in any one
instruction is likely to show up as a wrong final `acc` or a hang
before `HALT`. It's also the default program loaded in
`starter_library/washu2_ram.vhd` — you can load it as-is for Exercise 4.

```vhdl
0  => x"200A",   -- CLOAD 10       acc ← 0x000A
1  => x"4020",   -- DSTORE 0x020   mem[0x020] ← 0x000A
2  => x"2005",   -- CLOAD 5        acc ← 0x0005
3  => x"7020",   -- ADD 0x020      acc ← 5 + 10 = 0x000F
4  => x"8020",   -- AND 0x020      acc ← 0x000F AND 0x000A = 0x000A
5  => x"9007",   -- BRANCH 0x007   PC ← 0x007 (unconditional)
6  => x"0000",   -- HALT           (skipped)
7  => x"D021",   -- BRIND 0x021    PC ← mem[0x021] = 0x009
8  => x"0000",   -- HALT           (skipped)
9  => x"6022",   -- ISTORE 0x022   mem[mem[0x022]] ← acc = mem[0x030] ← 0x000A
10 => x"5022",   -- ILOAD 0x022    acc ← mem[mem[0x022]] = mem[0x030] = 0x000A
11 => x"1000",   -- NEGATE         acc ← -0x000A = 0xFFF6
12 => x"A013",   -- BRZERO 0x013   zero_flag='0' → not taken
13 => x"0000",   -- HALT           (final)

32 => x"0000",   -- (0x020) ADD/AND scratch cell
33 => x"0009",   -- (0x021) BRIND target: instruction address 0x009
34 => x"0030",   -- (0x022) ILOAD/ISTORE pointer → real target 0x030
48 => x"0000",   -- (0x030) ILOAD/ISTORE data cell
```

Expected after `HALT`: `acc = 0xFFF6`, `mem[0x030] = 0x000A`.

Walk through it by hand before simulating — this is exactly the kind of
trace you'll be asked to do cold in the viva.

---

## 4. Exercises

### Exercise 1 — Branches ★ REQUIRED

Implement Module 3 in full. Run all five programs from Module 3 §6.
Add `current_state`, `pc`, `zero_flag`, `pos_flag`, `neg_flag`, and
`acc` to the waveform. For the BRZERO "not taken" case, confirm `pc_ld`
stays `'0'` throughout `branch1` — this is easy to get backwards.

**Self-check:** What would happen to the "not taken" test if `pc_ld`'s
default (top of `fsm_proc`) were accidentally `'1'` instead of `'0'`?

### Exercise 2 — BRIND ★ REQUIRED

Implement Module 4. Run the BRIND test. Add `mar`, `mbr`, `pc` to the
waveform across `brind1`/`brind2`/`brind3` and verify the two-step
transfer: `mar` picks up the instruction's address field first, then
`mbr` picks up the value stored there, then `pc` picks up `mbr`.

### Exercise 3 — ILOAD and ISTORE ★ REQUIRED

Implement Module 5. Run both test programs. For ISTORE, you must
inspect `mem[0x030]` directly (via the RAM's internal signal in
simulation) since `acc` doesn't change — add the memory array to the
waveform, or use ModelSim's hierarchical signal browser to drill into
`uut/ram_inst/ram_mem`.

### Exercise 4 — Full integration ★ REQUIRED

Run the §3 program (already loaded as the default in
`starter_library/washu2_ram.vhd`). Confirm `acc = 0xFFF6` and
`mem[0x030] = 0x000A` after `HALT`. This should be the main stimulus in
your final testbench — `starter_library/tb_washu2_week8.vhd` already
waits for `done` and gives you the structure to add your own asserts.

### Exercise 5 — Flag edge cases (optional, recommended before the viva)

Write a short program that CLOADs `0x800` (the most negative 12-bit
sign-extended value) and confirm `neg_flag='1'`, `zero_flag='0'`,
`pos_flag='0'`. Then CLOAD `0` and confirm the opposite pattern. Be
ready to explain why `pos_flag`'s definition explicitly excludes zero.

---

Next: **Module 7 — Debugging Reference**
