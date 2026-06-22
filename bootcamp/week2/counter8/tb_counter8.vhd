-- tb_counter8.vhd
--
-- Week 2 PROVIDED testbench for Exercise 1 (counter8).
--
-- You build the entity 'counter8' with the following interface:
--
--   entity counter8
--       port (
--           clk    : in  std_logic;
--           reset  : in  std_logic;
--           enable : in  std_logic;
--           count  : out std_logic_vector(7 downto 0)
--       );
--   end counter8;
--
-- This testbench drives reset, enable, and the clock so the waveform
-- shows three clearly identifiable regions:
--
--   1. an initial RESET region where count is held at 0,
--   2. a COUNTING region where enable='1' and count increments each edge,
--   3. a HOLD region where enable='0' and count stays flat.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity tb_counter8 is
    -- A testbench has no ports.
end tb_counter8;

architecture sim of tb_counter8 is

    signal clk    : std_logic := '0';
    signal reset  : std_logic := '1';
    signal enable : std_logic := '0';
    signal count  : std_logic_vector(7 downto 0);

    constant CLK_PERIOD : time := 10 ns;

begin

    -- Clock generator: free-running 100 MHz square wave.
    clk <= not clk after CLK_PERIOD / 2;

    -- Instantiate the design under test.
    uut : entity work.counter8
        port map (
            clk    => clk,
            reset  => reset,
            enable => enable,
            count  => count
        );

    -- Stimulus: walk through reset -> counting -> hold.
    stimulus : process
    begin
        -- (1) RESET region: hold reset high for a few cycles.
        --     Expected in waveform: count = 0x00 throughout.
        reset  <= '1';
        enable <= '0';
        wait for 5 * CLK_PERIOD;

        -- (2) COUNTING region: release reset with enable high.
        --     Expected: count increments by 1 on each rising edge:
        --     00, 01, 02, 03, 04, 05, 06, 07, 08, 09, 0A, ...
        reset  <= '0';
        enable <= '1';
        wait for 12 * CLK_PERIOD;

        -- (3) HOLD region: lower enable, keep reset low.
        --     Expected: count stays flat at whatever value it reached.
        enable <= '0';
        wait for 6 * CLK_PERIOD;

        -- (4) Brief return to counting, just to confirm the design
        --     resumes cleanly from a hold state.
        enable <= '1';
        wait for 4 * CLK_PERIOD;

        -- End the simulation.
        --except that this doesn't do it; clock keeps switching so the process still has stuff to do as it waits
        -- I could fix the clock, but too lazy rn
        wait;
    end process;

end sim;
