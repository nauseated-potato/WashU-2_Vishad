# Week 6 · Module 1 — Overview: Why Study Architecture Before Coding?

Week 6 is deliberately different from every other week. There is **no VHDL
to write**. Instead, you spend the week reading, drawing, and tracing — on
paper — the architecture of the WashU-2 CPU that you will implement in Weeks
7 and 8.

This week gives you the architectural foundation that Week 7's coding is
directly built on. Every signal name, every state, and every bus protocol
decision in these notes maps to a VHDL signal or process arm in Week 7.
The code is a mechanical translation of the architecture — understanding it
first makes the implementation straightforward.

---

## 1. What this week covers

```
Module 1  — Overview and how to use these notes (this file)
Module 2  — WashU-2 registers, buses, and datapath organisation
Module 3  — The 14-instruction ISA: encoding, decoding, semantics
Module 4  — Address computation: direct, indirect, and immediate modes
Module 5  — The 17-state FSM: states, transitions, and control signals
Module 6  — Bus protocol and timing: how data moves each cycle
Module 7  — Cycle-by-cycle instruction traces (worked examples)
Module 8  — Pen-and-paper exercises and self-study questions
```

**Deliverables for Week 6 (no VHDL):**

| Deliverable | What it is | Where it goes |
|---|---|---|
| `instruction_trace.pdf` | Your hand-traced cycle-by-cycle table for 5 instructions | `architecture-study/` |
| `fsm_state_diagram.pdf` | Your hand-drawn 17-state FSM with all transitions and control signals | `architecture-study/` |

Both are submitted as scanned or photographed PDFs.

---

## 2. How to use these notes

These modules are **reference and explanation**, not a passive read. Every
section has an action item — a table to fill in, a diagram to draw, a trace
to complete. Do the action items on paper as you read. Do not read ahead
without completing each action item; later modules build directly on earlier
ones.

The suggested study order:

```
Day 1:  Module 2 (registers + buses) + Module 3 (ISA)
        Action: draw the datapath, fill in the ISA table
Day 2:  Module 4 (address computation) + Module 5 (FSM states)
        Action: draw the FSM skeleton, label every state
Day 3:  Module 6 (bus protocol) + Module 7 (worked traces)
        Action: trace ADD, LOAD, BRANCH with the worked examples
Day 4:  Module 8 (exercises)
        Action: complete the 5-instruction trace and draw the full FSM
Day 5:  Review + scan deliverables
```

---

## 3. The WashU-2 in context

The WashU-2 is a **16-bit accumulator-based CPU** with:
- A single accumulator register (`ACC`) for all ALU results
- A 16-bit program counter (`PC`)
- A memory address register (`MAR`) and memory buffer register (`MBR`)
- A 14-instruction ISA covering arithmetic, logic, load/store, and branches
- A single shared bus connecting all components
- A 17-state FSM as the control unit

It is not a toy. The architecture descends from the IBM 701 (1952) and the
same design principles appear in the original 8080 and 6502 processors.
Every concept — shared bus, MAR/MBR protocol, accumulator arithmetic,
multi-cycle fetch-decode-execute — is real computer architecture that appears
in production hardware.

The jump from Week 5's 4-instruction mini-CPU to the WashU-2 is large but
not discontinuous. Every component you built — the ALU, the RAM, the FSM
control unit — has a direct counterpart in the WashU-2. The differences are:
- 16-bit data width instead of 8-bit
- 14 instructions instead of 4
- A shared bus instead of direct point-to-point connections
- Multi-cycle instruction execution (up to 5 states per instruction)
- Indirect and immediate addressing modes

By the end of this week you should be able to explain every one of these
differences clearly.

> **Video — How a CPU executes instructions (Computerphile, 17 min):**
> [How a CPU Works — Computerphile](https://www.youtube.com/watch?v=XM4lGflQFvA)
> *(Covers MAR, MBR, ACC, and the fetch-execute cycle at exactly the level
> needed for Week 6 — watch on Day 1 before reading Module 2)*
>
> **Video — Accumulator-based CPU architecture (2023):**
> [Simple Accumulator CPU explained](https://www.youtube.com/watch?v=8o9pFzMPLCo)
> *(Walks through a similar ISA and bus protocol — good companion to Module 3)*

---

## 4. Notation used throughout Week 6

The following notation is used consistently in all modules. Learn it now so
it does not slow down reading later.

| Notation | Meaning | Example |
|---|---|---|
| `ACC` | Accumulator register | `ACC ← ACC + MBR` |
| `PC` | Program counter | `PC ← PC + 1` |
| `MAR` | Memory address register | `MAR ← PC` |
| `MBR` | Memory buffer register | `MBR ← mem[MAR]` |
| `IR` | Instruction register | `IR ← MBR` |
| `mem[X]` | Contents of memory at address X | `mem[MAR] ← ACC` |
| `IR[15:12]` | Bits 15 down to 12 of IR | opcode field |
| `IR[11:0]` | Bits 11 down to 0 of IR | address/operand field |
| `←` | Transfer / assignment | `MAR ← IR[11:0]` |
| `bus` | The shared 16-bit bus | all transfers go via `bus` |
| `EA` | Effective address | the final computed memory address |
| `ISA` | Instruction Set Architecture | the complete set of instructions a CPU understands |
| `RTL` | Register Transfer Language | notation describing data movement between registers |

All register transfers happen through the bus. No register can communicate
with another register without placing its value on the bus first. This is
the fundamental rule of the WashU-2 bus protocol and the source of most
multi-cycle instruction complexity.

---

Next: **Module 2 — Registers, Buses, and Datapath Organisation**
