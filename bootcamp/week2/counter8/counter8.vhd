library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

entity counter8 is
    port (clk, reset, enable: in std_logic;
    count : out std_logic_vector(7 downto 0));
end counter8;

architecture count of counter8 is
    signal count_int: std_logic_vector(7 downto 0);
begin
    process (clk, reset)
    begin
        if reset = '1' then
            count_int<=(others => '0');
        elsif rising_edge(clk) then
            if enable = '1' then
                count_int<=std_logic_vector(unsigned(count_int)+1);
            end if;
        end if;
    end process;
    count <= count_int;
end count;

