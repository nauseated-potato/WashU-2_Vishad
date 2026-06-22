library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity tb_ram8x8 is
end tb_ram8x8;

architecture sim of tb_ram8x8 is

	signal clk	  : std_logic := '0';
	signal reset	: std_logic := '1';
	signal we	   : std_logic := '0';
	signal addr	 : std_logic_vector(2 downto 0) := (others => '0');
	signal data_in  : std_logic_vector(7 downto 0) := (others => '0');
	signal data_out : std_logic_vector(7 downto 0);
	signal valid	: std_logic;

	signal sim_done: boolean:= false;

	constant CLK_PERIOD : time := 10 ns;

begin

	-- Clock generator
	--We do not want an infinite clock!
		clk_process: process
		begin
				if sim_done then
						wait;
				end if;
				clk <= not clk;
				wait for CLK_PERIOD / 2;
		end process;

	uut : entity work.ram8x8
		port map (
			clk	  => clk,
			we	   => we,
			reset	 => reset,
			addr	 => addr,
			data_in  => data_in,
			data_out => data_out,
			valid	=> valid
		);

	stimulus : process
	begin

		-- Phase 1: Reset (Needs to be tested later, obviously, but I'll let this section stay)
		reset <= '1';
		wait until rising_edge(clk);
		wait until rising_edge(clk);
		reset <= '0';
		wait until rising_edge(clk);

		-- Phase 2: Write four values
		-- Write 0xAA → address 0
		wait until rising_edge(clk);
		we <= '1'; addr <= "000"; data_in <= x"AA";

		-- Write 0xBB → address 1
		wait until rising_edge(clk);
		addr <= "001"; data_in <= x"BB";

		-- Write 0xCC → address 2
		wait until rising_edge(clk);
		addr <= "010"; data_in <= x"CC";

		-- Write 0xDD → address 3
		wait until rising_edge(clk);
		addr <= "011"; data_in <= x"DD";

		-- Phase 3: Read back all four values (check valid timing)
		wait until rising_edge(clk);
		we <= '0'; addr <= "000";  -- read address 0

		wait until rising_edge(clk);  -- data_out now holds 0xAA, valid='1'
		wait for 1 fs;
		assert data_out = x"AA" and valid = '1'
			report "FAIL: read addr 0" severity error;

		addr <= "001";				-- read address 1
		wait until rising_edge(clk);
		wait for 1 fs;
		assert data_out = x"BB" and valid = '1'
			report "FAIL: read addr 1" severity error;

		addr <= "010";
		wait until rising_edge(clk);
		wait for 1 fs;
		assert data_out = x"CC" report "FAIL: read addr 2" severity error;

		addr <= "011";
		wait until rising_edge(clk);
		wait for 1 fs;
		assert data_out = x"DD" report "FAIL: read addr 3" severity error;

		addr <= "010";
		reset<='1';
		wait until rising_edge(clk);
		wait for 1 fs;
		assert data_out = x"00" report "FAIL: read addr 2 after reset" severity error;
		reset<='0';

		-- Phase 4: Overwrite address 0 and verify updated value
		wait until rising_edge(clk);
		wait for 1 fs;
		we <= '1'; addr <= "000"; data_in <= x"FF";

		wait until rising_edge(clk);
		wait for 1 fs;
		we <= '0'; addr <= "000";

		wait until rising_edge(clk);
		wait for 1 fs;
		assert data_out = x"FF"
			report "FAIL: read after overwrite addr 0" severity error;

		-- Phase 5: Check valid is '0' in a write cycle
		wait until rising_edge(clk);
		we <= '1'; addr <= "000"; data_in <= x"11";
		wait until rising_edge(clk);
		wait for 1 fs;
		assert valid = '0'
			report "FAIL: valid should be '0' after write" severity error;
		
		-- Phase 6: valid = '1' in a read cycle
		wait until rising_edge(clk);
		we <= '0'; addr <= "000";
		wait until rising_edge(clk);
		wait for 1 fs;
		assert valid = '1'
			report "FAIL: valid should be '1' after read" severity error;

		wait until rising_edge(clk);
		report "RAM testbench complete." severity note;
		sim_done <= true;
		wait;
	end process stimulus;

end sim;
