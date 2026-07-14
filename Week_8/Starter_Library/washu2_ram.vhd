-- washu2_ram.vhd
--
-- Week 8 — PROVIDED 4096-location x 16-bit synchronous RAM.
-- Same infrastructure as the Week 7 version. Edit only the section
-- marked "PROGRAM: edit this initialiser".
--
-- Port summary:
--   clk      : in  std_logic
--   we       : in  std_logic                      -- '1' = write, '0' = read
--   addr     : in  std_logic_vector(11 downto 0)  -- 12-bit address (0x000..0xFFF)
--   data_in  : in  std_logic_vector(15 downto 0)  -- write data (from the_bus)
--   data_out : out std_logic_vector(15 downto 0)  -- read data (to bus via bus_mem)
--
-- Timing:
--   Write: on rising_edge(clk) with we='1', data_in is stored at addr.
--   Read:  on rising_edge(clk) with we='0', ram(addr) is captured into
--          data_out_reg. Data appears on data_out the NEXT clock cycle
--          (one-cycle registered read latency).
--
-- Instruction encoding reminder (16-bit word):
--   Bits 15:12 = opcode (4 bits)
--   Bits 11:0  = operand/address (12 bits)
--
--   Full opcode table (all 14 Week 8 instructions):
--     0000 = HALT    0001 = NEGATE  0010 = CLOAD   0011 = DLOAD
--     0100 = DSTORE  0101 = ILOAD   0110 = ISTORE  0111 = ADD
--     1000 = AND     1001 = BRANCH  1010 = BRZERO  1011 = BRPOS
--     1100 = BRNEG   1101 = BRIND
--
-- To run a Module 3/4/5 exercise program instead of the default
-- integration test below, replace the initialiser contents with that
-- module's program listing before compiling.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity washu2_ram is
    port (
        clk      : in  std_logic;
        we       : in  std_logic;
        addr     : in  std_logic_vector(11 downto 0);
        data_in  : in  std_logic_vector(15 downto 0);
        data_out : out std_logic_vector(15 downto 0)
    );
end washu2_ram;

architecture rtl of washu2_ram is

    type ram_type is array (0 to 4095) of std_logic_vector(15 downto 0);

    -- ==============================================================
    -- PROGRAM: edit this initialiser for each exercise / test program.
    --
    -- Array indices are DECIMAL integers.
    -- Address 0x020 = index 32, 0x021 = 33, 0x022 = 34, 0x030 = 48.
    --
    -- Current program: Module 6 Section 3 — full integration test
    -- exercising CLOAD, DSTORE, DLOAD, ADD, AND, BRANCH, BRIND, ISTORE,
    -- ILOAD, NEGATE, and BRZERO in one run.
    --
    -- Expected results after HALT:
    --   ACC        = 0xFFF6
    --   mem[0x030] = 0x000A
    --   done       = '1'
    -- ==============================================================
    signal ram_mem : ram_type := (

        -- ── Instructions (addresses 0x000-0x00D) ───────────────────
        0  => x"200A",   -- CLOAD 10       acc <- 0x000A
        1  => x"4020",   -- DSTORE 0x020   mem[0x020] <- 0x000A
        2  => x"2005",   -- CLOAD 5        acc <- 0x0005
        3  => x"7020",   -- ADD 0x020      acc <- 5 + 10 = 0x000F
        4  => x"8020",   -- AND 0x020      acc <- 0x000F AND 0x000A = 0x000A
        5  => x"9007",   -- BRANCH 0x007   PC <- 0x007 (unconditional)
        6  => x"0000",   -- HALT           (skipped)
        7  => x"D021",   -- BRIND 0x021    PC <- mem[0x021] = 0x009
        8  => x"0000",   -- HALT           (skipped)
        9  => x"6022",   -- ISTORE 0x022   mem[mem[0x022]] <- acc
        10 => x"5022",   -- ILOAD 0x022    acc <- mem[mem[0x022]]
        11 => x"1000",   -- NEGATE         acc <- -0x000A = 0xFFF6
        12 => x"A013",   -- BRZERO 0x013   zero_flag='0' -> not taken
        13 => x"0000",   -- HALT           (final)

        -- ── Data ─────────────────────────────────────────────────
        32 => x"0000",   -- (0x020) ADD/AND scratch cell
        33 => x"0009",   -- (0x021) BRIND target: instruction address 0x009
        34 => x"0030",   -- (0x022) ILOAD/ISTORE pointer -> real target 0x030
        48 => x"0000",   -- (0x030) ILOAD/ISTORE data cell

        others => x"0000"
    );

    signal data_out_reg : std_logic_vector(15 downto 0) := (others => '0');

begin

    mem_proc : process (clk)
    begin
        if rising_edge(clk) then
            if we = '1' then
                ram_mem(to_integer(unsigned(addr))) <= data_in;
            end if;
            -- Registered read: data_out valid ONE cycle after addr is presented
            data_out_reg <= ram_mem(to_integer(unsigned(addr)));
        end if;
    end process mem_proc;

    data_out <= data_out_reg;

end rtl;
