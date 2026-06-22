library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity tb_seq_det_101_nonoverlap is
end tb_seq_det_101_nonoverlap;

architecture sim of tb_seq_det_101_nonoverlap is
	signal clk, data, detected: std_logic:='0';
	signal reset: std_logic:='1';
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
	-- Device under test
	uut : entity work.seq_det_101_nonoverlap
		port map (
			clk	  => clk,
			reset	=> reset,
			data	 => data,
			detected => detected
		);

	stimulus : process
	begin
		-- PART 1
		reset <= '1';
		wait for 3 * CLK_PERIOD;
		reset <= '0';
		-- Important to test reset when the state differs from initial state; TODO

		-- PART 2: testing pattern 10101
		wait until rising_edge(clk); data <= '1';
		wait until rising_edge(clk); data <= '0';
		wait until rising_edge(clk); data <= '1';
		wait until rising_edge(clk); data <= '0';
		wait until rising_edge(clk); data <= '1';
		wait until rising_edge(clk);
		-- Expected state: s1

		--PART 3: TODO of PART 1
		reset <= '1';
		wait until rising_edge(clk); data <= '0';
		wait until rising_edge(clk);
		reset <= '0';
		data <= '1'; -- If reset fails but counter works, then detected will be '1' here; observed in next cycle
		wait until rising_edge(clk); data <= '0';
		wait until rising_edge(clk); data <= '1'; -- If everything works nicely, detected will be '1' here; observed in next cycle
		wait until rising_edge(clk); data <= '0';
		wait until rising_edge(clk);

		-- PART 4: end stimulus
		sim_done<=true;
		wait;
	end process;
end sim;

