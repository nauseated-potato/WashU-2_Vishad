# Week 5 · Module 5 — Testbenches for the Mini-Datapath

Testing a complete datapath is fundamentally different from testing a single
component. An ALU testbench applies inputs and reads outputs in the same
cycle. A RAM testbench checks read latency. A datapath testbench does
neither — instead it:

1. Resets the CPU.
2. Runs the clock for enough cycles for the program to complete.
3. Checks that `done` asserts at the right cycle.
4. Inspects internal signals — `acc`, `pc`, `ir`, `state` — to verify the
   CPU took the right path.

This module explains how to write such a testbench, introduces the technique
of exposing internal signals through debug ports, and provides a complete
worked testbench for Program 1 (the addition example).

---

## 1. The challenge: no external data outputs

The `mini_cpu` entity has only three ports: `clk`, `reset`, and `done`.
You cannot read `acc`, `pc`, or `state` from the testbench through these
ports alone. You have two options:

### Option A: Debug output ports (recommended for this week)

Add temporary output ports to `mini_cpu` for the signals you want to
observe:

    entity mini_cpu is
        port (
            clk      : in  std_logic;
            reset    : in  std_logic;
            done     : out std_logic;
            -- Debug ports: add these for simulation, remove before final synthesis
            dbg_acc  : out std_logic_vector(7 downto 0);
            dbg_pc   : out std_logic_vector(4 downto 0);
            dbg_ir   : out std_logic_vector(7 downto 0);
            dbg_state: out std_logic_vector(2 downto 0)  -- 000=FETCH1,001=FETCH2,010=EXECUTE,011=WRITEBACK,100=HALT
        );
    end mini_cpu;

Then in the architecture, connect them:

    dbg_acc   <= acc;
    dbg_pc    <= std_logic_vector(pc);
    dbg_ir    <= ir;
    dbg_state <= "000" when state = S_FETCH1
            else "001" when state = S_FETCH2
            else "010" when state = S_EXECUTE
            else "011" when state = S_WRITEBACK
            else "100"; -- S_HALT

The testbench can then assert on these signals directly. This is clean,
portable, and self-documenting.

### Option B: ModelSim object panel

In ModelSim, expand the DUT hierarchy in the Objects panel and drag
internal signals (`acc`, `pc`, `ir`, `state`) into the wave window. No
code changes needed — but you cannot write automated `assert` checks against
signals not visible in the testbench.

**Use Option A** for the exercises this week. The debug ports make
automated checking possible and make the waveform self-documenting.

---

## 2. How many cycles to run?

Each non-HALT instruction takes exactly **4 clock cycles**
(`S_FETCH1 → S_FETCH2 → S_EXECUTE → S_WRITEBACK`, see Module 2 §5-8 and
Module 4 §3). HALT takes **3 cycles** to reach `S_HALT`
(`S_FETCH1 → S_FETCH2 → S_EXECUTE → S_HALT`). Add a few extra cycles as
margin:

    cycles_needed = (N_non_halt_instructions × 4) + 3 + margin

For Program 1 (3 non-HALT instructions + HALT, from Module 4 §3):

    cycles = (3 × 4) + 3 + 3 = 18 cycles  (done='1' first appears at cycle 16;
                                            18 gives 2 cycles of margin)

In the testbench, use `wait for N * CLK_PERIOD` or count with a loop. Or,
more robustly, use `wait until done = '1' for N * CLK_PERIOD` (introduced
in §3 below) so you do not need to count cycles by hand at all. Always run
a few extra cycles beyond the expected `done` point — this confirms the CPU
stays in HALT and does not run off into undefined behaviour.

---

## 3. Using `assert` to check CPU state

