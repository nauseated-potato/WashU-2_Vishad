-- washu2_cpu_reference.vhd
--
-- Week 8 -- REFERENCE implementation of the WashU-2 CPU.
-- Supports all 14 instructions: HALT, NEGATE, CLOAD, DLOAD, DSTORE,
-- ADD, AND, BRANCH, BRZERO, BRPOS, BRNEG, BRIND, ILOAD, ISTORE.
--
-- READ THIS ONLY AFTER WRITING YOUR OWN washu2_cpu.vhd.
-- Every design decision is explained in Modules 2-6.
-- If something here differs from your implementation, compare against
-- the module notes to understand which is correct -- both may be valid
-- if the observable behaviour is the same.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity washu2_cpu is
    port (
        clk   : in  std_logic;
        reset : in  std_logic;
        done  : out std_logic
    );
end washu2_cpu;

architecture rtl of washu2_cpu is

    -- ----------------------------------------------------------------
    -- No component declaration needed for washu2_ram.
    -- Direct entity instantiation (entity work.washu2_ram) is used
    -- in the architecture body. washu2_ram.vhd must be in the same
    -- Quartus project.

    -- ----------------------------------------------------------------
    -- FSM state type -- all 22 states
    -- ----------------------------------------------------------------
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
    signal next_state    : state_type;

    -- ----------------------------------------------------------------
    -- Datapath registers (all 16-bit)
    -- ----------------------------------------------------------------
    signal acc : std_logic_vector(15 downto 0) := (others => '0');
    signal pc  : std_logic_vector(15 downto 0) := (others => '0');
    signal mar : std_logic_vector(15 downto 0) := (others => '0');
    signal mbr : std_logic_vector(15 downto 0) := (others => '0');
    signal ir  : std_logic_vector(15 downto 0) := (others => '0');

    -- ----------------------------------------------------------------
    -- Bus and internal wires
    -- ----------------------------------------------------------------
    signal the_bus      : std_logic_vector(15 downto 0);
    signal alu_result   : std_logic_vector(15 downto 0);
    signal mem_data_out : std_logic_vector(15 downto 0);
    signal ram_addr     : std_logic_vector(11 downto 0);
    signal ir_opcode    : std_logic_vector(3 downto 0);
    signal ir_addr      : std_logic_vector(11 downto 0);
    signal ir_addr_se   : std_logic_vector(15 downto 0);

    -- ----------------------------------------------------------------
    -- Bus output enables (exactly one '1' per clock cycle)
    -- ----------------------------------------------------------------
    signal bus_pc       : std_logic;
    signal bus_mbr      : std_logic;
    signal bus_acc      : std_logic;
    signal bus_ir_lower : std_logic;
    signal bus_ir_se    : std_logic;
    signal bus_alu      : std_logic;
    signal bus_mem      : std_logic;

    -- ----------------------------------------------------------------
    -- Register load enables and special controls
    -- ----------------------------------------------------------------
    signal mar_ld   : std_logic;
    signal mbr_ld   : std_logic;
    signal ir_ld    : std_logic;
    signal acc_ld   : std_logic;
    signal pc_ld    : std_logic;
    signal pc_inc   : std_logic;
    signal mem_we   : std_logic;
    signal alu_op   : std_logic_vector(2 downto 0);
    signal done_int : std_logic;

    -- ----------------------------------------------------------------
    -- Condition flags (combinational from acc)
    -- ----------------------------------------------------------------
    signal zero_flag : std_logic;
    signal pos_flag  : std_logic;
    signal neg_flag  : std_logic;

    -- ----------------------------------------------------------------
    -- Opcode constants (IR[15:12])
    -- ----------------------------------------------------------------
    constant OP_HALT   : std_logic_vector(3 downto 0) := "0000";
    constant OP_NEGATE : std_logic_vector(3 downto 0) := "0001";
    constant OP_CLOAD  : std_logic_vector(3 downto 0) := "0010";
    constant OP_DLOAD  : std_logic_vector(3 downto 0) := "0011";
    constant OP_DSTORE : std_logic_vector(3 downto 0) := "0100";
    constant OP_ILOAD  : std_logic_vector(3 downto 0) := "0101";
    constant OP_ISTORE : std_logic_vector(3 downto 0) := "0110";
    constant OP_ADD    : std_logic_vector(3 downto 0) := "0111";
    constant OP_AND    : std_logic_vector(3 downto 0) := "1000";
    constant OP_BRANCH : std_logic_vector(3 downto 0) := "1001";
    constant OP_BRZERO : std_logic_vector(3 downto 0) := "1010";
    constant OP_BRPOS  : std_logic_vector(3 downto 0) := "1011";
    constant OP_BRNEG  : std_logic_vector(3 downto 0) := "1100";
    constant OP_BRIND  : std_logic_vector(3 downto 0) := "1101";

    -- ----------------------------------------------------------------
    -- ALU operation codes
    -- ----------------------------------------------------------------
    constant ALU_ADD    : std_logic_vector(2 downto 0) := "000";
    constant ALU_AND    : std_logic_vector(2 downto 0) := "001";
    constant ALU_NOT    : std_logic_vector(2 downto 0) := "010";
    constant ALU_INC    : std_logic_vector(2 downto 0) := "011";
    constant ALU_PASS_B : std_logic_vector(2 downto 0) := "100";

