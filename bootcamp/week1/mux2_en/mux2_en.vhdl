library ieee;
use ieee.std_logic_1164.all;

library work;
use work.gates.all;

entity mux2_en is
   port (a, b, sel, en: in std_logic;
   y: out std_logic);
end mux2_en;

architecture switch of mux2_en is
   signal not_sel, a_and, b_and, checken: std_logic;
   begin
      unsel: entity work.inverter
         port map (a=>sel, y=>not_sel);

      asel: entity work.and_gate
         port map (a=>a, b=>not_sel, y=>a_and);

      bsel: entity work.and_gate
         port map (a=>sel, b=>b, y=>b_and);

      almost: entity work.or_gate
         port map (a=>a_and, b=>b_and, y=>checken);

      there: entity work.and_gate
         port map (a=>en, b=>checken, y=>y);
end switch;
