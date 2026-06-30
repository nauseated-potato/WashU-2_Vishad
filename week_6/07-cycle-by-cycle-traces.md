# Week 6 · Module 7 — Cycle-by-Cycle Instruction Traces

This module provides four complete, worked instruction traces. Each trace
shows every clock cycle, every state, every register value, and which bus
control signals are active. These are the benchmark for what your own traces
in Module 8 should look like.

Work through each trace **actively**: before reading the next row, pause
and predict what will happen. If your prediction is wrong, go back to
Modules 5 and 6 and find why.

---

## Trace format

Each trace uses this column layout:

| Cycle | State | PC | MAR | MBR | IR | ACC | Bus driver | Active loads | Notes |
|---|---|---|---|---|---|---|---|---|---|

- **Cycle:** clock cycle number from the start of the instruction (cycle 1 =
  the fetch1 state).
- **State:** FSM state name.
- **PC, MAR, MBR, IR, ACC:** register values **at the start** of the cycle
  (before any updates).
- **Bus driver:** which `bus_X` signal is `'1'` (what drives the bus).
- **Active loads:** which `_ld` or `_inc` signals fire (what latches from
  the bus or increments).
- **Notes:** what transfer occurs, what the register value will be at the
  **end** of the cycle.

---

## Trace 1 — `DLOAD 0x010`

**Setup:**
- `PC = 0x000` at the start
- `mem[0x000] = 0x3010` (= `DLOAD 0x010`, opcode `0011`, addr `0x010`)
- `mem[0x010] = 0x00AB` (the value to be loaded)
- `ACC = 0x0000` initially

| Cycle | State | PC | MAR | MBR | IR | ACC | Bus driver | Active loads | Notes |
|---|---|---|---|---|---|---|---|---|---|
| 1 | fetch1 | 0x000 | — | — | — | 0x0000 | bus_pc | mar_ld | MAR ← 0x000 |
| 2 | fetch2 | 0x000 | 0x000 | — | — | 0x0000 | bus_mem | mbr_ld, pc_inc | MBR ← mem[0x000]=0x3010; PC ← 0x001 |
| 3 | fetch3 | 0x001 | 0x000 | 0x3010 | — | 0x0000 | bus_mbr | ir_ld | IR ← 0x3010 |
| 4 | direct1 | 0x001 | 0x000 | 0x3010 | 0x3010 | 0x0000 | bus_ir_lower | mar_ld | MAR ← 0x010 (IR[11:0]) |
| 5 | direct2 | 0x001 | 0x010 | 0x3010 | 0x3010 | 0x0000 | bus_mem | mbr_ld | MBR ← mem[0x010]=0x00AB |
| 6 | load1 | 0x001 | 0x010 | 0x00AB | 0x3010 | 0x0000 | bus_mbr | acc_ld | ACC ← 0x00AB |
| **End** | — | 0x001 | 0x010 | 0x00AB | 0x3010 | **0x00AB** | — | — | Ready for next fetch |

**Result:** `ACC = 0x00AB`. `PC = 0x001` (pointing to next instruction).

**Key observations:**
- `MAR` is used twice: once for the instruction address (fetch1), once for
  the data address (direct1). It is overwritten freely.
- `MBR` is also used twice: once for the instruction word, once for the
  data value. After fetch3, the instruction is safely in `IR`; MBR is free.
- The instruction takes 6 clock cycles.

---

## Trace 2 — `ADD 0x011`

**Setup:** (continuing from Trace 1)
- `PC = 0x001`; `ACC = 0x00AB`
- `mem[0x001] = 0x7011` (= `ADD 0x011`, opcode `0111`, addr `0x011`)
- `mem[0x011] = 0x0055`

| Cycle | State | PC | MAR | MBR | IR | ACC | Bus driver | Active loads | Notes |
|---|---|---|---|---|---|---|---|---|---|
| 1 | fetch1 | 0x001 | 0x010 | 0x00AB | 0x3010 | 0x00AB | bus_pc | mar_ld | MAR ← 0x001 |
| 2 | fetch2 | 0x001 | 0x001 | 0x00AB | 0x3010 | 0x00AB | bus_mem | mbr_ld, pc_inc | MBR ← mem[0x001]=0x7011; PC ← 0x002 |
| 3 | fetch3 | 0x002 | 0x001 | 0x7011 | 0x3010 | 0x00AB | bus_mbr | ir_ld | IR ← 0x7011 |
| 4 | direct1 | 0x002 | 0x001 | 0x7011 | 0x7011 | 0x00AB | bus_ir_lower | mar_ld | MAR ← 0x011 |
| 5 | direct2 | 0x002 | 0x011 | 0x7011 | 0x7011 | 0x00AB | bus_mem | mbr_ld | MBR ← mem[0x011]=0x0055 |
| 6 | add1 | 0x002 | 0x011 | 0x0055 | 0x7011 | 0x00AB | bus_alu | acc_ld | ACC ← ALU(0x00AB + 0x0055) = 0x0100 |
| **End** | — | 0x002 | 0x011 | 0x0055 | 0x7011 | **0x0100** | — | — | |

