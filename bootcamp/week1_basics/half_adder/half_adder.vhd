library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

library work;
use work.gates.all;

entity half_adder is
    port (a, b: in std_logic;
    sum, carry: out std_logic);
end half_adder;

architecture adder of half_adder is
begin
    add: entity work.xor_gate
        port map (a=>a, b=>b, y=>sum);
    oth: entity work.and_gate
        port map (a=>a, b=>b, y=>carry);
end adder;
