# Week 5 · Module 4 — Loading a Program: RAM Initialisation

The mini-datapath is complete as a circuit, but it does nothing useful
without a program. This module explains how to encode instructions in binary,
how to pre-load the RAM with a program using VHDL initialisers, and how to
write and verify two programs that demonstrate LOAD, ADD, and STORE.

---

## 1. Encoding instructions by hand

Before writing programs, you must be able to encode any instruction into
its 8-bit binary representation and back again. This skill is essential
for Week 6 (studying the WashU-2 ISA) and Week 7 (debugging the CPU).

### Encoding rule

~~~text
Bits 7..5  = opcode (3 bits)
Bits 4..0  = operand address (5 bits)
~~~

| Opcode | Binary | Mnemonic |
|---|---|---|
| `000` | LOAD  | Load from memory into acc |
| `001` | ADD   | Add memory value to acc |
| `010` | STORE | Store acc to memory |
| `011` | HALT  | Stop execution |

### Encoding examples

~~~text
LOAD  0x10  →  opcode=000  operand=10000  →  00010000  =  0x10
ADD   0x11  →  opcode=001  operand=10001  →  00110001  =  0x31
STORE 0x12  →  opcode=010  operand=10010  →  01010010  =  0x52
HALT        →  opcode=011  operand=00000  →  01100000  =  0x60
~~~

### Decoding examples (going the other direction)

~~~text
0x23  =  00100011  →  bits[7:5]=001 (ADD),   bits[4:0]=00011 (addr 3)  →  ADD 0x03
0x45  =  01000101  →  bits[7:5]=010 (STORE),  bits[4:0]=00101 (addr 5)  →  STORE 0x05
0x08  =  00001000  →  bits[7:5]=000 (LOAD),   bits[4:0]=01000 (addr 8)  →  LOAD 0x08
~~~

Practise encoding and decoding at least 5 instructions by hand before
continuing. This is a skill that must become automatic.

---

## 2. RAM initialisation in VHDL

### A new shorthand: hexadecimal string literals

So far you have written `std_logic_vector` values as binary strings, e.g.
`"00010000"`. VHDL also allows **hexadecimal string literals**, written
with an `x` prefix:

~~~vhdl
x"10"   -- equivalent to "00010000"  (8 bits: each hex digit = 4 bits)
x"AB"   -- equivalent to "10101011"
x"0C"   -- equivalent to "00001100"
x"00"   -- equivalent to "00000000"
~~~

Each hex digit expands to exactly 4 bits, so `x"10"` (two hex digits) is an
8-bit vector — the same width as `"00010000"`. This is purely a notational
convenience; both forms produce identical hardware. Hex notation is used
from this point onward because instruction encodings are easier to read
and check in hex (matching the encoding tables in §1) than in binary.

~~~vhdl
-- These two lines are identical:
signal a : std_logic_vector(7 downto 0) := "00010000";
signal b : std_logic_vector(7 downto 0) := x"10";
~~~

> **Rule of thumb:** the number of hex digits × 4 must equal the vector
> width. An 8-bit vector needs exactly 2 hex digits (`x"AB"`); a 4-bit
> vector needs exactly 1 (`x"A"`). Using the wrong number of digits is a
> compile error.

### RAM initialisation in VHDL

The `ram32x8` component is initialised with a program using the aggregate
syntax from Week 4. Inside `ram32x8.vhd`, the `ram_mem` signal declaration
is where the program is loaded:

~~~vhdl
signal ram_mem : ram_type := (
    -- Program: compute 7 + 5, store at address 0x12
    0  => x"10",   -- LOAD  0x10   (load A=7 into acc)
    1  => x"31",   -- ADD   0x11   (acc = acc + B=5)
    2  => x"52",   -- STORE 0x12   (store result)
    3  => x"60",   -- HALT

    -- Data
    16 => x"07",   -- address 0x10: A = 7
    17 => x"05",   -- address 0x11: B = 5
    18 => x"00",   -- address 0x12: result (will be overwritten)

    others => (others => '0')
);
~~~

Note: VHDL array aggregate indices are decimal integers, not hex. Address
`0x10` = 16 decimal, `0x11` = 17, `0x12` = 18. Always convert hex
addresses to decimal when writing the initialiser.

### Why not load the program from a file?

