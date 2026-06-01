library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity counter8 is
    port (
        clk   : in  std_logic;
        count : out std_logic_vector(7 downto 0)
    );
end counter8;

architecture rtl of counter8 is
    signal count_int : std_logic_vector(7 downto 0) := (others => '0');
begin
    process (clk)
    begin
        if rising_edge(clk) then
            count_int <= std_logic_vector( unsigned(count_int) + 1 );
        end if;
    end process;

    count <= count_int;
end rtl;
