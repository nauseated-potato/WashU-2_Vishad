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
        -- 0  => x"2005",   -- CLOAD 5       (0010 000000000101) ACC ← 5
        -- 1  => x"1000",   -- NEGATE        (0001 000000000000) ACC ← -5 = 0xFFFB
        -- 2  => x"4010",   -- DSTORE 0x010  (0100 000000010000) mem[0x010] ← 0xFFFB
        -- 3  => x"2000",   -- CLOAD 0       (0010 000000000000) ACC ← 0 (clear acc)
        -- 4  => x"3010",   -- DLOAD 0x010   (0011 000000010000) ACC ← mem[0x010] = 0xFFFB
        -- 5  => x"0000",   -- HALT          (0000 000000000000)

        -- Prg D
        -- 0 => x"202A",   -- CLOAD 42 (ACC ← 42)
        -- 1 => x"4010",   -- DSTORE 0x010 (mem[0x010] ← ACC)
        -- 2 => x"2000",   -- CLOAD 0 (ACC ← 0, clears accumulator)
        -- 3 => x"3010",   -- DLOAD 0x010 (ACC ← mem[0x010] = 42)
        -- 4 => x"0000",   -- HALT

        -- ADD
        -- 0  => x"202A",   -- CLOAD 42      acc ← 0x002A
        -- 1  => x"4010",   -- DSTORE 0x010  mem[16] ← 0x002A
        -- 2  => x"2005",   -- CLOAD 5       acc ← 0x0005
        -- 3  => x"7010",   -- ADD 0x010     acc ← 5 + 42 = 47 = 0x002F
        -- 4  => x"0000",   -- HALT
        -- 16 => x"0000",   -- data slot

        --AND
        -- 0  => x"20FF",   -- CLOAD 0xFF    acc ← 0x00FF
        -- 1  => x"4010",   -- DSTORE 0x010  mem[16] ← 0x00FF
        -- 2  => x"20F0",   -- CLOAD 0xF0    acc ← 0x00F0
        -- 3  => x"8010",   -- AND 0x010     acc ← 0x00F0 AND 0x00FF = 0x00F0
        -- 4  => x"0000",   -- HALT
        -- 16 => x"0000",   -- data slot

        -- BRANCH
        -- 0 => x"2005",   -- CLOAD 5        acc ← 0x0005
        -- 1 => x"9004",   -- BRANCH 0x004   PC ← 0x004 (always taken)
        -- 2 => x"20FF",   -- CLOAD 0xFF     (skipped)
        -- 3 => x"0000",   -- HALT           (skipped)
        -- 4 => x"2007",   -- CLOAD 7        acc ← 0x0007  (landed here)
        -- 5 => x"0000",   -- HALT
        
        --BRZERO (taken)
        -- 0 => x"2000",   -- CLOAD 0        acc ← 0x0000
        -- 1 => x"A004",   -- BRZERO 0x004   zero_flag='1' → taken
        -- 2 => x"2001",   -- CLOAD 1        (skipped)
        -- 3 => x"0000",   -- HALT           (skipped)
        -- 4 => x"2002",   -- CLOAD 2        acc ← 0x0002  (landed)
        -- 5 => x"0000",   -- HALT

        -- BRZERO (not taken)
        -- 0 => x"2005",   -- CLOAD 5        acc ← 0x0005 (nonzero)
        -- 1 => x"A004",   -- BRZERO 0x004   zero_flag='0' → not taken
        -- 2 => x"2009",   -- CLOAD 9        acc ← 0x0009  (falls through, executes)
        -- 3 => x"0000",   -- HALT

        -- BRPOS (taken)
        -- 0 => x"2005",   -- CLOAD 5        acc ← 0x0005 (positive, nonzero)
        -- 1 => x"B004",   -- BRPOS 0x004    pos_flag='1' → taken
        -- 2 => x"2001",   -- (skipped)
        -- 3 => x"0000",   -- (skipped)
        -- 4 => x"2003",   -- CLOAD 3        acc ← 0x0003  (landed)
        -- 5 => x"0000",   -- HALT

        -- BRNEG (taken)
        -- 0 => x"2FFF",   -- CLOAD 0xFFF = CLOAD -1 (sign-extended)  acc ← 0xFFFF
        -- 1 => x"C004",   -- BRNEG 0x004    neg_flag = acc(15) = '1' → taken
        -- 2 => x"2001",   -- (skipped)
        -- 3 => x"0000",   -- (skipped)
        -- 4 => x"2005",   -- CLOAD 5        acc ← 0x0005  (landed)
        -- 5 => x"0000",   -- HALT

        -- BRIND
        -- 0  => x"2005",   -- CLOAD 5        acc ← 0x0005 (proves later CLOAD ran)
        -- 1  => x"D010",   -- BRIND 0x010    PC ← mem[0x010] = 0x0006
        -- 2  => x"2001",   -- (skipped)
        -- 3  => x"0000",   -- (skipped)
        -- 4  => x"2002",   -- (skipped)
        -- 5  => x"0000",   -- (skipped)
        -- 6  => x"2009",   -- CLOAD 9        acc ← 0x0009  (landed here via double hop)
        -- 7  => x"0000",   -- HALT
        -- 16 => x"0006",   -- pointer cell (address 0x010 = 16): jump target

        -- ILOAD
        -- 0  => x"5020",   -- ILOAD 0x020    acc ← mem[mem[0x020]]
        -- 1  => x"0000",   -- HALT
        -- 32 => x"0030",   -- (addr 0x020) pointer cell → real target 0x030
        -- 48 => x"002A",   -- (addr 0x030) data: 42

        -- ISTORE
        -- 0  => x"2007",   -- CLOAD 7        acc ← 0x0007
        -- 1  => x"6020",   -- ISTORE 0x020   mem[mem[0x020]] ← acc
        -- 2  => x"0000",   -- HALT
        -- 32 => x"0030",   -- (addr 0x020) pointer cell → real target 0x030
        -- 48 => x"0000",   -- (addr 0x030) initial data — should become 0x0007

        -- Integration
        0  => x"200A",   -- CLOAD 10       acc ← 0x000A
        1  => x"4020",   -- DSTORE 0x020   mem[0x020] ← 0x000A
        2  => x"2005",   -- CLOAD 5        acc ← 0x0005
        3  => x"7020",   -- ADD 0x020      acc ← 5 + 10 = 0x000F
        4  => x"8020",   -- AND 0x020      acc ← 0x000F AND 0x000A = 0x000A
        5  => x"9007",   -- BRANCH 0x007   PC ← 0x007 (unconditional)
        6  => x"0000",   -- HALT           (skipped)
        7  => x"D021",   -- BRIND 0x021    PC ← mem[0x021] = 0x009
        8  => x"0000",   -- HALT           (skipped)
        9  => x"6022",   -- ISTORE 0x022   mem[mem[0x022]] ← acc = mem[0x030] ← 0x000A
        10 => x"5022",   -- ILOAD 0x022    acc ← mem[mem[0x022]] = mem[0x030] = 0x000A
        11 => x"1000",   -- NEGATE         acc ← -0x000A = 0xFFF6
        12 => x"A013",   -- BRZERO 0x013   zero_flag='0' → not taken
        13 => x"0000",   -- HALT           (final)
        
        32 => x"0000",   -- (0x020) ADD/AND scratch cell
        33 => x"0009",   -- (0x021) BRIND target: instruction address 0x009
        34 => x"0030",   -- (0x022) ILOAD/ISTORE pointer → real target 0x030
        48 => x"0000",   -- (0x030) ILOAD/ISTORE data cell

        others => x"0000"
    );
    attribute ramstyle of ram_mem : signal is "block";
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
