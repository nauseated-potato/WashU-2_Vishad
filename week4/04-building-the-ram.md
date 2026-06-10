# Week 4 · Module 4 — Building the 16×8 RAM with Bidirectional Bus

This module builds the complete 16-location × 8-bit synchronous RAM with a
bidirectional data bus. Every design decision is explained step by step. The
RAM is one of the two components you submit at the mid-submission point —
together with the ALU and the FSM from Week 3.

---

## 1. Full specification

```
entity ram16x8 is
    port (
        clk      : in    std_logic;
        we       : in    std_logic;                     -- write enable
        addr     : in    std_logic_vector(3 downto 0);  -- 4-bit address (0..15)
        data_bus : inout std_logic_vector(7 downto 0)   -- bidirectional data
    );
end ram16x8;
```

**Behaviour:**
- On `rising_edge(clk)` with `we='1'`: write `data_bus` into location `addr`.
- On `rising_edge(clk)` with `we='0'`: read location `addr`; drive result
  onto `data_bus` on the *next* clock edge (registered read).
- When not actively reading (i.e., during a write, or when another device
  owns the bus), the RAM drives `data_bus` to `(others => 'Z')`.

---

## 2. Why `inout` and when to drive `'Z'`

The `inout` port mode means the port can be driven by the entity itself
*or* by something external. This creates a bus:

```
External driver (CPU/testbench) ─────┐
                                     ├──── data_bus ──── RAM internal storage
RAM output driver ───────────────────┘
```

The rule for a safe bidirectional bus:
- **Exactly one** driver is active at any time.
- All other drivers output `'Z'`.

If two drivers fight (one drives `'1'`, another drives `'0'`), the result
is `'X'` (unknown) in simulation and potentially hardware damage in real life.

For this RAM:
- During a **write** cycle: the CPU/testbench drives the bus; RAM must
  output `'Z'`.
- During a **read** cycle: the RAM drives the bus; CPU/testbench must
  output `'Z'`.

---

## 3. Complete VHDL source

```vhdl
-- ram16x8.vhd
-- 16-location × 8-bit synchronous RAM with bidirectional data bus.
-- Write on rising edge when we='1'.
-- Read on rising edge when we='0' (output appears on NEXT clock cycle).

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ram16x8 is
    port (
        clk      : in    std_logic;
        we       : in    std_logic;
        addr     : in    std_logic_vector(3 downto 0);
        data_bus : inout std_logic_vector(7 downto 0)
    );
end ram16x8;

architecture rtl of ram16x8 is

    -- Array type: 16 elements, each 8 bits wide
    type ram_type is array (0 to 15) of std_logic_vector(7 downto 0);

    -- RAM storage — initialised to all zeros.
    -- During simulation this gives predictable results.
    -- In synthesis, Quartus will infer block RAM (M9K) for this pattern.
    signal ram_mem : ram_type := (others => (others => '0'));

    -- Internal read-data register
    -- Holds the last read value; driven onto data_bus when we='0'.
    signal data_out_reg : std_logic_vector(7 downto 0) := (others => '0');

    -- Internal flag: are we in read mode this cycle?
    -- Needed to decide whether to drive the bus or tri-state it.
    signal read_active : std_logic := '0';

begin

    -- =================================================================
    -- Synchronous memory process: write and read on rising edge
    -- =================================================================
    mem_proc : process (clk)
    begin
        if rising_edge(clk) then
            if we = '1' then
                -- WRITE: store data_bus into addressed location.
                -- RAM does not drive the bus during a write (data is incoming).
                ram_mem(to_integer(unsigned(addr))) <= data_bus;
                read_active <= '0';
            else
                -- READ: capture addressed location into output register.
                data_out_reg <= ram_mem(to_integer(unsigned(addr)));
                read_active  <= '1';
            end if;
        end if;
    end process mem_proc;

    -- =================================================================
    -- Bidirectional bus driver
    -- Drive data_out_reg onto the bus when read_active='1'.
    -- Drive 'Z' when writing (bus is owned by the external driver).
    -- =================================================================
    data_bus <= data_out_reg when read_active = '1' else (others => 'Z');

end rtl;
```

---

## 4. Detailed walkthrough of each section

### The array type and `ram_mem`

```vhdl
type ram_type is array (0 to 15) of std_logic_vector(7 downto 0);
signal ram_mem : ram_type := (others => (others => '0'));
```

`(others => (others => '0'))` is a nested aggregate: the outer `others`
fills all 16 array positions; the inner `(others => '0')` fills all 8 bits
of each position with `'0'`. This initialises the entire RAM to zero.

### The `to_integer(unsigned(addr))` conversion

