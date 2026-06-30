# Week 6 · Module 5 — The 17-State FSM

The control unit of the WashU-2 is commonly described as a **17-state Moore FSM** — the exact count depends on which states are merged in your implementation (see §5), but 17 is the canonical target. Each state lasts exactly one clock cycle. The FSM's job is to assert the correct bus control
signals and register enables each cycle so that data flows through the
datapath in exactly the right way.

This is the most important module this week. Study it until you can draw
the complete state diagram from memory, including all transitions and the
key control signals asserted in each state. That is both the week's primary
deliverable and the most reliable guide when implementing the CPU in Week 7.

> **Action item:** As you read each state, add it to the FSM skeleton you
> started drawing in Module 2. By the end of §4 your diagram should show
> all 17 states with their transitions. In Module 6 you will add the bus
> control signals to each state.

---

## 1. State naming convention

States are named by their function. The prefix tells you which instruction
(or phase) they belong to:

| Prefix | Phase |
|---|---|
| `resetState` | Power-on / reset |
| `fetch1`, `fetch2`, `fetch3` | Instruction fetch (all instructions) |
| `halt1` | HALT |
| `neg1`, `neg2` | NEGATE |
| `cload1` | CLOAD |
| `direct1`, `direct2` | Shared data-access states for DLOAD, ADD, AND, DSTORE |
| `load1` | DLOAD final state (ACC ← MBR) |
| `add1` | ADD final state (ACC ← ACC + MBR) |
| `and1` | AND final state (ACC ← ACC AND MBR) |
| `store1` | DSTORE final state (mem[MAR] ← MBR) |
| `branch1` | BRANCH, BRZERO, BRPOS, BRNEG |
| `indirect1`, `indirect2` | Shared pointer-fetch states for ILOAD and ISTORE |
| `iload1` | ILOAD final states |
| `istore1` | ISTORE final states |
| `brind1`, `brind2` | BRIND |

The total fully-expanded (before any merges): `resetState` + 3 fetch
+ 1 halt + 2 neg + 1 cload + 2 direct + 1 load + 1 add + 1 and
+ 1 store + 1 branch + 2 indirect + 1 iload + 1 istore + 3 brind = **22**.
After applying merges (see §5), implementations typically reach **17–19 states**.

---

## 2. The fetch cycle: states shared by all instructions

Every instruction begins with the same three-state fetch sequence:

### `fetch1`
```
Operation:  MAR ← PC
Bus:        PC drives bus; MAR latches
Why:        Place the address of the next instruction onto the address bus
            so memory can start fetching it.
```

### `fetch2`
```
Operation:  MBR ← mem[MAR] ;  PC ← PC + 1
Bus:        Memory drives bus; MBR latches
            PC incremented (using the PC+1 incrementer, not the bus)
Why:        Wait one cycle for memory to respond. Latch the instruction
            into MBR. Increment PC now so it points to the *next* instruction
            while this one executes.
Note:       PC and MBR update simultaneously in this state. PC uses the
            dedicated incrementer path; MBR uses the bus from memory.
            These are two parallel operations, not sequential.
```

### `fetch3`
```
Operation:  IR ← MBR
Bus:        MBR drives bus; IR latches
Why:        Move the instruction from the memory buffer into the instruction
            register. After this state, decode logic can examine IR[15:12]
            to determine the opcode and select the next state.
Transition: Next state depends on IR[15:12] (the opcode).
```

After `fetch3`, the FSM branches based on the opcode:

```
IR[15:12]  →  Next state
──────────────────────────
  0000         halt1
  0001         neg1
  0010         cload1
  0011         direct1     (DLOAD path)
  0100         direct1     (DSTORE path — same first state!)
  0101         direct1     (ILOAD path)
  0110         direct1     (ISTORE path)
  0111         direct1     (ADD path)
  1000         direct1     (AND path)
  1001         branch1
  1010         branch1
  1011         branch1
  1100         branch1
  1101         brind1
  others        halt1
```

Notice that `DLOAD`, `DSTORE`, `ILOAD`, `ISTORE`, `ADD`, and `AND` all
share the same `direct1` state. The FSM doesn't yet know *which* of these
it is executing — all it knows is that a memory address (`IR[11:0]`) must
be loaded into `MAR`. The distinction happens later.

---

## 3. Execution states: instruction-specific

### `halt1`
```
Operation:  (none — freeze)
Control:    done ← '1'  (or a halt flag)
Transition: halt1 → halt1 (loops until reset)
```

### `neg1` and `neg2`
```
neg1:
  Operation:  ACC ← NOT(ACC)   (bitwise invert, using ALU)
  Bus:        ALU output drives bus; ACC latches
  Why:        First step of two's complement: invert all bits.

neg2:
  Operation:  ACC ← ACC + 1    (using ALU with B=0x0001 or a dedicated +1)
  Bus:        ALU output drives bus; ACC latches
  Why:        Second step: add 1 to complete the negation.
  Transition: neg2 → fetch1
```

