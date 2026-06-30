# Week 6 · Module 4 — Address Computation

Every instruction that touches memory must compute an **effective address
(EA)** — the final memory location to read from or write to. The WashU-2
supports three addressing modes. Understanding them precisely is essential
because the FSM states for each mode differ, and confusing them is the most
common mistake in the Week 7 implementation.

---

## 1. The three addressing modes

### Mode 1 — Immediate (CLOAD only)

The operand field `IR[11:0]` is the **data value itself**, not an address.
No memory access is needed to obtain the operand.

```
EA:  none
Data obtained:  sign_extend(IR[11:0])
Memory accesses:  0 (after the instruction fetch)
```

```
Example:  CLOAD 5
IR = 0010 000000000101
The value 5 is in IR itself. No further memory access needed.
ACC ← 0x0005
```

---

### Mode 2 — Direct (DLOAD, DSTORE, ADD, AND, BRIND)

The operand field `IR[11:0]` is the **memory address** of the data.
One memory access (after the instruction fetch) obtains the operand.

```
EA:  IR[11:0]
Data obtained:  mem[IR[11:0]]
Memory accesses:  1 (after fetch)
```

```
Example:  DLOAD 0x010
IR = 0011 000000010000
EA = 0x010
ACC ← mem[0x010]
```

---

### Mode 3 — Indirect (ILOAD, ISTORE)

The operand field `IR[11:0]` points to a memory location that itself holds
the **actual data address**. Two memory accesses (after the instruction fetch)
are needed: one to fetch the pointer, one to fetch the actual data.

```
EA:  mem[IR[11:0]]          (the pointer is dereferenced)
Data obtained:  mem[mem[IR[11:0]]]
Memory accesses:  2 (after fetch)
```

```
Example:  ILOAD 0x020
IR = 0101 000000100000
EA step 1:  MAR ← 0x020 → MBR ← mem[0x020]   (say mem[0x020] = 0x050)
EA step 2:  MAR ← 0x050 → MBR ← mem[0x050]   (actual data)
ACC ← MBR
```

---

## 2. Total memory accesses per instruction

This table matters for understanding why different instructions take
different numbers of FSM states:

| Instruction | Fetch | Addr access 1 | Addr access 2 | Total |
|---|---|---|---|---|
| `HALT`       | 1 | — | — | 1 |
| `NEGATE`     | 1 | — | — | 1 |
| `CLOAD`      | 1 | — | — | 1 |
| `DLOAD`      | 1 | read mem[addr] | — | 2 |
| `DSTORE`     | 1 | write mem[addr] | — | 2 |
| `ADD`        | 1 | read mem[addr] | — | 2 |
| `AND`        | 1 | read mem[addr] | — | 2 |
| `BRANCH`     | 1 | — | — | 1 |
| `BRZERO`     | 1 | — (cond. only) | — | 1 |
| `BRPOS`      | 1 | — (cond. only) | — | 1 |
| `BRNEG`      | 1 | — (cond. only) | — | 1 |
| `BRIND`      | 1 | read mem[addr] | — | 2 |
| `ILOAD`      | 1 | read mem[addr] | read mem[ptr] | 3 |
| `ISTORE`     | 1 | read mem[addr] | write mem[ptr] | 3 |

Each memory access corresponds to (at minimum) two FSM states: one to load
the address into MAR, and one to let memory respond and latch into MBR.
This is why `ILOAD` and `ISTORE` need the most FSM states.

---

## 3. Address computation for branch instructions

Branch instructions compute the **new PC value**, not a data address.

**Direct branches (BRANCH, BRZERO, BRPOS, BRNEG):**
```
New PC = IR[11:0]
```
The 12-bit field is zero-extended to 16 bits (branches cannot reach above
address `0x0FFF` using direct branch). The new PC is loaded in a single
state — no memory access, just a bus transfer from IR to PC.

**Indirect branch (BRIND):**
```
New PC = mem[IR[11:0]]
```
One memory access after the fetch. The effective address is read from
memory, then loaded into PC. This allows jump tables (array of branch
targets) and return-address jumps (used for function calls/returns in
hand-coded assembly).

---

## 4. Sign extension for CLOAD in detail

`CLOAD`'s operand is a 12-bit two's complement value. Loading it into the
16-bit `ACC` requires sign extension: the sign bit (`IR[11]`) is replicated
into the upper 4 bits of `ACC`.

In VHDL (Week 7), this looks like:

```vhdl
-- Sign-extend IR[11:0] to 16 bits
acc_next <= (15 downto 12 => ir(11)) & ir(11 downto 0);
-- If IR[11]='1': upper nibble filled with '1' (negative number preserved)
-- If IR[11]='0': upper nibble filled with '0' (positive number preserved)
```

The `(15 downto 12 => ir(11))` syntax is a VHDL aggregate that replicates
`ir(11)` into all four positions 15, 14, 13, 12.

---

## 5. Worked example: tracing address computation

Suppose memory contains:

| Address | Value | Meaning |
|---|---|---|
| `0x000` | `0x5007` | `ILOAD 0x007` |
| `0x007` | `0x0020` | pointer to actual data |
| `0x020` | `0x0042` | actual data value |

Trace the address computation for `ILOAD 0x007`:

```
State fetch1: MAR ← PC = 0x000
State fetch2: MBR ← mem[0x000] = 0x5007 ; PC ← PC+1 = 0x001
State fetch3: IR  ← MBR = 0x5007
              Decode: opcode=0101 (ILOAD), operand=0x007

State iload1: MAR ← IR[11:0] = 0x007
State iload2: MBR ← mem[0x007] = 0x0020   ← this is the pointer
State iload3: MAR ← MBR = 0x020            ← load the actual address
State iload4: MBR ← mem[0x020] = 0x0042   ← this is the actual data
State iload5: ACC ← MBR = 0x0042
```

Result: `ACC = 0x0042`.

> **Action item:** Trace `ISTORE 0x007` for the same memory layout, assuming
> `ACC = 0x00FF`. Which memory location gets written? What value? Draw the
> sequence of MAR/MBR/ACC states step by step.

---

## 6. Comparing addressing modes: a programming example

**Goal:** implement `A[i]` — access element `i` of an array, where `i` is
computed at runtime and stored in a register (i.e., in a memory location).

Assume:
- Array base address: `0x100`
- Index `i` stored at: `0x010`
- We want: `ACC ← mem[0x100 + i]`

With direct addressing alone, this is impossible at the ISA level because
the address `0x100 + i` is not known at compile time. With indirect
addressing:

```
; Pre-computation (done before this code): store 0x100+i at address 0x020
; (This part requires ADD and DSTORE to compute the pointer)

ILOAD 0x020    ; ACC ← mem[mem[0x020]] = mem[0x100 + i]
```

This is how C arrays work at the machine level. The pointer (the computed
address) is first stored in memory, then dereferenced with ILOAD.

---

Next: **Module 5 — The 17-State FSM**
