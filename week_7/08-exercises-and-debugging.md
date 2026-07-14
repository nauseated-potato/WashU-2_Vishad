# Week 7 · Module 8 — Exercises and Debugging Reference

---

## Exercise 1 — Build and verify the fetch cycle ★ REQUIRED

### What to do

1. Complete `washu2_cpu.vhd` through Stage A of Module 6 (resetState +
   fetch cycle only, `when others => next_state <= fetch1`).

2. Load Program A into `washu2_ram.vhd`:
   ```
   0 => x"0000"    -- HALT at address 0x000
   ```

3. Write `tb_washu2_week7.vhd` (Module 7 §4) and simulate.

4. Add `current_state`, `pc`, `mar`, `mbr`, `ir`, and `the_bus` to the
   waveform. Verify cycle-by-cycle against the expected trace in Module 7 §6.

### What correct behaviour looks like

- Cycle 1 (resetState): `current_state = resetState`, all registers = 0.
- Cycle 2 (fetch1): `the_bus = 0x0000` (= PC), `mar` updates to `0x000`.
- Cycle 3 (fetch2): `the_bus = mem[0x000] = 0x0000`, `mbr` updates;
  `pc` increments to `0x001`.
- Cycle 4 (fetch3): `the_bus = 0x0000` (= MBR). At the rising edge ending
  this cycle: `ir` updates to `0x0000`. The FSM dispatches to `halt1`
  because `mbr(15 downto 12) = "0000"` = HALT (decoded from MBR, not IR —
  IR is stale during fetch3; see Module 6 Stage A).
- Cycle 5 (halt1): `done = '1'`.

### Self-check questions *(for your own understanding)*

- In cycle 3, `pc_inc='1'` and `mbr_ld='1'` both fire at the same rising
  edge. How does VHDL handle two simultaneous updates in the same process?
- Why does `ir` still show the old value (`0x0000` initial) in cycle 2
  and 3, and only update at the end of cycle 4?
- If the first instruction were `0x1000` (NEGATE) instead of `0x0000`
  (HALT), what would `current_state` be at cycle 5?

---

## Exercise 2 — Implement and verify HALT, NEGATE, CLOAD ★ REQUIRED

### What to do

1. Add Stage B to the FSM (Module 6).

2. Verify NEGATE using this program:
   ```
   mem[0x000] = 0x202A   -- CLOAD 42       (ACC ← 42 = 0x002A)
   mem[0x001] = 0x1000   -- NEGATE         (ACC ← -42 = 0xFFD6)
   mem[0x002] = 0x0000   -- HALT
   ```
   Expected after HALT: `acc = 0xFFD6`.

