-- alu8.vhd
--
-- Week 5 — PROVIDED 8-bit ALU for the mini-datapath.
-- Do NOT modify this file.
--
-- Operation table:
--   "000"  ADD     result = a + b
--   "001"  SUB     result = a - b
--   "010"  AND     result = a AND b (bitwise)
--   "011"  OR      result = a OR b  (bitwise)
--   "100"  NOT     result = NOT a   (b ignored)
--   "101"  NEGATE  result = -a      (b ignored, two's complement)
--   "110"  XOR     result = a XOR b (bitwise)
--   "111"  PASS    result = b       (used for LOAD instruction)
--   others          result = 0x00

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity alu8 is
    port (
        a      : in  std_logic_vector(7 downto 0);
        b      : in  std_logic_vector(7 downto 0);
        op     : in  std_logic_vector(2 downto 0);
        result : out std_logic_vector(7 downto 0);
        zero   : out std_logic
    );
end alu8;

architecture rtl of alu8 is

    signal result_int : std_logic_vector(7 downto 0);

begin

    alu_proc : process (a, b, op)
    begin
        result_int <= (others => '0');

        case op is
            when "000" =>   -- ADD
                result_int <= std_logic_vector(unsigned(a) + unsigned(b));

            when "001" =>   -- SUB
                result_int <= std_logic_vector(unsigned(a) - unsigned(b));

            when "010" =>   -- AND
                result_int <= a and b;

            when "011" =>   -- OR
                result_int <= a or b;

            when "100" =>   -- NOT a
                result_int <= not a;

            when "101" =>   -- NEGATE a
                result_int <= std_logic_vector(-signed(a));

            when "110" =>   -- XOR
                result_int <= a xor b;

            when "111" =>   -- PASS: output = b
                -- Used by LOAD instruction to move mem_data_out into acc
                -- without any arithmetic.
                result_int <= b;

            when others =>
                result_int <= (others => '0');
        end case;
    end process alu_proc;

    result <= result_int;
    zero   <= '1' when result_int = x"00" else '0';

end rtl;
