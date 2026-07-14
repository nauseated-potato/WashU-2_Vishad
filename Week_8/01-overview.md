# Week 8 · Module 1 — Completing the CPU: Overview

Week 7 gave you a working CPU that fetches, decodes, and executes five
instructions. Week 8 adds the remaining nine. When this week is done,
`washu2_cpu.vhd` is a complete WashU-2 processor executing all 14 instructions.

---

## 1. What you add this week

| Stage | Instructions | New FSM states |
|---|---|---|
| D | `ADD`, `AND` | `add1`, `and1` |
| E | `BRANCH`, `BRZERO`, `BRPOS`, `BRNEG` | `branch1` (shared) |
| F | `BRIND` | `brind1`, `brind2`, `brind3` |
| G | `ILOAD`, `ISTORE` | `indirect1`, `indirect2`, `iload1`, `istore1` |

---

## 2. What does NOT change from Week 7

- The entity declaration — identical.
- The declarative region — all 22 states and all signals already declared.
- Process 1 (registered elements) — identical, no new registers.
- The bus multiplexer — identical.
- Flag logic — identical.

The only file you edit is `washu2_cpu.vhd`, and only in two places:
1. The ALU process (one change needed for ADD/AND — Module 2 §2).
2. The FSM process (new `when` arms replacing placeholders).

---

## 3. The Week 7 placeholder and how to replace it

Your Week 7 FSM has this block:

```vhdl
when add1 | and1 | indirect1 | indirect2 |
     iload1 | istore1 | branch1 |
     brind1 | brind2 | brind3 =>
    next_state <= fetch1;
```

As you complete each stage, remove the relevant states from this group
and give them their own `when` arms. After Stage G, delete the block
entirely. The `when others` arm below it stays.

---

## 4. Build order and checkpoints

Work stage by stage. Compile and simulate each stage before moving on.

```
Stage D — ADD and AND           Module 2   → test: acc = 47 after ADD test
Stage E — Four branch types     Module 3   → test: BRANCH skips instructions
Stage F — BRIND                 Module 4   → test: PC jumps to mem[addr]
Stage G — ILOAD and ISTORE      Module 5   → test: acc = data at pointer target
Complete → Exercises            Module 6
```

---

## 5. Control signal reference for Week 8 states

From Week 6 Module 6 — the signals asserted in each new state:

| State | bus active | latches | other |
|---|---|---|---|
| `add1` | `bus_alu` | `acc_ld` | `alu_op=ALU_ADD` |
| `and1` | `bus_alu` | `acc_ld` | `alu_op=ALU_AND` |
| `branch1` | `bus_ir_lower` | `pc_ld`† | — |
| `brind1` | `bus_ir_lower` | `mar_ld` | — |
| `brind2` | `bus_mem` | `mbr_ld` | — |
| `brind3` | `bus_mbr` | `pc_ld` | — |
| `indirect1` | `bus_mbr` | `mar_ld` | — |
| `indirect2` | `bus_mem` | `mbr_ld` | — |
| `iload1` | `bus_mbr` | `acc_ld` | — |
| `istore1` | `bus_acc` | `mbr_ld` | `mem_we` |

†`pc_ld` in `branch1` is conditional on the flag (Module 3 §2).

---

## 6. Before writing any code

Answer these from your Week 6 notes:

1. In `add1`, what drives the bus? What is `alu_op`? What latches?
2. In `branch1`, what drives the bus? What does `pc_ld` depend on?
3. Why do four branch instructions share one FSM state?
4. In `indirect1`, what value is being moved, from where to where, and why?
5. How many memory reads does ILOAD make after the fetch? Name each state.

---

Next: **Module 2 — ADD and AND**
