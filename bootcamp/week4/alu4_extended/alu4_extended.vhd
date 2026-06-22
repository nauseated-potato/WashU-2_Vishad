library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity alu4_extended is
	port (
		a		: in  std_logic_vector(3 downto 0);
		b		: in  std_logic_vector(3 downto 0);
		op	   : in  std_logic_vector(2 downto 0);
		result   : out std_logic_vector(3 downto 0);
		zero	 : out std_logic;   -- '1' when result = "0000"
		carry	: out std_logic;   -- '1' when ADD produces a carry out
		negative : out std_logic	-- '1' when result(3) = '1' (MSB set)
	);
end alu4_extended;

architecture alu of alu4_extended is
	signal result_int   : std_logic_vector(3 downto 0);
	constant ALU_ADD	: std_logic_vector(2 downto 0) := "000";
	constant ALU_SUB	: std_logic_vector(2 downto 0) := "001"; -- Carry is '0' for this operation
	constant ALU_AND	: std_logic_vector(2 downto 0) := "010";
	constant ALU_OR	 : std_logic_vector(2 downto 0) := "011";
	constant ALU_XOR	: std_logic_vector(2 downto 0) := "100";
	constant ALU_NOT	: std_logic_vector(2 downto 0) := "101";
	constant ALU_NEGATE : std_logic_vector(2 downto 0) := "110";
--  constant ALU_CLEAR  : std_logic_vector(2 downto 0) := "111";

begin
	calc: process (a, b, op)
		variable check_carry  : std_logic_vector(4 downto 0):="00000";
	begin
		result_int <= (others => '0'); -- ALU_CLEAR taken care of.
		carry <= '0';
		case op is
			when ALU_ADD =>
				result_int <= std_logic_vector(unsigned(a) + unsigned(b));
				check_carry := std_logic_vector(('0' & unsigned(a)) + ('0' & unsigned(b)));
			--  with a 4 bit check_carry
			--	if unsigned(check_carry)<unsigned(a) then
			--		carry <= '1';
			--	end if;
				carry <= check_carry(4);

			when ALU_SUB =>
				result_int <= std_logic_vector(unsigned(a)-unsigned(b));

			when ALU_AND =>
				result_int <= a and b;

			when ALU_OR =>
				result_int <= a or b;

			when ALU_XOR =>
				result_int <= a xor b;

			when ALU_NOT =>
				result_int <= not a;

			when ALU_NEGATE =>
				result_int <= std_logic_vector(-signed(a));

			when others =>
				result_int <= (others => '0');
				carry <= '0';
		end case;
	end process;

	result <= result_int;

	zero <= '0' when op="111" else '1' when result_int = "0000" else '0';
	negative <= '1' when result_int(3) = '1' else '0';
end alu;
