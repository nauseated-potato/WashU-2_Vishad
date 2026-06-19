# Week 5 · Module 2 — Datapath Architecture and Signal Map

Module 1 explained *what* a datapath is and *why* each part exists. This
module defines the exact architecture of the mini-datapath you will build:
every component, every signal, every connection. By the end of this module
you should be able to draw the complete block diagram from memory. Do not
start writing VHDL until you can do that.

> **Video — Simple CPU datapath explained (2023):**
> [Simple CPU design — Datapath and Control](https://www.youtube.com/watch?v=yl8vPW5hydQ)
> *(Walks through a very similar accumulator-based datapath with block
> diagram — highly recommended before reading §2)*

---

## 1. Top-level ports

The complete entity for the mini-datapath:

```vhdl
entity mini_cpu is
    port (
        clk   : in  std_logic;
        reset : in  std_logic;
        done  : out std_logic   -- '1' when HALT instruction reached
    );
end mini_cpu;
```

There are no external data ports — the program and data are stored inside
the on-chip RAM, which is part of the design. The only observable outputs
are the clock, reset, and the `done` flag. (For testing you will also expose
internal signals — more on that in Module 5.)

---

## 2. Components and their roles

The mini-datapath instantiates four sub-components:

### Component 1: RAM (32×8)

Stores both the program (instructions at low addresses) and data (operands
and results at higher addresses). Single-port: one address, one data bus,
shared for both reads and writes.

```text
Ports:  clk, we, addr[4:0], data_in[7:0], data_out[7:0]
```

A 5-bit address (`2^5 = 32`) gives 32 locations — enough for a small test
program and several data values.

### Component 2: ALU (8-bit)

Performs arithmetic and logic. For the mini-datapath, only ADD and pass-
through (used for LOAD) are needed — but building it to support the full
operation set from Week 4 means it can be reused in the WashU-2 CPU directly.

```text
Ports:  a[7:0], b[7:0], op[2:0], result[7:0], zero
```

### Component 3: Accumulator register

An 8-bit register that holds the current accumulator value. It has a load
enable (`acc_ld`): when `acc_ld='1'` on a rising clock edge, it captures
the ALU result. When `acc_ld='0'`, it holds its current value.

This is exactly the register design from Week 2 — a D flip-flop with enable.

### Component 4: Instruction register (IR)

An 8-bit register that holds the currently executing instruction. It is
loaded from memory output during the FETCH state, then held stable through
the EXECUTE state so the decode logic has a consistent instruction to work
with.

```text
Ports:  clk, reset, ir_ld, data_in[7:0], ir_out[7:0]
```

---

## 3. Internal signals: the complete signal map

Every signal in the architecture has a name, width, and a clear source and
destination. Define all of these in the architecture's declarative region
before `begin`.

```text
Signal name      Width   From                  To
─────────────────────────────────────────────────────────────────
pc               5 bits  PC register           RAM addr mux
pc_next          5 bits  PC incrementer        PC register input
ir               8 bits  IR register output    decode logic
ir_opcode        3 bits  ir(7 downto 5)        control FSM
ir_operand       5 bits  ir(4 downto 0)        RAM addr mux, ALU B input
acc              8 bits  accumulator reg out   ALU A input, RAM data_in
alu_result       8 bits  ALU result output     accumulator reg input
alu_zero         1 bit   ALU zero flag         (available for branches)
mem_data_out     8 bits  RAM data_out          IR register input, ALU B input
addr             5 bits  addr mux output       RAM addr input
─────────────────────────────────────────────────────────────────
Control signals (from FSM):
acc_ld           1 bit   FSM                   accumulator register
ir_ld            1 bit   FSM                   IR register
mem_we           1 bit   FSM                   RAM write enable
pc_inc           1 bit   FSM                   PC incrementer
addr_sel         1 bit   FSM                   address multiplexer
alu_op           3 bits  FSM / decode logic    ALU op input
done             1 bit   FSM                   top-level output
```

The `addr_sel` signal chooses between two address sources:
* `addr_sel = '0'` → RAM address = `pc` (fetch instruction)
* `addr_sel = '1'` → RAM address = `ir_operand` (access data)

---

## 4. The complete block diagram

Study this diagram until you could redraw it from memory. Every box is
a component or register; every arrow is a signal from the table above.

```text
                       ┌──────────────────────────────────────────┐
                       │           CONTROL FSM                     │
                       │  (state: FETCH / EXECUTE / HALT)          │
                       │                                           │
                       │  ir_ld  acc_ld  mem_we  pc_inc  addr_sel  │
                       │    │       │       │       │        │     │
                       │    │       │       │       │        │     │
                       └────┼───────┼───────┼───────┼────────┼─────┘
                            │       │       │       │        │
           ┌────────────────▼─┐   ┌─▼──┐   │    ┌──▼──┐   ┌▼─────────────┐
           │ IR (instr reg)   │   │acc │   │    │ PC  │   │ addr mux      │
           │ ir[7:0]          │   │reg │   │    │+inc │   │ 0→pc          │
           └────────────┬─────┘   └──┬─┘   │    └──┬──┘   │ 1→ir_operand  │
                        │            │      │       │      └──────┬────────┘
               ┌────────┴──────┐     │      │       │             │
               │ decode        │     │      │       └─────────────┤
               │ ir_opcode [7:5]│    │      │                     │
               │ ir_operand[4:0]◄────┼──────┼──────────────────── │
               └────────┬──────┘     │      │                     │
                        │ alu_op     │      │                     │addr[4:0]
                        ▼            ▼      │                     ▼
                   ┌─────────┐  ┌────────┐ │           ┌────────────────┐
                   │  ALU    │  │        │ │           │   RAM 32×8     │
                   │ a=acc ◄─┼──┤ acc    │ │           │                │
                   │ b=mem ◄─┼──┼──────── ┼───────────►│ we             │
                   │         │  └────────┘ │           │ addr ◄─────────┘
                   │ result  │             │           │ data_in ◄── acc
                   │   │     │             │           │ data_out ───────►
                   └───┼─────┘             │           └────────────────┘
                       │                   │                    │
                       └───────────────────┘           mem_data_out
                         alu_result → acc_reg
                                                   (also feeds IR and ALU B)
```

The key multiplexer to notice: **ALU input B** is fed from `mem_data_out`
(the RAM output). During LOAD, the ALU passes this directly to the result
(pass-through operation). During ADD, the ALU adds `acc` and `mem_data_out`.

---

## 5. Why one FETCH state is not enough: the RAM read-latency problem

Before presenting the control signal table, you need to understand a
timing problem that breaks the most obvious design.

The `ram32x8` component (Module 3 of Week 4, and the version provided this
week) is **registered**: `data_out` reflects `ram_mem(addr)` as it was on
the **previous** rising edge, not the current one.

```vhdl
-- ram32x8.vhd, inside the clocked process:
data_out_reg <= ram_mem(to_integer(unsigned(addr)));   -- registered!
```

Now consider a naive two-state FSM (`S_FETCH`, `S_EXECUTE`) where, during
`S_FETCH`, `addr_sel='0'` (so `addr = pc`) and `ir_ld='1'`:

```text
Cycle 1 (S_FETCH):  addr = pc = 0
                    At this edge: ir <= mem_data_out
                    But mem_data_out STILL reflects whatever addr was
                    BEFORE this cycle — NOT addr=0!
                    Also at this edge: data_out_reg <= ram_mem(0)  ← starts now

Cycle 2 (S_EXECUTE): mem_data_out NOW reflects ram_mem(0) — the correct
                     instruction — but ir_ld='0' this cycle, so it is
                     NEVER captured into ir!
```

**The instruction is never correctly latched.** `ir` always ends up one
address behind, or holding garbage. This is the *exact same* registered-read
latency issue you debugged in Week 4 Module 7 Bug 1 ("checking `data_out`
too early") — except here it is a bug in the **FSM design itself**, not
just the testbench.

### The fix: a three-state fetch sequence

The solution is to split FETCH into **two states**, giving the RAM a full
cycle to respond before `ir` latches:

```text
S_FETCH1:  addr_sel='0'  (addr = pc)         — present the address
S_FETCH2:  ir_ld='1'                          — NOW mem_data_out is valid;
                                                  capture it into ir
S_EXECUTE: decode ir, perform the operation
```

```text
Cycle 1 (S_FETCH1):  addr = pc = 0
                     At this edge: data_out_reg <= ram_mem(0)  ← capture starts

Cycle 2 (S_FETCH2):  mem_data_out NOW = ram_mem(0)  ✓ valid!
                     ir_ld='1'
                     At this edge: ir <= mem_data_out = ram_mem(0)  ✓ correct!

Cycle 3 (S_EXECUTE): ir holds the correct instruction. Decode and execute.
```

This three-state fetch (`S_FETCH1` → `S_FETCH2` → `S_EXECUTE`) is a smaller
preview of exactly the `fetch1` / `fetch2` / `fetch3` sequence you will
study in Week 6 for the full WashU-2 CPU — the same problem, the same
solution, at a larger scale. Internalising it now makes Week 6 much easier.

> **`addr_sel` during S_FETCH2 and S_EXECUTE:** during `S_FETCH2`, `addr`
> must still equal `pc` (so the RAM keeps presenting `ram_mem(pc)` — though
> by this point `data_out_reg` has already latched it and won't change
> again until the next write or the next address change). During
> `S_EXECUTE`, `addr_sel='1'` switches `addr` to the operand address,
> which starts the RAM capturing `ram_mem(operand)` — ready for the
> instructions that need it (see §7).

---

## 6. Control signal table: what the FSM asserts each state

For each state and each instruction, here is exactly which control signals
are active (`'1'`) and which are inactive (`'0'`):

### S_FETCH1 state (all instructions)

```text
Operation:  (none latched yet — just present the address)
```

| Signal | Value | Reason |
|---|---|---|
| `addr_sel` | `'0'` | PC drives the address; RAM begins capturing `ram_mem(pc)` |
| `ir_ld`    | `'0'` | `mem_data_out` is not yet valid — do not latch |
| `acc_ld`   | `'0'` | Do not disturb accumulator |
| `mem_we`   | `'0'` | Do not write to RAM |
| `pc_inc`   | `'0'` | Do not advance PC yet |

### S_FETCH2 state (all instructions)

```text
Operation:  ir ← mem_data_out (now valid)
            pc ← pc + 1        (advance for next fetch)
```

| Signal | Value | Reason |
|---|---|---|
| `addr_sel` | `'0'` | Keep PC on the address bus (no change needed yet) |
| `ir_ld`    | `'1'` | `mem_data_out` now correctly holds `ram_mem(pc)` — capture it |
| `acc_ld`   | `'0'` | Do not disturb accumulator |
| `mem_we`   | `'0'` | Do not write to RAM |
| `pc_inc`   | `'1'` | Advance PC now so it is correct for the next fetch |

### S_EXECUTE state — LOAD instruction

| Signal | Value | Reason |
|---|---|---|
| `addr_sel` | `'1'` | Operand address drives the RAM; begins capturing `ram_mem(operand)` |
| `ir_ld`    | `'0'` | IR already has the instruction |
| `acc_ld`   | `'0'` | **Cannot load yet** — `mem_data_out` for the operand is not valid until next cycle (see §7) |
| `mem_we`   | `'0'` | No write |
| `pc_inc`   | `'0'` | Already incremented in S_FETCH2 |
| `alu_op`   | PASS  | (used in the following state) |

### S_EXECUTE state — ADD instruction

| Signal | Value | Reason |
|---|---|---|
| `addr_sel` | `'1'` | Operand address drives RAM; begins capturing `ram_mem(operand)` |
| `ir_ld`    | `'0'` | — |
| `acc_ld`   | `'0'` | Cannot capture sum yet — operand not valid until next cycle |
| `mem_we`   | `'0'` | No write |
| `pc_inc`   | `'0'` | — |
| `alu_op`   | ADD   | (used in the following state) |

### S_EXECUTE state — STORE instruction

| Signal | Value | Reason |
|---|---|---|
| `addr_sel` | `'1'` | Operand address drives RAM |
| `ir_ld`    | `'0'` | — |
| `acc_ld`   | `'0'` | Accumulator does not change |
| `mem_we`   | `'0'` | Cannot write yet — see §7: write happens one cycle later |
| `pc_inc`   | `'0'` | — |

### HALT state

| Signal | Value | Reason |
|---|---|---|
| `pc_inc`   | `'0'` | Freeze — stop advancing |
| `mem_we`   | `'0'` | No writes |
| `acc_ld`   | `'0'` | No changes |
| `done`     | `'1'` | Signal completion |

Print this table and keep it on your desk while implementing Module 3.

---

## 7. Why LOAD, ADD, and STORE need a FOURTH state

The same read-latency rule from §5 applies to the **operand** access, not
just the instruction fetch. In `S_EXECUTE`, `addr_sel` switches to `'1'`
(operand address) — but `mem_data_out` does not reflect `ram_mem(operand)`
until the *following* cycle, because the RAM read is registered.

This means LOAD and ADD need one more state after `S_EXECUTE` to actually
capture the result, and STORE needs one more state to perform the write
(since `mem_we` must be asserted in the *same* cycle that `addr` already
equals the operand address — which is the cycle *after* `S_EXECUTE` sets
`addr_sel='1'`).

The clean way to handle this: **`S_EXECUTE` sets up the address (and,
for STORE, doesn't need to wait at all — see the note below); a final
state `S_WRITEBACK` performs the actual register update or memory write**.

```text
S_FETCH1   → S_FETCH2   → S_EXECUTE   → S_WRITEBACK   → S_FETCH1 (loop)
(present     (latch IR,    (set addr_sel    (capture ALU
 pc as addr)  pc+1)         to operand;       result into acc,
                             decode opcode)    OR perform mem write)
```

| Signal | S_WRITEBACK — LOAD | S_WRITEBACK — ADD | S_WRITEBACK — STORE |
|---|---|---|---|
| `addr_sel` | `'1'` (keep operand addr) | `'1'` | `'1'` |
| `acc_ld`   | `'1'` (capture `mem_data_out`, ALU=PASS) | `'1'` (capture `acc+mem_data_out`, ALU=ADD) | `'0'` |
| `mem_we`   | `'0'` | `'0'` | `'1'` — write `acc` to `ram_mem(operand)` now that `addr` has been `operand` for one full cycle |
| `alu_op`   | PASS | ADD | don't care |

> **STORE's write timing:** `mem_we='1'` and `addr_sel='1'` together in
> `S_WRITEBACK` means the RAM's `we='1'` write happens at an address that
> has been stable (`= operand`) since the start of `S_EXECUTE` — one full
> cycle, satisfying the RAM's synchronous write requirement. The data
> written is `data_in = acc` (always connected — see Module 3 §6).

So the **complete FSM has four states**: `S_FETCH1`, `S_FETCH2`, `S_EXECUTE`,
`S_WRITEBACK`, plus `S_HALT`. Every non-HALT instruction takes exactly
4 cycles (FETCH1, FETCH2, EXECUTE, WRITEBACK) — a clean, uniform timing
that also makes the testbench cycle-counting in Module 5 straightforward.

---

## 8. The timing relationship across all four states

```text
Clock:    ____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____
State:        FETCH1      FETCH2     EXECUTE    WRITEBACK
addr:         = pc        = pc       = operand   = operand
ir_ld:        '0'         '1'        '0'         '0'
pc_inc:       '0'         '1'        '0'         '0'
mem_data_out: (stale)     =ram[pc]   (stale)     =ram[operand]
ir:           (old)       (old)      =ram[pc]    =ram[pc]
acc/mem write:                                    happens HERE
```

Read this diagram alongside §5 and §7 until the pattern is automatic: **a
signal presented as `addr` during cycle N only appears on `mem_data_out`
during cycle N+1.** Every `_ld` or `mem_we` signal that depends on
`mem_data_out` must therefore be asserted one state *after* the
corresponding address was presented.

Trace the worked example from Module 1 §6 through this timing model
cycle by cycle before moving to Module 3. (Module 1's table will need
updating to 4-state timing too — Module 4 provides the corrected version.)

---

## 9. Summary checklist

Before moving to Module 3 (implementation), verify:

* You can draw the block diagram from §4 without looking.
* You know which signal each control bit drives.
* You understand the `addr_sel` mux: when is it `'0'`? When `'1'`?
* You can explain in your own words why a single FETCH state is not enough (§5), and why LOAD/ADD/STORE need a WRITEBACK state (§7).
* You can fill in the control signal table from memory for FETCH1, FETCH2, EXECUTE, WRITEBACK (for LOAD, ADD, STORE), and HALT.
* You have traced the four-state timing diagram from §8 cycle-by-cycle with a concrete example (e.g., `LOAD 0x10` from Module 1 §6).

Do not skip this checklist. Students who code directly from the specification
without internalising the signal map spend hours debugging what the block
diagram would have made obvious in minutes.

---

Next: **Module 3 — Implementing the Mini-Datapath in VHDL**