For a datapath testbench, `assert` is more powerful than for an ALU because
you can check *when* something happens, not just *what* it is.

    -- Wait for done to go high
    wait until done = '1';

    -- Allow one more cycle for the state to settle
    wait for CLK_PERIOD;

    -- Check final accumulator value
    assert dbg_acc = x"0C"
        report "FAIL: final acc expected 0x0C, wrong result"
        severity error;

    -- Check PC. Note: pc was incremented to 4 during S_FETCH2 of the HALT
    -- instruction (the same as every instruction's S_FETCH2) — it does NOT
    -- stay at the HALT instruction's own address (3). "Frozen" means pc no
    -- longer changes once S_HALT is reached, not that it equals the HALT
    -- instruction's address.
    assert dbg_pc = "00100"
        report "FAIL: PC should be frozen at 4 (= HALT address + 1) during HALT"
        severity error;

The `wait until done = '1'` statement is a powerful ModelSim/VHDL feature:
it suspends the testbench process until the condition becomes true. This
means you do not need to count cycles manually — you just wait for the
natural end-of-program signal.

### The timeout form: `wait until ... for ...`

There is one danger with `wait until done = '1'`: if your design has a bug
and `done` never goes high, the testbench process waits **forever** and the
simulation hangs (it will not finish on its own — you have to stop it
manually in ModelSim).

To guard against this, VHDL allows an optional timeout on `wait until`:

    wait until done = '1' for 20 * CLK_PERIOD;

This means: *"wait until `done='1'`, but give up after 20 clock periods
even if it never happens."* After this statement, execution continues
regardless of whether `done` actually went high — so you must follow it
with an `assert` to check which case occurred:

    wait until done = '1' for 20 * CLK_PERIOD;

    -- If 'done' never went high, this assertion fails and reports the message.
    -- If 'done' DID go high before the timeout, this assertion passes silently.
    assert done = '1'
        report "FAIL: done never asserted within 20 cycles"
        severity error;

This pattern — `wait until ... for ...` immediately followed by an
`assert` on the same condition — is used throughout the rest of this
module and in Module 7. Always include the timeout when waiting for a
condition that depends on your design being correct; otherwise a single
bug can hang the entire simulation.

---

## 4. Worked testbench — Program 1 (`mini_cpu` with Program 1 loaded)

    -- tb_mini_cpu.vhd
    -- Testbench for mini_cpu executing Program 1: result = 7 + 5.
    -- Expected: after HALT, dbg_acc = 0x0C, done = '1'.

    library IEEE;
    use IEEE.STD_LOGIC_1164.ALL;
    use IEEE.NUMERIC_STD.ALL;

    entity tb_mini_cpu is
    end tb_mini_cpu;

    architecture sim of tb_mini_cpu is

        signal clk       : std_logic := '0';
        signal reset     : std_logic := '1';
        signal done      : std_logic;
        signal dbg_acc   : std_logic_vector(7 downto 0);
        signal dbg_pc    : std_logic_vector(4 downto 0);
        signal dbg_ir    : std_logic_vector(7 downto 0);
        signal dbg_state : std_logic_vector(2 downto 0);

        constant CLK_PERIOD : time := 10 ns;

    begin

        clk <= not clk after CLK_PERIOD / 2;

        uut : entity work.mini_cpu
            port map (
                clk       => clk,
                reset     => reset,
                done      => done,
                dbg_acc   => dbg_acc,
                dbg_pc    => dbg_pc,
                dbg_ir    => dbg_ir,
                dbg_state => dbg_state
            );

        stimulus : process
        begin

            -- -------------------------------------------------------
            -- Phase 1: Hold reset for 3 cycles
            -- -------------------------------------------------------
            reset <= '1';
            wait for 3 * CLK_PERIOD;
            reset <= '0';

            -- -------------------------------------------------------
            -- Phase 2: Wait for program to complete
            -- Timeout after 20 cycles (should complete by cycle 16 — see
            -- Module 4 §3 trace; 20 gives a 4-cycle margin)
            -- -------------------------------------------------------
            wait until done = '1' for 20 * CLK_PERIOD;

            -- If done never went high, the following checks will fail
            assert done = '1'
                report "FAIL: done never asserted — CPU did not reach HALT"
                severity error;

            -- Allow one more cycle to settle
            wait for CLK_PERIOD;

            -- -------------------------------------------------------
            -- Phase 3: Check final state
            -- -------------------------------------------------------
            assert dbg_acc = x"0C"
                report "FAIL: acc should be 0x0C (12) after 7+5"
                severity error;

            -- pc was incremented to 4 during S_FETCH2 of the HALT instruction
            -- (see Module 4 §3, cycle 14) — it stays at 4 once S_HALT is reached.
            assert dbg_pc = "00100"
                report "FAIL: PC should be frozen at 4 (= HALT address + 1) during HALT"
                severity error;

            assert dbg_state = "100"
                report "FAIL: CPU should be in HALT state (100=S_HALT)"
                severity error;

            -- -------------------------------------------------------
            -- Phase 4: Verify CPU stays in HALT (does not escape)
            -- -------------------------------------------------------
            wait for 5 * CLK_PERIOD;

            assert done = '1'
                report "FAIL: CPU left HALT state unexpectedly"
                severity error;

            assert dbg_acc = x"0C"
                report "FAIL: acc changed after HALT"
                severity error;

            -- -------------------------------------------------------
            -- Phase 5: Test reset recovery
            -- Asserting reset should return CPU to FETCH at PC=0
            -- -------------------------------------------------------
            reset <= '1';
            wait for 2 * CLK_PERIOD;
            reset <= '0';

            wait for CLK_PERIOD;

            assert dbg_pc = "00000"
                report "FAIL: PC should be 0 after reset"
                severity error;

            assert done = '0'
                report "FAIL: done should be '0' after reset"
                severity error;

            wait for 5 * CLK_PERIOD;
            report "tb_mini_cpu: all checks passed." severity note;
            wait;
        end process stimulus;

    end sim;

---

## 5. Cycle-by-cycle tracing in simulation

When debugging, do not rely only on the final `assert` checks. Set up
the waveform window with these signals in this order:

    clk          — clock
    reset        — reset
    dbg_state    — FSM state (000=FETCH1/001=FETCH2/010=EXECUTE/011=WRITEBACK/100=HALT)
    dbg_pc       — program counter
    dbg_ir       — instruction register (shown as hex)
    dbg_acc      — accumulator (shown as unsigned decimal or hex)
    done         — completion flag

Then open the Module 4 execution trace table and walk through the waveform
cycle by cycle, checking:
- Does the state advance FETCH→EXECUTE→FETCH correctly?
- Does the PC increment on the right cycles?
- Does IR contain the right instruction during EXECUTE?
- Does acc update on the right cycles with the right values?

Any deviation from the trace table points directly to a bug in the control
signal for that state/instruction combination.

---

## 6. Common testbench mistakes for datapaths

**Mistake 1: Not enough reset time**

Asserting reset for only one cycle may not be sufficient if the RAM has
its own initialisation delay in simulation. Use at least 2–3 cycles of
reset.

**Mistake 2: Checking done too early**

`done` goes high in S_HALT. If you check it the same cycle the HALT
instruction enters `S_EXECUTE`, it will not be high yet — the FSM
transitions to `S_HALT` on the next edge (after `S_EXECUTE` decodes HALT).

**Mistake 3: Forgetting to add debug ports to the entity**

If you add debug ports to `mini_cpu.vhd` but forget to update the port map
in `tb_mini_cpu.vhd` (or vice versa), you will get a compile error about
missing ports. Update both files together.

**Mistake 4: Not recompiling after changing the RAM program**

The program is in `ram32x8.vhd`. If you change it and only re-simulate
without recompiling, ModelSim uses the old compiled design. Always full-
compile in Quartus after any source change.

---

Next: **Module 6 — Exercises**