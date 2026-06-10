# Week 4 · Module 5 — Exercises

Week 4 is the **mid-submission week**. The two required exercises produce
the components you submit alongside the Week 3 FSM. The optional exercise
challenges you to connect the ALU and RAM into a simple integrated system —
a direct preview of Week 5's mini-datapath.

**Workflow for every exercise:**
1. Read the specification completely, including the port table and all
   behaviour rules.
2. Work out the expected outputs by hand for the test cases listed.
3. Write and compile the design.
4. Write the testbench.
5. Simulate and verify your hand-calculated results appear in the waveform.

Starter files are in `starter_library/`.

---

## Exercise 1 — 4-bit ALU with Carry and Overflow Flags ★ REQUIRED

### Background

The module example built a basic 4-bit ALU with a zero flag. This exercise
extends it with two additional flag outputs: **carry** (unsigned overflow
from addition) and **negative** (the sign bit of the result). You will also
support a new operation: **XOR**. This requires you to design from the
operation table upward, rather than adapting a worked example.

### Specification

```
entity alu4_extended is
    port (
        a        : in  std_logic_vector(3 downto 0);
        b        : in  std_logic_vector(3 downto 0);
        op       : in  std_logic_vector(2 downto 0);
        result   : out std_logic_vector(3 downto 0);
        zero     : out std_logic;   -- '1' when result = "0000"
        carry    : out std_logic;   -- '1' when ADD produces a carry out
        negative : out std_logic    -- '1' when result(3) = '1' (MSB set)
    );
end alu4_extended;
```

Operation table (your design must match this exactly):

| `op`  | Operation | Notes |
|---|---|---|
| `"000"` | ADD    | Sets carry if result exceeds 4 bits |
| `"001"` | SUB    | Carry is `'0'` for this operation |
| `"010"` | AND    | Bitwise |
| `"011"` | OR     | Bitwise |
| `"100"` | XOR    | Bitwise exclusive-OR |
| `"101"` | NOT    | Unary, B ignored, carry `'0'` |
| `"110"` | NEGATE | Two's complement of A, B ignored, carry `'0'` |
| `"111"` | —      | `result = "0000"`, all flags `'0'` |

### Carry flag implementation

A 4-bit ADD may produce a 5-bit result. The carry flag is that 5th bit.
The trick in VHDL is to widen the operands to 5 bits before adding:

```vhdl
signal a5, b5, sum5 : unsigned(4 downto 0);
a5   <= '0' & unsigned(a);          -- zero-extend to 5 bits
b5   <= '0' & unsigned(b);
sum5 <= a5 + b5;
result_int <= std_logic_vector(sum5(3 downto 0));  -- lower 4 bits
carry_int  <= sum5(4);                              -- the extra bit
```

The `&` operator in VHDL is **concatenation** — it joins bits/vectors. Here
`'0' & unsigned(a)` produces a 5-bit value with `0` prepended.

### What to do

1. **Work out these test cases by hand before writing any code:**

   | a | b | op | result | zero | carry | negative |
   |---|---|---|---|---|---|---|
   | `"0111"` (7) | `"0001"` (1) | `"000"` ADD | ? | ? | ? | ? |
   | `"1111"` (15)| `"0001"` (1) | `"000"` ADD | ? | ? | ? | ? |
   | `"1010"` | `"1010"` | `"100"` XOR | ? | ? | ? | ? |
   | `"0011"` (3) | — | `"110"` NEGATE | ? | ? | ? | ? |
   | `"1000"` | — | `"101"` NOT | ? | ? | ? | ? |

2. **Implement** `alu4_extended.vhd`. Use `result_int` as an internal
   signal (same reason as in the module example). The carry and negative
   flags also need internal signals.

3. **Write** `tb_alu4_extended.vhd`. Your testbench must:
   - Test every operation at least once.
   - Include a case that produces `carry='1'` (ADD with large operands).
   - Include a case that produces `negative='1'` (any result with MSB set).
   - Include a case that produces `zero='1'`.
   - Show all output signals in the waveform.

4. **Simulate** and confirm your hand-computed table matches the waveform
   exactly. If any row differs, debug before moving on.

### Self-check questions *(for your own understanding — not submitted)*

- Why do we use 5-bit arithmetic to detect carry from a 4-bit addition,
  rather than trying to check the 4-bit result directly?
