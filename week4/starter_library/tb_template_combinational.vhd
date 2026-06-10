-- tb_template_combinational.vhd
--
-- Week 4 STARTER TEMPLATE for testbenches of purely combinational circuits
-- (ALUs, multiplexers, decoders, encoders — anything without a clock).
--
-- Copy this file, rename it (e.g. tb_alu4_extended.vhd), and fill in the
-- TODO sections.
--
-- Key difference from the FSM/clocked template:
--   No clock generator. Inputs change via 'wait for PROP_DELAY'.
--   Outputs are checked immediately after the propagation delay.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_template_combinational is
    -- Testbenches have NO ports.
end tb_template_combinational;

architecture sim of tb_template_combinational is

    -- ----------------------------------------------------------------
    -- 1. Signal declarations
    -- Declare one signal per port of your design.
    -- Give input signals initial values (default: all zeros or '0').
    -- ----------------------------------------------------------------

    -- TODO: add signals for all ports of your design. Example:
    -- signal a      : std_logic_vector(3 downto 0) := (others => '0');
    -- signal b      : std_logic_vector(3 downto 0) := (others => '0');
    -- signal op     : std_logic_vector(2 downto 0) := (others => '0');
    -- signal result : std_logic_vector(3 downto 0);
    -- signal zero   : std_logic;

    -- Propagation delay: how long to wait after changing inputs before
    -- reading outputs. 10 ns is typical for combinational logic at
    -- 100 MHz — adjust if your design uses a different clock period.
    constant PROP_DELAY : time := 10 ns;

begin

    -- ----------------------------------------------------------------
    -- 2. DUT instantiation
    -- Replace entity name and port map with your actual design.
    -- ----------------------------------------------------------------
    -- uut : entity work.YOUR_ENTITY_NAME
    --     port map (
    --         -- TODO: connect all ports
    --         -- a      => a,
    --         -- b      => b,
    --         -- op     => op,
    --         -- result => result,
    --         -- zero   => zero
    --     );

    -- ----------------------------------------------------------------
    -- 3. Stimulus process
    -- For each test case:
    --   a) Set input signals.
    --   b) wait for PROP_DELAY (let outputs settle).
    --   c) Check outputs with assert.
    -- ----------------------------------------------------------------
    stimulus : process
    begin

        -- TODO: replace the examples below with your actual test cases.

        -- Example test structure:
        -- op <= "000"; a <= "0011"; b <= "0101"; wait for PROP_DELAY;
        -- assert result = "1000"
        --     report "FAIL: operation X with inputs Y => expected Z"
        --     severity error;

        -- Tip: organise tests by operation, with a comment header for each.
        -- Test at least:
        --   - Normal operation (typical inputs, expected output)
        --   - Edge cases (maximum values, zeros, all-ones)
        --   - Zero-flag cases (if applicable)
        --   - Any overflow or carry conditions

        wait for PROP_DELAY; -- placeholder — delete when you add real tests

        -- Always end with a completion note.
        report "Testbench complete." severity note;
        wait; -- stops the stimulus process; simulation ends here

    end process stimulus;

end sim;