### `cload1`
```
Operation:  ACC ← sign_extend(IR[11:0])
Bus:        IR (sign-extended lower bits) drives bus; ACC latches
Transition: cload1 → fetch1
```

### `direct1` (shared entry state)
```
Operation:  MAR ← IR[11:0]
Bus:        IR lower 12 bits (zero-extended) drives bus; MAR latches
Why:        All instructions with a memory operand first load the operand
            address into MAR. This state does that work once, shared.
Transition: direct2
```

### `direct2` (shared memory-read state)
```
Operation:  MBR ← mem[MAR]
Bus:        Memory drives bus; MBR latches
Why:        Wait for memory to respond, latch the value into MBR.
Transition: depends on opcode:
  DLOAD  → load1
  DSTORE → store1
  ADD    → add1
  AND    → and1
  ILOAD  → indirect1   (need to dereference: MBR is now a pointer)
  ISTORE → indirect1
```

### `load1`
```
Operation:  ACC ← MBR
Bus:        MBR drives bus; ACC latches
Transition: load1 → fetch1
```

### `add1`
```
Operation:  ACC ← ACC + MBR   (ALU performs addition)
Bus:        ALU result drives bus; ACC latches
Transition: add1 → fetch1
```

### `and1`
```
Operation:  ACC ← ACC AND MBR   (ALU performs bitwise AND)
Bus:        ALU result drives bus; ACC latches
Transition: and1 → fetch1
```

### `store1`
```
Operation:  MBR ← ACC   then   mem[MAR] ← MBR
            (In some implementations this is split across two sub-steps
             within one state; in others it is one state with both
             MBR loaded and write-enable asserted simultaneously.)
Bus:        ACC drives bus; MBR latches; then write enable fires
Transition: store1 → fetch1
```

### `branch1`
```
Operation (for BRANCH):    PC ← IR[11:0]
Operation (for BRZERO):    if zero_flag then PC ← IR[11:0]
Operation (for BRPOS):     if pos_flag  then PC ← IR[11:0]
Operation (for BRNEG):     if neg_flag  then PC ← IR[11:0]
Bus:        IR lower 12 bits drives bus; PC latches (conditionally)
Why shared: All four instructions check a flag and optionally update PC.
            They differ only in *which* flag they check — the hardware
            is the same, just the enable condition changes.
Transition: branch1 → fetch1
```

> **Conditional implementation note:** For BRZERO, BRPOS, BRNEG — if the
> condition is *not* met, the PC was already incremented in `fetch2`. The
> CPU simply continues to `fetch1` with the already-incremented PC. No
> special "don't-branch" state is needed.

### `indirect1` and `indirect2`
```
indirect1:
  Operation:  MAR ← MBR   (MBR holds the pointer fetched in direct2)
  Bus:        MBR drives bus; MAR latches
  Why:        Load the pointer value (from direct2) as the new address.

indirect2:
  Operation:  MBR ← mem[MAR]   (fetch the data at the pointer address)
  Bus:        Memory drives bus; MBR latches
  Transition: depends on opcode:
    ILOAD  → iload1
    ISTORE → istore1
```

### `iload1`
```
Operation:  ACC ← MBR
Bus:        MBR drives bus; ACC latches
Transition: iload1 → fetch1
```
*(Identical to load1 — some implementations merge them.)*

### `istore1`
```
Operation:  MBR ← ACC  then  mem[MAR] ← MBR
Bus:        ACC drives bus; MBR latches; write enable asserted
Transition: istore1 → fetch1
```

### `brind1`, `brind2`, and `brind3`

BRIND needs to fetch a value from memory and load it into PC. Because the
shared bus can only carry one value per cycle and the RAM read is registered
(one-cycle latency — the same rule you worked with in Week 5), three
states are required:

```
brind1:
  Operation:  MAR ← IR[11:0]   (load the address of the branch target)
  Bus:        IR lower 12 bits drives bus; MAR latches

brind2:
  Operation:  MBR ← mem[MAR]   (fetch the branch target address from memory)
  Bus:        Memory drives bus; MBR latches
  Why:        One cycle for memory to respond — same as fetch2 and direct2.

brind3:
  Operation:  PC ← MBR          (load the fetched address into PC)
  Bus:        MBR drives bus; PC latches
  Transition: → fetch1
```

> **Why can't brind2 and brind3 be merged?** In a synchronous circuit,
> a register updated at the rising edge of cycle N cannot be read by
> combinational logic until after that edge. So MBR cannot be both
> written (from memory) and read (to drive PC) in the same clock cycle.
> Each transfer must occupy its own state — the same reason fetch2 and
> fetch3 are separate states.

---

## 4. Complete state transition diagram (textual)

