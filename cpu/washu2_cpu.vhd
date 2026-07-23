library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity washu2_cpu is
	port (
		clk	: in  std_logic;
		reset : in  std_logic;
		done  : out std_logic
	);
end washu2_cpu;

architecture rtl of washu2_cpu is
	type state_type is (
		resetState,
		fetch1, fetch2, fetch3,
		halt1,
		neg1, neg2,
		cload1,
		direct1, direct2,
		load1, add1, and1, store1,
		branch1,
		indirect1, indirect2,
		iload1, istore1,
		brind1, brind2, brind3
	);

	signal current_state : state_type := resetState;
	signal next_state	 : state_type;

	signal acc : std_logic_vector(15 downto 0) := (others => '0');
	signal pc  : std_logic_vector(15 downto 0) := (others => '0');
	signal mar : std_logic_vector(15 downto 0) := (others => '0');
	signal mbr : std_logic_vector(15 downto 0) := (others => '0');
	signal ir  : std_logic_vector(15 downto 0) := (others => '0');

	signal the_bus : std_logic_vector(15 downto 0);

	signal alu_result   : std_logic_vector(15 downto 0);
	signal mem_data_out : std_logic_vector(15 downto 0);
	signal ram_addr		: std_logic_vector(11 downto 0);
	signal ir_opcode	: std_logic_vector(3 downto 0);  -- IR[15:12]

	signal ir_addr	  : std_logic_vector(11 downto 0); -- IR[11:0]
	signal ir_addr_se   : std_logic_vector(15 downto 0); -- IR[11:0] sign-extended

	signal bus_pc	   : std_logic;  -- PC drives bus
	signal bus_mbr	  : std_logic;  -- MBR drives bus
	signal bus_acc	  : std_logic;  -- ACC drives bus
	signal bus_ir_lower : std_logic;  -- IR[11:0] zero-extended drives bus
	signal bus_ir_se	: std_logic;  -- IR[11:0] sign-extended drives bus
	signal bus_alu	  : std_logic;  -- ALU result drives bus
	signal bus_mem	  : std_logic;  -- memory output drives bus
	signal bus_sel : std_logic_vector(6 downto 0);

	signal mar_ld : std_logic;
	signal mbr_ld : std_logic;
	signal ir_ld  : std_logic;
	signal acc_ld : std_logic;
	signal pc_ld  : std_logic;

	signal pc_inc   : std_logic;
	signal mem_we   : std_logic;
	signal alu_op   : std_logic_vector(2 downto 0);
	signal done_int : std_logic;

	signal zero_flag : std_logic;
	signal pos_flag  : std_logic;
	signal neg_flag  : std_logic;

	constant OP_HALT   : std_logic_vector(3 downto 0) := "0000";
	constant OP_NEGATE : std_logic_vector(3 downto 0) := "0001";
	constant OP_CLOAD  : std_logic_vector(3 downto 0) := "0010";
	constant OP_DLOAD  : std_logic_vector(3 downto 0) := "0011";
	constant OP_DSTORE : std_logic_vector(3 downto 0) := "0100";
	constant OP_ILOAD  : std_logic_vector(3 downto 0) := "0101";
	constant OP_ISTORE : std_logic_vector(3 downto 0) := "0110";
	constant OP_ADD	: std_logic_vector(3 downto 0) := "0111";
	constant OP_AND	: std_logic_vector(3 downto 0) := "1000";
	constant OP_BRANCH : std_logic_vector(3 downto 0) := "1001";
	constant OP_BRZERO : std_logic_vector(3 downto 0) := "1010";
	constant OP_BRPOS  : std_logic_vector(3 downto 0) := "1011";
	constant OP_BRNEG  : std_logic_vector(3 downto 0) := "1100";
	constant OP_BRIND  : std_logic_vector(3 downto 0) := "1101";

	constant ALU_ADD	: std_logic_vector(2 downto 0) := "000";
	constant ALU_AND	: std_logic_vector(2 downto 0) := "001";
	constant ALU_NOT	: std_logic_vector(2 downto 0) := "010";
	constant ALU_INC	: std_logic_vector(2 downto 0) := "011";
	constant ALU_PASS_B : std_logic_vector(2 downto 0) := "100";

