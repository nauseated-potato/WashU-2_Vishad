-- the mod_counter uses the one-liner conditional to update tick

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity tb_mod_counter is
end tb_mod_counter;

architecture sim of tb_mod_counter is
	signal clk, reset, enable, tick:std_logic:='0';
	signal count : std_logic_vector(3 downto 0):=(others=>'0');
	signal sim_done: boolean:= false;
	constant CLK_PERIOD : time := 10 ns;
begin
	--We do not want an infinite clock!
	clk_process: process
	begin
		if sim_done then
			wait;
		end if;
		clk <= not clk;
		wait for CLK_PERIOD / 2;
	end process;

	dut: entity work.mod_counter
	port map( clk=>clk, reset=>reset, enable=>enable, tick=>tick, count=>count );

	stimulus: process
	begin
		--Part 1
		reset  <= '1';
		wait for 5 * CLK_PERIOD;

		--Part 2
		--tick shld be high for count N-1
		reset<='0';
		enable<='1';
		wait for 40*CLK_PERIOD;

		--Part 3
		enable<='0';
		wait for 5*CLK_PERIOD;

		--Part 4: restarting enable
		enable<='1';
		wait for 5*CLK_PERIOD;

		--Part 5: turn off enable and confirm that reset works
		enable<='0';
		reset<='1';
		wait for 5*CLK_PERIOD;

		--Part 6: Have you tried turning it off and on again?
		reset<='0';
		enable<='1';
		wait for 40*CLK_PERIOD;

		sim_done<=true;

		wait;

	end process;
end sim;
