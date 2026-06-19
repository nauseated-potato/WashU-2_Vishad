# Week 5 · Module 3 — Implementing the Mini-Datapath in VHDL

This module walks through the complete VHDL implementation of the
mini-datapath. Every section is explained in full. Study each section
against the block diagram from Module 2 before moving to the next.

The implementation is structured as a single top-level file (`mini_cpu.vhd`)
that instantiates sub-components. The sub-components (`alu8.vhd`,
`ram32x8.vhd`) are defined separately and listed in the starter library.

---

## 1. File structure

~~~text
mini_cpu.vhd          ← top-level: datapath + FSM wired together
alu8.vhd              ← 8-bit ALU  (provided in starter_library)
ram32x8.vhd           ← 32×8 RAM   (provided in starter_library)
tb_mini_cpu.vhd       ← testbench  (you write this in Module 5)
~~~

All four files must be added to the same Quartus project. The top-level
entity is `mini_cpu`.

---

## 2. Libraries and entity

~~~vhdl
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity mini_cpu is
    port (
        clk   : in  std_logic;
        reset : in  std_logic;
        done  : out std_logic
    );
end mini_cpu;
~~~

---

## 3. Architecture declarative region

This is the largest declarative region you have written so far. Every
internal signal from the Module 2 signal map gets declared here.

~~~vhdl
architecture rtl of mini_cpu is

    -- ---------------------------------------------------------------
    -- Sub-component instantiation: this design uses DIRECT ENTITY
    -- INSTANTIATION (entity work.X), as recommended in Module 1 §7.
    -- This means NO 'component' declarations are needed here at all —
    -- as long as alu8.vhd and ram32x8.vhd are in the same Quartus
    -- project, 'entity work.alu8' and 'entity work.ram32x8' resolve
    -- automatically. The instantiations themselves appear in §6.
    -- ---------------------------------------------------------------

    -- ---------------------------------------------------------------
    -- FSM state type
    --
    -- Four "working" states are needed, not two, because of the RAM's
    -- one-cycle registered read latency (see Module 2 §5 and §7):
    --   S_FETCH1   : present pc as the RAM address
    --   S_FETCH2   : mem_data_out is now valid -> latch into ir, pc++
    --   S_EXECUTE  : decode ir; present operand address to RAM
    --   S_WRITEBACK: mem_data_out for the operand is now valid ->
    --                update acc (LOAD/ADD) or write memory (STORE)
    -- ---------------------------------------------------------------
    type state_type is (S_FETCH1, S_FETCH2, S_EXECUTE, S_WRITEBACK, S_HALT);
    signal state      : state_type := S_FETCH1;
    signal next_state : state_type;

    -- ---------------------------------------------------------------
    -- Datapath registers
    -- ---------------------------------------------------------------
    signal pc      : unsigned(4 downto 0) := (others => '0'); -- program counter
    signal ir      : std_logic_vector(7 downto 0) := (others => '0'); -- instr reg
    signal acc     : std_logic_vector(7 downto 0) := (others => '0'); -- accumulator

    -- ---------------------------------------------------------------
    -- Datapath wires (combinational)
    -- ---------------------------------------------------------------
    signal ir_opcode   : std_logic_vector(2 downto 0); -- ir[7:5]
    signal ir_operand  : std_logic_vector(4 downto 0); -- ir[4:0]
    signal addr        : std_logic_vector(4 downto 0); -- RAM address
    signal alu_result  : std_logic_vector(7 downto 0);
    signal alu_zero    : std_logic;
    signal mem_data_out: std_logic_vector(7 downto 0);

    -- ---------------------------------------------------------------
    -- Control signals (driven by FSM combinational process)
    -- ---------------------------------------------------------------
    signal alu_op   : std_logic_vector(2 downto 0);
    signal acc_ld   : std_logic;
    signal ir_ld    : std_logic;
    signal mem_we   : std_logic;
    signal pc_inc   : std_logic;
    signal addr_sel : std_logic;
    signal done_int : std_logic;

    -- ---------------------------------------------------------------
    -- Instruction opcode constants
    -- ---------------------------------------------------------------
    constant OP_LOAD  : std_logic_vector(2 downto 0) := "000";
    constant OP_ADD   : std_logic_vector(2 downto 0) := "001";
    constant OP_STORE : std_logic_vector(2 downto 0) := "010";
    constant OP_HALT  : std_logic_vector(2 downto 0) := "011";

    -- ALU operation constants (matching alu8 definition)
    constant ALU_ADD  : std_logic_vector(2 downto 0) := "000";
    constant ALU_PASS : std_logic_vector(2 downto 0) := "111"; -- pass B through

