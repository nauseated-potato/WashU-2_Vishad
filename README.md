# WashU-2 CPU — Building a 16-bit Processor from Scratch with VHDL

> An 8-week mentorship project where you learn VHDL from zero and then design,
> build, and verify a working 16-bit accumulator-based CPU — entirely by hand,
> with no starter code.

---

## Table of Contents

1. [About the Project](#1-about-the-project)
2. [What We Are Building](#2-what-we-are-building)
3. [Tech Stack](#3-tech-stack)
4. [Repository & Submission Structure](#4-repository--submission-structure)
5. [How It Works — Architecture & Flow](#5-how-it-works--architecture--flow)
6. [Progress & Weekly Materials](#6-progress--weekly-materials)
7. [Resources](#7-resources)
8. [Ground Rules](#8-ground-rules)

---

## 1. About the Project

The **WashU-2 CPU** is a 16-bit, accumulator-based, multi-cycle processor
controlled by a 17-state finite state machine. It was originally introduced by
Prof. Jon Turner (Washington University in St. Louis) as a teaching
architecture, and in this project we rebuild it from the ground up in VHDL.

This is not a "fill in the blank" exercise. By the end of the program, you
will have written **every line** of the CPU and its testbench yourself —
the entity, the register set, the ALU, the instruction decoder, the finite
state machine, and the memory interface — and will be able to explain how each
piece works.

The project is structured so that nobody is thrown into the deep end. The first
five weeks are a hands-on VHDL bootcamp in which you build progressively
larger digital circuits (gates → registers → FSMs → an ALU → a small
datapath). Week 6 is a dedicated, pen-and-paper study of the WashU-2
architecture. Weeks 7–8 are the capstone, where everything learned comes
together into a complete, simulated processor.

| Property | Value |
|---|---|
| Data width | 16 bits |
| Architecture | Accumulator-based (single working register) |
| Pipeline | None — multi-cycle, one instruction at a time |
| Control | Finite State Machine with 17 states |
| Cycles / instruction | 4–7 clock cycles |
| Instruction size | 16 bits (4-bit opcode + 12-bit operand) |
| Instruction set | 14 instructions |
| Duration | 8 weeks |
| Format | Individual project (forked repository) |
| Language | VHDL (design + testbench) |

**Learning outcomes**

- Think in hardware: concurrency, signals vs. variables, clock-driven logic
- Write synthesizable VHDL: entities, architectures, processes, FSMs
- Design and debug finite state machines
- Understand CPU microarchitecture: fetch, decode, execute, writeback
- Understand instruction set architecture: opcodes, addressing modes, encoding
- Write self-checking testbenches and read simulation waveforms
- Handle bidirectional buses and tri-state arbitration

---

## 2. What We Are Building

A complete, working **WashU-2 CPU** in VHDL plus a verification testbench.

### Register set

| Register | Width | Purpose |
|---|---|---|
| `ACC` | 16-bit | Accumulator — holds working data / ALU result |
| `PC` | 16-bit | Program Counter — address of the next instruction |
| `iReg` | 16-bit | Instruction Register — current fetched instruction |
| `IAR` | 16-bit | Indirect Address Register — for ILOAD / ISTORE |
| `THIS` | 16-bit | Saved PC — address of the executing instruction |
| `tick` | 4-bit | Sub-cycle counter within each FSM state |

### Instruction set (14 instructions)

| Opcode | Mnemonic | Cycles | Operation |
|---|---|---|---|
| `0x0000` | HALT | 4 | Stop execution |
| `0x0001` | NEGATE | 4 | `ACC = two's complement of ACC` |
| `0x01xx` | BRANCH | 4 | `PC = THIS + sign_extend(offset)` |
| `0x02xx` | BRZERO | 4 | Branch if `ACC == 0` |
| `0x03xx` | BRPOS | 4 | Branch if `ACC > 0` |
| `0x04xx` | BRNEG | 4 | Branch if `ACC < 0` |
| `0x05xx` | BRIND | 5 | `PC = memory[target]` (indirect) |
| `0x1xxx` | CLOAD | 4 | `ACC = sign_extend(imm12)` |
| `0x2xxx` | DLOAD | 5 | `ACC = memory[page:adr]` |
| `0x3xxx` | ILOAD | 7 | `ACC = memory[memory[page:adr]]` |
| `0x5xxx` | DSTORE | 4 | `memory[page:adr] = ACC` |
| `0x6xxx` | ISTORE | 6 | `memory[memory[page:adr]] = ACC` |
| `0x8xxx` | ADD | 5 | `ACC = ACC + memory[page:adr]` |
| `0xCxxx` | AND | 5 | `ACC = ACC AND memory[page:adr]` |

### Deliverables by the end of the project

- `cpu_design.vhd` — the full CPU: entity, signals, ALU, address computation,
  debug multiplexer, decode function, main sequential process, memory control
  process.
- `cpu_tb.vhd` — a self-contained testbench: 256-word memory, clock generator,
  stimulus process, and result verification via `report` statements.
- A test program (encoded in the testbench memory) exercising arithmetic
  (ADD), logic (AND), data movement (CLOAD / DLOAD / DSTORE), and branching.
- A final report with waveform screenshots and analysis.

The bootcamp weeks also produce standalone artifacts (a counter, an FSM, a
4-bit ALU, a RAM module, a mini-datapath) that act as stepping stones.

---

## 3. Tech Stack

| Layer | Tool / Technology | Notes |
|---|---|---|
| Hardware description language | **VHDL** (IEEE 1076) | `std_logic_1164`, `numeric_std` |
| Primary toolchain | **Intel Quartus Prime** | Project, design entry, compilation, synthesis |
| Simulation & waveforms | **ModelSim / Questa** (bundled with Quartus) | Compile, run, and view waveforms |
| Version control | **Git** + GitHub/GitLab | One repo per person |
| Documentation | **Markdown / PDF** | Reports and notes |

**Quartus is the primary tool for the whole project** — design entry,
compilation, simulation, and waveform viewing all happen inside the Quartus
environment (using its bundled ModelSim/Questa simulator). Use it for
everything it can handle; no separate or additional tools are needed.

---

## 4. Repository & Submission Structure

**Fork** the project repository to your own GitHub/GitLab account. All work
is committed to your fork. Keep bootcamp weeks and the final CPU cleanly
separated so that progress is easy to track and review.

```
washu2-cpu-<your-name>/             ← your fork
│
├── README.md                       # Your info, build/run instructions
│
├── bootcamp/                       # Weeks 1–5: VHDL learning artifacts
│   │
│   ├── week1/
│   │   ├── exercise_1/             # One folder per exercise (names assigned each week)
│   │   │   ├── <design>.vhd
│   │   │   └── tb_<design>.vhd
│   │   ├── exercise_2/
│   │   │   ├── <design>.vhd
│   │   │   └── tb_<design>.vhd
│   │   ├── exercise_3/
│   │   │   ├── <design>.vhd
│   │   │   └── tb_<design>.vhd
│   │   └── week1_report.pdf        # RTL netlists + simulation waveforms for all Week 1 exercises
│   │
│   ├── week2/
│   │   ├── exercise_1/
│   │   │   ├── <design>.vhd
│   │   │   └── tb_<design>.vhd
│   │   ├── exercise_2/
│   │   │   ├── <design>.vhd
│   │   │   └── tb_<design>.vhd
│   │   ├── exercise_3/
│   │   │   ├── <design>.vhd
│   │   │   └── tb_<design>.vhd
│   │   └── week2_report.pdf        # RTL netlists + simulation waveforms for all Week 2 exercises
│   │
│   ├── week3/
│   │   ├── exercise_1/
│   │   │   ├── <design>.vhd
│   │   │   └── tb_<design>.vhd
│   │   ├── exercise_2/
│   │   │   ├── <design>.vhd
│   │   │   └── tb_<design>.vhd
│   │   ├── exercise_optional/       # Optional — include if attempted
│   │   │   ├── <design>.vhd
│   │   │   └── tb_<design>.vhd
│   │   └── week3_report.pdf        # RTL netlists + simulation waveforms for all Week 3 exercises
│   │
│   ├── week4/
│   │   ├── exercise_1/
│   │   │   ├── <design>.vhd
│   │   │   └── tb_<design>.vhd
│   │   ├── exercise_2/
│   │   │   ├── <design>.vhd
│   │   │   └── tb_<design>.vhd
│   │   ├── exercise_optional/
│   │   │   ├── <design>.vhd
│   │   │   └── tb_<design>.vhd
│   │   └── week4_report.pdf        # RTL netlists + simulation waveforms for all Week 4 exercises
│   │
│   └── week5/
│       ├── exercise_1/
│       │   ├── <design>.vhd
│       │   └── tb_<design>.vhd
│       └── week5_report.pdf        # RTL netlists + simulation waveforms for Week 5
│
├── architecture-study/             # Week 6: pen-and-paper deliverables
│   ├── instruction_trace.pdf       # 5-instruction cycle-by-cycle walkthrough
│   └── fsm_state_diagram.pdf       # Hand-drawn 17-state diagram
│
├── cpu/                            # Weeks 7–8: the final CPU (from scratch)
│   ├── cpu_design.vhd              # Complete WashU-2 CPU
│   ├── cpu_tb.vhd                  # Complete testbench + test program
│   └── quartus/                    # Quartus project files (.qpf, .qsf)
│
├── docs/
│   └── final_report.pdf            # Week 8 report (architecture, design, results)
│
└── .gitignore                      # Ignore Quartus build/output artifacts
```

### Weekly report PDF

Each week's folder contains **one PDF** (`weekN_report.pdf`) covering all
exercises for that week. The PDF must include, for every exercise:

- The **RTL netlist** view (from Quartus RTL Viewer) showing the synthesised
  logic for your design.
- The **simulation waveform** screenshot (from ModelSim) with all relevant
  signals labelled and at least the required number of cycles visible.
- A brief note (2–3 sentences) on any bugs you encountered and how you
  resolved them.

Compile all exercises for a given week into a single PDF before submitting —
do not submit separate PDFs per exercise.

### Submission policy

| Submission | When | What goes in |
|---|---|---|
| **Mid submission** | End of Week 4 | `bootcamp/week1/` through `bootcamp/week4/`, each with per-exercise folders and `weekN_report.pdf` |
| **End submission** | End of Week 8 | Complete `bootcamp/week5/`, `architecture-study/`, `cpu/`, `docs/final_report.pdf`, full fork zipped |

Commit regularly with meaningful messages. The commit history is itself
evidence that the work was done incrementally and by hand.

---

## 5. How It Works — Architecture & Flow

### 5.1 System block diagram

This is how the CPU and testbench connect during simulation.

```
                         +-------------------------------+
                         |        TESTBENCH (cpu_tb)     |
                         |                               |
   clk / reset  ---------+--->  Clock & Stimulus          |
                         |                               |
                         |   +-----------------------+   |
                         |   |  256 x 16-bit Memory  |   |
                         |   +-----------------------+   |
                         |        ^            |         |
                         |        | aBus       | dBus    |
                         |   (address)     (data, bi-dir)|
                         +--------|------------|---------+
                                  |            |
                         =========|============|=========  shared bus
                                  |            |
                         +--------v------------v---------+
                         |        WashU-2 CPU            |
                         |       (cpu_design)            |
                         |                               |
                         |   en / rw  -->  Memory ctrl   |
                         |                               |
                         |   +-----+   +-----+   +-----+ |
                         |   | PC  |   |iReg |   | IAR | |
                         |   +-----+   +-----+   +-----+ |
                         |        \       |       /      |
                         |         v      v      v       |
                         |     +---------------------+   |
                         |     |  17-state FSM       |   |
                         |     |  (control unit)     |   |
                         |     +---------------------+   |
                         |              |                |
                         |       +------v------+         |
                         |       | ACC |  ALU  |         |
                         |       +-------------+         |
                         +-------------------------------+
```

### 5.2 The universal instruction cycle

Every one of the 14 instructions follows the same overall flow. Only the
EXECUTE phase differs in length (1–4 cycles) and behaviour.

```
   +---------+      +---------+      +-----------+      +--------+
   |  FETCH  | ---> | DECODE  | ---> |  EXECUTE  | ---> | WRAPUP | --+
   | (3 cyc) | tick2| (in FSM)|      | (1-4 cyc) |      |        |   |
   +---------+      +---------+      +-----------+      +--------+   |
        ^                                                           |
        +-----------------------------------------------------------+
                       (return to FETCH for next instruction)
```

1. **FETCH (3 cycles)** — put `PC` on the address bus, read the instruction
   from memory into `iReg`, save `THIS = PC`, increment `PC`.
2. **DECODE** — examine the 4-bit opcode in `iReg`, choose the next FSM state.
3. **EXECUTE** — perform the operation (ALU op, memory access, branch, etc.).
4. **WRAPUP** — reset the `tick` counter and return to FETCH.

### 5.3 Address computation

```
opAdr  = THIS[15:12] & iReg[11:0]            (page-relative operand address)
target = THIS + sign_extend(iReg[7:0])       (PC-relative branch target)
```

---

## 6. Progress & Weekly Materials

The project runs over 8 weeks. The weekly breakdown below shows the topic
sequence and where the two submissions fall.

| Week | Topic |
|---|---|
| 1 | Digital logic refresher + VHDL first steps |
| 2 | Sequential logic & processes |
| 3 | Finite state machines in VHDL |
| 4 | ALU + memory + tri-state buses **(Mid submission)** |
| 5 | Mini-datapath: a 3-instruction "CPU" |
| 6 | WashU-2 architecture deep dive (pen & paper) |
| 7 | CPU implementation from scratch — part 1 |
| 8 | CPU part 2 + testbench + report **(End submission)** |

Material for each week — reading, guided exercises, and reference files — is
shared separately at or before the start of that week. Work through the
material for the current week before its session, and keep up with the
checkpoints below.

### Checkpoints

| Checkpoint | When | Gate |
|---|---|---|
| CP1 | End of Week 2 | Toolchain working; can simulate basic circuits |
| CP2 — **Mid submission** | End of Week 4 | FSM + ALU + RAM submitted with testbenches |
| CP3 | End of Week 6 | Mini-datapath built + architecture mastered on paper |
| CP4 | End of Week 7 | Partial CPU runs fetch–decode + simple instructions |
| CP5 — **End submission** | End of Week 8 | Full CPU + testbench + report submitted |

---

## 7. Resources

These are the **general references** used throughout the project. Read the
relevant sections as the topics come up. In addition to these, **week-specific
resources are provided separately each week** to support that week's material.

### Primary textbooks

- **Free Range VHDL** — Bryan Mealy & Fabrizio Tappero. A free,
  beginner-friendly VHDL textbook; our main language reference.
  <http://freerangefactory.org/>
- **Digital Design and Computer Architecture** — Harris & Harris.
  Chapters 1–4 for digital fundamentals, Chapters 6–7 for processor design.
- **The Designer's Guide to VHDL** — Peter Ashenden. A deeper reference for
  when you want the full picture of a language construct.

### Lectures & video series

- **Ben Eater — "Build an 8-bit computer" (YouTube series)**. The best
  intuition for what a CPU physically does; no prerequisites.
  <https://eater.net/8bit>
- **Nandland — VHDL tutorials & testbench walkthroughs**. Practical, example-
  driven, and aligned with how we write testbenches.
  <https://nandland.com/>
- **Prof. Jon Turner — WashU CPU course material**. The origin of the WashU-2
  architecture this project is built on.
  <https://www.arl.wustl.edu/~jon.turner/cse/260/>

### Tool documentation

- **Intel Quartus Prime** — installation, project setup, and compilation,
  from Intel's official documentation and download portal.
- **ModelSim / Questa** (bundled with Quartus) — compiling VHDL, running
  simulations, and reading waveforms; covered in the Intel/Quartus docs.

> The provided **CPU Implementation Documentation** (instruction-by-instruction
> cycle tables) is your most important reference for Weeks 7–8 — study it
> thoroughly before starting the CPU.

---

## 8. Ground Rules

- **No AI-generated code.** All VHDL must be written by hand. You must be able
  to explain every line of your code. This is non-negotiable and is the single
  most important rule of the project.
- **This is an individual project.** Fork the repository to your own account and do your own work. Sharing code with others is not allowed.
- **Understand before you code.** Especially Week 6 — do not start the CPU
  until you can trace instructions on paper.
- **Comment your code.** Brief, meaningful comments explaining your logic.
- **Commit incrementally.** A healthy commit history protects you and shows
  your process.
- **Keep evidence.** Save waveform screenshots as you go; you will need them
  for both submissions.

---

*WashU-2 CPU mentorship project. Architecture credit: Prof. Jon Turner,
Washington University in St. Louis.*