Real FPGAs load programs from `.mif` (Memory Initialization File) or `.hex`
files, which Quartus supports via the `$readmemh` or MIF format. For this
week, the inline VHDL initialiser is used because:
- It is self-contained in one file — no extra file to manage.
- It is synthesisable and simulatable without extra Quartus settings.
- It is easy to read and verify by inspection.

The WashU-2 CPU in Weeks 7–8 uses the same technique.

---

## 3. Program 1 — Addition: `result = A + B`

This is the worked example from Module 1. Here it is fully encoded as a
RAM initialiser.

**Program specification:**
- A = 7, stored at address 16 (`0x10`)
- B = 5, stored at address 17 (`0x11`)
- Result stored at address 18 (`0x12`)
- Expected result: 12 (`0x0C`)

**Encoded program:**

~~~vhdl
signal ram_mem : ram_type := (
    -- Instructions (addresses 0–3)
    0  => "00010000",   -- LOAD  0x10  (000 10000)
    1  => "00110001",   -- ADD   0x11  (001 10001)
    2  => "01010010",   -- STORE 0x12  (010 10010)
    3  => "01100000",   -- HALT        (011 00000)
    -- Data (addresses 16–18)
    16 => "00000111",   -- A = 7
    17 => "00000101",   -- B = 5
    18 => "00000000",   -- result placeholder
    others => (others => '0')
);
~~~

**Expected execution trace:**

Each non-HALT instruction takes exactly **4 cycles**
(`S_FETCH1 → S_FETCH2 → S_EXECUTE → S_WRITEBACK`), as derived in Module 2
§5-8. All register values shown are **at the start** of the cycle, i.e.
*before* that cycle's rising edge applies any updates. `addr` is the value
presented to the RAM this cycle (`pc` when `addr_sel='0'`, `ir_operand`
when `addr_sel='1'`). `mem_data_out` reflects `ram_mem(addr)` **from the
previous cycle's `addr`** (one-cycle registered latency).

| Cycle | State | PC | IR | acc | addr | mem_data_out | Notes |
|---|---|---|---|---|---|---|---|
| 1 | S_FETCH1 | 0 | — | 0x00 | 0x00 | (stale) | begin capturing ram[0x00] |
| 2 | S_FETCH2 | 0 | — | 0x00 | 0x00 | 0x10 | **ir←0x10 (LOAD 0x10); pc←1** |
| 3 | S_EXECUTE | 1 | 0x10 | 0x00 | 0x10 | (stale=0x10) | decode LOAD; begin capturing ram[0x10] |
| 4 | S_WRITEBACK | 1 | 0x10 | 0x00 | 0x10 | 0x07 | **acc←0x07** (=A); → S_FETCH1 |
| 5 | S_FETCH1 | 1 | 0x10 | 0x07 | 0x01 | (stale=0x07) | begin capturing ram[0x01] |
| 6 | S_FETCH2 | 1 | 0x10 | 0x07 | 0x01 | 0x31 | **ir←0x31 (ADD 0x11); pc←2** |
| 7 | S_EXECUTE | 2 | 0x31 | 0x07 | 0x11 | (stale=0x31) | decode ADD; begin capturing ram[0x11] |
| 8 | S_WRITEBACK | 2 | 0x31 | 0x07 | 0x11 | 0x05 | **acc←0x07+0x05=0x0C**; → S_FETCH1 |
| 9 | S_FETCH1 | 2 | 0x31 | 0x0C | 0x02 | (stale=0x05) | begin capturing ram[0x02] |
| 10 | S_FETCH2 | 2 | 0x31 | 0x0C | 0x02 | 0x52 | **ir←0x52 (STORE 0x12); pc←3** |
| 11 | S_EXECUTE | 3 | 0x52 | 0x0C | 0x12 | (stale=0x52) | decode STORE; begin capturing ram[0x12] |
| 12 | S_WRITEBACK | 3 | 0x52 | 0x0C | 0x12 | 0x00 | **mem_we=1: ram[0x12]←acc=0x0C**; → S_FETCH1 |
| 13 | S_FETCH1 | 3 | 0x52 | 0x0C | 0x03 | (stale=0x00) | begin capturing ram[0x03] |
| 14 | S_FETCH2 | 3 | 0x52 | 0x0C | 0x03 | 0x60 | **ir←0x60 (HALT); pc←4** |
| 15 | S_EXECUTE | 4 | 0x60 | 0x0C | — | (stale=0x60) | decode HALT; → S_HALT |
| 16 | S_HALT | 4 | 0x60 | 0x0C | — | — | **done='1'** (loops here) |

