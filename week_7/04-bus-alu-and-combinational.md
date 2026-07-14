# Week 7 · Module 4 — The Bus, ALU, and Combinational Logic

This module adds everything between `begin` and the first process: the RAM
instantiation, the bus multiplexer, IR field extraction, the ALU, and the
flag logic. All of these are concurrent statements — they have no clock and
respond immediately whenever their inputs change.

---

## 1. RAM instantiation

The RAM uses direct entity instantiation — no `component` declaration
needed (Module 3 §1 explains why). Key connections:
- `addr` takes only the lower 12 bits of `mar` — the RAM is 12-bit addressed
- `data_in` is wired to `the_bus`, not directly to `mbr` (explained in §6)
- `data_out` feeds `mem_data_out`, which later drives the bus when `bus_mem='1'`

```vhdl
    -- ----------------------------------------------------------------
    -- RAM (4096 × 16 bits)
    -- Direct entity instantiation: no component declaration needed.
    -- data_in is wired to the_bus so that DSTORE can write ACC to memory
    -- in a single cycle (see §6 for the full explanation).
    -- ----------------------------------------------------------------
    ram_inst : entity work.washu2_ram
        port map (
            clk      => clk,
            we       => mem_we,
            addr     => mar(11 downto 0),
            data_in  => the_bus,
            data_out => mem_data_out
        );
```

Note `mar(11 downto 0)` — the full MAR is 16 bits but only the lower 12
are used as the RAM address. The upper 4 bits of MAR are always zero for
a correctly-written program (the WashU-2 only has a 12-bit address space),
but truncating here is safer than relying on that assumption.

---

## 2. IR field extraction

Two concurrent assignments split the 16-bit instruction register into its
opcode and address fields. These are pure wire assignments — no logic, no
clock:

```vhdl
    -- ----------------------------------------------------------------
    -- IR field extraction (combinational wires)
    -- ----------------------------------------------------------------
    ir_opcode <= ir(15 downto 12);   -- 4-bit opcode
    ir_addr   <= ir(11 downto 0);    -- 12-bit operand/address field
```

The sign-extended version of `ir_addr` is used by `CLOAD`. The extension
rule (from Week 6 Module 3): replicate `ir(11)` into bits 15:12:

```vhdl
    ir_addr_se <= (15 downto 12 => ir(11)) & ir(11 downto 0);
```

`(15 downto 12 => ir(11))` is a VHDL aggregate that sets all four bit
positions 15, 14, 13, 12 to the value of `ir(11)`. Combined with `&`
(concatenation), the result is a 16-bit sign-extended version of the
12-bit operand. This is the same technique used in Week 4 for carry
detection, applied here to sign extension.

---

## 3. The bus multiplexer

The shared bus is implemented as a `with ... select` concurrent assignment
(the same construct used in Week 4). The select expression is the
**concatenation of all seven `bus_X` signals** into a single 7-bit vector.
Because exactly one `bus_X` is `'1'` at any time, the result is always
a **one-hot** pattern — one bit set, all others zero.

**One-hot patterns for 7 bus sources:**

| Active signal | 7-bit pattern | Source driven |
|---|---|---|
| `bus_pc`       | `"1000000"` | `pc` |
| `bus_mbr`      | `"0100000"` | `mbr` |
| `bus_acc`      | `"0010000"` | `acc` |
| `bus_ir_lower` | `"0001000"` | `ir_addr` zero-extended to 16 bits |
| `bus_ir_se`    | `"0000100"` | `ir_addr_se` (sign-extended) |
| `bus_alu`      | `"0000010"` | `alu_result` |
| `bus_mem`      | `"0000001"` | `mem_data_out` |

Reading `"1000000"`: bit 6 = `bus_pc`, bit 5 = `bus_mbr`, ..., bit 0 = `bus_mem`.
When `bus_pc='1'` and all others `'0'`, the concatenation gives `"1000000"`.

**New syntax — type qualification `std_logic_vector'(...)`:**
When you concatenate signals inside a `with` expression, VHDL cannot
automatically determine the type of the concatenated result (unlike in an
assignment statement where the target type is known). The type qualification
`std_logic_vector'(...)` tells the compiler explicitly: "treat this
concatenation as a `std_logic_vector`." You will only see this syntax in
`with` expressions that concatenate signals — everywhere else concatenation
works without it.

```vhdl
    -- ----------------------------------------------------------------
    -- Bus multiplexer: exactly one bus_X signal is '1' per cycle.
    -- The seven bus_X signals are concatenated into a 7-bit one-hot
    -- select vector. std_logic_vector'(...) is required syntax here
    -- to tell the compiler the type of the concatenated expression.
    -- ----------------------------------------------------------------
    with std_logic_vector'(bus_pc       &
                           bus_mbr      &
                           bus_acc      &
                           bus_ir_lower &
                           bus_ir_se    &
                           bus_alu      &
                           bus_mem) select
        the_bus <=
            pc                                  when "1000000",  -- bus_pc
            mbr                                 when "0100000",  -- bus_mbr
            acc                                 when "0010000",  -- bus_acc
            (15 downto 12 => '0') & ir_addr     when "0001000",  -- bus_ir_lower
            ir_addr_se                          when "0000100",  -- bus_ir_se
            alu_result                          when "0000010",  -- bus_alu
            mem_data_out                        when "0000001",  -- bus_mem
            (others => '0')                     when others;
```

