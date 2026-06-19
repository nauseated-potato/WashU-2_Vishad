-- ram32x8.vhd
--
-- Week 5 — PROVIDED 32-location × 8-bit synchronous RAM.
--
-- Edit the section marked "PROGRAM: edit this initialiser" to load
-- your program and data for each exercise.
--
-- Port summary:
--   clk      : in  std_logic
--   we       : in  std_logic         -- '1' = write, '0' = read
--   addr     : in  std_logic_vector(4 downto 0)   -- 5-bit address (0..31)
--   data_in  : in  std_logic_vector(7 downto 0)   -- write data
--   data_out : out std_logic_vector(7 downto 0)   -- read data (1-cycle latency)
--
-- Behaviour:
--   Write: on rising_edge(clk) with we='1', data_in is stored at addr.
--   Read:  on rising_edge(clk) with we='0', ram(addr) is captured into
--          data_out register. Data appears on data_out the NEXT clock cycle.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ram32x8 is
    port (
        clk      : in  std_logic;
        we       : in  std_logic;
        addr     : in  std_logic_vector(4 downto 0);
        data_in  : in  std_logic_vector(7 downto 0);
        data_out : out std_logic_vector(7 downto 0)
    );
end ram32x8;

architecture rtl of ram32x8 is

    type ram_type is array (0 to 31) of std_logic_vector(7 downto 0);

    -- ==============================================================
    -- PROGRAM: edit this initialiser for each exercise.
    --
    -- Instruction encoding:
    --   bits[7:5] = opcode:  000=LOAD  001=ADD  010=STORE  011=HALT
    --   bits[4:0] = operand address (decimal index into this array)
    --
    -- Array indices are DECIMAL. Address 0x10 = index 16, etc.
    --
    -- Example (Program 1: result = 7 + 5, stored at address 18):
    --   0  => "00010000",  -- LOAD  addr 16  (000 10000)
    --   1  => "00110001",  -- ADD   addr 17  (001 10001)
    --   2  => "01010010",  -- STORE addr 18  (010 10010)
    --   3  => "01100000",  -- HALT           (011 00000)
    --   16 => "00000111",  -- data: A = 7
    --   17 => "00000101",  -- data: B = 5
    --   18 => "00000000",  -- result placeholder
    -- ==============================================================
    signal ram_mem : ram_type := (
        -- TODO: replace this placeholder with your encoded program.
        -- Instructions go at low addresses (0, 1, 2, 3, ...)
        -- Data goes at higher addresses (16, 17, 18, ...)
        0  => "01100000",   -- HALT as placeholder (prevents runaway on default)
        others => (others => '0')
    );

    signal data_out_reg : std_logic_vector(7 downto 0) := (others => '0');

begin

    mem_proc : process (clk)
    begin
        if rising_edge(clk) then
            if we = '1' then
                ram_mem(to_integer(unsigned(addr))) <= data_in;
            end if;
            -- Read: always register the output (1-cycle latency)
            data_out_reg <= ram_mem(to_integer(unsigned(addr)));
        end if;
    end process mem_proc;

    data_out <= data_out_reg;

end rtl;
