# Week 4 · Module 6 — Testbenches for ALU and RAM Designs

Testing an ALU and testing a RAM require different strategies. An ALU is
combinational — you apply inputs and immediately read outputs. A RAM is
sequential — reads take a clock cycle, and write-then-read ordering matters.
This module covers both, provides a worked testbench for each, and explains
how to structure your own testbenches for Exercise 1 and 2.

---

## 1. Testing a combinational ALU

### Strategy

An ALU testbench is fundamentally an exhaustive (or near-exhaustive) truth
table. For each operation:
1. Apply `a`, `b`, `op`.
2. Wait a short propagation time (no clock needed — ALU is combinational).
3. Read `result`, `zero`, `carry`, `negative`.
4. Compare against expected.

Because the ALU has no clock, the testbench does not need a clock generator.
Inputs can change at arbitrary times. However, it is still good practice to
use a small `wait for N ns` between changes so the waveform is readable.

### Self-checking testbenches

For an ALU with many operations, manually checking the waveform is tedious.
A **self-checking testbench** uses VHDL `assert` statements to automatically
flag any mismatch:

```vhdl
-- After applying inputs and waiting:
assert result = "1000"
    report "ADD 3+5 failed: expected 1000, got " & to_string(result)
    severity error;
```

If the assertion fails, ModelSim prints the message and marks the simulation
as having errors. This is far faster than reading a waveform for 30+ test
cases.

The `to_string` function requires VHDL-2008 (`use IEEE.STD_LOGIC_1164.ALL`
in VHDL-2008 mode). If your Quartus project is in VHDL-93 mode, use this
workaround:

```vhdl
-- VHDL-93 compatible: just report a label, look at the waveform for the value
assert result = "1000"
    report "ADD 3+5 FAILED — check waveform at this timestamp"
    severity error;
```

### Worked ALU testbench (for `alu4` from Module 2)

```vhdl
-- tb_alu4.vhd
-- Self-checking testbench for the 4-bit ALU (Module 2 example).

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_alu4 is
end tb_alu4;

architecture sim of tb_alu4 is

    signal a      : std_logic_vector(3 downto 0) := (others => '0');
    signal b      : std_logic_vector(3 downto 0) := (others => '0');
    signal op     : std_logic_vector(2 downto 0) := (others => '0');
    signal result : std_logic_vector(3 downto 0);
    signal zero   : std_logic;

    -- Propagation delay — give the combinational logic time to settle
    constant PROP_DELAY : time := 10 ns;

begin

    uut : entity work.alu4
        port map (a => a, b => b, op => op, result => result, zero => zero);

    stimulus : process
    begin

        -- --------------------------------------------------------
        -- ADD tests
        -- --------------------------------------------------------
        op <= "000";
        a  <= "0011"; b <= "0101"; wait for PROP_DELAY;   -- 3+5=8
        assert result = "1000" and zero = '0'
            report "FAIL: ADD 3+5" severity error;

        a  <= "0000"; b <= "0000"; wait for PROP_DELAY;   -- 0+0=0
        assert result = "0000" and zero = '1'
            report "FAIL: ADD 0+0 (zero flag)" severity error;

        a  <= "1111"; b <= "0001"; wait for PROP_DELAY;   -- 15+1 wraps to 0
        assert result = "0000" and zero = '1'
            report "FAIL: ADD 15+1 overflow wrap" severity error;

        -- --------------------------------------------------------
        -- SUB tests
        -- --------------------------------------------------------
        op <= "001";
        a  <= "0101"; b <= "0011"; wait for PROP_DELAY;   -- 5-3=2
        assert result = "0010" and zero = '0'
            report "FAIL: SUB 5-3" severity error;

        a  <= "0011"; b <= "0011"; wait for PROP_DELAY;   -- 3-3=0
        assert result = "0000" and zero = '1'
            report "FAIL: SUB 3-3 (zero flag)" severity error;

        -- --------------------------------------------------------
        -- AND tests
        -- --------------------------------------------------------
        op <= "010";
        a  <= "1100"; b <= "1010"; wait for PROP_DELAY;   -- 1100 AND 1010 = 1000
        assert result = "1000" report "FAIL: AND" severity error;

        -- --------------------------------------------------------
        -- OR tests
        -- --------------------------------------------------------
        op <= "011";
        a  <= "1010"; b <= "0101"; wait for PROP_DELAY;   -- 1010 OR 0101 = 1111
        assert result = "1111" report "FAIL: OR" severity error;

        -- --------------------------------------------------------
        -- NOT tests
        -- --------------------------------------------------------
        op <= "100";
        a  <= "1010"; b <= "0000"; wait for PROP_DELAY;   -- NOT 1010 = 0101
        assert result = "0101" report "FAIL: NOT" severity error;

        a  <= "0000"; wait for PROP_DELAY;                 -- NOT 0000 = 1111
        assert result = "1111" and zero = '0'
            report "FAIL: NOT 0000" severity error;

        -- --------------------------------------------------------
        -- NEGATE tests
        -- --------------------------------------------------------
        op <= "101";
        a  <= "0011"; wait for PROP_DELAY;                 -- -3 = 1101
        assert result = "1101" report "FAIL: NEGATE 3" severity error;

        a  <= "0000"; wait for PROP_DELAY;                 -- -0 = 0 (zero flag)
        assert result = "0000" and zero = '1'
            report "FAIL: NEGATE 0 (zero flag)" severity error;

        -- --------------------------------------------------------
        -- Others: undefined op
        -- --------------------------------------------------------
        op <= "110"; a <= "1111"; b <= "1111"; wait for PROP_DELAY;
        assert result = "0000"
            report "FAIL: undefined op should output 0000" severity error;

        wait for PROP_DELAY;
        report "ALU testbench complete." severity note;
        wait;

    end process stimulus;

end sim;
```

