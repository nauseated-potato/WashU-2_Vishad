# Week 6 · Module 8 — Exercises and Self-Study Questions

This module contains the two required deliverables, four additional
self-study exercises, and a set of understanding questions to consolidate
the week's material. Complete the deliverables in order — the FSM diagram
depends on the control signal table, which depends on the state diagram,
which depends on understanding the traces.

---

## Deliverable 1 — Five-Instruction Execution Trace ★ REQUIRED

Produce a complete cycle-by-cycle execution trace for the following
5-instruction program. Your trace must match the format of Module 7's
worked examples exactly.

### The program

```
Address   Instruction    Encoding     Comment
0x000     CLOAD 10       0x200A      ACC ← 10
0x001     DSTORE 0x100   0x4100      mem[0x100] ← ACC
0x002     DLOAD  0x100   0x3100      ACC ← mem[0x100]   (round-trip check)
0x003     ADD    0x101   0x7101      ACC ← ACC + mem[0x101]
0x004     HALT           0x0000      stop
```

**Memory data:**

| Address | Value | Role |
|---|---|---|
| `0x100` | `0x0000` | Result of DSTORE (will be written) |
| `0x101` | `0x0005` | Addend (constant: 5) |

### What your trace must include

For each clock cycle of the entire program (all 5 instructions, every state),
your table must show:

