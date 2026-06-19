# Week 5 · Module 6 — Exercises

Week 5 has one large required exercise and one optional extension. Unlike
previous weeks where each exercise built an isolated component, both
exercises this week require you to design at the *system* level — wiring
multiple components together and reasoning about timing across the whole
pipeline.

**Workflow:**
1. Re-read the Module 2 block diagram and Module 4 execution trace.
2. For each exercise, write the program by hand first (encode it to binary).
3. Trace the expected execution cycle-by-cycle in a table before writing
   any VHDL.
4. Implement, simulate, and verify your trace matches the waveform.

---

## Exercise 1 — Mini-Datapath with Three-Value Maximum ★ REQUIRED

### Background

The module examples ran programs that compute `A + B`. This exercise
builds and runs a more interesting program: finding the **maximum of two
values** using only the three instructions (LOAD, ADD, STORE, HALT) available
in the mini-datapath.

Because the mini-datapath has no conditional branch instruction, you cannot
implement `if A > B then acc = A else acc = B` directly. Instead, you will
implement a mathematically equivalent approach:

    max(A, B) = ((A - B) + |A - B|) / 2 + B
    
    But without division, we use a simpler observation:
    If A >= B: A + (B + NOT(B)) = A + 0xFF... which is just A again (wraps)
    
    Simpler approach for this exercise:
      Compute A - B.
      If the result has its MSB clear (A >= B), the answer is A.
      If the result has its MSB set  (A < B),  the answer is B.

However, this still requires a conditional. Instead, **this exercise uses
a fixed test case** where you know A ≥ B at design time, and your program
simply demonstrates the correct fetch-execute-store behaviour across 5
instructions with the correct final result.

### Specification — `mini_cpu` with Program: `result = (A + B) - C`

You are given A = 15, B = 9, C = 4. The program must compute `(A + B) - C`
and store the result. Expected answer: `15 + 9 - 4 = 20 = 0x14`.

The mini-datapath's ALU supports SUB (opcode `"001"` with the ALU) but the
**instruction set only has ADD** as defined in Module 1. This means you
must implement subtraction by adding the two's complement:

    A - C = A + (-C) = A + NOT(C) + 1

Since you have no NOT instruction, use a pre-computed negation:
store `(-C)` as a data value in memory. For C=4: `-4` in 8-bit two's
complement = `0xFC = 11111100`.

So the program is:

    LOAD  addrA        ; acc = A = 15
    ADD   addrB        ; acc = A + B = 24 (0x18)
    ADD   addrNegC     ; acc = 24 + (-4) = 20 (0x14)
    STORE addrResult   ; mem[result] = 0x14
    HALT

### Memory layout

Choose your own addresses for each value (within the 32-location space).
Place instructions at addresses 0–4 and data at addresses 16–20. Fill in
this table before writing any VHDL:

| Address (dec) | Role | Value (binary) | Value (hex) |
|---|---|---|---|
| 0 | LOAD instr | ? | ? |
| 1 | ADD instr  | ? | ? |
| 2 | ADD instr  | ? | ? |
| 3 | STORE instr| ? | ? |
| 4 | HALT instr | ? | ? |
| 16 | A = 15   | ? | ? |
| 17 | B = 9    | ? | ? |
| 18 | −C = −4  | ? | ? |
| 19 | result   | 00000000 | 0x00 |

### What to do

1. **Encode all five instructions** into binary using the instruction format
   from Module 4 §1. Fill in the memory layout table completely.

2. **Write the execution trace** — a table with columns: Cycle, State, PC,
   IR, acc, addr, mem_data_out — for all cycles from reset until `done='1'`,
   in the same format as Module 4 §3. There should be **19 cycles**: the
   four non-HALT instructions (LOAD, ADD, ADD, STORE) each take 4 cycles
   (16 cycles total), and HALT takes 3 more cycles
   (`S_FETCH1 → S_FETCH2 → S_EXECUTE`) to reach `S_HALT` with `done='1'`
   on cycle 19.

3. **Implement** by modifying `ram32x8.vhd` to load your encoded program
   and data. The `mini_cpu.vhd` and `alu8.vhd` files from the starter
   library are used unchanged.

4. **Add debug ports** to `mini_cpu` as shown in Module 5:
   `dbg_acc`, `dbg_pc`, `dbg_ir`, `dbg_state`.

5. **Write `tb_mini_cpu_ex1.vhd`** that:
   - Applies reset for 3 cycles.
   - Waits for `done='1'` with a timeout of 25 cycles (program completes
     by cycle 19; 25 gives a 6-cycle margin).
   - Asserts `dbg_acc = x"14"` (the correct result).
   - Asserts `done` stays high for at least 3 more cycles (CPU stays in HALT).
   - Asserts `done` goes low after reset is applied again.

6. **Simulate** and verify your execution trace from step 2 matches the
   waveform exactly, cycle by cycle.

### Self-check questions *(for your own understanding — not submitted)*

- Why is `-4` represented as `0xFC` in 8-bit two's complement? Verify by
  adding `0x04 + 0xFC` in binary and confirming the 8-bit result is `0x00`.
- Your program uses 5 instruction slots (addresses 0–4) and 4 data slots
  (addresses 16–19). What is the maximum program length this mini-datapath
  can run before instructions and data overlap?
