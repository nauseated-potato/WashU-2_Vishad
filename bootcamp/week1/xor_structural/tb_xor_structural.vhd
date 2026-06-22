-- tb_xor_structural.vhd
-- Week 1 PROVIDED testbench for Exercise 1 (build XOR from AND/OR/NOT).
--
-- You build the entity 'xor_structural' with ports a, b, y.
-- This testbench checks it against the XOR truth table:
--   y = '1' only when a and b differ.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity tb_xor_structural is
end tb_xor_structural;

architecture sim of tb_xor_structural is

    signal a, b, y : std_logic;

begin

    uut : entity work.xor_structural
        port map (
            a => a,
            b => b,
            y => y
        );

    stimulus : process
    begin
        a <= '0'; b <= '0';
        wait for 10 ns;          -- expect y = '0'

        a <= '0'; b <= '1';
        wait for 10 ns;          -- expect y = '1'

        a <= '1'; b <= '0';
        wait for 10 ns;          -- expect y = '1'

        a <= '1'; b <= '1';
        wait for 10 ns;          -- expect y = '0'

        wait;
    end process;

end sim;
