-- tb_vending_machine.vhd
--
-- Week 3 — PROVIDED testbench for the vending_machine exercise (Exercise 1).
--
-- Covers four transaction paths:
--   (1) Three 5p coins   -> dispense, no change   (0 -> 5 -> 10 -> 15)
--   (2) One 10p + one 5p  -> dispense, no change   (0 -> 10 -> 15)
--   (3) Two 10p coins     -> dispense + change     (0 -> 10 -> 20)
--   (4) Reset mid-transaction -> credit clears, no dispense
--
-- Your vending_machine entity must use exactly these port names for the
-- instantiation below to compile.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity tb_vending_machine is
end tb_vending_machine;

architecture sim of tb_vending_machine is

    signal clk      : std_logic := '0';
    signal reset    : std_logic := '1';
    signal coin5    : std_logic := '0';
    signal coin10   : std_logic := '0';
    signal dispense : std_logic;
    signal change   : std_logic;

    constant CLK_PERIOD : time := 10 ns;

    -- Pulse one coin line high for exactly one clock cycle, edge-aligned.
    -- The same helper works for either coin: pass coin5 or coin10.
    procedure insert_coin (
        signal coin    : out std_logic;
        signal clk_sig : in  std_logic
    ) is
    begin
        wait until rising_edge(clk_sig);
        coin <= '1';
        wait until rising_edge(clk_sig);
        coin <= '0';
    end procedure;

begin

    -- Clock generator
    clk <= not clk after CLK_PERIOD / 2;

    -- Device under test
    uut : entity work.vending_machine
        port map (
            clk      => clk,
            reset    => reset,
            coin5    => coin5,
            coin10   => coin10,
            dispense => dispense,
            change   => change
        );

    stimulus : process
    begin

        -- ----------------------------------------------------------------
        -- Phase 0: reset
        -- ----------------------------------------------------------------
        reset <= '1';
        wait for 3 * CLK_PERIOD;
        reset <= '0';
        wait until rising_edge(clk);

        -- ----------------------------------------------------------------
        -- Phase 1: three 5p coins -> dispense (no change)
        -- Each insert_coin pulses for one cycle; one idle cycle between
        -- coins keeps the inputs cleanly separated and edge-aligned.
        -- ----------------------------------------------------------------
        insert_coin(coin5, clk);
        wait until rising_edge(clk);          -- idle cycle (no coin)
        insert_coin(coin5, clk);
        wait until rising_edge(clk);
        insert_coin(coin5, clk);
        wait for 3 * CLK_PERIOD;              -- observe dispense pulse

        -- ----------------------------------------------------------------
        -- Phase 2: reset, then 10p + 5p -> dispense (no change)
        -- ----------------------------------------------------------------
        reset <= '1';
        wait for 2 * CLK_PERIOD;
        reset <= '0';
        wait until rising_edge(clk);

        insert_coin(coin10, clk);
        wait until rising_edge(clk);
        insert_coin(coin5, clk);
        wait for 3 * CLK_PERIOD;

        -- ----------------------------------------------------------------
        -- Phase 3: reset, then 10p + 10p -> dispense + change
        -- ----------------------------------------------------------------
        reset <= '1';
        wait for 2 * CLK_PERIOD;
        reset <= '0';
        wait until rising_edge(clk);

        insert_coin(coin10, clk);
        wait until rising_edge(clk);
        insert_coin(coin10, clk);
        wait for 3 * CLK_PERIOD;

        -- ----------------------------------------------------------------
        -- Phase 4: reset mid-transaction -> no dispense
        -- Insert one 5p, then reset before the transaction completes.
        -- dispense must NOT fire afterwards.
        -- ----------------------------------------------------------------
        reset <= '1';
        wait for 2 * CLK_PERIOD;
        reset <= '0';
        wait until rising_edge(clk);

        insert_coin(coin5, clk);
        wait until rising_edge(clk);
        reset <= '1';                         -- interrupt before completion
        wait for 2 * CLK_PERIOD;
        reset <= '0';
        wait for 5 * CLK_PERIOD;              -- no more coins; no dispense

        wait;  -- end simulation
    end process stimulus;

end sim;
