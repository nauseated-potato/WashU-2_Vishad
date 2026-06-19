-- tb_template_datapath.vhd
--
-- Week 5 STARTER TEMPLATE for mini_cpu testbenches.
--
-- Copy this file, rename it (e.g. tb_mini_cpu_ex1.vhd), then:
--   1. Rename the entity to match your file (e.g. tb_mini_cpu_ex1).
--   2. Fill in the port map with the debug signals from your mini_cpu.
--   3. Replace the TODO assert blocks with your expected values.
--
-- Pre-written for you:
--   - Clock generator
--   - Reset phase (3 cycles)
--   - wait until done with 30-cycle timeout
--   - Reset recovery check

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- TODO: rename this entity to match your file name
entity tb_template_datapath is
end tb_template_datapath;

architecture sim of tb_template_datapath is

    signal clk       : std_logic := '0';
    signal reset     : std_logic := '1';
    signal done      : std_logic;

    -- Debug signals: uncomment and add more as needed.
    -- These must match the debug ports you added to mini_cpu.vhd.
    signal dbg_acc   : std_logic_vector(7 downto 0);
    signal dbg_pc    : std_logic_vector(4 downto 0);
    signal dbg_ir    : std_logic_vector(7 downto 0);
    signal dbg_state : std_logic_vector(2 downto 0);
    --   "000"=S_FETCH1, "001"=S_FETCH2, "010"=S_EXECUTE, "011"=S_WRITEBACK, "100"=S_HALT

    constant CLK_PERIOD : time := 10 ns;

begin

    -- Clock generator
    clk <= not clk after CLK_PERIOD / 2;

    -- DUT instantiation
    -- TODO: replace 'mini_cpu' with your actual entity name if different,
    --       and update the port map to match your debug port names.
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
        -- Phase 1: Apply reset for 3 cycles
        -- -------------------------------------------------------
        reset <= '1';
        wait for 3 * CLK_PERIOD;
        reset <= '0';

        -- -------------------------------------------------------
        -- Phase 2: Wait for program to complete (30-cycle timeout)
        -- -------------------------------------------------------
        wait until done = '1' for 30 * CLK_PERIOD;

        assert done = '1'
            report "FAIL: done never asserted — CPU did not reach HALT " &
                   "(check FSM, HALT opcode, and RAM initialiser)"
            severity error;

        -- Allow one more cycle to settle after done goes high
        wait for CLK_PERIOD;

        -- -------------------------------------------------------
        -- Phase 3: Check final state
        -- TODO: replace x"??" with your expected final acc value.
        -- TODO: replace "?????" with your expected final PC value (binary).
        -- -------------------------------------------------------
        assert dbg_acc = x"??"
            report "FAIL: acc has wrong final value"
            severity error;

        assert dbg_pc = "?????"
            report "FAIL: PC not frozen at expected HALT address"
            severity error;

        assert dbg_state = "100"
            report "FAIL: CPU not in HALT state (expected state=100)"
            severity error;

        -- -------------------------------------------------------
        -- Phase 4: Verify CPU stays in HALT (does not escape)
        -- -------------------------------------------------------
        wait for 5 * CLK_PERIOD;

        assert done = '1'
            report "FAIL: CPU escaped HALT state"
            severity error;

        assert dbg_acc = x"??"
            report "FAIL: acc changed while in HALT"
            severity error;

        -- -------------------------------------------------------
        -- Phase 5: Reset recovery — CPU must return to FETCH at PC=0
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

        assert dbg_state = "000"
            report "FAIL: CPU should be in S_FETCH1 state after reset"
            severity error;

        wait for 3 * CLK_PERIOD;
        report "Testbench complete." severity note;
        wait;
    end process stimulus;

end sim;