begin
    ram_addr <= the_bus(11 downto 0) when mar_ld = '1' else mar(11 downto 0);
	ram_inst : entity work.washu2_ram
		port map (
			clk	  => clk,
			we	   => mem_we,
			addr	 => ram_addr,
			data_in  => the_bus,
			data_out => mem_data_out
		);

	ir_opcode <= ir(15 downto 12);
	ir_addr   <= ir(11 downto 0);

	ir_addr_se <= (15 downto 12 => ir(11)) & ir(11 downto 0);

	bus_sel <= std_logic_vector'(bus_pc	   &
						   bus_mbr	  &
						   bus_acc	  &
						   bus_ir_lower &
						   bus_ir_se	&
						   bus_alu	  &
						   bus_mem);
	with bus_sel select
		the_bus <=
			pc								when "1000000",
			mbr								when "0100000",
			acc								when "0010000",
			(15 downto 12 => '0') & ir_addr	when "0001000",
			ir_addr_se						when "0000100",
			alu_result						when "0000010",
			mem_data_out					when "0000001",
			(others => '0')					when others;

	alu_proc : process (acc, mbr, alu_op)
	begin
		case alu_op is
			when ALU_ADD =>
				alu_result <= std_logic_vector(
					unsigned(acc) + unsigned(mbr));

			when ALU_AND =>
				alu_result <= acc and mbr;

			when ALU_NOT =>
				alu_result <= not acc;

			when ALU_INC =>
				alu_result <= std_logic_vector(
					unsigned(acc) + to_unsigned(1, 16));

			when ALU_PASS_B =>
				alu_result <= mbr;

			when others =>
				alu_result <= (others => '0');
		end case;
	end process alu_proc;

	zero_flag <= '1' when acc = x"0000" else '0';
	pos_flag  <= '1' when acc(15) = '0' and acc /= x"0000" else '0';
	neg_flag  <= acc(15);

		-- ================================================================
	-- PROCESS 1: Registered elements
	-- Updates all registers and FSM state on rising clock edge.
	-- ================================================================
	reg_proc : process (clk)
	begin
		if rising_edge(clk) then
			if reset = '1' then
				-- Synchronous reset: return everything to initial state
				current_state <= resetState;
				acc <= (others => '0');
				pc  <= (others => '0');
				mar <= (others => '0');
				mbr <= (others => '0');
				ir  <= (others => '0');
			else
				-- 1. FSM state update
				current_state <= next_state;

				-- 2. MAR: latches from bus when mar_ld='1'
				if mar_ld = '1' then
					mar <= the_bus;
				end if;

				-- 3. MBR: latches from bus when mbr_ld='1'
				if mbr_ld = '1' then
					mbr <= the_bus;
				end if;

				-- 4. IR: latches from bus when ir_ld='1'
				if ir_ld = '1' then
					ir <= the_bus;
				end if;

				-- 5. ACC: latches from bus when acc_ld='1'
				if acc_ld = '1' then
					acc <= the_bus;
				end if;

				-- 6. PC: two sources — bus (for branches) or incrementer
				if pc_ld = '1' then
					pc <= the_bus;
				elsif pc_inc = '1' then
					pc <= std_logic_vector(unsigned(pc) + 1);
				end if;
			end if;
		end if;
	end process reg_proc;

	fsm_proc : process (current_state, ir_opcode, mbr, zero_flag, pos_flag, neg_flag)
	begin

		next_state	<= current_state;
		bus_pc		<= '0';
		bus_mbr	   <= '0';
		bus_acc	   <= '0';
		bus_ir_lower  <= '0';
		bus_ir_se	 <= '0';
		bus_alu	   <= '0';
		bus_mem	   <= '0';
		mar_ld		<= '0';
		mbr_ld		<= '0';
		ir_ld		 <= '0';
		acc_ld		<= '0';
		pc_ld		 <= '0';
		pc_inc		<= '0';
		mem_we		<= '0';
		alu_op		<= ALU_PASS_B;
		done_int	  <= '0';

		case current_state is
			when resetState =>
				next_state <= fetch1;

				when fetch1 =>
				bus_pc	 <= '1';	-- PC drives the bus
				mar_ld	 <= '1';	-- MAR latches PC
				next_state <= fetch2;

			when fetch2 =>
				bus_mem	<= '1';	-- memory output drives the bus
				mbr_ld	 <= '1';	-- MBR latches memory output
				pc_inc	 <= '1';	-- PC ← PC + 1 (via incrementer, not bus)
				next_state <= fetch3;

			when fetch3 =>
				bus_mbr	<= '1';	-- MBR drives the bus (and IR)
				ir_ld	  <= '1';	-- IR latches MBR at next rising edge
				-- Decode from MBR (not ir_opcode — see note above)
				case mbr(15 downto 12) is
					when OP_HALT   => next_state <= halt1;
					when OP_NEGATE => next_state <= neg1;
					when OP_CLOAD  => next_state <= cload1;
					when OP_DLOAD  => next_state <= direct1;
					when OP_DSTORE => next_state <= direct1;
					when OP_ILOAD  => next_state <= direct1;
					when OP_ISTORE => next_state <= direct1;
					when OP_ADD	=> next_state <= direct1;
					when OP_AND	=> next_state <= direct1;
					when OP_BRANCH => next_state <= branch1;
					when OP_BRZERO => next_state <= branch1;
					when OP_BRPOS  => next_state <= branch1;
					when OP_BRNEG  => next_state <= branch1;
					when OP_BRIND  => next_state <= brind1;
					when others	=> next_state <= halt1;
				end case;

			when halt1 =>
				done_int   <= '1';
				next_state <= current_state;

			when neg1 =>
				alu_op	 <= ALU_NOT;
				bus_alu	<= '1';
				acc_ld	 <= '1';
				next_state <= neg2;

			when neg2 =>
				alu_op	 <= ALU_INC;
				bus_alu	<= '1';
				acc_ld	 <= '1';
				next_state <= fetch1;

			when cload1 =>
				bus_ir_se  <= '1';
				acc_ld	 <= '1';
				next_state <= fetch1;

			when direct1 =>
				bus_ir_lower <= '1';
				mar_ld	   <= '1';
				next_state   <= direct2;

			when direct2 =>
				bus_mem	<= '1';
				mbr_ld	 <= '1';

				case ir_opcode is
					when OP_DLOAD  => next_state <= load1;
					when OP_DSTORE => next_state <= store1;
					when OP_ADD	=> next_state <= add1;
					when OP_AND	=> next_state <= and1;
					when OP_ILOAD  => next_state <= indirect1;
					when OP_ISTORE => next_state <= indirect1;
					when others	=> next_state <= fetch1;
				end case;

			when load1 =>
				bus_mbr	<= '1';
				acc_ld	 <= '1';
				next_state <= fetch1;

			when store1 =>
				bus_acc	<= '1';
				mbr_ld	 <= '1';
				mem_we	 <= '1';
				next_state <= fetch1;

			when add1 =>
				alu_op	 <= ALU_ADD;
				bus_alu	<= '1';
				acc_ld	 <= '1';
				next_state <= fetch1;

			when and1 =>
				alu_op	 <= ALU_AND;
				bus_alu	<= '1';
				acc_ld	 <= '1';
				next_state <= fetch1;

			when branch1 =>
				bus_ir_lower <= '1';	-- target address onto bus
				case ir_opcode is
					when OP_BRANCH => pc_ld <= '1';		  -- unconditional
					when OP_BRZERO => pc_ld <= zero_flag;
					when OP_BRPOS  => pc_ld <= pos_flag;
					when OP_BRNEG  => pc_ld <= neg_flag;
					when others	=> pc_ld <= '0';		  -- safety
				end case;
				next_state <= fetch1;

			when brind1 =>
				bus_ir_lower <= '1';
				mar_ld	   <= '1';
				next_state   <= brind2;

			when brind2 =>
				bus_mem	<= '1';
				mbr_ld	 <= '1';
				next_state <= brind3;

			when brind3 =>
				bus_mbr	<= '1';
				pc_ld	  <= '1';
				next_state <= fetch1;

			when indirect1 =>
				bus_mbr	<= '1';
				mar_ld	 <= '1';
				next_state <= indirect2;

			when indirect2 =>
				bus_mem	<= '1';
				mbr_ld	 <= '1';
				case ir_opcode is
					when OP_ILOAD  => next_state <= iload1;
					when OP_ISTORE => next_state <= istore1;
					when others	=> next_state <= fetch1;   -- safety
				end case;

			when iload1 =>
				bus_mbr	<= '1';
				acc_ld	 <= '1';
				next_state <= fetch1;

			when istore1 =>
				bus_acc	<= '1';
				mbr_ld	 <= '1';
				mem_we	 <= '1';
				next_state <= fetch1;

			-- One may merge istore1 wit store1 and iload1 with load1, but I'll follow instructions

			when others =>
				next_state <= fetch1;

		end case;
	end process fsm_proc;

	done <= done_int;

end rtl;