**Final state (after cycle 16):** `acc = 0x0C`, `mem[0x12] = 0x0C`,
`pc = 0x04`, `done = '1'`.

> **Highlighted rows** (cycles 2, 4, 6, 8, 10, 12, 14) are where a register
> actually changes value — these are the rows to focus on when comparing
> against your waveform. The other rows are "setup" cycles where an address
> is presented but nothing latches yet.

Memorise this trace. Your simulation waveform must match it cycle-for-cycle.

---

## 4. Program 2 — Repeated addition: `result = A + B + C`

A slightly longer program that adds three values. This tests that the FSM
correctly sequences through more than two instructions without errors.

**Program specification:**
- A = 3, address 16
- B = 4, address 17
- C = 5, address 18
- Result at address 19
- Expected: 3+4+5 = 12 (`0x0C`)

**Encoded program:**

~~~vhdl
signal ram_mem : ram_type := (
    0  => "00010000",   -- LOAD  0x10  (load A)
    1  => "00110001",   -- ADD   0x11  (acc = A + B)
    2  => "00110010",   -- ADD   0x12  (acc = A + B + C)
    3  => "01010011",   -- STORE 0x13  (store result)
    4  => "01100000",   -- HALT
    16 => "00000011",   -- A = 3
    17 => "00000100",   -- B = 4
    18 => "00000101",   -- C = 5
    19 => "00000000",   -- result
    others => (others => '0')
);
~~~

**Expected result:** after HALT, `acc = 0x0C` and `mem[19] = 0x0C`.

**Cycle count:** 5 instructions total. The first 4 (LOAD, ADD, ADD, STORE)
each take 4 cycles (16 cycles total, cycles 1-16). HALT then takes 3 more
cycles to pass through `S_FETCH1 → S_FETCH2 → S_EXECUTE` (cycles 17-18-19),
reaching `S_HALT` with `done='1'` on cycle 19 — the same pattern as cycles
13-16 in the §3 trace. Produce your own cycle-by-cycle table for this
program (same format as §3) as practice before attempting Exercise 1 in
Module 6 — it is excellent preparation for the trace deliverable in
Week 6.

---

## 5. Switching programs: the correct workflow

Because the program is baked into the RAM initialiser inside `ram32x8.vhd`,
changing the program means editing that file. The workflow is:

1. Edit the `signal ram_mem : ram_type := (...)` initialiser in `ram32x8.vhd`.
2. Save.
3. In Quartus: **Processing → Start Compilation** (full recompile needed,
   because the initial values changed).
4. Re-run the simulation.

**Important:** the simulation will NOT pick up the new program if you only
re-run without recompiling. Always full-compile after changing the initialiser.

A cleaner alternative for frequent program changes is to pass the program
as a generic or load it from a `.mif` file. That is beyond this week's scope,
but the Module 7 reference section points to how to set this up if you want
to explore it.

---

## 6. Instruction encoding exercises (do these by hand)

Before moving on, encode and decode the following without looking at the
table. Check your answers against the encoding rule in §1.

**Encode these instructions:**

| Instruction | Your binary answer | Your hex answer |
|---|---|---|
| `LOAD 0x05`  | ? | ? |
| `ADD  0x1F`  | ? | ? |
| `STORE 0x00` | ? | ? |
| `ADD  0x0A`  | ? | ? |
| `HALT`       | ? | ? |

**Decode these bytes:**

| Hex byte | Opcode bits | Operand bits | Instruction |
|---|---|---|---|
| `0x08` | ? | ? | ? |
| `0x29` | ? | ? | ? |
| `0x4E` | ? | ? | ? |
| `0x60` | ? | ? | ? |
| `0x1F` | ? | ? | ? |

*(Answers: LOAD 0x05 = 00000101, ADD 0x1F = 00111111, STORE 0x00 = 01000000,
ADD 0x0A = 00101010, HALT = 01100000. Decoding: 0x08=LOAD 0x08,
0x29=ADD 0x09, 0x4E=STORE 0x0E, 0x60=HALT, 0x1F=LOAD 0x1F)*

---

Next: **Module 5 — Testbenches for the Mini-Datapath**