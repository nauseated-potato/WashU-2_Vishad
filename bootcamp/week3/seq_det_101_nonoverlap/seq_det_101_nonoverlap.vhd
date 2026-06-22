library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity seq_det_101_nonoverlap is
    port (
        clk      : in  std_logic;
        reset    : in  std_logic;
        data     : in  std_logic;
        detected : out std_logic
    );
end seq_det_101_nonoverlap;

architecture fsm of seq_det_101_nonoverlap is
	type state is (s, s1, s10, s101);
	signal current_state, next_state: state;
begin
	state_chng: process (clk)
	begin
		if rising_edge(clk) then
			if reset = '1' then
				current_state<=s;
			else
				current_state <= next_state;
			end if;
		end if;
	end process;

	machine: process(current_state, data)
	begin
		next_state <= current_state;
		detected <='0';

		case current_state is
			when s =>
				if data='1' then next_state <= s1; else next_state <= s; end if;

			when s1 =>
				if data='0' then next_state <= s10; elsif data='1' then next_state <= s1; else next_state<=s; end if; --Beware of undefined
				--Resetting at unkown signal in above

			when s10 =>
				if data='1' then next_state <= s101; else next_state <= s; end if;

			when s101 =>
				detected <='1';
				if data='1' then next_state <= s1; else next_state <= s; end if;

			when others =>
				next_state <= current_state;
		end case;
	end process;

end fsm;

