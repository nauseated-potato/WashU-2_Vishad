# Week 5 · Module 1 — From Components to a CPU: Datapath Concepts

Weeks 1 through 4 built the individual pieces: combinational logic, sequential
registers, FSMs, an ALU, and a RAM. Each piece was self-contained — you
simulated it in isolation and verified it worked on its own.

This week you connect them. The result is a tiny but real processor: a circuit
that fetches instructions from memory, decodes them, executes them on an
accumulator register through the ALU, and stores results back to memory.
It is not the full WashU-2 CPU — that comes in Weeks 7 and 8 — but it
shares its fundamental structure exactly. Every concept introduced this week
appears again, at larger scale, when you build the real CPU.

> **Video — How does a CPU work? (branch education, 20 min):**
> [How a CPU Works — Branch Education](https://www.youtube.com/watch?v=cNN_tTXABUA)
> *(Detailed visual walkthrough of fetch-decode-execute in a real processor —
> watch before reading this module if the concept is unfamiliar)*
>
> **Video — Building a simple CPU (Ben Eater 8-bit series intro):**
> [What is a clock signal? — Ben Eater](https://www.youtube.com/watch?v=kRlSFm519Bo)
> *(The first video in a series that builds exactly the kind of machine you
> are building this week — context for why each block exists)*

---

## 1. The three parts of every processor

Every processor, from the simplest microcontroller to the largest server
chip, has the same three structural parts:

**1. The datapath** — the wires and functional units that data flows through.
This includes: registers that hold values, an ALU that computes on them,
buses that carry data between units, and memory interfaces that read/write
external storage. The datapath does not decide *what* to do — it just
provides the *capability* to do things.

**2. The control unit** — the FSM that decides what the datapath does each
clock cycle. It reads the current instruction, decodes it, and generates
the control signals (ALU op code, register write enable, memory write enable,
multiplexer selects) that steer data through the datapath in the right way.

**3. The memory** — storage for both the program (instructions) and the
data the program manipulates. In simple designs these share one memory; in
more advanced architectures they are separate (Harvard architecture).

The mini-datapath you build this week has all three parts, though the control
unit is simplified: instead of a full instruction-decode FSM, it uses a
small state counter that steps through a fixed fetch–execute sequence.

---

## 2. The accumulator architecture

The simplest possible CPU organisation is the **accumulator architecture**:
there is exactly one general-purpose register, called the **accumulator**
(`acc`). Every ALU operation reads one operand from `acc`, and writes its
result back to `acc`. The second operand comes from memory (or is a constant
embedded in the instruction).

```text
          ┌──────────────────────────────────────────┐
          │              DATAPATH                     │
          │                                           │
          │  ┌──────┐    ┌───────┐    ┌───────────┐  │
 instr ──►│  │decode│──► │  ALU  │──► │accumulator│  │
          │  └──────┘    └───────┘    └─────┬─────┘  │
          │      ▲            ▲             │        │
          │      │       data │             │ acc     │
          │   ┌──┴──────────────────────────▼──────┐ │
          │   │              RAM                    │ │
          │   └────────────────────────────────────┘ │
          └──────────────────────────────────────────┘
```

**Advantages of the accumulator architecture:**
* Instruction encoding is simple: most instructions only need to specify one address (the other operand is always `acc`).
* Very little hardware is needed — one register, one ALU, one memory.

**Disadvantages:**
* Every intermediate result must be stored to memory and reloaded.
* With only one register, you cannot keep multiple live values. This is exactly why real CPUs have 8, 16, or 32 general-purpose registers.

The WashU-2 CPU is an accumulator architecture. Understanding it deeply
this week means the WashU-2 ISA in Week 6 will feel natural rather than
arbitrary.

---

## 3. The fetch–execute cycle

Every instruction the CPU runs goes through the same sequence of steps.
For a simple accumulator machine with no separate instruction register, the
cycle looks like this:

```text
┌──────────────────────────────────────────────────────────────┐
│                    FETCH–EXECUTE CYCLE                        │
│                                                               │
│  State 1 — FETCH:                                             │
│    Present program counter (PC) as address to memory.         │
│    Read instruction from RAM.                                 │
│                                                               │
│  State 2 — DECODE:                                            │
│    Inspect the instruction bits.                              │
│    Determine: what operation? what memory address?            │
│                                                               │
│  State 3 — EXECUTE:                                           │
│    Perform the operation:                                      │
│      - ALU computes result using acc and operand.             │
│      - Write result back to acc (or to memory for STORE).     │
│      - Increment PC (or branch to new address).               │
│                                                               │
│  → return to State 1                                          │
└──────────────────────────────────────────────────────────────┘
```

The mini-datapath this week uses a **four-state cycle**: `S_FETCH1`,
`S_FETCH2`, `S_EXECUTE`, and `S_WRITEBACK`. The two fetch states are needed
to account for the RAM's one-cycle registered read latency (explained fully
in Module 2 §5). Decode happens combinationally in `S_EXECUTE` — as soon as
the instruction register holds the correct instruction, the decode logic
derives the opcode and operand address immediately.

The real WashU-2 CPU uses a 17-state FSM to implement a more complete
version of this same cycle. You will study that in Week 6.

---

## 4. Control signals: what the FSM drives

The control unit does not carry data — it carries **control signals**: single
bits (or small vectors) that tell each datapath component what to do this
cycle. The complete set of control signals for the mini-datapath is small:

| Signal | Width | Drives | Meaning |
|---|---|---|---|
| `alu_op` | 3 bits | ALU | Which operation to perform |
| `acc_ld` | 1 bit | Accumulator register | `'1'` = capture ALU result this cycle |
| `mem_we` | 1 bit | RAM | `'1'` = write to RAM this cycle |
| `pc_inc` | 1 bit | Program counter | `'1'` = increment PC this cycle |
| `ir_ld`  | 1 bit | Instruction register | `'1'` = capture memory output this cycle |
| `addr_sel` | 1 bit | Address mux | `'0'` = PC drives addr, `'1'` = operand addr drives addr |

Every clock cycle, the FSM sets each of these signals. The datapath
components respond immediately (combinational) or on the next clock edge
(registered), depending on the component type.

This is the key insight of stored-program computers: **the program is data,
but control signals are not data**. The instructions stored in RAM tell the
FSM which combination of control signals to assert each cycle. The FSM's
only job is to implement that mapping.

---

## 5. The instruction format

The mini-datapath supports three instructions. Each instruction is 8 bits wide
and is encoded as follows:

```text
 Bits:  7  6  5  4  3  2  1  0
        ──────────  ──────────
         opcode      operand
         (3 bits)    (5 bits — memory address or constant)
```

| Opcode | Mnemonic | Operation | Description |
|---|---|---|---|
| `000` | `LOAD addr`  | `acc ← mem[addr]` | Load value from memory address into acc |
| `001` | `ADD  addr`  | `acc ← acc + mem[addr]` | Add memory value to acc |
| `010` | `STORE addr` | `mem[addr] ← acc` | Store acc to memory address |
| `011` | `HALT`       | stop | Assert done, freeze PC |

The operand field (bits 4..0) is a 5-bit memory address, giving access to
32 memory locations. For `HALT`, the operand field is ignored.

**Encoding examples:**

| Assembly | Binary | Hex |
|---|---|---|
| `LOAD 0x02` | `000 00010` | `0x02` |
| `ADD  0x03` | `001 00011` | `0x23` |
| `STORE 0x05`| `010 00101` | `0x45` |
| `HALT`      | `011 00000` | `0x60` |

This instruction format is intentionally simple. The WashU-2 ISA uses a
similar (but richer) format with 14 instructions and a larger address space,
which you study in Week 6.

---

## 6. A complete worked example: a micro-program

To make the week concrete, here is a complete program for the mini-datapath.
The program computes `result = A + B` where A and B are stored in memory,
and stores the result back to memory.

Memory layout:

| Address | Initial value | Role |
|---|---|---|
| 0x00 | `LOAD 0x10` | Instruction 0 |
| 0x01 | `ADD  0x11` | Instruction 1 |
| 0x02 | `STORE 0x12`| Instruction 2 |
| 0x03 | `HALT`      | Instruction 3 |
| 0x10 | `0x07` (7)  | Operand A |
| 0x11 | `0x05` (5)  | Operand B |
| 0x12 | `0x00`      | Result (will be written) |

Execution trace (high-level — see Module 4 for the full cycle-by-cycle
version with all four states per instruction):

```text
Instr#  Instruction     PC before   acc after   mem[0x12] after
  0     LOAD 0x10       0x00        0x07           0x00      acc ← mem[0x10]=7
  1     ADD  0x11       0x01        0x0C           0x00      acc ← 7+5=12
  2     STORE 0x12      0x02        0x0C           0x0C      mem[0x12] ← 12
  3     HALT            0x03        0x0C           0x0C      done='1'
```

After 12 cycles total (4 cycles × 3 executed instructions, plus the cycles
spent reaching `S_HALT` for HALT — see Module 4 for the exact count),
`mem[0x12]` contains `0x0C` (12 = 7+5). The `done` signal is high. The PC
no longer increments.

> **Why 4 cycles per instruction?** Each instruction goes through
> `S_FETCH1 → S_FETCH2 → S_EXECUTE → S_WRITEBACK`. This uniform timing
> comes from the RAM's one-cycle registered read latency — Module 2 §5-8
> derives it in full, and Module 4 gives the complete cycle-by-cycle trace
> for this exact program. For now, the instruction-level summary above is
> enough to understand *what* the program computes; Module 4 shows
> *exactly when* each register changes.

---

## 7. VHDL component instantiation

The mini-datapath is a **structural design**: it instantiates sub-components
(ALU, RAM, registers) and wires them together. VHDL has two syntaxes for
instantiating components. Both are correct; the direct entity instantiation
is preferred here because it does not require a `component` declaration:

```vhdl
-- Direct entity instantiation (preferred for this course)
alu_inst : entity work.alu4
    port map (
        a      => acc_reg,
        b      => mem_data,
        op     => alu_op,
        result => alu_result,
        zero   => alu_zero
    );

-- Component instantiation (requires a prior 'component' declaration)
component alu4 is
    port ( ... );
end component;
...
alu_inst : alu4
    port map ( ... );
```

The `entity work.alu4` syntax tells the compiler to find the entity named
`alu4` in the `work` library (the current project). As long as `alu4.vhd`
is in the same Quartus project, this works without any extra declaration.

When two port names match exactly, you can use **named association**
(`port_name => signal_name`) which is always unambiguous, or **positional
association** which maps ports by their declaration order. Always use named
association — it is immune to order changes and self-documenting.

---

## 8. Summary: what you need before Module 2

Before reading Module 2, make sure you can answer these:

1. Name the three structural parts of every processor.
2. What does the accumulator register hold?
3. What is a control signal, and who generates it?
4. For the mini-datapath instruction format, what do bits 7..5 encode?
5. Trace the fetch–execute cycle for the `ADD` instruction using the example program in §6. Which cycles touch the ALU? Which touch the RAM?

---

Next: **Module 2 — Datapath Architecture and Signal Map**