```
                        ┌─────────────────┐
           reset ──────►│   resetState    │
                        └────────┬────────┘
                                 │
                                 ▼
                        ┌────────────────┐
                    ┌──►│    fetch1      │◄──────────────────────────────────┐
                    │   └────────┬───────┘                                   │
                    │            │                                            │
                    │            ▼                                            │
                    │   ┌────────────────┐                                   │
                    │   │    fetch2      │                                   │
                    │   └────────┬───────┘                                   │
                    │            │                                            │
                    │            ▼                                            │
                    │   ┌────────────────┐                                   │
                    │   │    fetch3      │ ─── decode IR[15:12] ──────────── │
                    │   └────────┬───────┘                                   │
                    │       ┌────┴──────────────────────────────────────┐    │
                    │       │                                            │    │
                    │  ┌────▼────┐   ┌───────┐  ┌────────┐  ┌───────┐ │    │
                    │  │ halt1   │   │ neg1  │  │ cload1 │  │branch1│ │    │
                    │  │(loops)  │   └──┬────┘  └───┬────┘  └───┬───┘ │    │
                    │  └─────────┘      │            │            │     │    │
                    │               ┌───▼───┐        └────────────┘     │    │
                    │               │ neg2  │                  └─────────────┘
                    │               └───┬───┘
                    └───────────────────┘
                    │
                    │  ┌─────────────────────────────────────┐
                    │  │            direct1                   │
                    │  │  (DLOAD/DSTORE/ADD/AND/ILOAD/ISTORE)│
                    │  └──────────────┬──────────────────────┘
                    │                 │
                    │         ┌───────▼──────────┐
                    │         │     direct2       │
                    │         └──┬────┬───┬───┬──┘
                    │      ┌─────┘    │   │   └───────────────────┐
                    │  ┌───▼──┐  ┌───▼──┐ └─────┐           ┌────▼─────────┐
                    │  │load1 │  │ add1 │  ┌────▼──┐  ┌────▼──┐  indirect1 │
                    │  └──┬───┘  └───┬──┘  │ and1  │  │store1 │  └────┬────┘
                    │     │          │     └────┬──┘  └────┬──┘        │
                    └─────┴──────────┴──────────┴──────────┘      indirect2
                                                                    ┌───┴───┐
                                                               ┌───▼──┐ ┌──▼────┐
                                                               │iload1│ │istore1│
                                                               └──┬───┘ └───┬───┘
                                                                  └─────┬───┘
                                                                        │
                                                                    (→ fetch1)
```

---

## 5. How do we get to 17 states?

Starting from a fully-expanded listing, then applying merges:

```
Full listing (21 states):
  resetState, fetch1, fetch2, fetch3,       = 4
  halt1,                                     = 1
  neg1, neg2,                                = 2
  cload1,                                    = 1
  direct1, direct2,                          = 2
  load1, add1, and1, store1,                 = 4
  branch1,                                   = 1
  indirect1, indirect2,                      = 2
  iload1, istore1,                           = 2
  brind1, brind2, brind3                     = 3
  ─────────────────────────────────────────
  Total:                                     = 22
```

Apply two merges to reach 17:

**Merge 1 — `load1` and `iload1`:** Both states do exactly `ACC ← MBR`
with `bus_mbr=1, acc_ld=1`. They are identical operations. A single state
named `load1` can serve both DLOAD and ILOAD; the transition into it comes
from either `direct2` (DLOAD) or `indirect2` (ILOAD). Save 1 state → 21.

**Merge 2 — `store1` and `istore1`:** Both do `bus_acc=1, mbr_ld=1,
mem_we=1`. Identical. Merge into one `store1`. Save 1 state → 20.

**Merge 3 — `resetState` with `fetch1`:** In many implementations
`resetState` is simply the power-on condition; the CPU jumps directly to
`fetch1` on the first clock after reset is released. If `resetState` is
removed and reset instead forces `current_state ← fetch1`, the count
becomes 19.

**Merge 4 — `brind2` absorbs `brind3` as two micro-ops?** Not valid in
synchronous logic (explained in §3 above). brind stays as 3 states.

**Remaining merges to reach 17** depend on the specific implementation —
for example, some implementations fold `halt1` into a general "idle" state
shared with `resetState`, or collapse the branch states. The precise 17
depends on your implementation choices.

> **For the exercise:** aim for a diagram with 17–19 states.
> The exact count is less important than having all the register transfers
> correct. "Why does DLOAD take 6 cycles?" matters far more than whether
> your count is 17 or 18.

---

## 6. Summary: what to memorise

By the end of this module, be able to:
1. Name the states and their purpose. (Canonical set: resetState, fetch1–3, halt1, neg1–2, cload1, direct1–2, load1, add1, and1, store1, branch1, indirect1–2, iload1, istore1, brind1–3.)
2. Draw the transitions from `fetch3` based on the opcode.
3. Explain which states are shared between multiple instructions and why.
4. Trace any instruction through its states, naming each one and the
   register transfer it performs.

---

Next: **Module 6 — Bus Protocol and Timing**
