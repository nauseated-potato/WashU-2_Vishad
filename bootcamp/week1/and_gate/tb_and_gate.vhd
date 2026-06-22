-- tb_and_gate.vhd
-- Week 1 starter testbench: drives all four input combinations
-- through and_gate and lets you watch y in the waveform.
--
-- Expected: y = '1' only for the last case (a='1', b='1').

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity tb_and_gate is
    -- A testbench has NO ports: it is the whole sealed experiment.
end tb_and_gate;

architecture sim of tb_and_gate is

    -- Internal wires that connect to the design's ports.
    signal a, b, y : std_logic;

begin

    -- Instantiate the Unit Under Test (the design we are testing).
    uut : entity work.and_gate
        port map (
            a => a,
            b => b,
            y => y
        );

    -- Stimulus: walk through every input combination, 10 ns apart.
    stimulus : process
    begin
        a <= '0'; b <= '0';
        wait for 10 ns;          -- expect y = '0'

        a <= '0'; b <= '1';
        wait for 10 ns;          -- expect y = '0'

        a <= '1'; b <= '0';
        wait for 10 ns;          -- expect y = '0'

        a <= '1'; b <= '1';
        wait for 10 ns;          -- expect y = '1'

        wait;                    -- stop here forever
    end process;

end sim;
