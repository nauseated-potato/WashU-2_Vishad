# Week 6 · Module 2 — Registers, Buses, and Datapath Organisation

Before studying the instruction set or the FSM, you need a precise picture
of the hardware that executes them. This module defines every register,
every bus, and every functional unit in the WashU-2 datapath, and explains
why each exists.

> **Action item:** As you read each subsection, add the component to a
> block diagram you are drawing on paper. By the end of this module your
> diagram should show all registers connected to a single shared bus, with
> the ALU, memory, and control unit also labelled. Keep this diagram — you
> will add the FSM states and bus control signals to it in Modules 5 and 6.

---

## 1. The shared bus architecture

The WashU-2 uses a **single shared 16-bit bus**. Every data transfer between
any two components goes through this bus. Only one component may drive the
bus at any given time; all others must **tri-state** their outputs
(drive the output to a high-impedance `'Z'` state, effectively disconnecting
from the bus — the same `'Z'` you used in Week 4's bidirectional RAM).

```
          ┌────────────────────────────────────────────────────┐
          │                  16-bit shared BUS                  │
          └──┬──────┬────────┬────────┬──────────┬─────────────┘
             │      │        │        │          │
           ┌─▼─┐  ┌─▼─┐  ┌──▼──┐  ┌──▼──┐  ┌───▼───┐
           │ACC│  │ PC│  │ MAR │  │ MBR │  │  IR   │
           └───┘  └───┘  └─────┘  └──┬──┘  └───────┘
                                      │
                                   ┌──▼──────────────┐
                                   │    MEMORY        │
                                   │  (16-bit wide)   │
                                   └─────────────────┘
                                         ▲
                                   ┌─────┴─────┐
                                   │    ALU    │ ← ACC + MBR
                                   └───────────┘
```

The consequence of a shared bus: **no two transfers can happen in the same
clock cycle**. Each clock cycle allows exactly one source to drive the bus
and exactly one destination to latch it. This is why instructions take
multiple cycles — each register-to-register transfer needs its own cycle.

Compare this to the Week 5 mini-CPU which had direct point-to-point wires
between components. The shared bus uses less hardware (one bus instead of
many wires) but requires more cycles per instruction.

---

## 2. Register reference table

Study this table until you can reproduce it from memory.

| Register | Width | Purpose | Who writes to it | Who reads from it |
|---|---|---|---|---|
| `ACC` | 16 bits | Accumulator: holds current working value; one input to ALU | ALU result, MBR (for LOAD) | ALU input A, bus (for STORE) |
| `PC` | 16 bits | Program counter: address of next instruction to fetch | PC+1 incrementer, bus (for BRANCH) | MAR (during fetch) |
| `MAR` | 16 bits | Memory address register: address currently being accessed | bus (from PC or IR[11:0]) | Memory address input |
| `MBR` | 16 bits | Memory buffer register: data just read from / about to write to memory | Memory data output, bus (for STORE) | ALU input B, bus, IR |
| `IR` | 16 bits | Instruction register: holds the current instruction being executed | MBR (during fetch) | Decode logic, MAR (for address) |

> **Key observation:** MAR is never written directly by the result of a
> computation — it always receives either the PC (to fetch an instruction)
> or an address derived from the instruction (`IR[11:0]`). It is purely an
> address-holding register, never an arithmetic one.

---

## 3. The accumulator (`ACC`)

`ACC` is the central register. Every arithmetic and logic instruction reads
`ACC` as one operand and writes its result back to `ACC`. The sequence for
`ADD addr` is:

```
ACC ← ALU(ACC, MBR)
```

Where `MBR` holds `mem[addr]` fetched in an earlier state. The ALU always
takes `ACC` as its A input. The B input comes from `MBR`.

`ACC` also has a direct connection to the bus so it can be read out for
comparison (`BRZERO` checks if `ACC = 0`), for storing (`DSTORE` writes
`ACC` to memory), and for indirect addressing (`ILOAD` uses `ACC` as a
pointer).

### Zero flag

A single flag bit, derived combinationally from `ACC`:
```
zero_flag = (ACC = 0x0000)
```

This flag feeds into the branch instructions: `BRZERO` only changes the PC
if `zero_flag = '1'`. The zero flag is not a separate register — it is
computed from `ACC` every cycle.

Similarly:
- **Positive flag:** `pos_flag = (ACC[15] = '0') AND (ACC ≠ 0)`  (MSB clear and non-zero)
- **Negative flag:** `neg_flag = (ACC[15] = '1')`  (MSB set = two's complement negative)

These three flags support `BRZERO`, `BRPOS`, and `BRNEG` respectively.

---

## 4. The program counter (`PC`)

`PC` holds the address of the **next** instruction to be fetched. After each
fetch, `PC` is incremented by 1 (pointing to the following instruction).
Branch instructions write a new value to `PC` to redirect execution.

`PC` has two special connections:
1. An **incrementer**: a combinational circuit that computes `PC + 1`. The
   FSM can choose to load `PC + 1` or a branch target address into `PC`.
2. A **bus connection**: for branch instructions, the target address (from
   `IR[11:0]` or computed indirectly) is placed on the bus and loaded into
   `PC`.

---

## 5. MAR and MBR: the memory interface

`MAR` and `MBR` form the interface between the internal bus and external
memory. They are always used as a pair:

**To read from memory:**
```
Step 1: MAR ← (address)          -- load the address into MAR
Step 2: MBR ← mem[MAR]           -- memory reads MAR, presents data to MBR
        (takes one clock cycle for memory to respond)
```

**To write to memory:**
```
Step 1: MAR ← (address)          -- load the address
Step 2: MBR ← (data)             -- load the data to write
Step 3: mem[MAR] ← MBR           -- assert write enable; memory stores MBR
```

> **The MAR/MBR protocol is the single most important concept to memorise
> this week.** Every instruction that touches memory — all of them except
> HALT — uses this sequence. If you internalise this, every FSM state
> becomes obvious.

---

## 6. The instruction register (`IR`)

`IR` holds the instruction currently being executed. It is loaded from
`MBR` during the fetch cycle:

```
IR ← MBR    (where MBR holds the instruction word fetched from mem[PC])
```

`IR` is then held stable for the rest of the instruction's execution.
Its fields are:

```
 Bits:  15  14  13  12  |  11  10  9  8  7  6  5  4  3  2  1  0
        ─────────────────   ─────────────────────────────────────
           OPCODE (4 bits)         OPERAND / ADDRESS (12 bits)
```

- `IR[15:12]` — 4-bit opcode. With 4 bits, up to 16 opcodes are possible.
  The WashU-2 uses 14.
- `IR[11:0]` — 12-bit operand. For most instructions this is a **direct
  memory address** (giving access to 4096 = 2^12 locations). For `CLOAD`
  it is a **constant value**. For `BRIND` it is used differently — see
  Module 4.

---

## 7. The ALU

The WashU-2 ALU is simpler than the one you built in Week 4 — it only needs
to support the operations required by the ISA:

| Operation | When used |
|---|---|
| `A + B` | ADD, IADD |
| `A AND B` | AND |
| `A + 1` | NEGATE sub-step (invert then add 1) |
| `NOT A` | NEGATE sub-step |
| pass `B` | DLOAD, ILOAD (copy MBR to ACC) |
| pass `A` | DSTORE, branching (ACC or PC through for comparison) |

`A` is always `ACC`. `B` is always `MBR`. There is no general-purpose
operand selection.

---

## 8. The complete datapath block diagram

**Action item:** Using the information from this module, draw the following
on paper (A4, landscape). Label every component and every bus connection.
This is your primary reference document for the rest of the week.

Components to include:
- The 16-bit shared bus (draw as a thick horizontal line)
- `ACC`, `PC`, `MAR`, `MBR`, `IR` (draw as rectangles connected to the bus)
- Memory block (connected to `MAR` for address, to `MBR` for data)
- ALU (inputs from `ACC` and `MBR`; output back to bus and then `ACC`)
- PC incrementer (input from `PC`; output back to `PC` or bus)
- Decode logic (input from `IR[15:12]`; output to FSM)
- Three flag signals from `ACC`: `zero_flag`, `pos_flag`, `neg_flag`

Use arrows to show data flow direction. Mark which connections go through
the bus and which are direct (e.g., ALU output feeds back to ACC via bus).

---

## 9. Connecting Week 5 to Week 6: why the fetch now takes 3 states

In Week 5, the mini-CPU needed **two** fetch states (`S_FETCH1`, `S_FETCH2`)
because the RAM had a one-cycle registered read latency — the address had to
be held for one cycle before the data was valid on `mem_data_out`.

The WashU-2 uses the same RAM read-latency principle, but splits the fetch
into **three** states:

| State | Mini-CPU (Week 5) | WashU-2 (Week 6) |
|---|---|---|
| Present PC as address | `S_FETCH1` | `fetch1` (MAR ← PC) |
| RAM responds; latch instruction | `S_FETCH2` (ir ← mem_data_out, pc++) | `fetch2` (MBR ← mem[MAR], PC ← PC+1) |
| Move instruction to IR | *(combined with S_FETCH2)* | `fetch3` (IR ← MBR) |

The extra state in WashU-2 (`fetch3`) exists because the WashU-2 has a
dedicated `MBR` register that sits between memory and `IR`. In the mini-CPU,
`mem_data_out` was wired directly to the IR load — no MBR existed, so the
two transfers (RAM → IR) happened in one step. In the WashU-2:

- `fetch2`: memory drives the bus → MBR latches (RAM output captured)
- `fetch3`: MBR drives the bus → IR latches (instruction moved to IR)

Two bus transactions → two states. The underlying reason (registered RAM
read) is exactly the same as Week 5; only the extra MBR layer adds one more
cycle. Every other multi-state sequence in the WashU-2 FSM follows the same
logic — wherever memory is read, you will see this two-state pattern.

---

## 10. Summary: register quick-reference card

Reproduce this from memory before moving to Module 3.

```
┌──────────┬────────┬───────────────────────────────────────────┐
│ Register │  Bits  │  Role                                     │
├──────────┼────────┼───────────────────────────────────────────┤
│ ACC      │   16   │ Accumulator: ALU result + working value   │
│ PC       │   16   │ Program counter: address of next instr    │
│ MAR      │   16   │ Memory address register                   │
│ MBR      │   16   │ Memory buffer register (data to/from mem) │
│ IR       │   16   │ Instruction register: current instruction │
├──────────┼────────┼───────────────────────────────────────────┤
│ zero     │    1   │ Flag: ACC = 0                             │
│ positive │    1   │ Flag: ACC > 0 (MSB=0, non-zero)          │
│ negative │    1   │ Flag: ACC < 0 (MSB=1)                    │
└──────────┴────────┴───────────────────────────────────────────┘
```

---

Next: **Module 3 — The 14-Instruction ISA**