3. Verify CLOAD with a negative constant:
   ```
   mem[0x000] = 0x2FFF   -- CLOAD 0xFFF = CLOAD -1 (sign-extended)
   mem[0x001] = 0x0000   -- HALT
   ```
   Expected after HALT: `acc = 0xFFFF` (= −1 in 16-bit two's complement).

4. Add `neg1`, `neg2`, `cload1` to the waveform alongside `acc` and
   verify the register values match the expected traces.

### Expected NEGATE trace (starting from ACC = 0x002A after CLOAD)

| Cycle | State | acc at start | alu_op | the_bus at edge | acc at end |
|---|---|---|---|---|---|
| N+1 | neg1 | 0x002A | ALU_NOT | 0xFFD5 | 0xFFD5 |
| N+2 | neg2 | 0xFFD5 | ALU_INC | 0xFFD6 | 0xFFD6 |
| N+3 | fetch1 | 0xFFD6 | — | — | — |

Verify: `0x002A + 0xFFD6 = 0x10000` → lower 16 bits = `0x0000` ✓

### Self-check questions *(for your own understanding)*

- `CLOAD 0x800` has operand bits `100000000000`. What is `ir(11)`? What
  value does sign-extension produce in ACC?
- After `NEGATE`, the zero flag should be `'0'` for a non-zero input. After
  `CLOAD 0`, then `NEGATE`, what is ACC? Is `zero_flag` correct?
- In `neg1`, `bus_alu='1'` and `acc_ld='1'` fire simultaneously. Draw the
  signal flow: what path does data take from the current `acc` value to the
  updated `acc` value, including the ALU and bus?

---

## Exercise 3 — Implement and verify DLOAD and DSTORE ★ REQUIRED

### What to do

1. Add Stage C to the FSM (Module 6).

2. Load Program D (Module 7 §2) into `washu2_ram.vhd` and simulate.

3. Verify the full execution trace matches Module 7 §6.

4. Write a second test that exercises a DSTORE-then-DLOAD round trip with
   a different value — choose `0x1234` — and verify the round trip is exact.

### Additional test program (use this as a second test):

```
mem[0x000] = 0x2234   -- CLOAD 0x234 = 564  (ACC ← 0x0234)

Encoding check: opcode=0010, K=0x234=001000110100
Full word: 0010 001000110100 = 0x2234 ✓

mem[0x001] = 0x4020   -- DSTORE 0x020        (mem[0x020] ← 0x0234)
mem[0x002] = 0x2000   -- CLOAD 0             (ACC ← 0, clear acc)
mem[0x003] = 0x3020   -- DLOAD 0x020         (ACC ← mem[0x020] = 0x0234)
mem[0x004] = 0x0000   -- HALT
```

Expected after HALT: `acc = 0x0234`, `mem[0x020] = 0x0234`.

### Waveform signals to add for DSTORE/DLOAD

For DSTORE: `bus_acc`, `mem_we`, `mar`, `the_bus` during `store1`.
For DLOAD: `bus_ir_lower`, `mar`, `bus_mem`, `mbr`, `bus_mbr`, `acc` during
`direct1`, `direct2`, `load1`.

### Self-check questions *(for your own understanding)*

- In `direct1`, `bus_ir_lower='1'` puts IR[11:0] zero-extended onto the
  bus, and `mar_ld='1'` latches it. For instruction `0x3010` (DLOAD 0x010),
  what value does `the_bus` carry? What value does `mar` hold after the edge?
- In `direct2` for DSTORE, a memory read happens (`bus_mem='1'`, `mbr_ld='1'`).
  This reads `mem[MAR]` into MBR even though DSTORE does not need to read
  that value. Why is this harmless?
- `direct1` and `direct2` are shared between DLOAD, DSTORE, ADD, AND,
  ILOAD, and ISTORE. Looking at your `direct2` case statement, what
  determines which state comes after `direct2`?

---

## Debugging reference

### The eight most common Week 7 bugs

**Bug 1 — Bus contention (multiple `bus_X` signals asserted simultaneously)**

Symptom: `the_bus` shows `'X'` in simulation.

Cause: two `bus_X` signals are `'1'` in the same cycle, driving the bus
from two sources.

Fix: check the defaults section — every `bus_X` must default to `'0'`.
Check that no state sets more than one `bus_X` to `'1'`.

---

**Bug 2 — Latch inferred for a control signal**

Symptom: Quartus warning "Latch inferred for signal `bus_pc`" (or similar).

Cause: a control signal is not assigned in every branch of the `case`
statement. The defaults before the `case` must cover every signal.

Fix: confirm every control signal appears in the defaults section. Even
if the signal is only active in one or two states, it must be defaulted
to `'0'` before the `case`.

---

**Bug 3 — IR never updates (stuck at 0x0000)**

Symptom: `ir` stays `0x0000` even after the fetch cycle runs correctly.

Cause: `ir_ld` is never asserted, or `bus_mbr` is not `'1'` in `fetch3`.

Fix: check the `fetch3` arm:
```vhdl
when fetch3 =>
    bus_mbr <= '1';    -- ← both required
    ir_ld   <= '1';    -- ← both required
```

---

**Bug 4 — PC does not increment**

Symptom: `pc` stays at `0x000` forever; the CPU fetches the same
instruction repeatedly.

Cause: `pc_inc` is not `'1'` in `fetch2`, or the incrementer in Process 1
has a bug.

Fix: check the `fetch2` arm has `pc_inc <= '1'`. Check Process 1:
```vhdl
elsif pc_inc = '1' then
    pc <= std_logic_vector(unsigned(pc) + 1);
end if;
```

---

**Bug 5 — NEGATE produces wrong result**

Symptom: NEGATE gives `NOT(acc)` but does not add 1, or adds 1 to
the *original* value instead of the inverted value.

Cause A: `neg2` is missing the `ALU_INC` operation.
Cause B: the ALU reads `acc` combinationally, so in `neg2` it correctly
reads the *already-updated* `acc` (from the `neg1` edge). If `neg1` and
`neg2` have been merged into a single state this fails.

Fix: confirm two separate states exist (`neg1` for NOT, `neg2` for +1)
and that the ALU is connected to `acc` (which updates between the two edges).

---

**Bug 6 — DLOAD loads the wrong value (loads the instruction, not the data)**

Symptom: after DLOAD, `acc` holds the instruction word, not the data
at the operand address.

Cause: `direct1` is using `bus_mbr` instead of `bus_ir_lower` to load MAR.
If MAR gets MBR (which still holds the instruction) instead of IR[11:0]
(the operand address), the subsequent memory read fetches from the wrong
address.

Fix: check `direct1`:
```vhdl
when direct1 =>
    bus_ir_lower <= '1';   -- IR[11:0] zero-extended → not bus_mbr
    mar_ld       <= '1';
```

---

**Bug 7 — DSTORE writes to address 0 instead of the operand address**

Symptom: `mem[0x000]` is overwritten but `mem[operand]` is unchanged.

Cause: `mar` was not updated in `direct1` (see Bug 6), or `mem_we='1'`
fired in `direct2` rather than `store1`.

Fix: confirm `mem_we` is `'0'` in both `direct1` and `direct2` (defaults
handle this if set correctly). Only `store1` and `istore1` should set
`mem_we <= '1'`.

---

**Bug 8 — `done` never asserts**

Symptom: simulation runs past the timeout with `done` stuck at `'0'`.

Cause: `halt1` state is never reached. Most likely causes:
- The `fetch3` case decodes `ir_opcode` instead of `mbr(15 downto 12)`.
  `ir_opcode` is stale during `fetch3`; the decode must use `mbr(15 downto 12)`.
- The `when OP_HALT` arm is missing from the `fetch3` case.
- The `halt1` state arm is missing from the FSM entirely.

Fix: check `fetch3` case arm:
```vhdl
case mbr(15 downto 12) is   -- mbr, NOT ir_opcode
    when OP_HALT => next_state <= halt1;
    ...
end case;
```
Check `halt1` sets `done_int <= '1'`. Check `done <= done_int;` is present
after the FSM process.

---

### Systematic debugging workflow

```
1. Does it compile without errors?  Fix all errors first.
2. Does it compile without warnings?  Fix latch warnings (Bug 2) next.
3. Run Program A (HALT only).
   - Does 'done' assert within 6 cycles?
   - If not: check Bug 3 (IR), Bug 4 (PC), Bug 8 (done).
4. Verify fetch cycle manually against Module 7 §6 trace.
   - If MAR/MBR/IR don't update correctly: check Bugs 3-4, Process 1.
5. Add Stage B. Run Program B (NEGATE).
   - Check acc after neg1 = NOT(original acc).
   - Check acc after neg2 = NOT(original) + 1.
   - If wrong: check Bug 5.
6. Add Stage C. Run Program D.
   - Check acc after DLOAD = value stored by DSTORE.
   - If wrong address: check Bug 6 (direct1) or Bug 7 (mem_we timing).
```

---

## Week 7 submission checklist

- [ ] `washu2_cpu.vhd` — compiles with no errors, no latch warnings.
- [ ] `washu2_ram.vhd` — Program D loaded (from starter_library, edited).
- [ ] `tb_washu2_week7.vhd` — testbench covering all three exercise programs.
- [ ] Waveform screenshot: Program D full execution visible, all 5
      instructions traced with `current_state` and `acc` readable.
- [ ] `week7_report.pdf` — RTL netlist view of `washu2_cpu` + waveform
      screenshots + 2–3 sentences on any bugs found and fixed.

---

Next: **Week 8 — Completing the CPU**
