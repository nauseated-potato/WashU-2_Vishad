# Week 6 · Module 6 — Bus Protocol and Timing

The state diagram in Module 5 told you *what* each state does at a high
level. This module goes deeper: it specifies exactly which bus control
signals are asserted in each state. This is the translation layer between
the architecture (Module 5) and the VHDL implementation (Week 7).

Understanding this module means Week 7 is mostly mechanical translation.
Not understanding it means debugging blind.

---

## 1. Bus control signals

The shared bus requires explicit control to avoid contention. Each component
that can drive the bus has an **output enable** signal. Each register that
can receive from the bus has a **load enable** signal.

| Signal | Type | Meaning |
|---|---|---|
| `bus_pc`  | output enable | `'1'` → PC drives the bus |
| `bus_mbr` | output enable | `'1'` → MBR drives the bus |
| `bus_acc` | output enable | `'1'` → ACC drives the bus (used in DSTORE/ISTORE) |
| `bus_ir_lower` | output enable | `'1'` → IR[11:0] (zero-extended) drives the bus |
| `bus_ir_se` | output enable | `'1'` → IR[11:0] (sign-extended) drives the bus |
| `bus_alu` | output enable | `'1'` → ALU result drives the bus |
| `bus_mem` | output enable | `'1'` → Memory data output drives the bus |
| `mar_ld`  | load enable | `'1'` → MAR latches from bus on rising edge |
| `mbr_ld`  | load enable | `'1'` → MBR latches from bus on rising edge |
| `ir_ld`   | load enable | `'1'` → IR latches from bus on rising edge |
| `acc_ld`  | load enable | `'1'` → ACC latches from bus on rising edge |
| `pc_ld`   | load enable | `'1'` → PC latches from bus on rising edge |
| `pc_inc`  | special | `'1'` → PC ← PC + 1 (via dedicated incrementer, not bus) |
| `mem_we`  | write enable | `'1'` → memory stores MBR at address MAR |
| `alu_op`  | 3-bit select | selects ALU operation |
| `done`    | output | `'1'` → CPU has halted |

The rule: **exactly one `bus_X` signal is `'1'` in any given state**. If
two output enables are both `'1'` simultaneously, the bus has two drivers
— contention — and the result is undefined. The FSM guarantees this never
happens by design.

---

## 2. Control signal table: every state

This is the definitive reference. Every row is one FSM state. Every column
is a control signal. `'1'` means asserted; `'0'` means deasserted; `–`
means don't-care (leave as `'0'`).

| State | bus_pc | bus_mbr | bus_acc | bus_ir_lower | bus_ir_se | bus_alu | bus_mem | mar_ld | mbr_ld | ir_ld | acc_ld | pc_ld | pc_inc | mem_we | alu_op | done |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `resetState` | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | — | 0 |
| `fetch1` | **1** | 0 | 0 | 0 | 0 | 0 | 0 | **1** | 0 | 0 | 0 | 0 | 0 | 0 | — | 0 |
| `fetch2` | 0 | 0 | 0 | 0 | 0 | 0 | **1** | 0 | **1** | 0 | 0 | 0 | **1** | 0 | — | 0 |
| `fetch3` | 0 | **1** | 0 | 0 | 0 | 0 | 0 | 0 | 0 | **1** | 0 | 0 | 0 | 0 | — | 0 |
| `halt1` | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | — | **1** |
| `neg1` | 0 | 0 | 0 | 0 | 0 | **1** | 0 | 0 | 0 | 0 | **1** | 0 | 0 | 0 | NOT | 0 |
| `neg2` | 0 | 0 | 0 | 0 | 0 | **1** | 0 | 0 | 0 | 0 | **1** | 0 | 0 | 0 | INC | 0 |
| `cload1` | 0 | 0 | 0 | 0 | **1** | 0 | 0 | 0 | 0 | 0 | **1** | 0 | 0 | 0 | — | 0 |
| `direct1` | 0 | 0 | 0 | **1** | 0 | 0 | 0 | **1** | 0 | 0 | 0 | 0 | 0 | 0 | — | 0 |
| `direct2` | 0 | 0 | 0 | 0 | 0 | 0 | **1** | 0 | **1** | 0 | 0 | 0 | 0 | 0 | — | 0 |
| `load1` | 0 | **1** | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | **1** | 0 | 0 | 0 | — | 0 |
| `add1` | 0 | 0 | 0 | 0 | 0 | **1** | 0 | 0 | 0 | 0 | **1** | 0 | 0 | 0 | ADD | 0 |
| `and1` | 0 | 0 | 0 | 0 | 0 | **1** | 0 | 0 | 0 | 0 | **1** | 0 | 0 | 0 | AND | 0 |
| `store1` | 0 | 0 | **1** | 0 | 0 | 0 | 0 | 0 | **1** | 0 | 0 | 0 | 0 | **1** | — | 0 |
| `branch1` | 0 | 0 | 0 | **1** | 0 | 0 | 0 | 0 | 0 | 0 | 0 | **1**† | 0 | 0 | — | 0 |
| `indirect1` | 0 | **1** | 0 | 0 | 0 | 0 | 0 | **1** | 0 | 0 | 0 | 0 | 0 | 0 | — | 0 |
| `indirect2` | 0 | 0 | 0 | 0 | 0 | 0 | **1** | 0 | **1** | 0 | 0 | 0 | 0 | 0 | — | 0 |
| `iload1` | 0 | **1** | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | **1** | 0 | 0 | 0 | — | 0 |
| `istore1` | 0 | 0 | **1** | 0 | 0 | 0 | 0 | 0 | **1** | 0 | 0 | 0 | 0 | **1** | — | 0 |
| `brind1` | 0 | 0 | 0 | **1** | 0 | 0 | 0 | **1** | 0 | 0 | 0 | 0 | 0 | 0 | — | 0 |
| `brind2` | 0 | 0 | 0 | 0 | 0 | 0 | **1** | 0 | **1** | 0 | 0 | 0 | 0 | 0 | — | 0 |
| `brind3` | 0 | **1** | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | **1** | 0 | 0 | — | 0 |

