# Week 7 · Module 1 — From Architecture to Code: The Implementation Strategy

Week 6 gave you the complete WashU-2 architecture on paper: every register,
every bus transfer, every FSM state, every control signal. Week 7 translates
that into VHDL — starting from a completely blank file.

This is the most technically demanding week so far. The CPU is larger than
anything you have built, and the states interact in ways that are easy to
get wrong. The strategy below is how to approach it without becoming
overwhelmed.

---

## 1. What you build this week

By the end of Week 7 you will have a working `washu2_cpu.vhd` that correctly
executes five instructions:

| Instruction | Opcode | What it does |
|---|---|---|
| `HALT`   | `0000` | Stop; assert `done` |
| `NEGATE` | `0001` | `ACC ← −ACC` |
| `CLOAD`  | `0010` | `ACC ← sign_extend(IR[11:0])` |
| `DLOAD`  | `0011` | `ACC ← mem[IR[11:0]]` |
| `DSTORE` | `0100` | `mem[IR[11:0]] ← ACC` |

The remaining nine instructions (ADD, AND, BRANCH, BRZERO, BRPOS, BRNEG,
BRIND, ILOAD, ISTORE) are added in Week 8 — but because you are writing
the FSM using a shared-state design, adding them requires only adding new
`when` arms to an already-working case structure. Nothing built this week
needs to be rewritten.

---

## 2. The build order

Do not attempt to write the whole CPU at once and then simulate. Write
it in layers, compiling and partially simulating after each layer:

```
Step 1 — Entity and ports           (Module 2)
Step 2 — Architecture declarations  (Module 3)
          signals, constants, state type
Step 3 — Memory component           (Module 3)
          washu2_ram.vhd in starter_library
Step 4 — The bus                    (Module 4)
          concurrent mux statement
Step 5 — The ALU                    (Module 4)
          combinational process
Step 6 — Registered elements        (Module 5)
          clocked process for all registers + state
Step 7 — Control FSM                (Module 6)
          combinational process, fetch cycle only first
Step 8 — Extend FSM: HALT, NEGATE, CLOAD (Module 6)
Step 9 — Extend FSM: DLOAD, DSTORE  (Module 6)
Step 10 — Testbench + simulation    (Module 7)
```

After Step 7, you should be able to simulate the fetch cycle and watch
MAR, MBR, IR, and PC update correctly. Do not proceed to Step 8 until
the fetch cycle works.

---

## 3. Key differences from the Week 5 mini-CPU

You built a working CPU in Week 5. The WashU-2 differs in four concrete
ways that affect the VHDL:

**1. All registers are 16-bit, not 8-bit.**
Every `std_logic_vector` that holds a CPU register is `(15 downto 0)`.
The memory is also 16-bit wide. The ALU operates on 16-bit values.

**2. There is a shared bus with explicit output enables.**
In Week 5, connections were direct wires. Here, a multiplexer implements
the bus: exactly one `bus_X` control signal selects which component drives
the bus each cycle. Every registered element that can receive from the bus
checks its own `_ld` enable before latching.

**3. There are more registers: MAR, MBR, and IR in addition to ACC and PC.**
Each needs its own load enable signal and its own registered assignment in
the clocked process.

**4. The FSM has ~17–19 states instead of 5.**
The structure is identical to Week 5 (two-process template, enumerated
type, defaults before `case`) — only the number of `when` arms is larger.

Everything else — the two-process FSM template, `entity work.X`
instantiation, `numeric_std` arithmetic, `(others => '0')` defaults — is
identical to what you used in Weeks 3–5.

---

## 4. The complete file structure

```
washu2_cpu.vhd        ← the CPU: entity + architecture (you write this)
washu2_ram.vhd        ← 4096×16 synchronous RAM (provided in starter_library)
tb_washu2_week7.vhd   ← testbench for the 5 instructions (you write this)
```

All three files go in the same Quartus project. Set `washu2_cpu` as the
top-level entity.

> **Note on the RAM:** the provided `washu2_ram.vhd` uses separate
> `data_in` and `data_out` ports (no bidirectional bus) for clarity. The
> program initialiser works identically to Week 5's `ram32x8.vhd` — edit
> the marked section to load your test program.

---

## 5. Connecting Week 6 to Week 7: the signal naming convention

Every signal name in `washu2_cpu.vhd` maps directly to a row or column
in the Week 6 Module 6 control signal table. Use these names exactly —
they will be referenced in the debugging module and in the Week 8
extension:

| Week 6 name | VHDL signal | Width | Role |
|---|---|---|---|
| `ACC` | `acc` | 16 bits | Accumulator register |
| `PC` | `pc` | 16 bits | Program counter |
| `MAR` | `mar` | 16 bits | Memory address register |
| `MBR` | `mbr` | 16 bits | Memory buffer register |
| `IR` | `ir` | 16 bits | Instruction register |
| `bus_pc` | `bus_pc` | 1 bit | PC drives the bus |
| `bus_mbr` | `bus_mbr` | 1 bit | MBR drives the bus |
| `bus_acc` | `bus_acc` | 1 bit | ACC drives the bus |
| `bus_ir_lower` | `bus_ir_lower` | 1 bit | IR[11:0] zero-extended drives bus |
| `bus_ir_se` | `bus_ir_se` | 1 bit | IR[11:0] sign-extended drives bus |
| `bus_alu` | `bus_alu` | 1 bit | ALU result drives bus |
| `bus_mem` | `bus_mem` | 1 bit | Memory output drives bus |
| `mar_ld` | `mar_ld` | 1 bit | MAR latches from bus |
| `mbr_ld` | `mbr_ld` | 1 bit | MBR latches from bus |
| `ir_ld` | `ir_ld` | 1 bit | IR latches from bus |
| `acc_ld` | `acc_ld` | 1 bit | ACC latches from bus |
| `pc_ld` | `pc_ld` | 1 bit | PC latches from bus |
| `pc_inc` | `pc_inc` | 1 bit | PC ← PC + 1 |
| `mem_we` | `mem_we` | 1 bit | Write enable to RAM |
| `alu_op` | `alu_op` | 3 bits | ALU operation select |
| `done` | `done` | 1 bit | CPU halted |

---

## 6. Before writing any VHDL

Answer these on paper. If you cannot, re-read the relevant Week 6 module
before continuing.

1. What are the five registers in the WashU-2 and their widths?
2. In `fetch1`, which signal drives the bus? Which register latches?
3. In `fetch2`, which two things happen simultaneously? How is this possible?
4. In `fetch3`, which signal drives the bus? Which register latches?
5. After `fetch3`, which state does `DLOAD` transition to?
6. In `fetch3`, the FSM must decode from `mbr(15 downto 12)` rather than
   `ir_opcode`. Why? What value does `ir_opcode` hold during `fetch3`?
7. What is the address field of the instruction `0x3010`? What instruction is it?
8. What does `bus_ir_se` do differently from `bus_ir_lower`?
9. In `store1`, which three control signals are simultaneously active?

---

Next: **Module 2 — Entity, Ports, and Architecture Skeleton**