`(15 downto 12 => '0') & ir_addr` zero-extends `ir_addr` from 12 to 16
bits: the aggregate `(15 downto 12 => '0')` produces a 4-bit zero vector,
which is then concatenated with the 12-bit `ir_addr`. Same `&` operator
you have used since Week 4.

The `when others` arm produces `x"0000"` if no `bus_X` is asserted.
This should never happen in correct operation, but prevents `the_bus`
from being `'U'` during the reset state before the FSM starts.

---

## 4. The ALU

The WashU-2 ALU is a combinational process with `acc` and `the_bus` as
its two inputs (A and B respectively). In the Week 6 architecture, the
ALU's B input comes from MBR via the bus — so when the FSM asserts
`bus_mbr='1'`, `the_bus` carries the MBR value, and the ALU sees it on
its B input. This is how `ADD`, `AND`, `DLOAD`, and `ILOAD` all work:
the memory operand reaches the ALU through MBR → bus → ALU-B.

```vhdl
    -- ----------------------------------------------------------------
    -- ALU (combinational)
    -- Inputs:  A = acc,       B = the_bus
    -- Output:  alu_result
    -- ----------------------------------------------------------------
    alu_proc : process (acc, the_bus, alu_op)
    begin
        case alu_op is
            when ALU_ADD =>
                -- A + B: standard unsigned addition
                alu_result <= std_logic_vector(
                    unsigned(acc) + unsigned(the_bus));

            when ALU_AND =>
                -- A AND B: bitwise
                alu_result <= acc and the_bus;

            when ALU_NOT =>
                -- NOT A: bitwise invert (first step of NEGATE)
                -- B is ignored
                alu_result <= not acc;

            when ALU_INC =>
                -- A + 1: second step of NEGATE
                -- B is ignored
                alu_result <= std_logic_vector(
                    unsigned(acc) + to_unsigned(1, 16));

            when ALU_PASS_B =>
                -- Pass B through unchanged (used for DLOAD, ILOAD)
                alu_result <= the_bus;

            when others =>
                alu_result <= (others => '0');
        end case;
    end process alu_proc;
```

**Why is the ALU's B input `the_bus` in Week 7?**

For the five Week 7 instructions this is correct and sufficient:

- `NEGATE` uses `ALU_NOT` and `ALU_INC` — neither uses the B input at all.
- `DLOAD` uses `ALU_PASS_B` in `load1`, where `bus_mbr='1'` makes
  `the_bus = mbr`. So `ALU_PASS_B` passes `mbr` through to `alu_result`
  via `the_bus` without any problem.

In Week 8, adding `ADD` and `AND` creates a circular dependency: `add1`
asserts `bus_alu='1'`, making `the_bus = alu_result`, while the ALU also
reads `the_bus` as its B input — `alu_result = acc + alu_result` has no
stable solution. Week 8 Module 2 fixes this by changing the ALU B input
from `the_bus` to `mbr` directly. For now, `the_bus` is correct.

---

## 5. Flag logic

Three combinational flag signals derived from `acc`. These are used by the
branch instructions in Week 8, but declaring and connecting them now costs
nothing and means the Week 8 extension is a one-line addition to the FSM:

```vhdl
    -- ----------------------------------------------------------------
    -- Condition flags (combinational from acc)
    -- ----------------------------------------------------------------
    zero_flag <= '1' when acc = x"0000"                          else '0';
    pos_flag  <= '1' when acc(15) = '0' and acc /= x"0000"      else '0';
    neg_flag  <= acc(15);   -- MSB is the sign bit in two's complement
```

`neg_flag` is just a wire alias for `acc(15)` — no logic at all. `zero_flag`
and `pos_flag` are simple comparisons. All three update within the same
combinational delta cycle whenever `acc` changes.

---

## 6. Memory write timing: why `mem_we` and `mbr_ld` in `store1`

Looking ahead to `store1`: the Week 6 control table shows `bus_acc=1`,
`mbr_ld=1`, and `mem_we=1` simultaneously. Here is the exact mechanism:

1. The FSM sets `bus_acc='1'` → `the_bus = acc` (combinational, immediate).
2. `mbr_ld='1'` → on the rising clock edge, `mbr <= the_bus = acc`.
3. `mem_we='1'` → also on the rising clock edge, the RAM uses the current
   `mbr` value (the **old** mbr, before the edge update) as `data_in`...

Wait — this means `store1` writes the *old* MBR to memory, not `acc`. That
is wrong. The problem: if `data_in` were wired to `mbr`, `mem_we` in `store1`
would write the *stale* MBR value — not `acc`.

**The solution: wire `data_in` to `the_bus`** (which is what the RAM
instantiation in §1 already does). When `bus_acc='1'`, `the_bus = acc`
combinationally. The RAM receives `acc` as `data_in` the same instant —
no extra cycle needed. When `mem_we='1'` fires at the rising edge, the
RAM stores `the_bus` (= `acc`) at address `mar`. MBR is also updated
as a side-effect (via `mbr_ld='1'`), but it is not the source of the
write.

This is why §1 wires `data_in => the_bus` rather than `data_in => mbr`.

---

## 7. Compile checkpoint

After adding all the concurrent statements from this module, compile again.
Expected result: no errors, possibly a warning about unused signals (that
is fine — the processes in Modules 5 and 6 will use them). Fix any errors
before proceeding.

---

Next: **Module 5 — The Registered Process: Updating Registers and State**
