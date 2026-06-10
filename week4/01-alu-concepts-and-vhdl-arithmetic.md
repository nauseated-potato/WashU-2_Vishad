# Week 4 · Module 1 — The Arithmetic Logic Unit: Concepts & VHDL Arithmetic

By the end of Week 3 you could build FSMs that remember state and react to
inputs. This week you build two components that sit at the very heart of
every CPU: the **Arithmetic Logic Unit (ALU)** and a **RAM block**. Together
with the FSM you already know, these are literally the three ingredients that
make the WashU-2 CPU possible. Everything from Week 5 onward is just
connecting these pieces.

This module covers what an ALU is, how signed and unsigned arithmetic works
in VHDL, and the `numeric_std` library that makes it practical. Module 2
builds the complete 4-bit ALU step by step.

> **Video — What is an ALU? (crash course, 7 min):**
> [ALU — How Computers Do Math (Crash Course Computer Science #5)](https://www.youtube.com/watch?v=1I5ZMmrOfnA)
> *(Excellent conceptual overview of what an ALU does and why — watch first
> if the concept is unfamiliar)*

---

## 1. What is an ALU?

An **Arithmetic Logic Unit** is a combinational circuit that takes two
operands and an operation selector, and produces a result. It is
*combinational* — no clock, no state, outputs change immediately when
inputs change.

```
      a[3:0] ──────────┐
                       ▼
      b[3:0] ──────►  ALU  ──────► result[3:0]
                       ▲
    op[2:0]  ──────────┘           + flags (zero, carry, overflow…)
```

The `op` input selects which operation to perform. The ALU simply routes
the operands through the selected logic and outputs the answer. No
clocking, no memory.

For the WashU-2 CPU, the ALU operations are: ADD, SUB, AND, OR, NOT
(unary, uses only A), and NEGATE (two's-complement negation of A).

Every CPU instruction that touches data — arithmetic, logic, comparisons —
passes through the ALU. Understanding it thoroughly means understanding
what a CPU can actually *do*.

---

## 2. Representing numbers: unsigned vs signed

A 4-bit signal can represent:
- **Unsigned:** 0 to 15 (`0000` = 0, `1111` = 15)
- **Signed (two's complement):** −8 to +7 (`0000` = 0, `0111` = +7,
  `1000` = −8, `1111` = −1)

The bits are identical — only the *interpretation* changes. The VHDL type
`std_logic_vector` has no interpretation; it is just bits. To do arithmetic
you must tell VHDL which interpretation to use.

### Two's complement — the essential rule

To negate a number in two's complement:
1. Invert all bits (NOT).
2. Add 1.

Example: negate `0011` (+3):
- Invert: `1100`
- Add 1: `1101` → which represents −3 in 4-bit signed.

Check: `0011 + 1101 = 10000` — the lower 4 bits are `0000` = 0. Correct.

This rule is how `NEGATE` and `SUB` operations work internally in hardware.
`A − B = A + (NOT B) + 1`. The ALU never needs a separate subtraction
circuit — it reuses the adder with a negated operand.

> **Video — Two's complement explained (Ben Eater, 10 min):**
> [Binary: Signed integers and two's complement](https://www.youtube.com/watch?v=4qH4unVtJkE)
> *(Builds intuition from scratch for two's complement encoding and why it works)*

---

## 3. The `numeric_std` library

VHDL's standard `std_logic_vector` does not support `+`, `-`, or comparison
operators. You must convert to a numeric type first. The correct library for
this is `IEEE.NUMERIC_STD`.

```vhdl
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;   -- gives us: unsigned, signed, and arithmetic operators
```

`numeric_std` defines two numeric types built from `std_logic`:

| Type | Meaning | Range (4-bit) |
|---|---|---|
| `unsigned` | Non-negative integer | 0 to 15 |
| `signed` | Two's complement integer | −8 to +7 |

Both types support `+`, `-`, `*`, comparison operators (`<`, `>`, `=`), and
conversion functions.

> **Never use `std_logic_arith` or `std_logic_unsigned`.** These are
> non-standard Synopsys packages that cause portability problems. Always use
> `numeric_std`. If you see code using them online, translate it.

---

## 4. Type conversions in `numeric_std`

Because VHDL is strongly typed, you will constantly convert between
`std_logic_vector`, `unsigned`, `signed`, and `integer`. Here are the
conversions you will use every week:

```vhdl
-- std_logic_vector → unsigned (for addition/subtraction without sign)
signal a_vec : std_logic_vector(3 downto 0);
signal a_uns : unsigned(3 downto 0);
a_uns <= unsigned(a_vec);

-- std_logic_vector → signed (for signed arithmetic)
signal a_sig : signed(3 downto 0);
a_sig <= signed(a_vec);

-- unsigned/signed → std_logic_vector (to drive an output port)
signal result_vec : std_logic_vector(3 downto 0);
result_vec <= std_logic_vector(a_uns + b_uns);

-- integer → unsigned/signed (for constants and loop bounds)
signal count : unsigned(3 downto 0);
count <= to_unsigned(5, 4);    -- value 5, 4-bit result

-- unsigned/signed → integer (rarely needed in synthesis)
variable n : integer;
n := to_integer(count);
```

The pattern you will use constantly for ALU arithmetic:

```vhdl
-- Add two std_logic_vectors and get a std_logic_vector result:
result <= std_logic_vector(unsigned(a) + unsigned(b));

-- Signed addition (same bit pattern, different overflow behaviour):
result <= std_logic_vector(signed(a) + signed(b));

-- Bitwise AND/OR/NOT work directly on std_logic_vector — no cast needed:
result <= a and b;
result <= a or b;
result <= not a;
```

---

## 5. The operation selector: `std_logic_vector` and `case`

The ALU selects its operation using a `case` statement on the `op` input.
This is the same `case` pattern you used in FSM Process 2, but simpler —
there is no state, no `next_state`, just: given `op`, assign `result`.

```vhdl
-- ALU operation codes — defined as constants for readability
constant ALU_ADD    : std_logic_vector(2 downto 0) := "000";
constant ALU_SUB    : std_logic_vector(2 downto 0) := "001";
constant ALU_AND    : std_logic_vector(2 downto 0) := "010";
constant ALU_OR     : std_logic_vector(2 downto 0) := "011";
constant ALU_NOT    : std_logic_vector(2 downto 0) := "100";
constant ALU_NEGATE : std_logic_vector(2 downto 0) := "101";

-- In the combinational process:
case op is
    when ALU_ADD    => result <= std_logic_vector(unsigned(a) + unsigned(b));
    when ALU_SUB    => result <= std_logic_vector(unsigned(a) - unsigned(b));
    when ALU_AND    => result <= a and b;
    when ALU_OR     => result <= a or b;
    when ALU_NOT    => result <= not a;
    when ALU_NEGATE => result <= std_logic_vector(-signed(a));
    when others     => result <= (others => '0');
end case;
```

Notice: `(others => '0')` is a VHDL aggregate that fills every bit with `'0'`,
regardless of vector width. It is the cleanest way to zero-out a vector.

---

## 6. Flags: zero detection

Many ALUs produce **flag** outputs alongside the result — single bits that
describe properties of the result. The most important for the WashU-2 CPU is
the **zero flag**: `result = 0`.

```vhdl
-- Zero flag: '1' if all result bits are '0'
zero <= '1' when result = (result'range => '0') else '0';

-- Simpler and more readable equivalent:
zero <= '1' when unsigned(result) = 0 else '0';
```

The zero flag is what makes conditional branches (`BRZERO`) possible: the
CPU only follows the branch if the accumulator result is zero.

Other common flags (not required in Week 4 but good to know):
- **Carry:** the bit shifted out of the MSB during addition.
- **Overflow:** signed overflow (carry into MSB ≠ carry out of MSB).
- **Negative:** the sign bit (MSB) of the result.

---

## 7. Concurrent signal assignment: an ALU without a process

Because the ALU is purely combinational, you can implement the output
assignments as **concurrent signal assignments** in the architecture body,
without any process at all. This is an alternative VHDL style worth knowing:

```vhdl
architecture rtl of alu4 is
    signal add_result : std_logic_vector(3 downto 0);
    signal sub_result : std_logic_vector(3 downto 0);
    -- etc.
begin
    add_result <= std_logic_vector(unsigned(a) + unsigned(b));
    sub_result <= std_logic_vector(unsigned(a) - unsigned(b));

    with op select result <=
        add_result when "000",
        sub_result when "001",
        a and b    when "010",
        a or b     when "011",
        not a      when "100",
        std_logic_vector(-signed(a)) when "101",
        (others => '0') when others;
end rtl;
```

The `with … select` statement is the concurrent equivalent of a `case`
inside a process. Both styles synthesise to the same hardware (a multiplexer).
The process-based `case` style is used in Module 2 because it is more
familiar from Week 3. Either is correct.

---

## 8. Summary: what you need before building the ALU

Before starting Module 2, make sure you can answer these without looking:

1. What does the `op` input to an ALU select?
2. Why do we cast `std_logic_vector` to `unsigned` or `signed` before adding?
3. What does `(others => '0')` produce for a 4-bit vector?
4. How do you compute `A − B` using only addition and bit inversion?
5. What does the zero flag indicate, and why is it important for branches?

If any of these feel uncertain, re-read the relevant section above before
moving on. The ALU implementation in Module 2 uses all of these concepts
without re-explaining them.

---

Next: **Module 2 — Building the 4-bit ALU**