---

## 2. Testing a synchronous RAM

### Strategy

RAM testing has two phases that are easy to get wrong:

**Phase 1 — Write:** drive `we='1'`, present `addr` and `data_in` (or
`data_bus`), and hold for at least one rising edge.

**Phase 2 — Read:** drive `we='0'`, present `addr`, wait **two** rising
edges (one to trigger the read, one for the data to appear), then check
`data_out`.

The most common mistake: checking `data_out` on the same edge as the read
request, getting `'U'` or stale data, and thinking the RAM is broken. The
read latency is by design. Always wait one extra cycle.

### RAM read/write timing helper pattern

```vhdl
-- Helper: write one byte to the RAM
procedure ram_write (
    signal we_s      : out std_logic;
    signal addr_s    : out std_logic_vector(2 downto 0);
    signal data_in_s : out std_logic_vector(7 downto 0);
    address          : in  std_logic_vector(2 downto 0);
    data             : in  std_logic_vector(7 downto 0);
    signal clk_s     : in  std_logic
) is begin
    wait until rising_edge(clk_s);
    we_s      <= '1';
    addr_s    <= address;
    data_in_s <= data;
    wait until rising_edge(clk_s);
    we_s <= '0';
end procedure;

-- Helper: read one byte and check it
procedure ram_read (
    signal we_s     : out std_logic;
    signal addr_s   : out std_logic_vector(2 downto 0);
    signal data_out : in  std_logic_vector(7 downto 0);
    signal valid_s  : in  std_logic;
    address         : in  std_logic_vector(2 downto 0);
    expected        : in  std_logic_vector(7 downto 0);
    signal clk_s    : in  std_logic
) is begin
    wait until rising_edge(clk_s);
    we_s   <= '0';
    addr_s <= address;
    wait until rising_edge(clk_s);    -- request issued
    wait until rising_edge(clk_s);    -- data appears
    assert valid_s = '1'
        report "FAIL: valid not asserted after read" severity error;
    assert data_out = expected
        report "FAIL: RAM read mismatch" severity error;
end procedure;
```

Procedures in VHDL are declared in the architecture's declarative region
(between `architecture sim of ... is` and `begin`). They are called like
functions in the stimulus process.

---

## 3. Worked RAM testbench (for `ram8x8` from Exercise 2)

