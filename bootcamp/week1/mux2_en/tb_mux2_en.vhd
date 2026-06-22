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

entity tb_mux2_en is
end tb_mux2_en;

architecture sim of tb_mux2_en is

    signal a, b, sel, y, en : std_logic;

begin

    uut : entity work.mux2_en
        port map (
            a   => a,
            b   => b,
            sel => sel,
            y   => y,
            en  => en
        );

    stimulus : process
    begin
        a <= '0'; b <= '0'; sel <= '0'; en <= '0';
        wait for 10 ns;
  
        a <= '0'; b <= '0'; sel <= '1'; en <= '0';
        wait for 10 ns;
  
        a <= '0'; b <= '1'; sel <= '0'; en <= '0';
        wait for 10 ns;
  
        a <= '0'; b <= '1'; sel <= '1'; en <= '0';
        wait for 10 ns;
  
        a <= '1'; b <= '0'; sel <= '0'; en <= '0';
        wait for 10 ns;
  
        a <= '1'; b <= '0'; sel <= '1'; en <= '0';
        wait for 10 ns;
  
        a <= '1'; b <= '1'; sel <= '0'; en <= '0';
        wait for 10 ns;
  
        a <= '1'; b <= '1'; sel <= '1'; en <= '0';
        wait for 10 ns;

        a <= '0'; b <= '0'; sel <= '0'; en <= '1';
        wait for 10 ns;
  
        a <= '0'; b <= '0'; sel <= '1'; en <= '1';
        wait for 10 ns;
  
        a <= '0'; b <= '1'; sel <= '0'; en <= '1';
        wait for 10 ns;
  
        a <= '0'; b <= '1'; sel <= '1'; en <= '1';
        wait for 10 ns;
  
        a <= '1'; b <= '0'; sel <= '0'; en <= '1';
        wait for 10 ns;
  
        a <= '1'; b <= '0'; sel <= '1'; en <= '1';
        wait for 10 ns;
  
        a <= '1'; b <= '1'; sel <= '0'; en <= '1';
        wait for 10 ns;
  
        a <= '1'; b <= '1'; sel <= '1'; en <= '1';
        wait for 10 ns;

        wait;
    end process;

end sim;
