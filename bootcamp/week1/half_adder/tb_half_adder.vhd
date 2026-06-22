-- tb_half_adder.vhd
-- Week 1 PROVIDED reference testbench for Exercise 3 (half adder).
--
-- You build the entity 'half_adder' with ports a, b, sum, carry.
--   sum   = a XOR b
--   carry = a AND b
--
-- Note the half adder has TWO outputs: the testbench declares a
-- signal for each and connects both in the port map. Watch both
-- 'sum' and 'carry' in the waveform.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity tb_half_adder is
end tb_half_adder;

architecture sim of tb_half_adder is

    signal a, b       : std_logic;
    signal sum, carry : std_logic;

begin

    uut : entity work.half_adder
        port map (
            a     => a,
            b     => b,
            sum   => sum,
            carry => carry
        );

    stimulus : process
    begin
        a <= '0'; b <= '0';
        wait for 10 ns;          -- expect sum='0' carry='0'

        a <= '0'; b <= '1';
        wait for 10 ns;          -- expect sum='1' carry='0'

        a <= '1'; b <= '0';
        wait for 10 ns;          -- expect sum='1' carry='0'

        a <= '1'; b <= '1';
        wait for 10 ns;          -- expect sum='0' carry='1'

        wait;
    end process;

end sim;