†`pc_ld` in `branch1` is conditional: only asserted if the relevant flag
matches (`zero_flag` for BRZERO, `pos_flag` for BRPOS, `neg_flag` for
BRNEG, always for BRANCH).

> **Study technique:** cover the signal columns and reconstruct them from
> the state name alone. For each state ask: what goes on the bus? What
> latches from the bus? Is there a memory write? Does the ALU do something?

---

## 3. Deriving control signals from first principles

You do not need to memorise the table blindly. Every row follows from two
questions:

**Question 1: What register transfer happens in this state?**
- Write it in the form `DEST ← SOURCE` or `DEST ← OP(A, B)`

**Question 2: What bus path implements that transfer?**
- SOURCE drives the bus: set `bus_SOURCE = '1'`
- DEST latches from the bus: set `DEST_ld = '1'`
- If SOURCE is the ALU, set `bus_alu = '1'` and choose `alu_op`
- If DEST is memory, set `mem_we = '1'` (MBR is written to mem[MAR])

Example — derive `direct1` from scratch:

```
Step 1: What does direct1 do?
  MAR ← IR[11:0]     (load the data address into MAR)

Step 2: What drives the bus?
  Source = IR lower 12 bits, zero-extended → bus_ir_lower = '1'

Step 3: What latches from the bus?
  Destination = MAR → mar_ld = '1'

Step 4: Anything else?
  No memory write, no ALU operation, no PC change.

Result: bus_ir_lower='1', mar_ld='1', everything else '0'.
```

This matches the table. Practise this derivation for every state before
it is more reliable than memorising the table entry-by-entry.

---

## 4. The conditional branch mechanism

Branch instructions (`BRZERO`, `BRPOS`, `BRNEG`) use the same FSM state
(`branch1`) but condition the `pc_ld` enable on a flag:

```vhdl
-- In the FSM's combinational process (Week 7 VHDL):
when branch1 =>
    bus_ir_lower <= '1';
    case ir(15 downto 12) is
        when "1001" =>  pc_ld <= '1';                          -- BRANCH: always
        when "1010" =>  pc_ld <= zero_flag;                    -- BRZERO
        when "1011" =>  pc_ld <= pos_flag;                     -- BRPOS
        when "1100" =>  pc_ld <= neg_flag;                     -- BRNEG
        when others =>  pc_ld <= '0';
    end case;
```

If the condition is not met, `pc_ld = '0'` and the PC (already incremented
in `fetch2`) is left alone. Execution continues with the next instruction.
No extra "not-taken" state is needed.

---

## 5. The STORE timing subtlety

`store1` and `istore1` write `ACC` to memory. The sequence is:

```
DSTORE addr execution:
  direct1:  MAR ← IR[11:0]        (set the destination address)
  direct2:  MBR ← mem[MAR]        (memory read — the result is DISCARDED
                                    for STORE; this state is shared with
                                    DLOAD/ADD/AND so the read always happens)
  store1:   ACC → bus → MBR        (bus_acc=1, mbr_ld=1: ACC drives the bus,
                                    MBR latches the value to be written)
            mem[MAR] ← MBR         (mem_we=1: write MBR to memory at MAR)
```