**Result:** `ACC = 0x00AB + 0x0055 = 0x0100`. Correct (171 + 85 = 256).

---

## Trace 3 — `BRZERO 0x000` (branch not taken)

**Setup:**
- `PC = 0x002`; `ACC = 0x0100` (non-zero — branch will NOT be taken)
- `mem[0x002] = 0xA000` (= `BRZERO 0x000`, opcode `1010`, addr `0x000`)
- `zero_flag = '0'` (because `ACC = 0x0100 ≠ 0`)

| Cycle | State | PC | MAR | MBR | IR | ACC | Bus driver | Active loads | Notes |
|---|---|---|---|---|---|---|---|---|---|
| 1 | fetch1 | 0x002 | — | — | 0x7011 | 0x0100 | bus_pc | mar_ld | MAR ← 0x002 |
| 2 | fetch2 | 0x002 | 0x002 | — | 0x7011 | 0x0100 | bus_mem | mbr_ld, pc_inc | MBR ← 0xA000; PC ← 0x003 |
| 3 | fetch3 | 0x003 | 0x002 | 0xA000 | 0x7011 | 0x0100 | bus_mbr | ir_ld | IR ← 0xA000 |
| 4 | branch1 | 0x003 | — | 0xA000 | 0xA000 | 0x0100 | bus_ir_lower | pc_ld=**0** | zero_flag='0' → condition false → PC unchanged |
| **End** | — | **0x003** | — | 0xA000 | 0xA000 | 0x0100 | — | — | Branch NOT taken; PC still 0x003 |

**Result:** `PC = 0x003` (the next sequential instruction). The branch to
`0x000` did not happen because `ACC ≠ 0`.

**Now trace the same instruction with `ACC = 0x0000` (branch taken):**

| Cycle | State | PC | MAR | MBR | IR | ACC | Bus driver | Active loads | Notes |
|---|---|---|---|---|---|---|---|---|---|
| 1 | fetch1 | 0x002 | — | — | — | **0x0000** | bus_pc | mar_ld | MAR ← 0x002 |
| 2 | fetch2 | 0x002 | 0x002 | — | — | 0x0000 | bus_mem | mbr_ld, pc_inc | MBR ← 0xA000; PC ← 0x003 |
| 3 | fetch3 | 0x003 | 0x002 | 0xA000 | — | 0x0000 | bus_mbr | ir_ld | IR ← 0xA000 |
| 4 | branch1 | 0x003 | — | 0xA000 | 0xA000 | 0x0000 | bus_ir_lower | pc_ld=**1** | zero_flag='1' → PC ← 0x000 |
| **End** | — | **0x000** | — | 0xA000 | 0xA000 | 0x0000 | — | — | Branch TAKEN; PC jumps to 0x000 |

Notice: `PC` was incremented to `0x003` in fetch2 — then overwritten to
`0x000` in branch1. The increment was wasted work, but that is fine. This
is the standard fetch-then-branch pattern.

---

## Trace 4 — `ILOAD 0x020`

**Setup:**
- `PC = 0x003`; `ACC = 0x0000`
- `mem[0x003] = 0x5020` (= `ILOAD 0x020`, opcode `0101`, addr `0x020`)
- `mem[0x020] = 0x0050` (the pointer — points to address 0x050)
- `mem[0x050] = 0x00FF` (the actual data)

| Cycle | State | PC | MAR | MBR | IR | ACC | Bus driver | Active loads | Notes |
|---|---|---|---|---|---|---|---|---|---|
| 1 | fetch1 | 0x003 | — | — | — | 0x0000 | bus_pc | mar_ld | MAR ← 0x003 |
| 2 | fetch2 | 0x003 | 0x003 | — | — | 0x0000 | bus_mem | mbr_ld, pc_inc | MBR ← 0x5020; PC ← 0x004 |
| 3 | fetch3 | 0x004 | 0x003 | 0x5020 | — | 0x0000 | bus_mbr | ir_ld | IR ← 0x5020 |
| 4 | direct1 | 0x004 | — | 0x5020 | 0x5020 | 0x0000 | bus_ir_lower | mar_ld | MAR ← 0x020 (pointer address) |
| 5 | direct2 | 0x004 | 0x020 | 0x5020 | 0x5020 | 0x0000 | bus_mem | mbr_ld | MBR ← mem[0x020] = 0x0050 (the pointer) |
| 6 | indirect1 | 0x004 | 0x020 | 0x0050 | 0x5020 | 0x0000 | bus_mbr | mar_ld | MAR ← 0x0050 (load pointer into MAR) |
| 7 | indirect2 | 0x004 | 0x050 | 0x0050 | 0x5020 | 0x0000 | bus_mem | mbr_ld | MBR ← mem[0x050] = 0x00FF (actual data) |
| 8 | iload1 | 0x004 | 0x050 | 0x00FF | 0x5020 | 0x0000 | bus_mbr | acc_ld | ACC ← 0x00FF |
| **End** | — | 0x004 | 0x050 | 0x00FF | 0x5020 | **0x00FF** | — | — | |