Array indices in VHDL must be `integer` (or a type with natural range).
`addr` is `std_logic_vector`. The conversion chain:
1. `unsigned(addr)` — interpret the bit pattern as a non-negative number.
2. `to_integer(...)` — convert to VHDL integer for use as an array index.

Do not skip the `unsigned` step: `to_integer` cannot accept
`std_logic_vector` directly.

### The `read_active` flag

The concurrent bus-driver statement needs to know whether to drive the bus
or tri-state it. Using a registered `read_active` flag (updated in the same
process as the memory) ensures the bus driver changes in sync with the data
output register — both update one cycle after the read is requested.

An alternative is to derive the drive condition from `we` directly:

```vhdl
data_bus <= data_out_reg when we = '0' else (others => 'Z');
```

This is simpler, but it changes the bus state *immediately* when `we`
changes (combinationally), which can cause a brief glitch between when `we`
changes and when the data register catches up. The `read_active` flag avoids
this. Use whichever your implementation is comfortable with, but understand
the difference.

---

## 5. Simulation timing: what to expect in the waveform

The registered read introduces a **one-cycle latency**. Here is the timing:

```
Cycle:       1       2       3       4       5
clk:    ____/‾‾‾‾\___/‾‾‾‾\___/‾‾‾‾\___/‾‾‾‾\___
we:          1       1       0       0
addr:        0       1       0       1
data_bus:  0xAB    0xCD      Z     [0xAB] [0xCD]
                             ↑       ↑
                          read req  output appears (1 cycle later)
```

- Cycles 1–2: writes. `we='1'`. The testbench drives data onto the bus;
  the RAM stores it. `read_active='0'` so the RAM outputs `'Z'` (bus free).
- Cycle 3: read address 0. `we='0'`. Bus is `'Z'` (RAM has not driven it
  yet — the data will appear on cycle 4).
- Cycle 4: `data_out_reg` now holds `0xAB` (captured on cycle 3's edge).
  `read_active='1'`, so RAM drives `0xAB` onto the bus.
- Cycle 5: read address 1. Same pattern — `0xCD` appears on cycle 6.

**This one-cycle read latency is by design.** It matches how the WashU-2
CPU's multi-cycle fetch works: it issues a read in one state and reads the
data in the next state.

---

## 6. Initialising RAM with a program (preview for Week 7)

When you build the WashU-2 CPU, you will need the RAM to contain a program
at power-up. The initialisation syntax from Module 3 is used:

```vhdl
signal ram_mem : ram_type := (
    -- A tiny test program for the WashU-2 CPU (preview — explained in Week 7)
    0  => "00000001",  -- CLOAD  1   (load constant 1 into accumulator)
    1  => "00100010",  -- ADD    2   (add value at address 2)
    2  => "00000101",  -- data: 5
    3  => "01100011",  -- DSTORE 3   (store result)
    others => (others => '0')
);
```

For now, keep the `(others => (others => '0'))` default. You will replace
it in Week 7 when you have a real program to load.

---

## 7. Common mistakes

**Mistake 1: Bus contention in the testbench**

The most frequent simulation bug when working with bidirectional buses is
the testbench *also* driving `data_bus` during a read cycle:

```vhdl
-- WRONG in testbench: driving the bus while the RAM also drives it
data_bus <= "11001100";   -- testbench always drives
-- Result: 'X' on the bus during read cycles
```

The testbench must tri-state the bus when reading:

```vhdl
-- CORRECT in testbench: release the bus for reads
data_bus <= (others => 'Z') when we = '0' else cpu_data_out;
```

**Mistake 2: Reading `data_bus` before the latency expires**

Checking `data_bus` on the same clock edge as the read request will give
`'Z'` or stale data. Always check one cycle after the read request.

**Mistake 3: Using `addr` directly as an array index**

```vhdl
-- WRONG: std_logic_vector cannot be used as an integer index
ram_mem(addr) <= data_bus;

-- CORRECT
ram_mem(to_integer(unsigned(addr))) <= data_bus;
```

**Mistake 4: Forgetting `NUMERIC_STD`**

```vhdl
-- Compile error: 'to_integer' and 'unsigned' not defined
-- unless you have:
use IEEE.NUMERIC_STD.ALL;
```

---

## 8. RTL view in Quartus

After compiling, open the RTL Viewer. You should see:
- A memory block (Quartus may represent this as a single "RAM" primitive
  when it successfully infers block RAM).
- Multiplexers and registers on the read/write control path.
- The bidirectional bus driver (a tri-state buffer symbol).

If the RTL Viewer shows an array of flip-flops instead of a RAM block, the
synthesiser could not infer block RAM — this usually means the process
structure does not match Quartus's recognised pattern. Check that both read
and write are inside `if rising_edge(clk) then`.

---

Next: **Module 5 — Exercises**