begin
~~~

---

## 4. Instruction decode (combinational)

The instruction register bits are split into opcode and operand immediately —
these are just wire aliases, not registers:

~~~vhdl
    -- ---------------------------------------------------------------
    -- Instruction decode: split IR into fields
    -- These are combinational — they change as soon as IR changes.
    -- ---------------------------------------------------------------
    ir_opcode  <= ir(7 downto 5);
    ir_operand <= ir(4 downto 0);
~~~

---

## 5. Address multiplexer (combinational)

~~~vhdl
    -- ---------------------------------------------------------------
    -- Address mux: FSM selects between PC (fetch) and operand (execute)
    -- ---------------------------------------------------------------
    addr <= std_logic_vector(pc) when addr_sel = '0'
            else ir_operand;
~~~

---

## 6. Component instantiations

~~~vhdl
    -- ---------------------------------------------------------------
    -- RAM instantiation (direct entity instantiation — no component
    -- declaration needed; see note in §3)
    -- data_in is always acc: only STORE writes, and it always writes acc
    -- ---------------------------------------------------------------
    ram_inst : entity work.ram32x8
        port map (
            clk      => clk,
            we       => mem_we,
            addr     => addr,
            data_in  => acc,
            data_out => mem_data_out
        );

    -- ---------------------------------------------------------------
    -- ALU instantiation (direct entity instantiation)
    -- A input is always acc; B input is always mem_data_out
    -- ---------------------------------------------------------------
    alu_inst : entity work.alu8
        port map (
            a      => acc,
            b      => mem_data_out,
            op     => alu_op,
            result => alu_result,
            zero   => alu_zero
        );
~~~

---

## 7. Registered datapath elements (Process 1)

All registers — PC, IR, accumulator — are updated in a single clocked
process. This keeps all state updates synchronous and in one place.

