-- ram16x8.vhd
-- 16-location × 8-bit synchronous RAM with bidirectional data bus.
-- Write on rising edge when we='1'.
-- Read on rising edge when we='0' (output appears on NEXT clock cycle).

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ram16x8 is
    port (
        clk      : in    std_logic;
        we       : in    std_logic;
        addr     : in    std_logic_vector(3 downto 0);
        data_bus : inout std_logic_vector(7 downto 0)
    );
end ram16x8;

architecture rtl of ram16x8 is

    -- Array type: 16 elements, each 8 bits wide
    type ram_type is array (0 to 15) of std_logic_vector(7 downto 0);

    -- RAM storage — initialised to all zeros.
    -- During simulation this gives predictable results.
    -- In synthesis, Quartus will infer block RAM (M9K) for this pattern.
    signal ram_mem : ram_type := (others => (others => '0'));

    -- Internal read-data register
    -- Holds the last read value; driven onto data_bus when we='0'.
    signal data_out_reg : std_logic_vector(7 downto 0) := (others => '0');

    -- Internal flag: are we in read mode this cycle?
    -- Needed to decide whether to drive the bus or tri-state it.
    signal read_active : std_logic := '0';

begin

    -- =================================================================
    -- Synchronous memory process: write and read on rising edge
    -- =================================================================
    mem_proc : process (clk)
    begin
        if rising_edge(clk) then
            if we = '1' then
                -- WRITE: store data_bus into addressed location.
                -- RAM does not drive the bus during a write (data is incoming).
                ram_mem(to_integer(unsigned(addr))) <= data_bus;
                read_active <= '0';
            else
                -- READ: capture addressed location into output register.
                data_out_reg <= ram_mem(to_integer(unsigned(addr)));
                read_active  <= '1';
            end if;
        end if;
    end process mem_proc;

    -- =================================================================
    -- Bidirectional bus driver
    -- Drive data_out_reg onto the bus when read_active='1'.
    -- Drive 'Z' when writing (bus is owned by the external driver).
    -- =================================================================
    data_bus <= data_out_reg when read_active = '1' else (others => 'Z');

end rtl;
