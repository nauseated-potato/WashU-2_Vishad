# Week 4 · Module 7 — Debugging ALU & RAM + Quick Reference

This module collects the most common bugs in ALU and RAM designs, how to
spot them in the waveform, and how to fix them. It also serves as a
reference card for all new VHDL syntax introduced this week — keep it open
while working on the exercises.

---

## 1. ALU debugging: the seven most common problems

### Bug 1 — Using `std_logic_arith` / `std_logic_unsigned`

**Symptom:** Design compiles and works in Quartus, but fails in other tools
or when ported. Subtle type mismatch warnings.

**Fix:** Replace with `IEEE.NUMERIC_STD.ALL`. Then:
- `std_logic_vector` → `unsigned(...)` → arithmetic → `std_logic_vector(...)`

---

### Bug 2 — Reading an `out` port back

**Symptom (VHDL-93):** Compiler error: *"signal result cannot be read in
this context"*.

```vhdl
-- Wrong: reading 'result' (an out port) in the same architecture
zero <= '1' when result = "0000" else '0';  -- error in VHDL-93
```

**Fix:** use an internal signal:

```vhdl
signal result_int : std_logic_vector(3 downto 0);
...
result <= result_int;
zero   <= '1' when result_int = "0000" else '0';
```

---

### Bug 3 — Missing signal in sensitivity list

**Symptom:** Simulation gives wrong results when one input changes but the
others do not. Adding a `wait for 1 ns` makes it correct (indicating a
re-evaluation was needed).

```vhdl
-- Wrong for a 3-input combinational process:
process (a, op)   -- b is missing!

-- Correct:
process (a, b, op)
```

---

### Bug 4 — Incorrect type cast for signed operations

**Symptom:** NEGATE gives the wrong result, or the result is always 0.

```vhdl
-- Wrong: unsigned cannot be negated
result_int <= std_logic_vector(-unsigned(a));  -- compile error

-- Correct: negate as signed
result_int <= std_logic_vector(-signed(a));
```

---

### Bug 5 — Carry flag not wide enough

**Symptom:** Carry is always `'0'` even for large additions.

```vhdl
-- Wrong: 4-bit + 4-bit = 4-bit, carry is dropped silently
result_int <= std_logic_vector(unsigned(a) + unsigned(b));
carry_int  <= ???   -- no 5th bit to read

-- Correct: use 5-bit arithmetic
signal sum5 : unsigned(4 downto 0);
sum5       <= ('0' & unsigned(a)) + ('0' & unsigned(b));
result_int <= std_logic_vector(sum5(3 downto 0));
carry_int  <= sum5(4);
```

---

### Bug 6 — No `when others` arm in the case statement

**Symptom:** Quartus warning: *"Case statement does not cover all
conditions."* Undefined op codes may cause `result` to hold its previous
value (latch inferred).

**Fix:** always include `when others => result_int <= (others => '0');`.

---

### Bug 7 — Latch inferred for `result_int`

**Symptom:** Quartus warning: *"Latch inferred for signal result_int."*
Result holds its previous value when it should be `"0000"`.

**Cause:** `result_int` is not assigned in every branch of the `case`
statement.

**Fix:** add a default assignment before the `case`:

```vhdl
result_int <= (others => '0');   -- default before case
case op is
    ...
end case;
```

---

## 2. RAM debugging: the five most common problems

### Bug 1 — Checking `data_out` too early (read latency)

**Symptom:** `data_out` shows `'U'` or zeros when you check it immediately
after a read request.

**Fix:** always wait **one extra clock cycle** after the read request before
checking `data_out`. The registered read stores the value on the edge; it
appears on `data_out` one cycle later.

```vhdl
-- Wrong
we <= '0'; addr <= "001";
wait until rising_edge(clk);
-- data_out is NOT valid here yet

-- Correct
we <= '0'; addr <= "001";
wait until rising_edge(clk);   -- read request issued
wait until rising_edge(clk);   -- data_out is now valid
-- check data_out here
```

---

### Bug 2 — Bus contention (`'X'` on `data_bus`)

**Symptom:** `data_bus` shows `'X'` (conflicting drivers) during read
cycles in simulation.

**Cause:** the testbench is driving `data_bus` at the same time as the RAM.

**Fix:** make the testbench tri-state the bus when `we='0'`:

```vhdl
data_bus <= cpu_data when we = '1' else (others => 'Z');
```

---

### Bug 3 — Using `addr` directly as an array index

**Symptom:** Compiler error: *"type std_logic_vector cannot be used as
array index"*.

```vhdl
-- Wrong
data_out <= ram_mem(addr);

-- Correct
data_out <= ram_mem(to_integer(unsigned(addr)));
```

---

### Bug 4 — RAM not inferring block RAM

**Symptom:** RTL Viewer shows flip-flops instead of a memory block.
Compilation succeeds but uses many more logic elements than expected.

**Cause:** the read or write is not inside `if rising_edge(clk) then`.

```vhdl
-- Wrong: asynchronous read — Quartus cannot infer block RAM
data_out <= ram_mem(to_integer(unsigned(addr)));  -- outside clocked process

-- Correct: both read and write inside clocked process
if rising_edge(clk) then
    if we = '1' then
        ram_mem(...) <= data_in;
    end if;
    data_out <= ram_mem(...);    -- inside the clocked block
end if;
```

