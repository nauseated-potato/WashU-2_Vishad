# Week 6 · Module 3 — The 14-Instruction ISA

This module defines every instruction the WashU-2 can execute. For each
instruction you need to know: its mnemonic, its opcode, what it does to the
registers, and approximately how many FSM states it requires. Module 5 gives
the exact FSM states; here the focus is on semantics — what the instruction
*means* to a programmer.

> **Action item:** Copy the ISA table in §1 onto a card. By the end of
> this week you should be able to recall any instruction's semantics from
> its opcode, and encode/decode any instruction from binary.

---

## 1. The complete ISA table

| Opcode | Mnemonic | Operand | Semantic | Clock cycles |
|---|---|---|---|---|
| `0000` | `HALT`   | — | Stop execution | 4 (fetch×3 + halt1) |
| `0001` | `NEGATE` | — | `ACC ← −ACC` (two's complement) | 5 (fetch×3 + neg1 + neg2) |
| `0010` | `CLOAD`  | `K` | `ACC ← K` (load constant, 12-bit sign-extended) | 4 (fetch×3 + cload1) |
| `0011` | `DLOAD`  | `addr` | `ACC ← mem[addr]` (direct load) | 6 (fetch×3 + direct1 + direct2 + load1) |
| `0100` | `DSTORE` | `addr` | `mem[addr] ← ACC` (direct store) | 6 (fetch×3 + direct1 + direct2 + store1) |
| `0101` | `ILOAD`  | `addr` | `ACC ← mem[mem[addr]]` (indirect load) | 8 (fetch×3 + direct1,2 + indirect1,2 + iload1) |
| `0110` | `ISTORE` | `addr` | `mem[mem[addr]] ← ACC` (indirect store) | 8 (fetch×3 + direct1,2 + indirect1,2 + istore1) |
| `0111` | `ADD`    | `addr` | `ACC ← ACC + mem[addr]` | 6 (fetch×3 + direct1 + direct2 + add1) |
| `1000` | `AND`    | `addr` | `ACC ← ACC AND mem[addr]` | 6 (fetch×3 + direct1 + direct2 + and1) |
| `1001` | `BRANCH` | `addr` | `PC ← addr` (unconditional) | 4 (fetch×3 + branch1) |
| `1010` | `BRZERO` | `addr` | `if ACC = 0 then PC ← addr` | 4 (fetch×3 + branch1) |
| `1011` | `BRPOS`  | `addr` | `if ACC > 0 then PC ← addr` | 4 (fetch×3 + branch1) |
| `1100` | `BRNEG`  | `addr` | `if ACC < 0 then PC ← addr` | 4 (fetch×3 + branch1) |
| `1101` | `BRIND`  | `addr` | `PC ← mem[addr]` (indirect branch) | 6 (fetch×3 + brind1 + brind2 + brind3) |

> There are 14 instructions. Opcodes `1110` and `1111` are undefined —
> treat as `HALT` in your implementation.

---

## 2. Instruction encoding

Every instruction is 16 bits wide, encoded as:

```
 Bit:  15  14  13  12   11  10   9   8   7   6   5   4   3   2   1   0
       ─────────────────  ──────────────────────────────────────────────
        OPCODE (4 bits)              OPERAND (12 bits)
```

For most instructions the operand is a **12-bit memory address** (range
0x000 to 0xFFF). For `CLOAD`, the operand is a **12-bit constant**, which
is sign-extended to 16 bits before loading into `ACC`. For `HALT` and
`NEGATE`, the operand field is ignored (set to zero by convention).

### Encoding examples

Work through each of these manually before checking:

```
DLOAD 0x00A  →  opcode=0011, addr=000000001010  →  0011 000000001010  =  0x300A
ADD   0x00B  →  opcode=0111, addr=000000001011  →  0111 000000001011  =  0x700B
DSTORE 0x00C →  opcode=0100, addr=000000001100  →  0100 000000001100  =  0x400C
BRANCH 0x003 →  opcode=1001, addr=000000000011  →  1001 000000000011  =  0x9003
BRZERO 0x003 →  opcode=1010, addr=000000000011  →  1010 000000000011  =  0xA003
CLOAD  5     →  opcode=0010, K=000000000101     →  0010 000000000101  =  0x2005
HALT         →  opcode=0000, operand=0           →  0000 000000000000  =  0x0000
NEGATE       →  opcode=0001, operand=0           →  0001 000000000000  =  0x1000
```

### Decoding exercises (do these by hand)

| Hex word | Opcode bits | Mnemonic | Operand (hex) | Full instruction |
|---|---|---|---|---|
| `0x3005` | ? | ? | ? | ? |
| `0x700A` | ? | ? | ? | ? |
| `0x9010` | ? | ? | ? | ? |
| `0x1000` | ? | ? | ? | ? |
| `0xA003` | ? | ? | ? | ? |
| `0x5007` | ? | ? | ? | ? |
| `0x6007` | ? | ? | ? | ? |

*(Answers: DLOAD 0x005, ADD 0x00A, BRANCH 0x010, NEGATE,
BRZERO 0x003, ILOAD 0x007, ISTORE 0x007)*

---

## 3. Instruction groups and their semantics

### Group 1 — Control: HALT and NEGATE

**HALT** (`0000`): the CPU stops. The FSM enters a halt state and remains
there until reset. No registers change after HALT is decoded. This is the
one instruction with no operand that actually does something visible —
it is how you know your CPU has completed its program.

**NEGATE** (`0001`): computes the two's complement negation of `ACC`.
```
ACC ← −ACC
```
Implemented in hardware as: `ACC ← NOT(ACC) + 1`. This typically requires
two ALU operations and thus more FSM states than a single-cycle instruction.
The operand field is `000000000000` and is ignored.

---

### Group 2 — Load and Store: CLOAD, DLOAD, DSTORE, ILOAD, ISTORE

**CLOAD K** (`0010`): loads a constant into `ACC`. The 12-bit value `K`
is **sign-extended** to 16 bits before being written to ACC. This is the
only instruction where the operand is a *value*, not an *address*. Useful
for initialising a counter or register to a known value without needing
to store it in memory first.

```
ACC ← sign_extend(IR[11:0])
```

**Sign extension** is the operation of widening a two's complement number
from N bits to M bits while preserving its numerical value. The rule is
simple: copy the sign bit (the MSB) into every new upper bit.

- If `IR[11] = '0'` (positive): bits 15:12 are all set to `'0'`.
  Example: `K = 000000000101` (+5) → `0000 000000000101` = `0x0005` = +5 ✓
- If `IR[11] = '1'` (negative): bits 15:12 are all set to `'1'`.
  Example: `K = 111111111111` (−1 in 12-bit) → `1111 111111111111` = `0xFFFF` = −1 ✓

You used the same principle in Week 4 when widening operands for the carry
flag (`'0' & unsigned(a)` prepends a zero-sign bit). CLOAD does the same
thing but with a potentially `'1'` sign bit.

Example: `CLOAD 0xFFF` → `K = 1111 1111 1111` → sign bit = 1 → sign-extended = `1111 1111 1111 1111` = `0xFFFF` = −1.

**DLOAD addr** (`0011`): loads `ACC` from a memory address.
```
MAR ← IR[11:0]    (load address into MAR)
MBR ← mem[MAR]    (fetch data from memory)
ACC ← MBR         (copy to accumulator)
```

**DSTORE addr** (`0100`): stores `ACC` to a memory address.
```
MAR ← IR[11:0]
MBR ← ACC          (put ACC value into the memory buffer)
mem[MAR] ← MBR    (write to memory)
```

**ILOAD addr** (`0101`): *indirect* load. The address in the instruction is
a *pointer* — it points to a memory location that itself holds the actual
data address. Two memory reads are needed.
```
MAR ← IR[11:0]         (address of the pointer)
MBR ← mem[MAR]         (fetch the pointer value)
MAR ← MBR              (now MAR holds the actual data address)
MBR ← mem[MAR]         (fetch the actual data)
ACC ← MBR
```

This is C's `*ptr` dereference operation in hardware.

**ISTORE addr** (`0110`): *indirect* store. Two memory accesses needed —
one to fetch the pointer, one to write the data.
```
MAR ← IR[11:0]
MBR ← mem[MAR]
MAR ← MBR
MBR ← ACC
mem[MAR] ← MBR
```

> **Key distinction — direct vs indirect:**
> - `DLOAD 0x010` fetches the value *at* address `0x010`.
> - `ILOAD 0x010` fetches the value at the address *stored in* `0x010`.
> If `mem[0x010] = 0x020`, then `ILOAD 0x010` fetches `mem[0x020]`.

---

### Group 3 — Arithmetic and Logic: ADD, AND

**ADD addr** (`0111`): adds the value at `addr` to `ACC`.
```
MAR ← IR[11:0]
MBR ← mem[MAR]
ACC ← ACC + MBR
```

**AND addr** (`1000`): bitwise AND of `ACC` and the value at `addr`.
```
MAR ← IR[11:0]
MBR ← mem[MAR]
ACC ← ACC AND MBR
```

---

### Group 4 — Branches: BRANCH, BRZERO, BRPOS, BRNEG, BRIND

All branches change the `PC` — either unconditionally or based on a flag.

**BRANCH addr** (`1001`): unconditional jump.
```
PC ← IR[11:0]
```

**BRZERO addr** (`1010`): branch if accumulator is zero.
```
if ACC = 0 then PC ← IR[11:0]
```

**BRPOS addr** (`1011`): branch if accumulator is positive.
```
if ACC > 0 then PC ← IR[11:0]    (i.e., ACC[15] = '0' AND ACC ≠ 0)
```

**BRNEG addr** (`1100`): branch if accumulator is negative.
```
if ACC < 0 then PC ← IR[11:0]    (i.e., ACC[15] = '1')
```

**BRIND addr** (`1101`): indirect branch. Load the branch target from memory
rather than from the instruction itself.
```
MAR ← IR[11:0]
MBR ← mem[MAR]
PC  ← MBR
```
Used for computed jumps (jump tables, function return addresses).

---

## 4. Writing assembly programs: a worked example

The following program computes the absolute value of a number stored at
address `0x010` and stores the result at address `0x011`.

```
; abs.asm — compute |mem[0x010]|, store at mem[0x011]
; Algorithm:
;   if mem[0x010] >= 0, result is mem[0x010] unchanged
;   if mem[0x010] < 0, result is -mem[0x010]

0x000:  DLOAD  0x010    ; ACC ← mem[0x010]   (load the value)
0x001:  BRPOS  0x004    ; if ACC > 0, skip negation → jump to DSTORE
0x002:  BRZERO 0x004    ; if ACC = 0, skip negation → jump to DSTORE
0x003:  NEGATE          ; ACC ← -ACC          (negate if negative)
0x004:  DSTORE 0x011    ; mem[0x011] ← ACC   (store result)
0x005:  HALT
```

Encoded:

| Address | Instruction | Encoding | Hex |
|---|---|---|---|
| 0x000 | `DLOAD 0x010` | `0011 000000010000` | `0x3010` |
| 0x001 | `BRPOS 0x004` | `1011 000000000100` | `0xB004` |
| 0x002 | `BRZERO 0x004`| `1010 000000000100` | `0xA004` |
| 0x003 | `NEGATE`      | `0001 000000000000` | `0x1000` |
| 0x004 | `DSTORE 0x011`| `0100 000000010001` | `0x4011` |
| 0x005 | `HALT`        | `0000 000000000000` | `0x0000` |

> **Action item:** Trace this program for two cases:
> 1. `mem[0x010] = 0x0005` (+5). Which branch is taken? What is `mem[0x011]` at the end?
> 2. `mem[0x010] = 0xFFFB` (−5 in two's complement). Which branch is taken?
>    What does NEGATE produce? What is `mem[0x011]`?

---

## 5. The CLOAD sign-extension rule

`CLOAD` is the most frequently misunderstood instruction. Work through these
examples manually:

| `CLOAD K` (decimal) | 12-bit binary K | Sign extended to 16-bit | Loaded into ACC |
|---|---|---|---|
| `CLOAD 1`    | `000000000001` | `0000 000000000001` | `0x0001` = +1 |
| `CLOAD 2047` | `011111111111` | `0000 011111111111` | `0x07FF` = +2047 |
| `CLOAD -1`   | `111111111111` | `1111 111111111111` | `0xFFFF` = −1 |
| `CLOAD -2048`| `100000000000` | `1111 100000000000` | `0xF800` = −2048 |

The sign-extension rule: copy `IR[11]` into bits `15:12` of the result.
This preserves the numerical value of the 12-bit two's complement number
when widening to 16 bits.

---

## 6. ISA design observations

These questions develop your understanding of the design trade-offs in the
WashU-2 ISA. Think through each one before reading Week 7:

1. **Why is there no SUB instruction?** Subtraction can be emulated: to
   compute `A − B`, first `NEGATE` to get `−A`... wait, that's wrong.
   Actually: load B, NEGATE to get `−B`, store `−B`, then load A and
   ADD `−B`. This takes 5 instructions instead of 1. Real ISAs add SUB
   for efficiency; WashU-2 omits it for simplicity.

2. **Why have both DLOAD and ILOAD?** Direct addressing covers most cases.
   Indirect addressing is needed for arrays (where the index is computed at
   runtime), function pointers, and return addresses. Without ILOAD/ISTORE,
   you cannot implement these patterns.

3. **Why four branch instructions?** Three condition codes (zero, positive,
   negative) plus unconditional gives the minimum set needed to implement
   any comparison. `A > B` can be computed as `A − B > 0` (BRPOS); `A ≤ B`
   as `A − B ≤ 0` (BRZERO or BRNEG).

4. **Why is the constant in CLOAD only 12 bits?** The instruction is 16
   bits wide with 4 bits used for the opcode, leaving 12 bits for the
   constant. If you need a 16-bit constant, you must build it in two steps
   (load the lower 12 bits, then manipulate the upper 4 bits using AND/OR).

---

Next: **Module 4 — Address Computation**