~~~vhdl
    -- ---------------------------------------------------------------
    -- PROCESS 1: Registered datapath elements + FSM state register
    -- Everything that needs a clock edge goes here.
    -- ---------------------------------------------------------------
    registers : process (clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                -- Synchronous reset: return everything to initial state
                state <= S_FETCH1;
                pc    <= (others => '0');
                ir    <= (others => '0');
                acc   <= (others => '0');
            else
                -- FSM state update
                state <= next_state;

                -- Program counter: increment when pc_inc='1' (in S_FETCH2)
                if pc_inc = '1' then
                    pc <= pc + 1;
                end if;

                -- Instruction register: load from memory when ir_ld='1'
                -- (in S_FETCH2 — see Module 2 §5/§8 for why this is the
                -- correct cycle for mem_data_out to be valid)
                if ir_ld = '1' then
                    ir <= mem_data_out;
                end if;

                -- Accumulator: load from ALU result when acc_ld='1'
                -- (in S_WRITEBACK — see Module 2 §7)
                if acc_ld = '1' then
                    acc <= alu_result;
                end if;
            end if;
        end if;
    end process registers;
~~~

---

## 8. Control FSM (Process 2)

The FSM has five states: `S_FETCH1`, `S_FETCH2`, `S_EXECUTE`, `S_WRITEBACK`,
and `S_HALT`. Every non-HALT instruction takes exactly **4 cycles** — this
uniform timing is what Module 2 §7-8 derived from the RAM's read latency.
The combinational process sets all control signals based on the current
state and the decoded opcode. Every control signal must have a default
before the `case` statement.

~~~vhdl
    -- ---------------------------------------------------------------
    -- PROCESS 2: Control FSM — combinational next-state + control signals
    -- ---------------------------------------------------------------
    control : process (state, ir_opcode)
    begin
        -- *** DEFAULTS: all control signals inactive ***
        -- Setting defaults here prevents latches even if a signal
        -- is not explicitly set in every branch.
        next_state <= state;          -- default: stay
        alu_op     <= ALU_PASS;
        acc_ld     <= '0';
        ir_ld      <= '0';
        mem_we     <= '0';
        pc_inc     <= '0';
        addr_sel   <= '0';
        done_int   <= '0';

        case state is

            -- =======================================================
            -- S_FETCH1: present PC as the RAM address.
            -- mem_data_out is NOT valid yet (registered read latency) —
            -- do not latch anything this cycle.
            -- =======================================================
            when S_FETCH1 =>
                addr_sel   <= '0';    -- PC drives RAM address
                next_state <= S_FETCH2;

            -- =======================================================
            -- S_FETCH2: mem_data_out now holds ram_mem(pc) — capture it
            -- into IR. Increment PC at the same time (parallel, both
            -- happen on this cycle's rising edge).
            -- =======================================================
            when S_FETCH2 =>
                addr_sel   <= '0';    -- keep PC on the address bus
                ir_ld      <= '1';    -- capture RAM output into IR — NOW valid
                pc_inc     <= '1';    -- advance PC for the next fetch
                next_state <= S_EXECUTE;

            -- =======================================================
            -- S_EXECUTE: decode IR. Present the operand address to RAM
            -- (for instructions that need one). mem_data_out for the
            -- OPERAND is not valid until next cycle — do not latch yet.
            -- =======================================================
            when S_EXECUTE =>
                addr_sel <= '1';      -- operand address drives RAM
                                       -- (harmless for HALT — ignored)

                case ir_opcode is

                    when OP_LOAD | OP_ADD | OP_STORE =>
                        -- All three need one more cycle for mem_data_out
                        -- (the operand value) to become valid.
                        next_state <= S_WRITEBACK;

                    when OP_HALT =>
                        next_state <= S_HALT;

                    when others =>
                        -- Unknown opcode: treat as NOP, refetch
                        next_state <= S_FETCH1;

                end case;

            -- =======================================================
            -- S_WRITEBACK: mem_data_out now holds ram_mem(operand).
            -- Complete the instruction: update acc, or write memory.
            -- =======================================================
            when S_WRITEBACK =>
                addr_sel <= '1';       -- keep operand address stable

                case ir_opcode is

                    when OP_LOAD =>
                        -- acc ← mem[operand]
                        -- ALU passes mem_data_out through to result
                        alu_op     <= ALU_PASS;
                        acc_ld     <= '1';
                        next_state <= S_FETCH1;

                    when OP_ADD =>
                        -- acc ← acc + mem[operand]
                        alu_op     <= ALU_ADD;
                        acc_ld     <= '1';
                        next_state <= S_FETCH1;

                    when OP_STORE =>
                        -- mem[operand] ← acc
                        -- 'addr' has equalled 'operand' since S_EXECUTE,
                        -- so the write address is stable for this edge.
                        mem_we     <= '1';
                        next_state <= S_FETCH1;

                    when others =>
                        next_state <= S_FETCH1;

                end case;

            -- =======================================================
            -- S_HALT: hold indefinitely, assert done
            -- =======================================================
            when S_HALT =>
                done_int   <= '1';
                next_state <= S_HALT;   -- stay here until reset

            when others =>
                next_state <= S_FETCH1;

        end case;
    end process control;

    -- ---------------------------------------------------------------
    -- Output driver
    -- ---------------------------------------------------------------
    done <= done_int;

end rtl;
~~~

### A note on the `|` (OR) choice operator

The line `when OP_LOAD | OP_ADD | OP_STORE =>` is new syntax: the `|`
symbol inside a `case` choice means "match any of these values". It is
equivalent to writing three separate `when` arms with identical bodies.
Use it whenever multiple choices lead to exactly the same action — it
keeps the code shorter without changing the hardware produced.

---

## 9. The complete file in one block

For reference, here is the complete `mini_cpu.vhd` assembled in order.
When adding to Quartus, make sure `alu8.vhd` and `ram32x8.vhd` are also
in the project before attempting compilation.

The file order for compilation in Quartus (add files in this order, or
set `mini_cpu` as the top-level entity and let Quartus resolve dependencies):

1. `alu8.vhd`
2. `ram32x8.vhd`
3. `mini_cpu.vhd`
4. `tb_mini_cpu.vhd`

~~~vhdl
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity mini_cpu is
    port (
        clk   : in  std_logic;
        reset : in  std_logic;
        done  : out std_logic
    );
end mini_cpu;

architecture rtl of mini_cpu is

    type state_type is (S_FETCH1, S_FETCH2, S_EXECUTE, S_WRITEBACK, S_HALT);
    signal state      : state_type := S_FETCH1;
    signal next_state : state_type;

    signal pc      : unsigned(4 downto 0) := (others => '0'); 
    signal ir      : std_logic_vector(7 downto 0) := (others => '0'); 
    signal acc     : std_logic_vector(7 downto 0) := (others => '0'); 

    signal ir_opcode   : std_logic_vector(2 downto 0); 
    signal ir_operand  : std_logic_vector(4 downto 0); 
    signal addr        : std_logic_vector(4 downto 0); 
    signal alu_result  : std_logic_vector(7 downto 0);
    signal alu_zero    : std_logic;
    signal mem_data_out: std_logic_vector(7 downto 0);

    signal alu_op   : std_logic_vector(2 downto 0);
    signal acc_ld   : std_logic;
    signal ir_ld    : std_logic;
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
            clk      => clk,
            we       => mem_we,
            addr     => addr,
            data_in  => acc,
            data_out => mem_data_out
        );

    alu_inst : entity work.alu8
        port map (
            a      => acc,
            b      => mem_data_out,
            op     => alu_op,
            result => alu_result,
            zero   => alu_zero
        );

    registers : process (clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                state <= S_FETCH1;
                pc    <= (others => '0');
                ir    <= (others => '0');
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
        alu_op     <= ALU_PASS;
        acc_ld     <= '0';
        ir_ld      <= '0';
        mem_we     <= '0';
        pc_inc     <= '0';
        addr_sel   <= '0';
        done_int   <= '0';

        case state is

            when S_FETCH1 =>
                addr_sel   <= '0';    
                next_state <= S_FETCH2;

            when S_FETCH2 =>
                addr_sel   <= '0';    
                ir_ld      <= '1';    
                pc_inc     <= '1';    
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
                        alu_op     <= ALU_PASS;
                        acc_ld     <= '1';
                        next_state <= S_FETCH1;

                    when OP_ADD =>
                        alu_op     <= ALU_ADD;
                        acc_ld     <= '1';
                        next_state <= S_FETCH1;

                    when OP_STORE =>
                        mem_we     <= '1';
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

    done <= done_int;

end rtl;
~~~

---

## 10. Critical implementation notes

### Note 1: Why both registers and combinational logic in one design?

The `registers` process is clocked. The `control` process is combinational.
They work together exactly like the two-process FSM from Week 3 — except
now the "output" is a whole set of control signals rather than a few LEDs.
The pattern is identical; only the scale is larger.

### Note 2: Why are there TWO fetch states (S_FETCH1, S_FETCH2)?

This is the most important design decision in this module — re-read
Module 2 §5 if any of this is unclear.

The RAM's read is **registered**: a value presented on `addr` during cycle
N only appears on `mem_data_out` during cycle N+1. If `ir_ld='1'` were
asserted in the *same* cycle that `addr_sel='0'` first selects `pc`
(i.e., a single combined FETCH state), `ir` would latch `mem_data_out` as
it was *before* `addr=pc` was even presented — the wrong value, one
address behind.

The fix: `S_FETCH1` presents `addr=pc` and does nothing else. By
`S_FETCH2`, `mem_data_out` correctly holds `ram_mem(pc)`, so `ir_ld='1'`
in `S_FETCH2` captures the right instruction. `pc_inc='1'` also happens in
`S_FETCH2` — incrementing `pc` here (rather than in `S_FETCH1`) does not
cause a problem, because `addr` has already been used to start the RAM
read; `pc`'s new value will be needed only at the *next* `S_FETCH1`.

### Note 3: Why does S_EXECUTE not update acc or write memory directly?

The same read-latency rule applies again in `S_EXECUTE`: when `addr_sel`
switches to `'1'` (operand address), `mem_data_out` does not reflect
`ram_mem(operand)` until the *following* cycle. So:
- `S_EXECUTE` can only *present* the operand address (`addr_sel <= '1'`)
  and decide, via `next_state`, which kind of instruction this is.
- `S_WRITEBACK` is where `mem_data_out` finally holds `ram_mem(operand)`,
  and where `acc_ld` / `mem_we` actually fire.

### Note 4: The STORE timing

During `S_WRITEBACK` for a STORE instruction:
- `addr_sel='1'` → RAM address = `ir_operand` (has been stable since
  `S_EXECUTE` — a full cycle — satisfying the RAM's synchronous write
  requirement)
- `mem_we='1'` → RAM write enable
- `data_in = acc` → the value being written (always connected, see §6)

The write happens at the **rising edge** ending `S_WRITEBACK`. The data in
`acc` is stable at that point — `acc` is only updated (via `acc_ld`) during
the `S_WRITEBACK` of LOAD or ADD, never during STORE's own `S_WRITEBACK`.

### Note 5: ALU_PASS for LOAD

The LOAD instruction needs to copy `mem[operand]` directly into `acc`
without any arithmetic. Rather than building a separate bypass path, we use
the ALU in "pass B through" mode: `alu_op = ALU_PASS` makes the ALU output
equal to its B input (`mem_data_out`), which is then written into `acc` via
`acc_ld='1'`. The `alu8` component defines this as opcode `"111"`.

---

Next: **Module 4 — Loading a Program: RAM Initialisation**