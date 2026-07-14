-- washu2_ram.vhd
--
-- Week 7 — PROVIDED 4096-location × 16-bit synchronous RAM.
--
-- Edit only the section marked "PROGRAM: edit this initialiser".
-- Everything else is fixed infrastructure — do not modify it.
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
--   This latency is why the fetch cycle needs fetch1 AND fetch2:
--     fetch1 presents addr=pc to the RAM.
--     fetch2 reads the now-valid data_out into MBR.
--
-- Instruction encoding reminder (16-bit word):
--   Bits 15:12 = opcode (4 bits)
--   Bits 11:0  = operand/address (12 bits)
--
--   Opcode table:
--     0000 = HALT    0001 = NEGATE  0010 = CLOAD   0011 = DLOAD
--     0100 = DSTORE  0101 = ILOAD   0110 = ISTORE  0111 = ADD
--     1000 = AND     1001 = BRANCH  1010 = BRZERO  1011 = BRPOS
--     1100 = BRNEG   1101 = BRIND
--
--   Example encodings:
--     HALT           = 0x0000  (0000 000000000000)
--     NEGATE         = 0x1000  (0001 000000000000)
--     CLOAD 42       = 0x202A  (0010 000000101010)
--     CLOAD -1       = 0x2FFF  (0010 111111111111)
--     DLOAD 0x010    = 0x3010  (0011 000000010000)
--     DSTORE 0x010   = 0x4010  (0100 000000010000)
--     ADD 0x010      = 0x7010  (0111 000000010000)
--     BRANCH 0x003   = 0x9003  (1001 000000000011)
--     BRZERO 0x003   = 0xA003  (1010 000000000011)

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
    -- Address 0x010 = index 16, 0x020 = 32, 0x100 = 256, etc.
    --
    -- Instructions go at low addresses (0, 1, 2, ...).
    -- Data values go at higher addresses (e.g., 16, 32, 256, ...).
    --
    -- Current program: Exercise 1, Program A — HALT only.
    -- Replace with your own program for each exercise.
    -- ==============================================================
    attribute ramstyle : string;
    attribute ramstyle of ram_mem : signal is "block";
    signal ram_mem : ram_type := (
        -- ================================================================
        -- DEFAULT PROGRAM: self-test for all five Week 7 instructions.
        -- Expected results after HALT:
        --   ACC        = 0xFFFB  (-5 in two's complement)
        --   mem[0x010] = 0xFFFB  (stored by DSTORE, reloaded by DLOAD)
        --   PC         = 0x0006  (incremented past HALT in fetch2)
        --   done       = '1'
        --
        -- Replace this initialiser with your own program for each exercise.
        -- Array indices are DECIMAL: 0x010 = 16, 0x020 = 32, etc.
        -- ================================================================

        -- ── Instructions (addresses 0x000–0x005) ──────────────────────
        0  => x"2005",   -- CLOAD 5       (0010 000000000101) ACC ← 5
        1  => x"1000",   -- NEGATE        (0001 000000000000) ACC ← -5 = 0xFFFB
        2  => x"4010",   -- DSTORE 0x010  (0100 000000010000) mem[0x010] ← 0xFFFB
        3  => x"2000",   -- CLOAD 0       (0010 000000000000) ACC ← 0 (clear acc)
        4  => x"3010",   -- DLOAD 0x010   (0011 000000010000) ACC ← mem[0x010] = 0xFFFB
        5  => x"0000",   -- HALT          (0000 000000000000)

        -- ── Data (address 0x010 = decimal 16) ─────────────────────────
        16 => x"0000",   -- data slot for DSTORE/DLOAD (overwritten at runtime)

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
