library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity mini_cpu is
	port (
		clk   : in  std_logic;
		reset : in  std_logic;
		done  : out std_logic;
		dbg_acc:   out std_logic_vector(7 downto 0);
		dbg_pc:    out std_logic_vector(4 downto 0);
		dbg_ir:    out std_logic_vector(7 downto 0);
		dbg_state: out std_logic_vector(2 downto 0)
	);
end mini_cpu;

architecture rtl of mini_cpu is

	type state_type is (S_FETCH1, S_FETCH2, S_EXECUTE, S_WRITEBACK, S_HALT);
	signal state	  : state_type := S_FETCH1;
	signal next_state : state_type;

	signal pc	  : unsigned(4 downto 0) := (others => '0'); 
	signal ir	  : std_logic_vector(7 downto 0) := (others => '0'); 
	signal acc	 : std_logic_vector(7 downto 0) := (others => '0'); 

	signal ir_opcode   : std_logic_vector(2 downto 0); 
	signal ir_operand  : std_logic_vector(4 downto 0); 
	signal addr		: std_logic_vector(4 downto 0); 
	signal alu_result  : std_logic_vector(7 downto 0);
	signal alu_zero	: std_logic;
	signal mem_data_out: std_logic_vector(7 downto 0);

	signal alu_op   : std_logic_vector(2 downto 0);
	signal acc_ld   : std_logic;
	signal ir_ld	: std_logic;
	signal mem_we   : std_logic;
	signal pc_inc   : std_logic;
	signal addr_sel : std_logic;
	signal done_int : std_logic;

	constant OP_LOAD  : std_logic_vector(2 downto 0) := "000";
	constant OP_ADD   : std_logic_vector(2 downto 0) := "001";
	constant OP_STORE : std_logic_vector(2 downto 0) := "010";
	constant OP_HALT  : std_logic_vector(2 downto 0) := "011";

	constant ALU_ADD  : std_logic_vector(2 downto 0) := "000";
	constant ALU_PASS : std_logic_vector(2 downto 0) := "111"; 

begin

	ir_opcode  <= ir(7 downto 5);
	ir_operand <= ir(4 downto 0);

	addr <= std_logic_vector(pc) when addr_sel = '0'
			else ir_operand;

	ram_inst : entity work.ram32x8
		port map (
			clk	  => clk,
			we	   => mem_we,
			addr	 => addr,
			data_in  => acc,
			data_out => mem_data_out
		);

	alu_inst : entity work.alu8
		port map (
			a	  => acc,
			b	  => mem_data_out,
			op	 => alu_op,
			result => alu_result,
			zero   => alu_zero
		);

	registers : process (clk)
	begin
		if rising_edge(clk) then
			if reset = '1' then
				state <= S_FETCH1;
				pc	<= (others => '0');
				ir	<= (others => '0');
				acc   <= (others => '0');
			else
				state <= next_state;

				if pc_inc = '1' then
					pc <= pc + 1;
				end if;

				if ir_ld = '1' then
					ir <= mem_data_out;
				end if;

				if acc_ld = '1' then
					acc <= alu_result;
				end if;
			end if;
		end if;
	end process registers;

	control : process (state, ir_opcode)
	begin
		next_state <= state;		  
		alu_op	 <= ALU_PASS;
		acc_ld	 <= '0';
		ir_ld	  <= '0';
		mem_we	 <= '0';
		pc_inc	 <= '0';
		addr_sel   <= '0';
		done_int   <= '0';

		case state is

			when S_FETCH1 =>
				addr_sel   <= '0';	
				next_state <= S_FETCH2;

			when S_FETCH2 =>
				addr_sel   <= '0';	
				ir_ld	  <= '1';	
				pc_inc	 <= '1';	
				next_state <= S_EXECUTE;

			when S_EXECUTE =>
				addr_sel <= '1';	  

				case ir_opcode is
					when OP_LOAD | OP_ADD | OP_STORE =>
						next_state <= S_WRITEBACK;
					when OP_HALT =>
						next_state <= S_HALT;
					when others =>
						next_state <= S_FETCH1;
				end case;

			when S_WRITEBACK =>
				addr_sel <= '1';	   

				case ir_opcode is
					when OP_LOAD =>
						alu_op	 <= ALU_PASS;
						acc_ld	 <= '1';
						next_state <= S_FETCH1;

					when OP_ADD =>
						alu_op	 <= ALU_ADD;
						acc_ld	 <= '1';
						next_state <= S_FETCH1;

					when OP_STORE =>
						mem_we	 <= '1';
						next_state <= S_FETCH1;

					when others =>
						next_state <= S_FETCH1;
				end case;

			when S_HALT =>
				done_int   <= '1';
				next_state <= S_HALT;   

			when others =>
				next_state <= S_FETCH1;

		end case;
	end process control;

	dbg_acc   <= acc;
	dbg_pc    <= std_logic_vector(pc);
	dbg_ir    <= ir;
	dbg_state <= "000" when state = S_FETCH1
	        else "001" when state = S_FETCH2
	        else "010" when state = S_EXECUTE
	        else "011" when state = S_WRITEBACK
	        else "100"; -- S_HALT

	done <= done_int;

end rtl;
