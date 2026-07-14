# Week 8 · Module 8 — Report Guidelines and Submission

This is the final deliverable of the mentorship: `docs/final_report.pdf`
plus the completed `cpu/` folder. This module tells you what the report
needs to contain and how it will be assessed, not how to write the CPU
— by this point that's done.

---

## 1. Report structure

Write the report as a single PDF with these sections, in this order:

### 1. Architecture summary (half a page)

A short description of the WashU-2 in your own words: register set,
instruction format, FSM style (multi-cycle, no pipeline). Don't
transcribe the README — write it as if explaining the design to someone
who has not seen this project.

### 2. RTL netlist

Export the RTL Viewer output from Quartus for `washu2_cpu`. One
screenshot (or a small set, if Quartus splits it across pages) is
enough — it doesn't need per-instruction netlists, just the whole
synthesized design.

### 3. Waveform evidence — one per instruction family

Not all 14 instructions individually — group them by the FSM states
they exercise, matching Modules 2–5:

| Group | Instructions | Screenshot must show |
|---|---|---|
| Direct arithmetic | ADD, AND | `add1`/`and1`, `acc`, `mbr`, `alu_op` |
| Conditional branch | BRANCH, BRZERO, BRPOS, BRNEG | `branch1`, `pc_ld`, the relevant flag, `pc` before/after |
| Indirect branch | BRIND | `brind1`→`brind2`→`brind3`, `mar`, `mbr`, `pc` |
| Double-indirect | ILOAD, ISTORE | `indirect1`→`indirect2`, `mar`, `mbr`, and either `acc` (ILOAD) or the RAM's internal array (ISTORE) |
| Integration | all of the above together | the full Module 6 §3 program, `current_state` visible end-to-end |

For each screenshot: label the states along the timeline, and make sure
`current_state` and the relevant data signals are in hex radix and
legible at the zoom level you captured.

### 4. Bugs encountered

For each bug from Module 7 you actually hit (or any bug not covered
there), 2–3 sentences: what the symptom was, what you initially
suspected, and what the actual cause turned out to be. This section is
read closely in the viva — vague entries like "had some latch issues,
fixed them" are not sufficient; name the specific signal and state.

### 5. Cycle-count table

For each of the 14 instructions, state how many clock cycles it takes
from `fetch1` to the start of the next `fetch1` (including the 3-cycle
fetch). Cross-check this against the state list you assembled in
Module 6 §2 — an instruction's cycle count is exactly the number of
states in its path through the FSM.

### 6. Self-assessment

One paragraph: which instruction was hardest to get right and why. This
is the question most likely to open the viva — write it as your actual
answer, not as a formality.

---

## 2. What the viva checks

The mock viva is not about reciting the report — it's a spot-check that
you can explain any part of the FSM without notes. Be ready for
questions in this shape, picked essentially at random:

- "Trace `ISTORE 0x022` cycle by cycle, starting from `fetch1`. What is
  in `MAR` at the start of `indirect2`? What is in `MBR`?"
- "Why does `branch1` use `bus_ir_lower` and not `bus_ir_se`, given that
  `CLOAD` needs the sign-extended version but branch targets don't?"
- "If I changed `indirect1` to assert `bus_ir_lower` instead of
  `bus_mbr`, what would ILOAD actually load into `ACC`, given the test
  program from Module 5?"
- "What happens if two `bus_X` signals are asserted in the same state
  by mistake — what would you see on `the_bus` in simulation, and why?"

If a question stalls you, the expected move is to reconstruct the
answer from the datapath (which register can source `the_bus`, which
control signal enables which register), not to guess.

---

## 3. End submission checklist

Per `README.md` §4, the end submission includes:

- [ ] `bootcamp/week5/` — mini-datapath (if not already submitted with
      the mid submission).
- [ ] `architecture-study/` — Week 6 notes and instruction traces.
- [ ] `cpu/washu2_cpu.vhd` — compiles with zero errors, zero latch
      warnings, all 22 states present, placeholder block removed
      (Module 6 §1).
- [ ] `cpu/washu2_ram.vhd` — final test program loaded, or structured so
      the testbench can swap programs in.
- [ ] `cpu/cpu_tb.vhd` — self-checking testbench covering: the Week 7
      programs, all five Module 3 programs, the Module 4 program, both
      Module 5 programs, and the Module 6 §3 integration program.
- [ ] Waveform screenshots per §1.3 above, all legible.
- [ ] `docs/final_report.pdf` — all six sections from §1.
- [ ] Full fork zipped, per README submission policy.
- [ ] Ready for the mock viva — able to state, from memory, which states
      any given instruction visits and why, with no notes.

---

*Week 8 complete. The WashU-2 CPU now executes all 14 instructions.*
