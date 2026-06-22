library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

entity mod_counter is
	generic(N:Integer:=10);
	port(clk, reset, enable: in std_logic;
	count : out std_logic_vector(3 downto 0);
	tick  : out std_logic);
end mod_counter;

architecture lallaa of mod_counter is
	signal count_int: std_logic_vector(3 downto 0):=(others=>'0');
begin
	process (clk, reset)
	begin
		if reset = '1' then
			count_int<=(others => '0');
		elsif rising_edge(clk) then
			if enable = '1' then
				count_int<=std_logic_vector((unsigned(count_int)+1) rem N);
			end if;
		end if;
	end process;
	count <= count_int;
	tick <= '1' when unsigned(count_int) = N-1 else '0';
end lallaa;

