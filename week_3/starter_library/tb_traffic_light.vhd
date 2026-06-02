-- tb_traffic_light.vhd
--
-- Week 3 — PROVIDED reference testbench for the traffic_light design
-- from Module 2. The traffic light is a worked example (not an exercise);
-- this complete, correct testbench is provided so you can study a full FSM
-- testbench before writing your own.
--
-- Tests:
--   (a) reset enters S_RED with red='1', yellow='0', green='0';
--   (b) two full 14-cycle rotations are visible;
--   (c) a mid-rotation reset returns the FSM to S_RED.
--
-- To see the state, drag the DUT's internal 'current_state' signal into
-- the Wave window (see Module 5, section 1).

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity tb_traffic_light is
end tb_traffic_light;

architecture sim of tb_traffic_light is

    signal clk    : std_logic := '0';
    signal reset  : std_logic := '1';
    signal red    : std_logic;
    signal yellow : std_logic;
    signal green  : std_logic;

    constant CLK_PERIOD : time := 10 ns;

begin

    -- Clock generator
    clk <= not clk after CLK_PERIOD / 2;

    -- Device under test
    uut : entity work.traffic_light
        port map (
            clk    => clk,
            reset  => reset,
            red    => red,
            yellow => yellow,
            green  => green
        );

    stimulus : process
    begin
        -- Phase 1: hold reset; expect red='1', yellow='0', green='0'.
        reset <= '1';
        wait for 3 * CLK_PERIOD;

        -- Phase 2: release reset; run two full rotations (28 cycles).
        reset <= '0';
        wait for 28 * CLK_PERIOD;

        -- Phase 3: assert reset mid-rotation; FSM snaps back to S_RED.
        reset <= '1';
        wait for 2 * CLK_PERIOD;
        reset <= '0';

        -- Phase 4: one more rotation to confirm recovery.
        wait for 14 * CLK_PERIOD;

        wait for 5 * CLK_PERIOD;
        wait;  -- end simulation
    end process stimulus;

end sim;
