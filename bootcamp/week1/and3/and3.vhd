library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

library work;
use work.gates.all;

entity and3 is
   port (a,b,c: in std_logic;
   y: out std_logic);
end and3;

architecture abc of and3 is
   signal b1: std_logic;
begin
   and1: entity work.and_gate
      port map (a=>b, b=>c, y=>b1);
   and2: entity work.and_gate
      port map (a=>a, b=>b1, y=>y);
end abc;
