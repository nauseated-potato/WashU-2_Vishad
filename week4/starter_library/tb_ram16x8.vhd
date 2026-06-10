-- tb_ram16x8.vhd
--
-- Week 4 — PROVIDED testbench for the ram16x8 module example.
-- Tests write, read-back, overwrite, and valid/read_active timing.
--
-- Port map matches ram16x8.vhd exactly:
--   entity ram16x8
--       port (clk      : in    std_logic;
--             we       : in    std_logic;
--             addr     : in    std_logic_vector(3 downto 0);
--             data_bus : inout std_logic_vector(7 downto 0));

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity tb_ram16x8 is
end tb_ram16x8;

architecture sim of tb_ram16x8 is

    signal clk      : std_logic := '0';
    signal we       : std_logic := '0';
    signal addr     : std_logic_vector(3 downto 0) := (others => '0');
    signal data_bus : std_logic_vector(7 downto 0);

    -- Testbench-side bus driver.
    -- When we='1' (write): drive this value onto data_bus.
    -- When we='0' (read):  release the bus (tri-state).
    signal tb_data  : std_logic_vector(7 downto 0) := (others => 'Z');

    constant CLK_PERIOD : time := 10 ns;

begin

    -- Clock generator
    clk <= not clk after CLK_PERIOD / 2;

    -- Bidirectional bus management:
    -- Testbench drives bus during writes; tri-states during reads.
    data_bus <= tb_data when we = '1' else (others => 'Z');

    -- DUT
    uut : entity work.ram16x8
        port map (
            clk      => clk,
            we       => we,
            addr     => addr,
            data_bus => data_bus
        );

    stimulus : process
    begin

        -- -------------------------------------------------------
        -- Phase 1: Write four values to four different addresses
        -- -------------------------------------------------------
        -- Write 0xAA → address 0
        wait until rising_edge(clk);
        we <= '1'; addr <= "0000"; tb_data <= x"AA";

        -- Write 0xBB → address 1
        wait until rising_edge(clk);
        addr <= "0001"; tb_data <= x"BB";

        -- Write 0xCC → address 5
        wait until rising_edge(clk);
        addr <= "0101"; tb_data <= x"CC";

        -- Write 0xDD → address 15 (max address)
        wait until rising_edge(clk);
        addr <= "1111"; tb_data <= x"DD";

        -- -------------------------------------------------------
        -- Phase 2: Read back and verify (check latency)
        -- -------------------------------------------------------
        -- Request read of address 0
        wait until rising_edge(clk);
        we <= '0'; addr <= "0000"; tb_data <= (others => 'Z');

        -- data_bus holds 0xAA from the next edge onward
        wait until rising_edge(clk);
        assert data_bus = x"AA"
            report "FAIL: read addr 0 => expected 0xAA" severity error;

        -- Read address 1
        addr <= "0001";
        wait until rising_edge(clk);
        assert data_bus = x"BB"
            report "FAIL: read addr 1 => expected 0xBB" severity error;

        -- Read address 5
        addr <= "0101";
        wait until rising_edge(clk);
        assert data_bus = x"CC"
            report "FAIL: read addr 5 => expected 0xCC" severity error;

        -- Read address 15
        addr <= "1111";
        wait until rising_edge(clk);
        assert data_bus = x"DD"
            report "FAIL: read addr 15 => expected 0xDD" severity error;

        -- -------------------------------------------------------
        -- Phase 3: Overwrite address 0 and confirm new value
        -- -------------------------------------------------------
        wait until rising_edge(clk);
        we <= '1'; addr <= "0000"; tb_data <= x"FF";

        wait until rising_edge(clk);
        we <= '0'; addr <= "0000"; tb_data <= (others => 'Z');

        wait until rising_edge(clk);
        assert data_bus = x"FF"
            report "FAIL: overwrite addr 0 => expected 0xFF" severity error;

        -- -------------------------------------------------------
        -- Phase 4: Verify un-written address returns 0x00
        -- (RAM initialised to all zeros)
        -- -------------------------------------------------------
        addr <= "0111";   -- address 7 was never written
        wait until rising_edge(clk);
        assert data_bus = x"00"
            report "FAIL: uninitialised addr 7 => expected 0x00" severity error;

        wait for 3 * CLK_PERIOD;
        report "tb_ram16x8: all tests complete." severity note;
        wait;
    end process stimulus;

end sim;