```vhdl
-- tb_ram8x8.vhd
-- Starter testbench for the ram8x8 exercise.
-- Students should expand the test coverage.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity tb_ram8x8 is
end tb_ram8x8;

architecture sim of tb_ram8x8 is

    signal clk      : std_logic := '0';
    signal reset    : std_logic := '1';
    signal we       : std_logic := '0';
    signal addr     : std_logic_vector(2 downto 0) := (others => '0');
    signal data_in  : std_logic_vector(7 downto 0) := (others => '0');
    signal data_out : std_logic_vector(7 downto 0);
    signal valid    : std_logic;

    constant CLK_PERIOD : time := 10 ns;

begin

    clk <= not clk after CLK_PERIOD / 2;

    uut : entity work.ram8x8
        port map (
            clk      => clk,
            we       => we,
            addr     => addr,
            data_in  => data_in,
            data_out => data_out,
            valid    => valid
        );

    stimulus : process
    begin

        -- Phase 1: Reset
        reset <= '1';
        wait for 2 * CLK_PERIOD;
        reset <= '0';
        wait for CLK_PERIOD;

        -- Phase 2: Write four values
        -- Write 0xAA → address 0
        wait until rising_edge(clk);
        we <= '1'; addr <= "000"; data_in <= x"AA";

        -- Write 0xBB → address 1
        wait until rising_edge(clk);
        addr <= "001"; data_in <= x"BB";

        -- Write 0xCC → address 2
        wait until rising_edge(clk);
        addr <= "010"; data_in <= x"CC";

        -- Write 0xDD → address 3
        wait until rising_edge(clk);
        addr <= "011"; data_in <= x"DD";

        -- Phase 3: Read back all four values (check valid timing)
        wait until rising_edge(clk);
        we <= '0'; addr <= "000";  -- read address 0

        wait until rising_edge(clk);  -- data_out now holds 0xAA, valid='1'
        assert data_out = x"AA" and valid = '1'
            report "FAIL: read addr 0" severity error;

        addr <= "001";                -- read address 1
        wait until rising_edge(clk);
        assert data_out = x"BB" and valid = '1'
            report "FAIL: read addr 1" severity error;

        addr <= "010";
        wait until rising_edge(clk);
        assert data_out = x"CC" report "FAIL: read addr 2" severity error;

        addr <= "011";
        wait until rising_edge(clk);
        assert data_out = x"DD" report "FAIL: read addr 3" severity error;

        -- Phase 4: Overwrite address 0 and verify updated value
        wait until rising_edge(clk);
        we <= '1'; addr <= "000"; data_in <= x"FF";

        wait until rising_edge(clk);
        we <= '0'; addr <= "000";

        wait until rising_edge(clk);
        assert data_out = x"FF"
            report "FAIL: read after overwrite addr 0" severity error;

        -- Phase 5: Check valid is '0' after a write cycle
        wait until rising_edge(clk);
        we <= '1'; addr <= "000"; data_in <= x"11";
        wait until rising_edge(clk);
        assert valid = '0'
            report "FAIL: valid should be '0' after write" severity error;

        wait for 5 * CLK_PERIOD;
        report "RAM testbench complete." severity note;
        wait;
    end process stimulus;

end sim;
```

---

## 4. Testing the bidirectional bus (for Exercise 2 optional / Module 4 RAM)

When the RAM has an `inout` port, the testbench must manage bus ownership
explicitly. This is the trickiest part of the bidirectional testbench.

```vhdl
-- In the testbench, drive data_bus conditionally:
-- When writing: drive the bus with the data to be written.
-- When reading: tri-state the testbench side (let the RAM drive).

signal tb_drive : std_logic_vector(7 downto 0) := (others => 'Z');
signal we_tb    : std_logic := '0';

-- The bus connection: testbench drives tb_drive,
-- but we tri-state it during reads:
data_bus <= tb_drive when we_tb = '1' else (others => 'Z');

-- In stimulus:
-- Write:
we_tb    <= '1';
tb_drive <= x"AB";
addr     <= "0000";
wait until rising_edge(clk);

-- Read (release the bus):
we_tb    <= '0';
tb_drive <= (others => 'Z');  -- MUST tri-state, or bus contention
addr     <= "0000";
wait until rising_edge(clk);   -- read issued
wait until rising_edge(clk);   -- data appears on bus
-- Now read data_bus
```

**Key debugging tip:** if you see `'X'` on `data_bus` during a read, the
testbench is still driving it. Add `tb_drive <= (others => 'Z')` before the
read request.

---

## 5. What good waveforms look like

**ALU waveform:** all inputs change cleanly; `result`, `zero`, `carry`,
`negative` respond within the propagation delay. No `'X'` or `'U'` values.
The assert messages in the transcript panel should all say nothing (silence
= pass).

**RAM waveform signals to include:**
```
clk | reset | we | addr | data_in | data_out | valid
```
The `valid` signal should form clean one-cycle pulses aligned exactly one
cycle after each `we='0'` edge. If `valid` is always high or always low,
the `read_active` logic has a bug.

---

Next: **Module 7 — Debugging ALU & RAM + Reference**
