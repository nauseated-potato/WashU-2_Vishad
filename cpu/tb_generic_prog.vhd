-- tb_generic_prog.vhd
--
-- allows programs oif larger length to run

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity tb_generic_prog is
end tb_generic_prog;

architecture sim of tb_generic_prog is

    signal clk   : std_logic := '0';
    signal reset : std_logic := '1';
    signal done  : std_logic;

    signal sim_done: boolean:= false;


    constant CLK_PERIOD : time := 10 ns;

begin

    -- Clock generator    --We do not want an infinite clock!
        clk_process: process
        begin
                if sim_done then
                        wait;
                end if;
                clk <= not clk;
                wait for CLK_PERIOD / 2;
        end process;

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
        wait until done = '1' for 1024 * CLK_PERIOD;

        assert done = '1'
            report "FAIL: done never asserted - CPU did not reach HALT. " &
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
        -- Phase 4: Reset recovery - CPU must return to resetState
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
        wait until done = '1' for 1024 * CLK_PERIOD;

        assert done = '1'
            report "FAIL: CPU did not complete program after reset recovery"
            severity error;

        wait for 3 * CLK_PERIOD;
        report "tb_generic_prog: stimulus complete." severity note;
        sim_done <= true;
        wait;

    end process stimulus;

end sim;
