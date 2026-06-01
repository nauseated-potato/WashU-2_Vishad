
library ieee;
use ieee.std_logic_1164.all;

package gates is

    component inverter is
        port (
            a : in std_logic;
            y : out std_logic
        );
    end component;

    component and_gate is
        port (
            a : in std_logic;
            b : in std_logic;
            y : out std_logic
        );
    end component;

    component nand_gate is
        port (
            a : in std_logic;
            b : in std_logic;
            y : out std_logic
        );
    end component;

    component or_gate is
        port (
            a : in std_logic;
            b : in std_logic;
            y : out std_logic
        );
    end component;

    component nor_gate is
        port (
            a : in std_logic;
            b : in std_logic;
            y : out std_logic
        );
    end component;

    component xor_gate is
        port (
            a : in std_logic;
            b : in std_logic;
            y : out std_logic
        );
    end component;

    component xnor_gate is
        port (
            a : in std_logic;
            b : in std_logic;
            y : out std_logic
        );
    end component;

    component half_adder is
        port (
            a     : in std_logic;
            b     : in std_logic;
            sum   : out std_logic;
            carry : out std_logic
        );
    end component;

end package gates;

--------------------------------------------------
-- Inverter
--------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity inverter is
    port (
        a : in std_logic;
        y : out std_logic
    );
end entity inverter;

architecture rtl of inverter is
begin

    y <= not a;

end rtl;

--------------------------------------------------
-- AND Gate
--------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity and_gate is
    port (
        a : in std_logic;
        b : in std_logic;
        y : out std_logic
    );
end entity and_gate;

architecture rtl of and_gate is
begin

    y <= a and b;

end rtl;

--------------------------------------------------
-- NAND Gate
--------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity nand_gate is
    port (
        a : in std_logic;
        b : in std_logic;
        y : out std_logic
    );
end entity nand_gate;

architecture rtl of nand_gate is
begin

    y <= not (a and b);

end rtl;

--------------------------------------------------
-- OR Gate
--------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity or_gate is
    port (
        a : in std_logic;
        b : in std_logic;
        y : out std_logic
    );
end entity or_gate;

architecture rtl of or_gate is
begin

    y <= a or b;

end rtl;

--------------------------------------------------
-- NOR Gate
--------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity nor_gate is
    port (
        a : in std_logic;
        b : in std_logic;
        y : out std_logic
    );
end entity nor_gate;

architecture rtl of nor_gate is
begin

    y <= not (a or b);

end rtl;

--------------------------------------------------
-- XOR Gate
--------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity xor_gate is
    port (
        a : in std_logic;
        b : in std_logic;
        y : out std_logic
    );
end entity xor_gate;

architecture rtl of xor_gate is
begin

    y <= a xor b;

end rtl;

--------------------------------------------------
-- XNOR Gate
--------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity xnor_gate is
    port (
        a : in std_logic;
        b : in std_logic;
        y : out std_logic
    );
end entity xnor_gate;

architecture rtl of xnor_gate is
begin

    y <= not (a xor b);

end rtl;

--------------------------------------------------
-- Half Adder
--------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity half_adder is
    port (
        a     : in std_logic;
        b     : in std_logic;
        sum   : out std_logic;
        carry : out std_logic
    );
end entity half_adder;

architecture rtl of half_adder is
begin

    sum   <= a xor b;
    carry <= a and b;

end rtl;