---

### Bug 5 — Forgetting to initialise RAM

**Symptom:** `data_out` shows `'U'` (undriven) on first read even though
you just "wrote" something. The write looks correct in the waveform.

**Cause:** The RAM was never initialised. VHDL simulates uninitialized
`std_logic` as `'U'`. On a real FPGA, the power-up content is undefined.

**Fix:** initialise in the signal declaration:

```vhdl
signal ram_mem : ram_type := (others => (others => '0'));
```

---

## 3. Systematic debugging workflow for Week 4

```
ALU problems:
  1. Does it compile without warnings? Fix all warnings first.
  2. Apply a single known input (e.g., ADD 3+5). Does result = "1000"?
  3. If not: check sensitivity list, then check the case arm for ADD.
  4. Check zero flag for the 0+0 case. If wrong: check result_int vs result.
  5. Check carry for 15+1. If wrong: check 5-bit arithmetic.
  6. Test remaining ops one at a time.

RAM problems:
  1. Does it compile? Fix all warnings (especially "latch inferred").
  2. Write one value, then read it back. Does data_out match?
     If not: check if you are waiting for the correct number of cycles.
  3. Check valid timing: is valid high exactly the cycle after the read?
  4. If using inout: check for 'X' on the bus. If present: check who is
     driving the bus during reads.
  5. Open RTL Viewer: does Quartus show a RAM block or flip-flops?
```

---

## 4. New VHDL syntax introduced this week — quick reference

### Concatenation operator `&`

Join two signals or values:

```vhdl
signal a4 : std_logic_vector(3 downto 0);
signal a5 : std_logic_vector(4 downto 0);
a5 <= '0' & a4;     -- prepend a '0': a5 = 0 & a[3:0]
a5 <= a4 & '0';     -- append a '0': a5 = a[3:0] & 0 (left-shift by 1)
```

### Aggregate initialisation `(others => ...)`

Set all elements of a vector or array to the same value:

```vhdl
signal result : std_logic_vector(7 downto 0);
result <= (others => '0');    -- "00000000"
result <= (others => '1');    -- "11111111"
result <= (others => 'Z');    -- "ZZZZZZZZ"

-- For a 2D array (RAM):
signal ram_mem : ram_type := (others => (others => '0'));
```

### Array type declaration

```vhdl
type <type_name> is array (<range>) of <element_type>;

-- Examples:
type ram_type   is array (0 to 15) of std_logic_vector(7 downto 0);  -- 16×8 RAM
type lut_type   is array (0 to 7)  of std_logic_vector(3 downto 0);  -- 8×4 LUT
type byte_array is array (natural range <>) of std_logic_vector(7 downto 0); -- unconstrained
```

### `inout` port mode

```vhdl
port (
    data_bus : inout std_logic_vector(7 downto 0)
);
-- Drive it:    data_bus <= value;
-- Tri-state:   data_bus <= (others => 'Z');
-- Read from:   my_signal <= data_bus;  (works regardless of who drives)
```

### 5-bit carry detection

```vhdl
signal a5, b5, sum5 : unsigned(4 downto 0);
a5   <= '0' & unsigned(a);    -- zero-extend 4→5 bits
b5   <= '0' & unsigned(b);
sum5 <= a5 + b5;
result_int <= std_logic_vector(sum5(3 downto 0));   -- result bits
carry_int  <= sum5(4);                               -- carry bit
```

### Numeric conversions reference

```vhdl
-- std_logic_vector → unsigned → arithmetic → std_logic_vector
std_logic_vector(unsigned(a) + unsigned(b))

-- std_logic_vector → signed → negate → std_logic_vector
std_logic_vector(-signed(a))

-- std_logic_vector → unsigned → integer (for array index)
to_integer(unsigned(addr))

-- integer → unsigned (for constant values)
to_unsigned(5, 4)    -- value 5 as a 4-bit unsigned

-- unsigned/signed → std_logic_vector
std_logic_vector(my_unsigned_signal)
```

---

## 5. Recommended resources

**Numeric_std and type conversions:**
- [VHDL numeric_std — the definitive guide (VHDLwhiz)](https://vhdlwhiz.com/numeric-std/)
  *Written reference, covers every conversion with examples. Bookmark this.*

**RAM inference in Quartus:**
- [Inferred Memory — Intel Quartus documentation](https://www.intel.com/content/www/us/en/docs/programmable/683082/current/inferred-memory.html)
  *Official guide on how to write VHDL that Quartus recognises as block RAM.*

**Video — VHDL Arrays and RAM (2023):**
- [VHDL Arrays — How to Use Them](https://www.youtube.com/watch?v=5hIVzKVoOuo)
  *Covers array type declaration, initialisation, and indexing with worked examples*

**Video — Understanding bidirectional buses:**
- [Tri-State Buffers & Buses in VHDL](https://www.youtube.com/watch?v=3uXD_JFdqCM)
  *Explains `'Z'`, bus contention, and the `inout` port mode*

---

*Week 4 complete. You now have the three fundamental CPU components:
an FSM (Week 3), an ALU (this week), and a RAM (this week). Week 5 connects
them into a working, if tiny, processor. The concepts of this week — signed
arithmetic, memory read latency, and bus protocols — appear unchanged in the
WashU-2 CPU you build in Weeks 7 and 8.*