**Result:** `ACC = 0x00FF`. The chain: IR[11:0]=0x020 → mem[0x020]=0x050
→ mem[0x050]=0x00FF. Two levels of indirection, 8 clock cycles.

**Key observation:** MAR is overwritten twice — once with 0x020 (pointer
address) in direct1, and again with 0x050 (actual data address) in
indirect1. This is correct and expected.

---

## Trace 5 — `DSTORE 0x100` (continuation of Traces 1 and 2)

**Setup:** (continuing from Trace 2)
- `PC = 0x002`; `ACC = 0x0100`
- `mem[0x002] = 0x4100` (= `DSTORE 0x100`, opcode `0100`, addr `0x100`)
- We will write `ACC = 0x0100` to address `0x100`

| Cycle | State | PC | MAR | MBR | IR | ACC | Bus driver | Active loads | Notes |
|---|---|---|---|---|---|---|---|---|---|
| 1 | fetch1 | 0x002 | 0x011 | 0x0055 | 0x7011 | 0x0100 | bus_pc | mar_ld | MAR ← 0x002 |
| 2 | fetch2 | 0x002 | 0x002 | 0x0055 | 0x7011 | 0x0100 | bus_mem | mbr_ld, pc_inc | MBR ← 0x4100; PC ← 0x003 |
| 3 | fetch3 | 0x003 | 0x002 | 0x4100 | 0x7011 | 0x0100 | bus_mbr | ir_ld | IR ← 0x4100 |
| 4 | direct1 | 0x003 | 0x002 | 0x4100 | 0x4100 | 0x0100 | bus_ir_lower | mar_ld | MAR ← 0x100 (destination address) |
| 5 | direct2 | 0x003 | 0x100 | 0x4100 | 0x4100 | 0x0100 | bus_mem | mbr_ld | MBR ← mem[0x100] (discarded — STORE doesn't use this) |
| 6 | store1 | 0x003 | 0x100 | (stale) | 0x4100 | 0x0100 | bus_acc | mbr_ld, mem_we | ACC → bus → MBR; mem[0x100] ← ACC = 0x0100 |
| **End** | — | 0x003 | 0x100 | 0x0100 | 0x4100 | **0x0100** | — | — | mem[0x100] now contains 0x0100 |

**Result:** `mem[0x100] = 0x0100`. `ACC` is unchanged. `PC = 0x003`.

**Key observations:**
- Cycle 5 (`direct2`) reads memory into MBR — this value is immediately
  discarded in cycle 6 when ACC drives the bus. This is the shared-state
  overhead described in Module 6 §5.
- Cycle 6 (`store1`): `bus_acc=1` and `mem_we=1` fire simultaneously.
  ACC (0x0100) drives the bus; MBR latches it; memory writes it to MAR (0x100).
- DSTORE takes **6 cycles** — the same as DLOAD, because both share the
  `direct1`/`direct2` path.

---

## Viva-style trace questions

After working through all five traces, practise these without looking at
any notes. Give yourself 10 minutes per trace.

1. Trace `NEGATE` starting from `ACC = 0x0003`, `PC = 0x005`.
   Write out all 5 states (fetch1, fetch2, fetch3, neg1, neg2). What is
   `ACC` after `neg1`? After `neg2`? Verify: `0x0003 + NOT(0x0003) = 0xFFFF`
   (all ones), so `NOT(0x0003) = 0xFFFC` and `0xFFFC + 1 = 0xFFFD`.

2. Trace `CLOAD -1` (opcode `0010`, operand = `0xFFF`).
   Opcode `0010` → `cload1`. IR[11:0] = `0xFFF` = `111111111111`. Sign-extend:
   IR[11] = 1, so bits 15:12 are all 1. ACC ← `1111 111111111111` = `0xFFFF`.
   Verify: `0xFFFF` in 16-bit two's complement = −1.

3. Trace `BRANCH 0x010` starting from `PC = 0x007`.
   How many cycles total? What is `PC` after `fetch2`? After `branch1`?

4. Trace `CLOAD 10` followed immediately by `DSTORE 0x100` (the first two
   instructions of Deliverable 1). Number cycles continuously from 1.
   What is `mem[0x100]` after cycle 10?

---

Next: **Module 8 — Pen-and-Paper Exercises and Viva Preparation**