- If you accidentally stored the HALT instruction at address 3 instead of 4,
  what would happen? Would `done` fire early? Would any data be corrupted?
- The accumulator is 8 bits. What is the largest `A + B` sum your program
  can compute without overflow? What happens in your implementation if
  the sum exceeds 255?

---

## Optional Exercise — Extend the ISA: Add a SUB Instruction ✦ OPTIONAL

*Attempt only after Exercise 1 is fully working and simulating correctly.
This exercise requires modifying both the control unit and the instruction
encoding — do not underestimate the amount of careful thought it requires.*

### Background

The mini-datapath currently supports four instructions: LOAD, ADD, STORE,
HALT. This exercise adds a fifth: **SUB**, which subtracts a memory value
from the accumulator.

    SUB addr  →  acc ← acc − mem[addr]

Adding a new instruction requires changes in three places:
1. The **instruction encoding** (assign a new opcode).
2. The **control FSM** (add a `when OP_SUB` arm in the EXECUTE case).
3. The **program** (write a new test program that uses SUB).

### Part A — Instruction encoding

Choose an opcode for SUB. You have opcodes `000`–`011` taken. Assign
`100` to SUB. Update the constant in `mini_cpu.vhd`:

    constant OP_SUB : std_logic_vector(2 downto 0) := "100";

Encoding: `SUB addr` → bits[7:5] = `100`, bits[4:0] = addr.

### Part B — Control FSM modification

SUB is a memory-operand instruction, exactly like ADD — it needs the same
two-state split across `S_EXECUTE` and `S_WRITEBACK` (see Module 2 §7 and
Module 3 §8 for why a single state is not enough).

**In `S_EXECUTE`**, add `OP_SUB` to the group that needs a writeback cycle:

    when OP_LOAD | OP_ADD | OP_SUB | OP_STORE =>
        next_state <= S_WRITEBACK;

**In `S_WRITEBACK`**, add a new arm:

    when OP_SUB =>
        alu_op     <= ALU_SUB;     -- drive ALU to subtract
        acc_ld     <= '1';         -- capture result into acc
        next_state <= S_FETCH1;

The `ALU_SUB` constant must match the opcode defined in `alu8.vhd`.
Check the provided `alu8.vhd` in the starter library for the correct value.

> **Reminder:** like ADD, SUB takes 4 cycles total
> (`S_FETCH1 → S_FETCH2 → S_EXECUTE → S_WRITEBACK`). The ALU performs
> `acc - mem_data_out`, and `mem_data_out` is only valid in
> `S_WRITEBACK` — which is exactly why the `alu_op <= ALU_SUB` and
> `acc_ld <= '1'` assignments belong there, not in `S_EXECUTE`.

### Part C — Test program: `result = A - B`

Write a 4-instruction program that computes `A - B` directly using SUB,
where A = 20 (`0x14`) and B = 7 (`0x07`). Expected result: 13 (`0x0D`).

    LOAD  addrA    ; acc = 20
    SUB   addrB    ; acc = 20 - 7 = 13
    STORE addrRes  ; mem[result] = 13
    HALT

Encode the program, load it into `ram32x8.vhd`, and verify with a testbench.

### Part D — Compare with two's complement approach

In Exercise 1, you computed `A - C` by adding `NOT(C) + 1` (the two's
complement negation stored as a data value). Now you have a real SUB
instruction.

Write a brief comparison (3–5 sentences, as a comment block at the top of
`tb_mini_cpu_sub.vhd`):

- Which approach is more convenient for the programmer? Why?
- Which approach requires more memory locations? Why?
- If you were designing the WashU-2 CPU ISA, would you include both SUB and
  NEGATE as separate instructions, or just one? Justify your answer.

### Part E — Testbench

Write `tb_mini_cpu_sub.vhd`. Verify:
- `done='1'` is reached.
- `dbg_acc = x"0D"` after HALT.
- Reset recovery works.

### Self-check questions *(for your own understanding — not submitted)*

- You now have opcodes 000–100 defined (LOAD, ADD, STORE, HALT, SUB).
  That leaves 011 values unused (`101`, `110`, `111`). What behaviour does
  your current implementation have for these opcodes? Is it safe?
- Adding SUB required changes to the FSM but not to the datapath wiring.
  What does this tell you about the separation of concerns between the
  control unit and the datapath?
- The WashU-2 CPU has 14 instructions but only one ALU and one accumulator.
  Based on what you have done this week, describe in one paragraph how a
  14-instruction CPU control FSM differs from your 4-instruction one.

---

## Submission Checklist

- [ ] `ram32x8.vhd` — correctly encodes Exercise 1 program and data.
- [ ] `mini_cpu.vhd` — with debug output ports added.
- [ ] `tb_mini_cpu_ex1.vhd` — passes all assert checks, done fires correctly.
- [ ] Execution trace table from step 2 (in a comment block or PDF).
- [ ] Waveform screenshot: all debug signals visible, `done='1'` visible.
- [ ] `week5_report.pdf` — RTL netlist of `mini_cpu` + waveform screenshot
      + 2–3 sentences on any bugs found.
- [ ] *(Optional)* `tb_mini_cpu_sub.vhd` — SUB instruction verified.