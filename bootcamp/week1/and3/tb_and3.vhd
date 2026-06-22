library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity tb_and3 is
end tb_and3;

architecture sim of tb_and3 is
   signal a,b,c,y: std_logic;
begin
   dut: entity work.and3
      port map (a=>a, b=>b, c=>c, y=>y);
   stimulus: process
   begin
      a <= '0'; b <= '0'; c <= '0';
      wait for 10 ns;

      a <= '0'; b <= '0'; c <= '1';
      wait for 10 ns;

      a <= '0'; b <= '1'; c <= '0';
      wait for 10 ns;

      a <= '0'; b <= '1'; c <= '1';
      wait for 10 ns;

      a <= '1'; b <= '0'; c <= '0';
      wait for 10 ns;

      a <= '1'; b <= '0'; c <= '1';
      wait for 10 ns;

      a <= '1'; b <= '1'; c <= '0';
      wait for 10 ns;

      a <= '1'; b <= '1'; c <= '1';
      wait for 10 ns;
      
      wait;
   end process;
end sim;
