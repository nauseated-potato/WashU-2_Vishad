library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_alu4_extended is
end tb_alu4_extended;

architecture sim of tb_alu4_extended is

	signal a	  : std_logic_vector(3 downto 0) := (others => '0');
	signal b	  : std_logic_vector(3 downto 0) := (others => '0');
	signal op	 : std_logic_vector(2 downto 0) := (others => '0');
	signal result : std_logic_vector(3 downto 0);
	signal zero, negative, carry   : std_logic;

	constant PROP_DELAY : time := 10 ns;

begin

	uut : entity work.alu4_extended
		port map (
			a	  => a,
			b	  => b,
			op	 => op,
			result => result,
			zero   => zero,
			negative => negative,
			carry => carry
		);

	stimulus : process
	begin

		-- -------------------------------------------------------
		-- ADD  (op = "000")
		-- -------------------------------------------------------
		op <= "000";

		a <= "0011"; b <= "0101"; wait for PROP_DELAY;  -- 3+5=8
		assert result = "1000" and zero = '0' and negative = '1' and carry = '0'
			report "FAIL: ADD 3+5 => expected 1000, zero=0 and negative = '1' and carry = '0'" severity error;

		a <= "0000"; b <= "0000"; wait for PROP_DELAY;  -- 0+0=0, zero flag
		assert result = "0000" and zero = '1' and negative = '0' and carry = '0'
			report "FAIL: ADD 0+0 => expected 0000, zero=1 and negative = '0' and carry = '0'" severity error;

		a <= "1111"; b <= "0001"; wait for PROP_DELAY;  -- 15+1 wraps to 0
		assert result = "0000" and zero = '1' and negative = '0' and carry = '1'
			report "FAIL: ADD wrap 15+1 => expected 0000, zero=1 and negative = '0' and carry = '1'" severity error;

		a <= "0011"; b <= "0001"; wait for PROP_DELAY;  -- 3+1=4
		assert result = "0100" and zero = '0' and negative = '0' and carry = '0'
			report "FAIL: ADD 3+1 => expected 0100, zero=0 and negative = '0' and carry = '0'" severity error;

		-- -------------------------------------------------------
		-- SUB  (op = "001")
		-- -------------------------------------------------------
		op <= "001";

		a <= "0101"; b <= "0011"; wait for PROP_DELAY;  -- 5-3=2
		assert result = "0010" and zero = '0' and negative = '0' and carry = '0'
			report "FAIL: SUB 5-3 => expected 0010, zero=0 and negative = '0' and carry = '0'" severity error;

		a <= "0011"; b <= "0011"; wait for PROP_DELAY;  -- 3-3=0
		assert result = "0000" and zero = '1' and negative = '0' and carry = '0'
			report "FAIL: SUB 3-3 => expected 0000, zero=1 and negative = '0' and carry = '0'" severity error;

		a <= "0001"; b <= "0011"; wait for PROP_DELAY;  -- 1-3 wraps (unsigned)
		assert result = "1110" and zero = '0' and negative = '1' and carry = '0'
			report "FAIL: SUB 1-3 wrap => expected 1110, zero=0 and negative = '1' and carry = '0'" severity error;

		a <= "1011"; b <= "0011"; wait for PROP_DELAY;  -- -5-3=-8
		assert result = "1000" and zero = '0' and negative = '1' and carry = '0'
			report "FAIL: SUB 3-3 => expected 0000, zero=0 and negative = '1' and carry = '0'" severity error;

		-- -------------------------------------------------------
		-- AND  (op = "010")
		-- -------------------------------------------------------
		op <= "010";

		a <= "1100"; b <= "1010"; wait for PROP_DELAY;  -- 1100 AND 1010 = 1000
		assert result = "1000" and zero = '0' and negative = '1' and carry = '0'
			report "FAIL: AND 1100 & 1010 => expected 1000, zero=0 and negative = '1' and carry = '0'" severity error;

		a <= "1111"; b <= "0000"; wait for PROP_DELAY;  -- 1111 AND 0000 = 0000, zero
		assert result = "0000" and zero = '1' and negative = '0' and carry = '0'
			report "FAIL: AND 1111 & 0000 => expected 0000, zero=1 and negative = '0' and carry = '0'" severity error;

		-- -------------------------------------------------------
		-- OR   (op = "011")
		-- -------------------------------------------------------
		op <= "011";

		a <= "1010"; b <= "0101"; wait for PROP_DELAY;  -- 1010 OR 0101 = 1111
		assert result = "1111" and zero = '0' and negative = '1' and carry = '0'
			report "FAIL: OR 1010 | 0101 => expected 1111, zero=0 and negative = '1' and carry = '0'" severity error;

		a <= "0000"; b <= "0000"; wait for PROP_DELAY;  -- 0 OR 0 = 0
		assert result = "0000" and zero = '1' and negative = '0' and carry = '0'
			report "FAIL: OR 0|0 => expected 0000, zero=1 and negative = '0' and carry = '0'" severity error;
		-- -------------------------------------------------------
		-- XOR   (op = "100")
		-- -------------------------------------------------------
		op <= "100";

		a <= "1010"; b <= "0101"; wait for PROP_DELAY;  -- 1010 XOR 0101 = 1111
		assert result = "1111" and zero = '0' and negative = '1' and carry = '0'
			report "FAIL: XOR 1010 ^ 0101 => expected 1111, zero=1" severity error;

		a <= "0010"; b <= "0110"; wait for PROP_DELAY;  -- 0010 OR 0110 = 0100
		assert result = "0100" and zero = '0' and negative = '0' and carry = '0'
			report "FAIL: XOR 0010 ^ 0110 => expected 0100, zero=0 and negative = '0' and carry = '0'" severity error;

		-- -------------------------------------------------------
		-- NOT  (op = "101")
		-- -------------------------------------------------------
		op <= "101";

		a <= "1010"; wait for PROP_DELAY;			   -- NOT 1010 = 0101
		assert result = "0101" and zero = '0' and negative = '0' and carry = '0'
			report "FAIL: NOT 1010 => expected 0101 and zero = '0' and negative = '0' and carry = '0'" severity error;

		a <= "1111"; wait for PROP_DELAY;			   -- NOT 1111 = 0000
		assert result = "0000" and zero = '1' and negative = '0' and carry = '0'
			report "FAIL: NOT 1111 => expected 0000, zero=1 and negative = '0' and carry = '0'" severity error;

		a <= "0000"; wait for PROP_DELAY;			   -- NOT 0000 = 1111
		assert result = "1111" and zero = '0' and negative = '1' and carry = '0'
			report "FAIL: NOT 0000 => expected 1111, zero=0 and negative = '1' and carry = '0'" severity error;

		-- -------------------------------------------------------
		-- NEGATE  (op = "110")
		-- -------------------------------------------------------
		op <= "110";

		a <= "0011"; wait for PROP_DELAY;			   -- -3 = 1101
		assert result = "1101" and zero = '0' and negative = '1' and carry = '0'
			report "FAIL: NEGATE 3 => expected 1101 and zero = '0' and negative = '1' and carry = '0'" severity error;

		a <= "1010"; wait for PROP_DELAY;			   -- -(-6) = 0110
		assert result = "0110" and zero = '0' and negative = '0' and carry = '0'
			report "FAIL: NEGATE -6 => expected 0110 and zero = '0' and negative = '0' and carry = '0'" severity error;

		a <= "0000"; wait for PROP_DELAY;			   -- -0 = 0, zero flag
		assert result = "0000" and zero = '1' and negative = '0' and carry = '0'
			report "FAIL: NEGATE 0 => expected 0000, zero=1 and negative = '0' and carry = '0'" severity error;

		a <= "1000"; wait for PROP_DELAY;			   -- -(-8) = -8 (overflow)
		assert result = "1000" and zero = '0' and negative = '1' and carry = '0'
			report "FAIL: NEGATE -8 => expected 1000 (special case) and zero = '0' and negative = '1' and carry = '0'" severity error;

		-- -------------------------------------------------------
		-- Undefined (op = "111") — should output 0000
		-- -------------------------------------------------------
		op <= "111";

		a <= "1111"; b <= "1111"; wait for PROP_DELAY;
		assert result = "0000" and zero = '0' and negative = '0' and carry = '0'
			report "FAIL: undefined op 111 => expected 0000 and zero = '0' and negative = '0' and carry = '0'" severity error;

        wait for PROP_DELAY;
        report "tb_alu4: all tests complete." severity note;

		wait;
	end process;
end sim;
