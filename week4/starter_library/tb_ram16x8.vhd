-- tb_ram16x8.vhd
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity tb_ram16x8 is
end tb_ram16x8;

architecture sim of tb_ram16x8 is

    signal clk      : std_logic := '0';
    signal we       : std_logic := '0';
    signal addr     : std_logic_vector(3 downto 0) := (others => '0');
    signal data_bus : std_logic_vector(7 downto 0);

    signal tb_data  : std_logic_vector(7 downto 0) := (others => 'Z');
    constant CLK_PERIOD : time := 10 ns;

begin

    clk <= not clk after CLK_PERIOD / 2;
    data_bus <= tb_data when we = '1' else (others => 'Z');

    uut : entity work.ram16x8
        port map (
            clk      => clk,
            we       => we,
            addr     => addr,
            data_bus => data_bus
        );

    stimulus : process
    begin
        ----------------------------------------------------------------
        -- WRITE PHASE
        ----------------------------------------------------------------
        we <= '1';
        addr <= "0000"; tb_data <= x"AA";
        wait until rising_edge(clk);

        addr <= "0001"; tb_data <= x"BB";
        wait until rising_edge(clk);

        addr <= "0101"; tb_data <= x"CC";
        wait until rising_edge(clk);

        addr <= "1111"; tb_data <= x"DD";
        wait until rising_edge(clk);

        ----------------------------------------------------------------
        -- READ ADDRESS 0
        ----------------------------------------------------------------
        we <= '0';
        tb_data <= (others => 'Z');
        
        addr <= "0000";
        wait until rising_edge(clk);
        wait for 1 ns;

        assert data_bus = x"AA"
            report "FAIL: read addr 0 => expected 0xAA" severity error;

        ----------------------------------------------------------------
        -- READ ADDRESS 1
        ----------------------------------------------------------------
        addr <= "0001";
        wait until rising_edge(clk);
        wait for 1 ns;

        assert data_bus = x"BB"
            report "FAIL: read addr 1 => expected 0xBB" severity error;

        ----------------------------------------------------------------
        -- READ ADDRESS 5
        ----------------------------------------------------------------
        addr <= "0101";
        wait until rising_edge(clk);
        wait for 1 ns;

        assert data_bus = x"CC"
            report "FAIL: read addr 5 => expected 0xCC" severity error;

        ----------------------------------------------------------------
        -- READ ADDRESS 15
        ----------------------------------------------------------------
        addr <= "1111";
        wait until rising_edge(clk);
        wait for 1 ns;

        assert data_bus = x"DD"
            report "FAIL: read addr 15 => expected 0xDD" severity error;

        ----------------------------------------------------------------
        -- OVERWRITE ADDRESS 0
        ----------------------------------------------------------------
        we <= '1';
        addr <= "0000";
        tb_data <= x"FF";
        wait until rising_edge(clk);

        we <= '0';
        tb_data <= (others => 'Z');
        addr <= "0000";

        wait until rising_edge(clk);   -- issue read and wait for data
        wait for 1 ns;

        assert data_bus = x"FF"
            report "FAIL: overwrite addr 0 => expected 0xFF" severity error;

        ----------------------------------------------------------------
        -- UNINITIALIZED ADDRESS 7
        ----------------------------------------------------------------
        addr <= "0111";
        wait until rising_edge(clk);
        wait for 1 ns;

        assert data_bus = x"00"
            report "FAIL: uninitialised addr 7 => expected 0x00" severity error;

        report "tb_ram16x8: all tests complete." severity note;
        wait;

    end process stimulus;
end sim;
