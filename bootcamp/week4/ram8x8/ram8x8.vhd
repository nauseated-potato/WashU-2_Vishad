library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ram8x8 is
	port (
		clk	   : in  std_logic;
		we		: in  std_logic;					 -- write enable
		reset : in std_logic;
		addr	  : in  std_logic_vector(2 downto 0);  -- 3-bit address (0..7)
		data_in   : in  std_logic_vector(7 downto 0);  -- write data
		data_out  : out std_logic_vector(7 downto 0);  -- read data
		valid	 : out std_logic					   -- '1' one cycle after read
	);
end ram8x8;

architecture rw of ram8x8 is
	type ram_type is array (0 to 7) of std_logic_vector(7 downto 0);
	signal ram_mem : ram_type := (others => (others => '0')); -- (others => "00000000" also works; but the size of each elem of ram is hard-coded this way, which I guess one would not want
begin
	process (clk)
	begin
		if rising_edge(clk) then
			if reset='1' then
				data_out <= (others => '0');
				valid<='0';
			else
				if we = '1' then
					-- WRITE: store data_bus into addressed location.
					-- RAM does not drive the bus during a write (data is incoming).
					ram_mem(to_integer(unsigned(addr))) <= data_in;
					valid <= '0';
				else
					-- READ: capture addressed location into output register.
					data_out <= ram_mem(to_integer(unsigned(addr)));
					valid  <= '1';
				end if;
			end if;
		end if;
	end process;
end rw;
