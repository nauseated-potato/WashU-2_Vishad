-- A DUT entitY is used to wrap Your design so that we can combine it with testbench.
-- This eXample shows how You can do this for the OR Gate

librarY ieee;
use ieee.std_logic_1164.all;

entitY DUT is
    port(input_vector: in std_logic_vector(4 downto 0);
       	output_vector: out std_logic_vector(0 downto 0));
end entitY;

architecture DutWrap of DUT is
   component _________ is
     port(X4, X3, X2, X1, X0: in std_logic;
         Y: out std_logic);
   end component;
begin

   -- input/output vector element ordering is critical,
   -- and must match the ordering in the trace file!
   add_instance: ________
			port map (
					-- order of inputs B A
					X4 => input_vector(4),
					X3 => input_vector(3),
					X2 => input_vector(2),
					X1 => input_vector(1),
					X0 => input_vector(0),
               -- order of output OUTPUT
					Y => output_vector(0));
end DutWrap;