- Cycle number (numbered continuously from 1)
- FSM state name
- PC value (before the cycle's update)
- MAR value
- MBR value
- IR value
- ACC value
- Which bus driver is active
- Which load/enable signals fire
- A brief note on what transfer occurs

### Expected outcome

After HALT:
- `ACC = 0x000F` (15 = 10 + 5)
- `mem[0x100] = 0x000A` (written by DSTORE as 10; then read back unchanged by DLOAD — the round-trip verifies the store worked)
- `PC = 0x005` (incremented past HALT in fetch2)
- **Total clock cycles = 26** — work through each instruction:

| Instruction | States | Cycles |
|---|---|---|
| `CLOAD 10` | fetch1, fetch2, fetch3, cload1 | 4 |
| `DSTORE 0x100` | fetch1,2,3, direct1, direct2, store1 | 6 |
| `DLOAD 0x100` | fetch1,2,3, direct1, direct2, load1 | 6 |
| `ADD 0x101` | fetch1,2,3, direct1, direct2, add1 | 6 |
| `HALT` | fetch1, fetch2, fetch3, halt1 | 4 |
| **Total** | | **26** |

Verify your trace has exactly 26 rows before you scan it.

### Trace production guidelines

- Use a landscape A4 sheet or a wide table in your PDF.
- Write register values in hex (`0x00AB` not `171`).
- Be consistent: write the register value **before** the cycle updates it.
- For `fetch2`, note both `mbr_ld` AND `pc_inc` as active (they happen
  simultaneously).
- Circle (or highlight) each cycle where `ACC` changes value.
- Mark the instruction boundary between each pair of instructions.

---

## Deliverable 2 — Hand-Drawn 17-State FSM Diagram ★ REQUIRED

Draw the complete 17-state FSM on paper (A3 if possible, A4 landscape
otherwise). Scan or photograph and submit as a PDF.

### Requirements for the diagram

**States:** draw all states as labelled circles or rounded rectangles. Aim for 17–19 depending on your merge decisions (see Module 5 §5). At minimum include: resetState, fetch1–3, halt1, neg1–2, cload1, direct1–2, load1, add1, and1, store1, branch1, indirect1–2, iload1, istore1, brind1–3.

**Transitions:** draw an arrow between every pair of states that has a
direct transition. Label every arrow with its condition (e.g., `IR[15:12]=0011`
for the fetch3 → direct1 transition for DLOAD).

**Initial state:** mark `resetState` with an incoming arrow and label
`reset`.

**Control signals:** inside each state circle (or in a box adjacent to
it), list the control signals that are asserted (`'1'`) in that state.
Use the abbreviated names from Module 6 (e.g., `bus_pc, mar_ld`).
Do NOT list signals that are `'0'` — only list the active ones.

**Branch conditions:** the `branch1` state has a conditional transition
back to fetch1. Show `pc_ld` as `zero_flag` / `pos_flag` / `neg_flag` /
`'1'` depending on the opcode. This can be shown as four separate annotated
arrows from `branch1`, or as one arrow with a conditional label.

### Diagram quality checklist

- [ ] All states present and labelled (aim for 17–19 — see Module 5 §5 for why the count varies by implementation).
- [ ] All transitions from `fetch3` labelled with the opcode condition.
- [ ] `direct1` and `direct2` shown as shared states with multiple incoming
      arrows (from fetch3 for DLOAD, DSTORE, ADD, AND, ILOAD, ISTORE).
- [ ] `branch1` shown as shared with conditional `pc_ld`.
- [ ] `indirect1` and `indirect2` shown with two incoming arrows (from
      direct2 for both ILOAD and ISTORE).
- [ ] Every state has at least one control signal listed.
- [ ] The diagram is large enough to read without magnification.

---

## Self-Study Exercise 1 — Decode and Trace

Decode each of the following 16-bit hex words and write the full RTL
sequence (using the Module 6 summary format, not full cycle-by-cycle).
No trace table needed — just the sequence of register transfers.

| Hex word | Instruction | RTL sequence |
|---|---|---|
| `0x3008` | ? | ? |
| `0x7010` | ? | ? |
| `0x9005` | ? | ? |
| `0x600A` | ? | ? |
| `0x200F` | ? | ? |
| `0xB002` | ? | ? |
| `0xD015` | ? | ? |
| `0x1000` | ? | ? |

Then pick any two and write the full cycle-by-cycle trace (like Deliverable 1)
for those two instructions only, using:
- `PC = 0x010` at the start
- Memory values of your choice (make them simple: `0x0001`, `0x0002`, etc.)

---

## Self-Study Exercise 2 — Write a WashU-2 Program

Write a WashU-2 assembly program that computes:

```
result = (A * 2) + B
```

Where `A` and `B` are stored in memory at addresses `0x100` and `0x101`,
and the result is stored at `0x102`.

**Constraints:**
- The ISA has no multiply instruction. Implement `A * 2` as `A + A`.
- You may not modify `A` or `B` in memory.
- Use as few instructions as possible.

Write your answer in this format:

```
Address   Mnemonic        Hex encoding   Comment
0x000     ...             ...            ...
```

Then encode every instruction to hex and verify by hand that `result = 2A+B`
for `A=3`, `B=7` (expected: `6+7=13 = 0x000D`).

---

## Self-Study Exercise 3 — Find the Bug

The following program is supposed to count from 0 to 3 using a loop.
It contains **two bugs**. Find them, explain what symptom each would produce,
and write the corrected program.

```
Address   Instruction    Hex       Comment
0x000     CLOAD 0        0x2000   ACC ← 0 (counter)
0x001     DSTORE 0x100   0x4100   mem[0x100] ← counter
0x002     DLOAD  0x100   0x3100   ACC ← counter
0x003     ADD    0x101   0x7101   ACC ← counter + 1
0x004     DSTORE 0x100   0x4100   mem[0x100] ← counter+1
0x005     CLOAD 3        0x2003   ACC ← 3   (limit)
0x006     BRZERO 0x002   0xA002   if counter = 3, exit loop  ← BUG 1
0x007     BRANCH 0x002   0x9002   loop back
0x008     HALT           0x0000   done
```

Data:
```
0x101: 0x0001   (increment value)
```

Hint for Bug 1: what is in `ACC` when the BRZERO check runs? Is it the
counter or something else?

Hint for Bug 2: think about what value terminates the loop vs what the
comparison computes.

---

## Self-Study Exercise 4 — Indirect Addressing Scenario

Suppose you have an array of 8 values stored at addresses `0x200`–`0x207`.
You want to read the element at index `i`, where `i` is stored at `0x100`.

```
Array:  mem[0x200] = 0x0011
        mem[0x201] = 0x0022
        ...
        mem[0x207] = 0x0088
Index:  mem[0x100] = 0x0003   (read element at index 3 = value 0x0044)
```

Write the WashU-2 assembly to load `array[i]` into `ACC`. Your program
must work for **any** value of `i` (0–7), not just `i=3`.

Hint: you need to compute `0x200 + i` and store it somewhere as a pointer,
then use `ILOAD` to follow that pointer. This requires at least one CLOAD,
one ADD, one DSTORE, and one ILOAD.

---

## Understanding questions

Work through these before starting Week 7. Most answers are in this week's
modules — the goal is to find them, not look them up.

### Architecture

1. Describe the WashU-2 datapath. What registers does it have, and what
   is each one's role?

2. Why does the WashU-2 use a single shared bus rather than direct
   point-to-point connections between all registers?

3. What is the role of MAR and MBR? Why are two registers needed for
   memory access rather than one?

4. What is the difference between the accumulator register and a
   general-purpose register file (like in a modern ARM or x86 CPU)?

### ISA

5. What is the opcode for ADD? For ILOAD? For BRZERO?

6. Encode `DSTORE 0x05A` as a 16-bit hex word.

7. Decode `0x600C`. What instruction is it? What address does it operate on?

8. What is the difference between `DLOAD` and `ILOAD`? Give an example
   where you would use each.

9. Why does the WashU-2 have three separate branch instructions (BRZERO,
   BRPOS, BRNEG) instead of just one conditional branch?

10. What does `CLOAD -1` load into ACC? Show the sign-extension step.

### FSM and timing

11. How many clock cycles does `DLOAD` take? Name every state and its
    register transfer.
    *(6 — fetch1, fetch2, fetch3, direct1, direct2, load1)*

12. How many clock cycles does `ISTORE` take? Name every state and the
    register transfer in each.
    *(8 — fetch1, fetch2, fetch3, direct1, direct2, indirect1, indirect2, istore1)*

13. In `fetch2`, two things happen simultaneously: `MBR ← mem[MAR]` and
    `PC ← PC+1`. Explain how this is possible in synchronous hardware.
    *(Both are registered updates at the same rising edge. `PC+1` uses the
    incrementer, not the bus, so it does not conflict with `bus_mem`
    driving MBR. In VHDL, both sit inside `if rising_edge(clk)`)*

14. The `direct1` and `direct2` states are shared between DLOAD, DSTORE,
    ADD, AND, ILOAD, and ISTORE. In `direct2`, a memory read always happens
    even for DSTORE where the result is discarded. Why does the design
    accept this, and how could you redesign the FSM to avoid it?

15. What state does `fetch3` transition to for opcode `0111`? What does
    that state do?

16. In `branch1`, how does the FSM implement conditional branching? Which
    control signal is conditional, and what determines its value?

### Design decisions

17. The WashU-2 has no SUB instruction. How would you compute `A − B`?
    Write the instruction sequence.

18. To add a `NOT` instruction (bitwise NOT of ACC), what changes are
    needed in: (a) the ISA encoding, (b) the FSM, (c) the ALU?

19. The WashU-2 has a 12-bit address field. How many memory locations can
    it address? Could this be increased without changing instruction width?

20. What is the difference between `BRANCH` and `BRIND`? Give a concrete
    example of when a program needs `BRIND` rather than `BRANCH`.

---

## Week 6 submission checklist

- [ ] `instruction_trace.pdf` — complete cycle-by-cycle trace for all
      5 instructions in Deliverable 1. Every row filled in. Committed to
      `architecture-study/` in your fork.
- [ ] `fsm_state_diagram.pdf` — hand-drawn FSM (17–19 states). All states,
      all transitions, all active control signals. Committed to
      `architecture-study/` in your fork.
- [ ] Self-study exercises 1–4 completed on paper (not submitted).
- [ ] Understanding questions 1–20 worked through.

---

*Week 6 complete. You now have a precise, detailed understanding of the
WashU-2 architecture. Every register, every bus transfer, every FSM state,
every control signal is defined. Week 7 is the direct translation of this
understanding into VHDL — every concept from this week maps to a signal
name, a process arm, or a case branch in the implementation.*
