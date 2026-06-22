library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

library work;
use work.gates.all;

entity xor_structural is
   port (a, b: in std_logic;
   y: out std_logic);
end xor_structural;

architecture struct of xor_structural is
   signal or_out, and_out, not_out: std_logic;
begin
   g1: entity work.and_gate
      port map (a=>a, b=>b, y=>and_out);

   g2: entity work.or_gate
      port map (a=>a, b=>b, y=>or_out);

   g3: entity work.inverter
      port map (a=>and_out, y=>not_out);

   g4: entity work.and_gate
      port map (a=>or_out, b=>not_out, y=>y);
end struct;
