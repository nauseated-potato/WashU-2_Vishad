# Week 4 · Module 2 — Building the 4-bit ALU

This module walks through the complete 4-bit ALU from entity declaration
to simulation, with every design decision explained. The ALU supports six
operations: ADD, SUB, AND, OR, NOT, and NEGATE. It also produces a zero
flag. Read every section before writing any code.

> **Video — Building an ALU in VHDL (FPGA tutorial, 2023):**
> [4-bit ALU in VHDL — Full Design Walkthrough](https://www.youtube.com/watch?v=RqhCp5TzFsQ)
> *(Covers entity, case statement for op selection, and waveform verification)*
>
> **Video — ALU Design with flags (Nandland):**
> [VHDL ALU Design](https://www.youtube.com/watch?v=h4v4KBnH2Kc)
> *(Another angle on the same problem, useful to watch both)*

---

## 1. Specification

```
entity alu4 is
    port (
        a      : in  std_logic_vector(3 downto 0);  -- operand A
        b      : in  std_logic_vector(3 downto 0);  -- operand B
        op     : in  std_logic_vector(2 downto 0);  -- operation select
        result : out std_logic_vector(3 downto 0);  -- operation result
        zero   : out std_logic                       -- '1' when result = 0
    );
end alu4;
```

Operation table:

| `op` | Operation | Expression |
|---|---|---|
| `"000"` | ADD    | `result = A + B` |
| `"001"` | SUB    | `result = A − B` |
| `"010"` | AND    | `result = A AND B` (bitwise) |
| `"011"` | OR     | `result = A OR B` (bitwise) |
| `"100"` | NOT    | `result = NOT A` (B ignored) |
| `"101"` | NEGATE | `result = −A` (two's complement, B ignored) |
| others  | —      | `result = "0000"` |

The `zero` flag is `'1'` whenever `result = "0000"`, regardless of the
operation. It is driven **from the result signal**, not computed separately.

---

## 2. Design decisions

### Why `std_logic_vector` for ports?

ALU ports are `std_logic_vector` rather than `unsigned` or `signed` because:
- The CPU buses are `std_logic_vector`.
- The port represents raw bits; the interpretation (signed vs unsigned)
  depends on the operation, not the wire.
- Using `std_logic_vector` at the boundary and casting internally is the
  standard practice.

### Why a `signal result_int`?

The output port `result` is mode `out`, which in VHDL-93 (the standard used
by Quartus by default) cannot be read back inside the architecture. To drive
the `zero` flag from the result, we need an internal signal that mirrors
the result:

```vhdl
signal result_int : std_logic_vector(3 downto 0);
...
result <= result_int;
zero   <= '1' when result_int = "0000" else '0';
```

This is a standard idiom. Without `result_int`, you would get a compile
error when trying to read `result` on the right-hand side of an assignment.

*(Note: VHDL-2008 allows reading `out` ports directly, but Quartus defaults
to VHDL-93. Use the internal signal to stay compatible.)*

### Why operation constants?

```vhdl
constant ALU_ADD    : std_logic_vector(2 downto 0) := "000";
```

Using named constants instead of bare string literals (`"000"`) means:
- A typo (`"0O0"` — letter O not zero) is caught at compile time.
- The operation table is self-documenting.
- If you ever need to reassign op codes, one change propagates everywhere.

---

## 3. Complete VHDL source

Study this line by line before using it. Every section maps directly to a
concept from Module 1.

```vhdl
-- alu4.vhd
-- 4-bit ALU supporting ADD, SUB, AND, OR, NOT, NEGATE.
-- Purely combinational: no clock, no state.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity alu4 is
    port (
        a      : in  std_logic_vector(3 downto 0);
        b      : in  std_logic_vector(3 downto 0);
        op     : in  std_logic_vector(2 downto 0);
        result : out std_logic_vector(3 downto 0);
        zero   : out std_logic
    );
end alu4;

architecture rtl of alu4 is

    -- Internal signal so we can read 'result' back for the zero flag.
    -- (VHDL-93 does not allow reading 'out' ports internally.)
    signal result_int : std_logic_vector(3 downto 0);

    -- Operation select constants — change here to re-assign op codes
    constant ALU_ADD    : std_logic_vector(2 downto 0) := "000";
    constant ALU_SUB    : std_logic_vector(2 downto 0) := "001";
    constant ALU_AND    : std_logic_vector(2 downto 0) := "010";
    constant ALU_OR     : std_logic_vector(2 downto 0) := "011";
    constant ALU_NOT    : std_logic_vector(2 downto 0) := "100";
    constant ALU_NEGATE : std_logic_vector(2 downto 0) := "101";

begin

    -- =================================================================
    -- Combinational process: select operation based on 'op'
    -- No clock — this is pure combinational logic.
    -- Sensitivity list must include ALL inputs (a, b, op).
    -- =================================================================
    alu_logic : process (a, b, op)
    begin
        -- Default: output zero for any undefined op code
        result_int <= (others => '0');

        case op is
            when ALU_ADD =>
                -- Unsigned addition. Cast both operands, add, cast back.
                result_int <= std_logic_vector(unsigned(a) + unsigned(b));

            when ALU_SUB =>
                -- Unsigned subtraction. Wraps on underflow (e.g. 3−5 = 14).
                result_int <= std_logic_vector(unsigned(a) - unsigned(b));

            when ALU_AND =>
                -- Bitwise AND. No cast needed — operates directly on bits.
                result_int <= a and b;

            when ALU_OR =>
                -- Bitwise OR.
                result_int <= a or b;

            when ALU_NOT =>
                -- Bitwise NOT (unary). B is ignored.
                result_int <= not a;

            when ALU_NEGATE =>
                -- Two's complement negation of A. B is ignored.
                -- signed(a) interprets A as a signed number; unary minus
                -- negates it; we cast back to std_logic_vector.
                result_int <= std_logic_vector(-signed(a));

            when others =>
                -- Undefined op: output zero (safety default)
                result_int <= (others => '0');
        end case;
    end process alu_logic;

    -- =================================================================
    -- Output drivers: connect internal result to ports
    -- =================================================================
    result <= result_int;

    -- Zero flag: asserted whenever the result is all zeros
    zero <= '1' when result_int = "0000" else '0';

end rtl;
```

---

## 4. Worked examples: expected outputs

Before simulating, compute these by hand and verify your simulation matches.

**ADD: `a = "0011"` (3), `b = "0101"` (5), op = "000"**
- `3 + 5 = 8` → `result = "1000"`, `zero = '0'`

**SUB: `a = "0101"` (5), `b = "0011"` (3), op = "001"**
- `5 − 3 = 2` → `result = "0010"`, `zero = '0'`

**SUB with wrap: `a = "0001"` (1), `b = "0011"` (3), op = "001"**
- Unsigned: `1 − 3` wraps → `result = "1110"` (14 unsigned), `zero = '0'`
- As signed this is `−2`, which also gives `"1110"` — consistent.

**AND: `a = "1010"`, `b = "1100"`, op = "010"**
- `1010 AND 1100 = 1000` → `result = "1000"`, `zero = '0'`

**OR: `a = "1010"`, `b = "0101"`, op = "011"**
- `1010 OR 0101 = 1111` → `result = "1111"`, `zero = '0'`

**NOT: `a = "1010"`, op = "100"**
- `NOT 1010 = 0101` → `result = "0101"`, `zero = '0'`

**NEGATE: `a = "0011"` (+3), op = "101"**
- `−0011`: invert → `1100`, add 1 → `1101` → `result = "1101"`, `zero = '0'`
- Check: `0011 + 1101 = 10000` → lower 4 bits = `0000`. Correct.

**NEGATE zero: `a = "0000"`, op = "101"**
- `−0000`: invert → `1111`, add 1 → `10000` → lower 4 bits = `0000`
- `result = "0000"`, `zero = '1'` ← the zero flag fires

**ADD overflow: `a = "1111"` (15), `b = "0001"` (1), op = "000"**
- `15 + 1 = 16` → 5 bits; lower 4 bits = `"0000"`, carry discarded
- `result = "0000"`, `zero = '1'` ← zero flag fires on overflow wrapping to 0

Write all of these into a table and keep it next to you while simulating.

---

## 5. The zero flag in context: why it matters for the CPU

In the WashU-2 CPU, the `BRZERO` instruction (Branch if Zero) checks a
condition flag before deciding whether to change the program counter. The
zero flag from the ALU (latched into the accumulator's zero flag register)
is exactly what `BRZERO` reads. Without the zero flag, the CPU could not
loop — it could not check "have I done this N times yet?". Every `for` loop
in compiled code ultimately depends on a zero comparison exactly like this.

This is why `zero` is a required port of the ALU, not an optional extra.

---

## 6. Common mistakes

**Mistake 1: Using `std_logic_arith` or `std_logic_unsigned`**

```vhdl
-- Wrong: non-standard library
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

-- Correct: always use numeric_std
use IEEE.NUMERIC_STD.ALL;
```

The non-standard libraries work in Quartus but fail on other tools. Avoid them.

**Mistake 2: Forgetting `b` in the sensitivity list**

```vhdl
-- Wrong: b is read in the process but not listed
alu_logic : process (a, op)

-- Correct
alu_logic : process (a, b, op)
```

In simulation, if `b` changes while `op = ALU_ADD`, the process will not
re-evaluate and the result will be stale. This is a simulation-only bug
(synthesis ignores sensitivity lists) but causes confusing waveforms.

**Mistake 3: Driving `result` directly and then reading it back**

```vhdl
-- Wrong in VHDL-93: cannot read 'out' port
result <= std_logic_vector(unsigned(a) + unsigned(b));
zero   <= '1' when result = "0000" else '0';  -- compile error: 'result' is out
```

Use the `result_int` internal signal pattern shown in §3.

**Mistake 4: No `when others` arm**

Without `when others`, the `case` statement does not cover all 8 possible
op codes (only 6 are defined). The synthesiser will warn about incomplete
case coverage, and the behaviour for op codes `"110"` and `"111"` is
undefined. The default `(others => '0')` ensures a safe, predictable output.

---

## 7. RTL view in Quartus

After compiling the ALU, open **Tools → Netlist Viewers → RTL Viewer**.
You should see:
- A large multiplexer selecting between the six operation results.
- Six parallel computation paths feeding into the mux.
- A comparator (or AND-reduction) generating the `zero` flag from `result_int`.

If you see a latch symbol anywhere, check your sensitivity list and
defaults. A purely combinational circuit should synthesise with no latches.

---

Next: **Module 3 — Memory: RAM, ROM, and How Hardware Stores Data**