- The `negative` flag is simply `result(3)` (the MSB). For which ALU
  operations is the negative flag meaningful as a sign indicator? For
  which operations does it not carry that meaning?
- XOR has the property that `a XOR a = 0` for any `a`. What use does this
  have in a CPU? (Hint: how would you zero a register without having a
  `"0000"` constant available?)
- The `carry` flag is only set for ADD in this design. Real ALUs also set a
  borrow flag for subtraction. How would you compute a borrow for SUB using
  the same 5-bit widening trick?

---

## Exercise 2 — 8×8 Synchronous RAM with Read-Valid Signal ★ REQUIRED

### Background

The module example built a 16×8 RAM. This exercise builds a smaller **8×8
RAM** (8 locations × 8 bits, 3-bit address) but adds one important feature:
a **read-valid** output signal that tells the consumer when the output data
is actually valid (one cycle after a read is requested). This is the
handshake pattern used in pipelined memory interfaces.

Note the bidirectional bus from the module example is **not** used here —
the data interface is split into separate `data_in` and `data_out` ports
for clarity. The bidirectional bus technique is kept for the optional
exercise.

### Specification

```
entity ram8x8 is
    port (
        clk       : in  std_logic;
        we        : in  std_logic;                     -- write enable
        addr      : in  std_logic_vector(2 downto 0);  -- 3-bit address (0..7)
        data_in   : in  std_logic_vector(7 downto 0);  -- write data
        data_out  : out std_logic_vector(7 downto 0);  -- read data
        valid     : out std_logic                       -- '1' one cycle after read
    );
end ram8x8;
```

### Behaviour

- On `rising_edge(clk)` with `we='1'`: store `data_in` at `addr`.
  `valid` is `'0'` this cycle.
- On `rising_edge(clk)` with `we='0'`: capture `ram(addr)` into
  `data_out` register. Assert `valid='1'` on the **following** clock cycle.
- `valid` returns to `'0'` on any cycle after a write (or when `we` goes
  back to `'1'`).
- On reset (synchronous): clear `data_out` to `"00000000"`, `valid='0'`.
  RAM contents are **not** cleared on reset (consistent with real block RAM
  behaviour).

### What to do

1. **Trace through this transaction sequence by hand before coding.** Fill
   in the expected `data_out` and `valid` for every cycle:

   | Cycle | we | addr | data_in | data_out | valid | Note |
   |---|---|---|---|---|---|---|
   | 1 | 1 | 000 | 0xAA | ? | ? | Write 0xAA → addr 0 |
   | 2 | 1 | 001 | 0xBB | ? | ? | Write 0xBB → addr 1 |
   | 3 | 0 | 000 | — | ? | ? | Read addr 0 |
   | 4 | 0 | 001 | — | ? | ? | Read addr 1 |
   | 5 | 1 | 000 | 0xCC | ? | ? | Write 0xCC → addr 0 |
   | 6 | 0 | 000 | — | ? | ? | Read addr 0 (updated value) |
   | 7 | — | — | — | ? | ? | Data appears |

2. **Implement** `ram8x8.vhd`.

3. **Write** `tb_ram8x8.vhd`. Requirements:
   - Reset phase at the start.
   - Write distinct values to at least 4 different addresses.
   - Read back all 4 addresses and verify `valid` pulses correctly.
   - Perform a read-after-write to the same address to check updated data.
   - All signals visible in waveform: `clk`, `we`, `addr`, `data_in`,
     `data_out`, `valid`.

4. **Simulate** and verify your hand-trace table matches the waveform.

### Self-check questions *(for your own understanding — not submitted)*

- The `valid` signal is high for exactly one cycle after each read. If a
  consumer needs to read 4 consecutive addresses, how many clock cycles does
  it take to get all 4 valid outputs?
- Why is the RAM content not cleared on reset? What would happen to a CPU
  that cleared its program memory every time the reset button was pressed?
- What would change if you moved `data_out <= ram(...)` *outside* the clocked
  process (making it a concurrent assignment)? Would `valid` still be
  meaningful? Would Quartus infer block RAM?
- The module example used a bidirectional `inout` bus. This exercise uses
  separate `data_in` and `data_out`. What are the trade-offs between the two
  interfaces?

---

## Optional Exercise — ALU + RAM: Mini Accumulator System ✦ OPTIONAL