**Why does `store1` show both `mbr_ld=1` and `mem_we=1` in the same row?**

In a single clock cycle, the bus can carry exactly one value. `store1` does:
1. ACC drives the bus (`bus_acc=1`) → MBR latches it (`mbr_ld=1`).
2. Simultaneously, `mem_we=1` fires a write using the *old* MBR value and
   the current MAR address.

In VHDL, both updates happen at the same rising edge. At the start of
`store1`, MBR still holds the stale value from `direct2`. The memory write
(`mem_we=1`) uses that old MBR value... but that is wrong — we want to write
ACC, not the stale MBR value.

The resolution: in a real WashU-2 implementation, **the memory write uses
the bus directly** (not MBR as an intermediate), so when ACC drives the bus
and `mem_we=1`, the memory sees ACC's value on the bus and stores it. MBR
is updated as a side-effect but is not the source of the write. Treat this
as: `bus_acc=1` + `mem_we=1` = ACC written to mem[MAR] in one cycle.

**Why does `direct2` read memory even for STORE?**

The `direct1`/`direct2` states are shared across DLOAD, ADD, AND, DSTORE,
ILOAD, and ISTORE. For DSTORE, the read in `direct2` is wasteful but
harmless — the value fetched into MBR is immediately overwritten in `store1`
when ACC drives the bus. The 17-state design accepts this redundant read for
simplicity; a more optimised design would branch before `direct2` for STORE.

---

## 6. Register transfer language (RTL) summary per instruction

This is the compact representation you should be able to produce for any
instruction without looking at notes.

```
HALT:     fetch1,2,3 → halt1(loop)

NEGATE:   fetch1,2,3 → neg1: ACC←NOT(ACC)
                      → neg2: ACC←ACC+1 → fetch1

CLOAD K:  fetch1,2,3 → cload1: ACC←sign_ext(IR[11:0]) → fetch1

DLOAD:    fetch1,2,3 → direct1: MAR←IR[11:0]
                     → direct2: MBR←mem[MAR]
                     → load1:   ACC←MBR → fetch1

DSTORE:   fetch1,2,3 → direct1: MAR←IR[11:0]
                     → direct2: (MBR←mem[MAR], discarded)
                     → store1:  MBR←ACC; mem[MAR]←MBR → fetch1

ADD:      fetch1,2,3 → direct1: MAR←IR[11:0]
                     → direct2: MBR←mem[MAR]
                     → add1:    ACC←ACC+MBR → fetch1

AND:      fetch1,2,3 → direct1: MAR←IR[11:0]
                     → direct2: MBR←mem[MAR]
                     → and1:    ACC←ACC AND MBR → fetch1

BRANCH:   fetch1,2,3 → branch1: PC←IR[11:0] → fetch1

BRZERO:   fetch1,2,3 → branch1: if zero then PC←IR[11:0] → fetch1

BRPOS:    fetch1,2,3 → branch1: if pos  then PC←IR[11:0] → fetch1

BRNEG:    fetch1,2,3 → branch1: if neg  then PC←IR[11:0] → fetch1

BRIND:    fetch1,2,3 → brind1:    MAR←IR[11:0]
                     → brind2:    MBR←mem[MAR]
                     → brind3:    PC←MBR → fetch1

ILOAD:    fetch1,2,3 → direct1:   MAR←IR[11:0]
                     → direct2:   MBR←mem[MAR]   ← MBR = pointer
                     → indirect1: MAR←MBR
                     → indirect2: MBR←mem[MAR]   ← MBR = actual data
                     → iload1:    ACC←MBR → fetch1

ISTORE:   fetch1,2,3 → direct1:   MAR←IR[11:0]
                     → direct2:   MBR←mem[MAR]   ← MBR = pointer
                     → indirect1: MAR←MBR
                     → indirect2: MBR←mem[MAR]   ← (read discarded)
                     → istore1:   MBR←ACC; mem[MAR]←MBR → fetch1
```

> **Action item:** Cover this summary and reproduce it from memory for
> three instructions of your choice: one simple (CLOAD), one medium (ADD),
> one complex (ILOAD). If you can do all three in under 5 minutes without
> errors, you have a solid grasp of the FSM structure.

---

Next: **Module 7 — Cycle-by-Cycle Instruction Traces**
