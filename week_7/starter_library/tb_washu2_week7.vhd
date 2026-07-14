-- tb_washu2_week7.vhd
--
-- Week 7 — PROVIDED testbench for washu2_cpu.
--
-- DEFAULT: tests the self-test program (CLOAD 5, NEGATE, DSTORE, CLOAD 0,
-- DLOAD, HALT). See Module 9 §4 for the full program listing.
--
-- Expected results after HALT:
--   ACC        = 0xFFFB  (-5 in two's complement)
--   mem[0x010] = 0xFFFB
--   PC         = 0x0006
--   done       = '1'
--
-- To test Exercise programs: change the RAM initialiser in washu2_ram.vhd
-- and update the timeout / expected values below accordingly.
--
-- Since washu2_cpu has no debug output ports, add internal signals
-- to the ModelSim waveform via the Objects panel:
--   current_state, pc, mar, mbr, ir, acc, the_bus
-- Set radix to Hexadecimal for all data signals.
-- See Module 7 §5 for step-by-step instructions.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity tb_washu2_week7 is
end tb_washu2_week7;

architecture sim of tb_washu2_week7 is

    signal clk   : std_logic := '0';
    signal reset : std_logic := '1';
    signal done  : std_logic;

    constant CLK_PERIOD : time := 10 ns;

begin

    -- Clock generator
    clk <= not clk after CLK_PERIOD / 2;

    -- DUT
    uut : entity work.washu2_cpu
        port map (
            clk   => clk,
            reset => reset,
            done  => done
        );

    stimulus : process
    begin

        -- --------------------------------------------------------
        -- Phase 1: Apply reset for 3 cycles
        -- --------------------------------------------------------
        reset <= '1';
        wait for 3 * CLK_PERIOD;
        reset <= '0';

        -- --------------------------------------------------------
        -- Phase 2: Wait for program to complete
        --
        -- Set timeout to (expected cycles + generous margin).
        -- See Module 7 §7 for cycle count per instruction:
        --
        --   Program A (HALT only):          6 cycles
        --   Program B (NEGATE + HALT):     11 cycles
        --   Program C (CLOAD + HALT):      10 cycles
        --   Program D (CLOAD+DSTORE+CLOAD+DLOAD+HALT): 24 cycles + 1 resetState = 25 total
        --
        -- Self-test program: 30 cycles. Timeout = 40 (10-cycle margin).
        -- For Exercise programs with loops, increase this timeout.
        -- --------------------------------------------------------
        wait until done = '1' for 40 * CLK_PERIOD;

        assert done = '1'
            report "FAIL: done never asserted — CPU did not reach HALT. " &
                   "Check fetch cycle, opcode decode, and halt1 state."
            severity error;

        -- Let the final state settle
        wait for CLK_PERIOD;

        -- --------------------------------------------------------
        -- Self-test verification (waveform-based).
        --
        -- Internal signals (acc, pc, etc.) are not accessible as ports.
        -- Verify the following in ModelSim's waveform window:
        --
        --   acc        should be 0xFFFB  after halt1
        --   pc         should be 0x0006  (frozen after HALT)
        --   mem[0x010] should be 0xFFFB  (written by DSTORE, check via
        --                                  the RAM instance in Objects panel)
        --   the_bus    should never show 'X' (would indicate bus contention)
        --
        -- If acc ≠ 0xFFFB, check which instruction produced the wrong value:
        --   acc ≠ 0x0005 after cload1  → CLOAD broken
        --   acc ≠ 0xFFFB after neg2    → NEGATE broken
        --   acc ≠ 0x0000 after cload1  → second CLOAD broken
        --   acc ≠ 0xFFFB after load1   → DLOAD broken (or DSTORE wrote wrong value)
        -- --------------------------------------------------------

        -- --------------------------------------------------------
        -- Phase 3: Verify CPU stays in HALT
        -- --------------------------------------------------------
        wait for 5 * CLK_PERIOD;

        assert done = '1'
            report "FAIL: CPU left HALT state unexpectedly"
            severity error;

        -- --------------------------------------------------------
        -- Phase 4: Reset recovery — CPU must return to resetState
        --          and begin fetching again
        -- --------------------------------------------------------
        reset <= '1';
        wait for 2 * CLK_PERIOD;
        reset <= '0';
        wait for CLK_PERIOD;

        assert done = '0'
            report "FAIL: done should be 0 after reset"
            severity error;

        -- After reset, CPU re-executes the program.
        -- Wait for it to halt again to confirm recovery.
        wait until done = '1' for 60 * CLK_PERIOD;

        assert done = '1'
            report "FAIL: CPU did not complete program after reset recovery"
            severity error;

        wait for 3 * CLK_PERIOD;
        report "tb_washu2_week7: stimulus complete." severity note;
        wait;

    end process stimulus;

end sim;