begin

    -- ================================================================
    -- RAM instantiation
    -- data_in is wired to the_bus so DSTORE/ISTORE write ACC (via
    -- bus_acc) directly to memory without an extra MBR-load cycle.
    -- ================================================================
    -- RAM address mux: while mar_ld is asserted (an address is being
    -- latched into MAR this cycle), present that incoming value to the
    -- RAM immediately via the_bus. Otherwise present the already-latched
    -- mar. This keeps the address stable for the full cycle BEFORE the
    -- register that captures it (mar) even updates, which is what lets
    -- the RAM's one-cycle registered read land correctly in the very
    -- next state. See errata note in Module 7.
    ram_addr <= the_bus(11 downto 0) when mar_ld = '1' else mar(11 downto 0);

    ram_inst : entity work.washu2_ram
        port map (
            clk      => clk,
            we       => mem_we,
            addr     => ram_addr,
            data_in  => the_bus,
            data_out => mem_data_out
        );

    -- ================================================================
    -- IR field extraction (pure wires -- combinational)
    -- ================================================================
    ir_opcode <= ir(15 downto 12);
    ir_addr   <= ir(11 downto 0);

    -- Sign-extend IR[11:0] to 16 bits for CLOAD
    ir_addr_se <= (15 downto 12 => ir(11)) & ir(11 downto 0);

    -- ================================================================
    -- Bus multiplexer
    -- Exactly one bus_X signal is '1' per clock cycle.
    -- ================================================================
    with std_logic_vector'(bus_pc       &
                           bus_mbr      &
                           bus_acc      &
                           bus_ir_lower &
                           bus_ir_se    &
                           bus_alu      &
                           bus_mem) select
        the_bus <=
            pc                              when "1000000",
            mbr                             when "0100000",
            acc                             when "0010000",
            (15 downto 12 => '0') & ir_addr when "0001000",
            ir_addr_se                      when "0000100",
            alu_result                      when "0000010",
            mem_data_out                    when "0000001",
            (others => '0')                 when others;

    -- ================================================================
    -- ALU (combinational)
    -- A = acc, B = mbr.
    -- Week 8 change: B comes from mbr, not the_bus (Module 2 Section 1).
    -- Using the_bus as B would create a combinational loop for ADD/AND,
    -- since those states drive the_bus FROM the ALU result itself.
    -- ================================================================
    alu_proc : process (acc, mbr, alu_op)
    begin
        case alu_op is
            when ALU_ADD =>
                alu_result <= std_logic_vector(unsigned(acc) + unsigned(mbr));
            when ALU_AND =>
                alu_result <= acc and mbr;
            when ALU_NOT =>
                alu_result <= not acc;
            when ALU_INC =>
                alu_result <= std_logic_vector(unsigned(acc) + to_unsigned(1, 16));
            when ALU_PASS_B =>
                alu_result <= mbr;
            when others =>
                alu_result <= (others => '0');
        end case;
    end process alu_proc;

    -- ================================================================
    -- Condition flags (combinational from acc)
    -- ================================================================
    zero_flag <= '1' when acc = x"0000"                     else '0';
    pos_flag  <= '1' when acc(15) = '0' and acc /= x"0000"  else '0';
    neg_flag  <= acc(15);

    -- ================================================================
    -- PROCESS 1: Registered elements
    -- All register updates and FSM state transition on rising edge.
    -- ================================================================
    reg_proc : process (clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                current_state <= resetState;
                acc <= (others => '0');
                pc  <= (others => '0');
                mar <= (others => '0');
                mbr <= (others => '0');
                ir  <= (others => '0');
            else
                current_state <= next_state;

                if mar_ld = '1' then
                    mar <= the_bus;
                end if;

                if mbr_ld = '1' then
                    mbr <= the_bus;
                end if;

                if ir_ld = '1' then
                    ir <= the_bus;
                end if;

                if acc_ld = '1' then
                    acc <= the_bus;
                end if;

                -- PC: bus load takes priority over increment
                if pc_ld = '1' then
                    pc <= the_bus;
                elsif pc_inc = '1' then
                    pc <= std_logic_vector(unsigned(pc) + 1);
                end if;
            end if;
        end if;
    end process reg_proc;

    -- ================================================================
    -- PROCESS 2: Control FSM (combinational)
    -- Sets all control signals based on current_state and ir_opcode.
    -- ================================================================
    fsm_proc : process (current_state, ir_opcode, mbr, zero_flag, pos_flag, neg_flag)
    begin
        -- ------------------------------------------------------------
        -- DEFAULTS: all control signals inactive.
        -- ------------------------------------------------------------
        next_state    <= current_state;
        bus_pc        <= '0';
        bus_mbr       <= '0';
        bus_acc       <= '0';
        bus_ir_lower  <= '0';
        bus_ir_se     <= '0';
        bus_alu       <= '0';
        bus_mem       <= '0';
        mar_ld        <= '0';
        mbr_ld        <= '0';
        ir_ld         <= '0';
        acc_ld        <= '0';
        pc_ld         <= '0';
        pc_inc        <= '0';
        mem_we        <= '0';
        alu_op        <= ALU_PASS_B;
        done_int      <= '0';

        case current_state is

            -- --------------------------------------------------------
            -- resetState: jump to fetch1, nothing else
            -- --------------------------------------------------------
            when resetState =>
                next_state <= fetch1;

            -- --------------------------------------------------------
            -- FETCH CYCLE (shared by all instructions)
            -- --------------------------------------------------------
            when fetch1 =>
                -- MAR <- PC
                bus_pc     <= '1';
                mar_ld     <= '1';
                next_state <= fetch2;

            when fetch2 =>
                -- MBR <- mem[MAR],  PC <- PC + 1
                bus_mem    <= '1';
                mbr_ld     <= '1';
                pc_inc     <= '1';
                next_state <= fetch3;

            when fetch3 =>
                -- IR <- MBR (see Week 7 Module 6 Stage A for why this
                -- dispatch must decode from mbr, not ir_opcode)
                bus_mbr    <= '1';
                ir_ld      <= '1';
                case mbr(15 downto 12) is
                    when OP_HALT   => next_state <= halt1;
                    when OP_NEGATE => next_state <= neg1;
                    when OP_CLOAD  => next_state <= cload1;
                    when OP_DLOAD  => next_state <= direct1;
                    when OP_DSTORE => next_state <= direct1;
                    when OP_ILOAD  => next_state <= direct1;
                    when OP_ISTORE => next_state <= direct1;
                    when OP_ADD    => next_state <= direct1;
                    when OP_AND    => next_state <= direct1;
                    when OP_BRANCH => next_state <= branch1;
                    when OP_BRZERO => next_state <= branch1;
                    when OP_BRPOS  => next_state <= branch1;
                    when OP_BRNEG  => next_state <= branch1;
                    when OP_BRIND  => next_state <= brind1;
                    when others    => next_state <= halt1;
                end case;

            -- --------------------------------------------------------
            -- HALT
            -- --------------------------------------------------------
            when halt1 =>
                done_int   <= '1';
                next_state <= halt1;

            -- --------------------------------------------------------
            -- NEGATE: ACC <- NOT(ACC) + 1
            -- --------------------------------------------------------
            when neg1 =>
                alu_op     <= ALU_NOT;
                bus_alu    <= '1';
                acc_ld     <= '1';
                next_state <= neg2;

            when neg2 =>
                alu_op     <= ALU_INC;
                bus_alu    <= '1';
                acc_ld     <= '1';
                next_state <= fetch1;

            -- --------------------------------------------------------
            -- CLOAD K: ACC <- sign_extend(IR[11:0])
            -- --------------------------------------------------------
            when cload1 =>
                bus_ir_se  <= '1';
                acc_ld     <= '1';
                next_state <= fetch1;

            -- --------------------------------------------------------
            -- DIRECT MEMORY ACCESS (shared: DLOAD, DSTORE, ADD, AND,
            --                               ILOAD, ISTORE)
            -- --------------------------------------------------------
            when direct1 =>
                -- MAR <- IR[11:0]  (operand address)
                bus_ir_lower <= '1';
                mar_ld       <= '1';
                next_state   <= direct2;

            when direct2 =>
                -- MBR <- mem[MAR]
                bus_mem    <= '1';
                mbr_ld     <= '1';
                case ir_opcode is
                    when OP_DLOAD  => next_state <= load1;
                    when OP_DSTORE => next_state <= store1;
                    when OP_ADD    => next_state <= add1;
                    when OP_AND    => next_state <= and1;
                    when OP_ILOAD  => next_state <= indirect1;
                    when OP_ISTORE => next_state <= indirect1;
                    when others    => next_state <= fetch1;
                end case;

            -- --------------------------------------------------------
            -- DLOAD final: ACC <- MBR
            -- --------------------------------------------------------
            when load1 =>
                bus_mbr    <= '1';
                acc_ld     <= '1';
                next_state <= fetch1;

            -- --------------------------------------------------------
            -- DSTORE final: mem[MAR] <- ACC
            -- --------------------------------------------------------
            when store1 =>
                bus_acc    <= '1';
                mbr_ld     <= '1';
                mem_we     <= '1';
                next_state <= fetch1;

            -- --------------------------------------------------------
            -- add1: ACC <- ACC + MBR
            -- --------------------------------------------------------
            when add1 =>
                alu_op     <= ALU_ADD;
                bus_alu    <= '1';
                acc_ld     <= '1';
                next_state <= fetch1;

            -- --------------------------------------------------------
            -- and1: ACC <- ACC AND MBR
            -- --------------------------------------------------------
            when and1 =>
                alu_op     <= ALU_AND;
                bus_alu    <= '1';
                acc_ld     <= '1';
                next_state <= fetch1;

            -- --------------------------------------------------------
            -- branch1: PC <- IR[11:0], conditionally
            -- Shared by BRANCH, BRZERO, BRPOS, BRNEG.
            -- --------------------------------------------------------
            when branch1 =>
                bus_ir_lower <= '1';
                case ir_opcode is
                    when OP_BRANCH => pc_ld <= '1';
                    when OP_BRZERO => pc_ld <= zero_flag;
                    when OP_BRPOS  => pc_ld <= pos_flag;
                    when OP_BRNEG  => pc_ld <= neg_flag;
                    when others    => pc_ld <= '0';
                end case;
                next_state <= fetch1;

            -- --------------------------------------------------------
            -- brind1: MAR <- IR[11:0]
            -- --------------------------------------------------------
            when brind1 =>
                bus_ir_lower <= '1';
                mar_ld       <= '1';
                next_state   <= brind2;

            -- --------------------------------------------------------
            -- brind2: MBR <- mem[MAR]
            -- --------------------------------------------------------
            when brind2 =>
                bus_mem    <= '1';
                mbr_ld     <= '1';
                next_state <= brind3;

            -- --------------------------------------------------------
            -- brind3: PC <- MBR
            -- --------------------------------------------------------
            when brind3 =>
                bus_mbr    <= '1';
                pc_ld      <= '1';
                next_state <= fetch1;

            -- --------------------------------------------------------
            -- indirect1: MAR <- MBR
            -- Shared by ILOAD and ISTORE.
            -- --------------------------------------------------------
            when indirect1 =>
                bus_mbr    <= '1';
                mar_ld     <= '1';
                next_state <= indirect2;

            -- --------------------------------------------------------
            -- indirect2: MBR <- mem[MAR]
            -- --------------------------------------------------------
            when indirect2 =>
                bus_mem    <= '1';
                mbr_ld     <= '1';
                case ir_opcode is
                    when OP_ILOAD  => next_state <= iload1;
                    when OP_ISTORE => next_state <= istore1;
                    when others    => next_state <= fetch1;
                end case;

            -- --------------------------------------------------------
            -- iload1: ACC <- MBR
            -- --------------------------------------------------------
            when iload1 =>
                bus_mbr    <= '1';
                acc_ld     <= '1';
                next_state <= fetch1;

            -- --------------------------------------------------------
            -- istore1: mem[MAR] <- ACC
            -- --------------------------------------------------------
            when istore1 =>
                bus_acc    <= '1';
                mbr_ld     <= '1';
                mem_we     <= '1';
                next_state <= fetch1;

            when others =>
                next_state <= fetch1;

        end case;
    end process fsm_proc;

    -- ================================================================
    -- Output driver
    -- ================================================================
    done <= done_int;

end rtl;
