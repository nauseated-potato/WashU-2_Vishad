-- tb_washu2_week8.vhd
--
-- Week 8 -- PROVIDED testbench for washu2_cpu.
--
-- DEFAULT: tests the Module 6 Section 3 integration program (loaded by
-- default in washu2_ram.vhd) -- CLOAD, DSTORE, DLOAD, ADD, AND, BRANCH,
-- BRIND, ISTORE, ILOAD, NEGATE, BRZERO.
--
-- Expected results after HALT:
--   ACC        = 0xFFF6
--   mem[0x030] = 0x000A
--   done       = '1'
--
-- To test a Module 3/4/5 exercise program instead: change the RAM
-- initialiser in washu2_ram.vhd and update the timeout / expected
-- values below accordingly.
--
-- Since washu2_cpu has no debug output ports, add internal signals to
-- the ModelSim waveform via the Objects panel:
--   current_state, pc, mar, mbr, ir, acc, the_bus, zero_flag, pos_flag, neg_flag
-- Set radix to Hexadecimal for all data signals. To inspect memory
-- directly (needed for ISTORE checks), drill into
-- uut/ram_inst/ram_mem in the hierarchy browser.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity tb_washu2_week8 is
end tb_washu2_week8;

architecture sim of tb_washu2_week8 is

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
        -- Set timeout to (expected cycles + generous margin). Count
        -- states visited, not instructions -- e.g. ISTORE alone visits
        -- direct1, direct2, indirect1, indirect2, istore1 (5 states)
        -- plus the 3-cycle fetch = 8 cycles for that one instruction.
        --
        -- The default 14-instruction integration program (Module 6
        -- Section 3) needs roughly 70 cycles including three HALT
        -- fetches that are skipped over by branches. Timeout below
        -- gives a generous margin -- increase it if you extend the
        -- program.
        -- --------------------------------------------------------
        wait until done = '1' for 120 * CLK_PERIOD;

        assert done = '1'
            report "FAIL: done never asserted -- CPU did not reach HALT. " &
                   "Check the branch/BRIND/indirect dispatch chains " &
                   "(Module 7 Bugs 1-4) before assuming a fetch-cycle bug."
            severity error;

        -- Let the final state settle
        wait for CLK_PERIOD;

        -- --------------------------------------------------------
        -- Self-test verification (waveform-based).
        --
        -- Internal signals (acc, pc, etc.) are not accessible as ports.
        -- Verify the following in ModelSim's waveform window:
        --
        --   acc        should be 0xFFF6  after halt1
        --   mem[0x030] should be 0x000A  (written by ISTORE, check via
        --                                  uut/ram_inst/ram_mem)
        --   the_bus    should never show 'X' (would indicate bus contention)
        --
        -- If acc is wrong, narrow down which instruction produced the
        -- wrong value by checking acc after each of these states in
        -- order: cload1 (x000A) -> add1 (x000F) -> and1 (x000A) ->
        -- iload1 (x000A) -> neg2 (xFFF6, final).
        -- --------------------------------------------------------

        -- --------------------------------------------------------
        -- Phase 3: Verify CPU stays in HALT
        -- --------------------------------------------------------
        wait for 5 * CLK_PERIOD;

        assert done = '1'
            report "FAIL: CPU left HALT state unexpectedly"
            severity error;

        -- --------------------------------------------------------
        -- Phase 4: Reset recovery -- CPU must return to resetState
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
        wait until done = '1' for 130 * CLK_PERIOD;

        assert done = '1'
            report "FAIL: CPU did not complete program after reset recovery"
            severity error;

        wait for 3 * CLK_PERIOD;
        report "tb_washu2_week8: stimulus complete." severity note;
        wait;

    end process stimulus;

end sim;
