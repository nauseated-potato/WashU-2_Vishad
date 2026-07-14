-- washu2_cpu_reference.vhd
--
-- Week 7 — REFERENCE implementation of the WashU-2 CPU.
-- Supports: HALT, NEGATE, CLOAD, DLOAD, DSTORE.
-- Week 8 adds: ADD, AND, BRANCH, BRZERO, BRPOS, BRNEG, BRIND, ILOAD, ISTORE.
--
-- READ THIS ONLY AFTER WRITING YOUR OWN washu2_cpu.vhd.
-- Every design decision is explained in Modules 2-6.
-- If something here differs from your implementation, compare against
-- the module notes to understand which is correct — both may be valid
-- if the behaviour is the same.

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
    -- FSM state type — all states declared now, even those used in Week 8
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
    -- data_in is wired to the_bus so DSTORE writes ACC (via bus_acc)
    -- directly to memory without an extra MBR-load cycle.
    -- ================================================================
    ram_inst : entity work.washu2_ram
        port map (
            clk      => clk,
            we       => mem_we,
            addr     => mar(11 downto 0),
            data_in  => the_bus,
            data_out => mem_data_out
        );

    -- ================================================================
    -- IR field extraction (pure wires — combinational)
    -- ================================================================
    ir_opcode <= ir(15 downto 12);
    ir_addr   <= ir(11 downto 0);

    -- Sign-extend IR[11:0] to 16 bits for CLOAD
    -- Rule: copy IR[11] into bits 15:12
    ir_addr_se <= (15 downto 12 => ir(11)) & ir(11 downto 0);

    -- ================================================================
    -- Bus multiplexer
    -- Exactly one bus_X signal is '1' per clock cycle.
    -- The when-others arm prevents the_bus going 'U' during reset.
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
    -- A = acc, B = the_bus
    -- ================================================================
    alu_proc : process (acc, the_bus, alu_op)
    begin
        case alu_op is
            when ALU_ADD =>
                alu_result <= std_logic_vector(unsigned(acc) + unsigned(the_bus));
            when ALU_AND =>
                alu_result <= acc and the_bus;
            when ALU_NOT =>
                alu_result <= not acc;
            when ALU_INC =>
                alu_result <= std_logic_vector(unsigned(acc) + to_unsigned(1, 16));
            when ALU_PASS_B =>
                alu_result <= the_bus;
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
        -- Without these, any signal not set in every branch
        -- causes a latch to be inferred.
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
                -- MAR ← PC
                bus_pc     <= '1';
                mar_ld     <= '1';
                next_state <= fetch2;

            when fetch2 =>
                -- MBR ← mem[MAR],  PC ← PC + 1
                bus_mem    <= '1';
                mbr_ld     <= '1';
                pc_inc     <= '1';
                next_state <= fetch3;

            when fetch3 =>
                -- IR ← MBR  (the new instruction latches into IR at the
                -- rising edge that ENDS this state — so ir_opcode still
                -- reflects the PREVIOUS instruction during this state).
                -- The dispatch must therefore decode from mbr(15 downto 12),
                -- which holds the correct new instruction throughout fetch3
                -- because it was updated at the end of fetch2.
                bus_mbr    <= '1';
                ir_ld      <= '1';
                case mbr(15 downto 12) is   -- decode MBR, not ir_opcode
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
            -- NEGATE: ACC ← NOT(ACC) + 1
            -- --------------------------------------------------------
            when neg1 =>
                -- ACC ← NOT(ACC)
                alu_op     <= ALU_NOT;
                bus_alu    <= '1';
                acc_ld     <= '1';
                next_state <= neg2;

            when neg2 =>
                -- ACC ← ACC + 1  (ACC is now NOT(original))
                alu_op     <= ALU_INC;
                bus_alu    <= '1';
                acc_ld     <= '1';
                next_state <= fetch1;

            -- --------------------------------------------------------
            -- CLOAD K: ACC ← sign_extend(IR[11:0])
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
                -- MAR ← IR[11:0]  (operand address)
                bus_ir_lower <= '1';
                mar_ld       <= '1';
                next_state   <= direct2;

            when direct2 =>
                -- MBR ← mem[MAR]
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
            -- DLOAD final: ACC ← MBR
            -- --------------------------------------------------------
            when load1 =>
                bus_mbr    <= '1';
                acc_ld     <= '1';
                next_state <= fetch1;

            -- --------------------------------------------------------
            -- DSTORE final: mem[MAR] ← ACC
            -- bus_acc puts ACC on the_bus; data_in=the_bus so RAM sees ACC
            -- --------------------------------------------------------
            when store1 =>
                bus_acc    <= '1';
                mbr_ld     <= '1';
                mem_we     <= '1';
                next_state <= fetch1;

            -- --------------------------------------------------------
            -- ADD, AND, indirect states, brind — placeholders for Week 8
            -- Currently fall through to fetch1 safely.
            -- --------------------------------------------------------
            when add1 | and1 | indirect1 | indirect2 |
                 iload1 | istore1 | branch1 |
                 brind1 | brind2 | brind3 =>
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