*Attempt after completing both required exercises. This exercise has no
worked example in the modules — you design the architecture yourself.
It is a direct preview of the Week 5 mini-datapath.*

### Background

Connect the `alu4_extended` (Exercise 1) and `ram8x8` (Exercise 2) into a
small system: a **mini accumulator**. The system has one register (the
accumulator `acc`) and executes a fixed 4-instruction program stored in RAM.
There is no CPU control unit yet — the sequencer is a simple counter that
advances one state per clock cycle.

### Specification

```
entity mini_acc is
    port (
        clk    : in  std_logic;
        reset  : in  std_logic;
        done   : out std_logic;                    -- '1' when program complete
        result : out std_logic_vector(3 downto 0)  -- accumulator output
    );
end mini_acc;
```

### Fixed program (hard-coded in RAM at initialisation)

The RAM is pre-loaded with the following 4 bytes. Your design executes them
in order (addresses 0, 1, 2, 3), one per clock cycle, then asserts `done`:

| Address | Byte | Meaning |
|---|---|---|
| 0 | `"00000011"` | Load constant 3 into accumulator |
| 1 | `"00000101"` | ADD 5 to accumulator (operand is the lower 4 bits) |
| 2 | `"00001010"` | AND accumulator with `"1010"` |
| 3 | `"00000000"` | HALT (assert done) |

The sequencer simply reads address 0 on cycle 1, address 1 on cycle 2, etc.
You do **not** need a full fetch-decode-execute cycle — just step through the
four addresses with a 2-bit counter.

### What to do

**Part A — Architecture diagram**

Before writing any VHDL, draw a block diagram showing:
- The `ram8x8` block (or a simplified version with only `data_out`).
- The `alu4_extended` block with its inputs and outputs.
- The accumulator register (a single clocked `std_logic_vector(3 downto 0)`).
- A 2-bit program counter that drives `addr`.
- Signal names on every connection.

**Part B — Implementation**

Write `mini_acc.vhd`. Instantiate `ram8x8` and `alu4_extended` as
components inside `mini_acc`. Implement:
- A 2-bit counter as the program counter.
- Logic to decode the RAM output and drive the ALU `op` and `b` inputs.
- The accumulator register that captures the ALU result each cycle.
- The `done` output when the counter reaches address 3.

**Part C — Testbench**

Write `tb_mini_acc.vhd`. Apply reset, release it, and run for 10 clock
cycles. Verify:
- `result` matches the expected accumulator value after each instruction.
- `done` asserts on the correct cycle.
- By hand: what should `result` be after all 3 non-HALT instructions?

**Part D — Self-check questions *(for your own understanding)*:**

- After the LOAD, ADD, and AND instructions, what is the final accumulator
  value? Trace it in binary.
- The program counter is a 2-bit counter — it wraps to 0 after 3. What
  would happen if `done` was not asserted and the program "looped"? Which
  instruction would execute again?
- This design hard-codes the program in the RAM initialisation. Real CPUs
  load programs from external storage. What would need to change in this
  architecture to support loading a different program at runtime?

---

## Mid-Submission Checklist

This is the mid-submission point. Your fork must contain the following
in `bootcamp/week1/` through `bootcamp/week4/`:

### Week 4 required files
- [ ] `alu4_extended.vhd` — compiles without errors or latch warnings.
- [ ] `tb_alu4_extended.vhd` — all operations tested, carry case covered.
- [ ] `ram8x8.vhd` — synchronous, valid signal works correctly.
- [ ] `tb_ram8x8.vhd` — write + read + valid timing verified.
- [ ] `week4_report.pdf` — RTL netlists and waveform screenshots for both
      exercises, plus 2–3 sentence bug notes per exercise.

### Week 4 optional
- [ ] `mini_acc.vhd` — correct final accumulator value.
- [ ] `tb_mini_acc.vhd` — done signal fires on correct cycle.
- [ ] Block diagram (included in `week4_report.pdf` or separate scan).

### Carry-over check (must be in fork before mid submission)
- [ ] Week 1: 3 exercises each in own folder + `week1_report.pdf`.
- [ ] Week 2: 3 exercises each in own folder + `week2_report.pdf`.
- [ ] Week 3: 2 required + optional (if done) + `week3_report.pdf`.
