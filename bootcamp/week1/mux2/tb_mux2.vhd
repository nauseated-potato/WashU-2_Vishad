-- tb_mux2.vhd
-- Week 1 PROVIDED testbench for Exercise 2 (2:1 multiplexer).
--
-- You build the entity 'mux2' with ports a, b, sel, y.
-- Behaviour: sel='0' -> y follows a ; sel='1' -> y follows b.
--
-- Distinct values are placed on a and b so you can clearly SEE
-- which input is being routed to y in the waveform.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity tb_mux2 is
end tb_mux2;

architecture sim of tb_mux2 is

    signal a, b, sel, y : std_logic;

begin

    uut : entity work.mux2
        port map (
            a   => a,
            b   => b,
            sel => sel,
            y   => y
        );

    stimulus : process
    begin
        -- Fixed, different values so routing is obvious: a=0, b=1.
        a <= '0';
        b <= '1';

        sel <= '0';
        wait for 10 ns;          -- expect y = a = '0'

        sel <= '1';
        wait for 10 ns;          -- expect y = b = '1'

        -- Swap the data values and test again: a=1, b=0.
        a <= '1';
        b <= '0';

        sel <= '0';
        wait for 10 ns;          -- expect y = a = '1'

        sel <= '1';
        wait for 10 ns;          -- expect y = b = '0'

        wait;
    end process;

end sim;
