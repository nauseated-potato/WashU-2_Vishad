library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity vending_machine is
	port (
		clk	  : in  std_logic;
		reset	: in  std_logic;
		coin5	: in  std_logic;   -- '1' for one clock cycle when 5p inserted
		coin10   : in  std_logic;   -- '1' for one clock cycle when 10p inserted
		dispense : out std_logic;   -- '1' for one cycle when item is released
		change   : out std_logic	-- '1' for one cycle when 5p change is given
	);
end vending_machine;

architecture fsm of vending_machine is
	type state is (s0, s5, s10, s15, s20);
	signal current_state, next_state: state;
	signal sig5, sig10: std_logic:='0';
begin

	state_chng: process (clk)
	begin
		if rising_edge(clk) then
			if reset = '1' then
				current_state <= s0;
			else
				current_state <= next_state;
			end if;
		end if;
	end process;

	machine: process(current_state, coin5, coin10)
	begin
		next_state <= current_state;
		dispense <= '0';
		change <= '0';

		case current_state is
			when s0 =>
				if coin5='1' then
					next_state<=s5;
				elsif coin10='1' then
					next_state<=s10;
				end if;

			when s5 =>
				if coin5='1' then
					next_state<=s10;
				elsif coin10='1' then
					next_state<=s15;
				end if;

			when s10 =>
				if coin5='1' then
					next_state<=s15;
				elsif coin10='1' then
					next_state<=s20;
				end if;

			when s15 =>
				next_state<=s0;
				dispense<='1';
			--assumed here that s15 is handled sufficiently fast that user can't put a coin while vm is at s15

			when s20 =>
				next_state<=s0;
				dispense<='1';
				change<='1';
			--assumed here that s20 is handled sufficiently fast that user can't put a coin while vm is at s20

			when others =>
				next_state <= current_state;

		end case;
	end process;

end fsm;
