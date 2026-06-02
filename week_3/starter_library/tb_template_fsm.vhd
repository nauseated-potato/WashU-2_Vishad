-- tb_template_fsm.vhd
--
-- Week 3 STARTER TEMPLATE for testbenches of FSM designs.
--
-- Copy this file, rename it (e.g. tb_seq_det_101.vhd), and fill in the
-- TODO sections. The clock generator and reset phase are already written.
--
-- Key pattern for FSM testbenches:
--   Use  wait until rising_edge(clk);  before each input change.
--   This ensures every bit/signal is presented for a full clock period
--   and sampled correctly by the DUT on the NEXT rising edge.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity tb_template_fsm is
    -- Testbenches have NO ports.
end tb_template_fsm;

architecture sim of tb_template_fsm is

    -- ----------------------------------------------------------------
    -- 1. Signal declarations
    -- Declare one signal per port of your FSM.
    -- Clock starts at '0' so the first 'not clk' produces a rising edge.
    -- ----------------------------------------------------------------
    signal clk   : std_logic := '0';
    signal reset : std_logic := '1';

    -- TODO: add your FSM's input and output signals here. Examples:
    -- signal data     : std_logic := '0';
    -- signal btn_a    : std_logic := '0';
    -- signal detected : std_logic;

    constant CLK_PERIOD : time := 10 ns;

begin

    -- ----------------------------------------------------------------
    -- 2. Clock generator
    -- Produces a free-running clock. Do not modify.
    -- ----------------------------------------------------------------
    clk <= not clk after CLK_PERIOD / 2;

    -- ----------------------------------------------------------------
    -- 3. DUT instantiation
    -- Replace the entity name and port map with your actual FSM.
    -- ----------------------------------------------------------------
    -- uut : entity work.YOUR_FSM_NAME
    --     port map (
    --         clk   => clk,
    --         reset => reset
    --         -- TODO: connect all other ports here
    --     );

    -- ----------------------------------------------------------------
    -- 4. Stimulus process
    -- ----------------------------------------------------------------
    stimulus : process
    begin

        -- Phase 1: Reset (hold for at least 2 cycles)
        reset <= '1';
        wait for 2 * CLK_PERIOD;
        reset <= '0';

        -- Phase 2: Apply input sequence, one value per clock cycle.
        --
        -- Pattern to use for serial bit-by-bit input (e.g. sequence detectors):
        --
        --   wait until rising_edge(clk); data <= '1';
        --   wait until rising_edge(clk); data <= '0';
        --   wait until rising_edge(clk); data <= '1';
        --   ...
        --
        -- Pattern for single-cycle pulse inputs (e.g. button presses):
        --
        --   wait until rising_edge(clk); btn_a <= '1';
        --   wait until rising_edge(clk); btn_a <= '0';  -- de-assert next cycle
        --   wait for CLK_PERIOD;                         -- idle gap
        --
        -- TODO: replace this with your actual stimulus

        wait for 5 * CLK_PERIOD; -- placeholder — delete and write your stimulus

        -- Phase 3: Let the final state settle, then end simulation.
        -- Always keep at least 5 cycles at the end so the last transition
        -- is clearly visible in the waveform before the simulation stops.
        wait for 5 * CLK_PERIOD;
        wait; -- stops the stimulus process; simulation ends here

    end process stimulus;

end sim;
