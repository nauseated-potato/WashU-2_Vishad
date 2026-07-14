# Week 7 · Module 6 — The Control FSM

Process 2 is the combinational FSM. It reads `current_state` and
`ir_opcode`, and sets every control signal for the current cycle. This
process is where the Week 6 control signal table becomes VHDL.

Build it in three stages, compiling and simulating after each:
- **Stage A:** defaults + `resetState` + fetch cycle only
- **Stage B:** add HALT, NEGATE, CLOAD
- **Stage C:** add DLOAD, DSTORE

---

## Stage A — Defaults, resetState, and fetch cycle

### An important timing detail: why `mbr(15 downto 12)` in fetch3

Before reading the code, understand this point — it is easy to get wrong:

In `fetch3`, the FSM asserts `bus_mbr='1'` and `ir_ld='1'`. The intention
is to load IR with the new instruction from MBR. But here is the timing:

- **Combinationally** (during fetch3): Process 2 evaluates `case ... is`
  to set `next_state`. At this point, `ir` still holds the **previous**
  instruction — it has not been updated yet. So `ir_opcode = ir(15 downto 12)`
  is **stale**.
- **At the rising edge** ending fetch3: `ir <= the_bus (= mbr)` — the new
  instruction finally enters `ir`. But `next_state` was already decided
  combinationally using the stale value.

The fix: decode from `mbr(15 downto 12)` in the fetch3 dispatch, not from
`ir_opcode`. MBR was correctly loaded at the end of `fetch2` and holds the
right instruction throughout the entire `fetch3` state.

After `fetch3`, all other states (`direct1`, `direct2`, `load1`, etc.) can
safely use `ir_opcode` because `ir` has been correctly updated.

### The defaults

Every control signal must get a default value before the `case` statement.
Without defaults, any signal not explicitly set in every branch will cause
a latch to be inferred. The correct default for every control signal is
inactive (`'0'`, `'0'`, etc.):

```vhdl
    -- ================================================================
    -- PROCESS 2: Control FSM (combinational)
    -- ================================================================
    fsm_proc : process (current_state, ir_opcode, mbr, zero_flag, pos_flag, neg_flag)
    begin
        -- --------------------------------------------------------
        -- DEFAULTS: every signal inactive
        -- Must appear before the case statement.
        -- --------------------------------------------------------
        next_state    <= current_state;   -- default: stay in current state
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
        alu_op        <= ALU_PASS_B;    -- safe default: no side-effect
        done_int      <= '0';

        -- --------------------------------------------------------
        -- STATE MACHINE
        -- --------------------------------------------------------
        case current_state is

            -- ====================================================
            -- resetState: transition immediately to fetch1
            -- No bus activity, no register updates.
            -- ====================================================
            when resetState =>
                next_state <= fetch1;

            -- ====================================================
            -- FETCH CYCLE (shared by all instructions)
            -- fetch1: MAR ← PC
            -- fetch2: MBR ← mem[MAR],  PC ← PC + 1
            -- fetch3: IR  ← MBR
            -- ====================================================
            when fetch1 =>
                bus_pc     <= '1';    -- PC drives the bus
                mar_ld     <= '1';    -- MAR latches PC
                next_state <= fetch2;

            when fetch2 =>
                bus_mem    <= '1';    -- memory output drives the bus
                mbr_ld     <= '1';    -- MBR latches memory output
                pc_inc     <= '1';    -- PC ← PC + 1 (via incrementer, not bus)
                next_state <= fetch3;

            when fetch3 =>
                -- IR ← MBR: the new instruction latches into IR at the
                -- rising edge that ENDS this state. ir_opcode therefore
                -- still reflects the PREVIOUS instruction during fetch3.
                -- The dispatch must use mbr(15 downto 12) instead, which
                -- holds the correct new instruction throughout fetch3.
                bus_mbr    <= '1';    -- MBR drives the bus (and IR)
                ir_ld      <= '1';    -- IR latches MBR at next rising edge
                -- Decode from MBR (not ir_opcode — see note above)
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
                    when others    => next_state <= halt1;  -- safety
                end case;

            -- ====================================================
            -- All other states: placeholder for Stage B/C/Week 8
            -- ====================================================
            when others =>
                next_state <= fetch1;   -- safe fallback

        end case;
    end process fsm_proc;

    -- Output driver
    done <= done_int;
```

**Compile and simulate the fetch cycle now** (see Module 7 for the testbench
template). Verify that after reset:
- Cycle 1 (resetState): transition to fetch1.
- Cycle 2 (fetch1): MAR gets the PC value; PC=0 so MAR=0x000.
- Cycle 3 (fetch2): MBR gets mem[0x000]; PC increments to 0x001.
- Cycle 4 (fetch3): IR gets MBR (the first instruction); FSM transitions
  based on the opcode.

Do not add Stage B until this works correctly.

---

## Stage B — HALT, NEGATE, CLOAD

Replace the `when others => next_state <= fetch1;` arm with the specific
arms below, and keep `when others` as the final fallback.

### HALT

```vhdl
            -- ====================================================
            -- HALT: assert done, loop forever
            -- ====================================================
            when halt1 =>
                done_int   <= '1';
                next_state <= halt1;    -- stay until reset
```

### NEGATE

`NEGATE` uses two ALU states. `neg1` inverts all bits of ACC (NOT); `neg2`
adds 1 to the inverted value. Both write their result back to ACC via the
bus:

```vhdl
            -- ====================================================
            -- NEGATE: ACC ← NOT(ACC) + 1  (two's complement negation)
            -- neg1: bus_alu drives bus with NOT(ACC); ACC latches it
            -- neg2: bus_alu drives bus with ACC+1;   ACC latches it
            -- ====================================================
            when neg1 =>
                alu_op     <= ALU_NOT;  -- ALU computes NOT(acc)
                bus_alu    <= '1';      -- ALU result drives bus
                acc_ld     <= '1';      -- ACC latches NOT(acc)
                next_state <= neg2;

            when neg2 =>
                alu_op     <= ALU_INC;  -- ALU computes acc + 1
                bus_alu    <= '1';
                acc_ld     <= '1';      -- ACC latches acc+1
                next_state <= fetch1;
```

**Timing note:** in `neg1`, the ALU receives the *current* `acc` value
(before the clock edge) and computes `NOT(acc)`. At the clock edge, `acc`
is updated to `NOT(acc)`. In `neg2`, the ALU receives the *already-inverted*
`acc` (now `NOT(acc)`) and computes `NOT(acc) + 1`. At the clock edge,
`acc` becomes the final negated value. The two-state sequence is necessary
because the ALU cannot do both NOT and +1 in a single combinational path
and then correctly latch back — splitting into two states makes each step
a clean registered update.

### CLOAD

```vhdl
            -- ====================================================
            -- CLOAD K: ACC ← sign_extend(IR[11:0])
            -- bus_ir_se puts the sign-extended constant on the bus
            -- ====================================================
            when cload1 =>
                bus_ir_se  <= '1';    -- IR[11:0] sign-extended drives bus
                acc_ld     <= '1';    -- ACC latches the constant
                next_state <= fetch1;
```

`ir_addr_se` (declared in Module 3) is already the sign-extended version
of `IR[11:0]`. The `bus_ir_se` signal selects it as the bus source
(Module 4 §3), so this single state is sufficient.

---

## Stage C — DLOAD and DSTORE

These instructions use the shared `direct1` and `direct2` states, then
branch to either `load1` or `store1`.

### `direct1` and `direct2` (shared)

```vhdl
            -- ====================================================
            -- direct1: MAR ← IR[11:0]   (load the data address)
            -- Shared by: DLOAD, DSTORE, ADD, AND, ILOAD, ISTORE
            -- ====================================================
            when direct1 =>
                bus_ir_lower <= '1';   -- IR[11:0] zero-extended drives bus
                mar_ld       <= '1';   -- MAR latches the operand address
                next_state   <= direct2;

            -- ====================================================
            -- direct2: MBR ← mem[MAR]   (fetch data from memory)
            -- Shared by same set as direct1.
            -- ====================================================
            when direct2 =>
                bus_mem    <= '1';    -- memory output drives bus
                mbr_ld     <= '1';   -- MBR latches memory data
                -- Branch to the correct execution state
                case ir_opcode is
                    when OP_DLOAD  => next_state <= load1;
                    when OP_DSTORE => next_state <= store1;
                    when OP_ADD    => next_state <= add1;
                    when OP_AND    => next_state <= and1;
                    when OP_ILOAD  => next_state <= indirect1;
                    when OP_ISTORE => next_state <= indirect1;
                    when others    => next_state <= fetch1;   -- safety
                end case;
```

**The decode in `direct2`:** the FSM remembers which instruction it is
executing because `ir_opcode` is a combinational signal always derived
from `ir` — it does not need to be stored separately. By `direct2`,
`ir` holds the correct instruction (loaded in `fetch3`), so `ir_opcode`
still correctly identifies which path to take.

### DLOAD

```vhdl
            -- ====================================================
            -- load1: ACC ← MBR  (MBR holds the loaded value)
            -- Used by DLOAD (and ILOAD in Week 8 via iload1)
            -- ====================================================
            when load1 =>
                bus_mbr    <= '1';     -- MBR drives bus
                acc_ld     <= '1';     -- ACC latches MBR value
                next_state <= fetch1;
```

### DSTORE

```vhdl
            -- ====================================================
            -- store1: mem[MAR] ← ACC
            -- bus_acc drives the bus (and the_bus feeds data_in of RAM)
            -- mbr_ld='1' updates MBR as a side-effect (harmless)
            -- mem_we='1' writes the_bus value to mem[MAR]
            -- ====================================================
            when store1 =>
                bus_acc    <= '1';    -- ACC drives bus (and RAM data_in)
                mbr_ld     <= '1';   -- MBR latches ACC (side-effect)
                mem_we     <= '1';   -- RAM writes the_bus to mem[MAR]
                next_state <= fetch1;
```

Refer to Module 4 §6 for the detailed explanation of why `data_in` is
wired to `the_bus` and why this gives the correct write behaviour in one
clock cycle.

---

## Complete FSM process (all of Week 7)

Assembling the three stages gives the complete process body for Week 7.
The full listing is in `starter_library/washu2_cpu_week7.vhd` for
reference — do not copy it directly; understand each section before
looking at it.

---

## Compile and simulation checkpoint

After Stage C, the CPU should compile without errors or latch warnings.
Check:

1. No "latch inferred" warnings — every control signal gets a default.
2. No "signal has no driver" errors — every signal declared in Module 3
   is assigned somewhere in Process 1 or Process 2.
3. No "case statement incomplete" warnings — `when others` catches any
   undefined opcode or state.

Proceed to Module 7 for testbench construction and simulation.

> **Before simulating:** read Module 9 §1 (datapath diagram) and §2
> (FSM state transition diagram). The diagrams show exactly which signals
> should be active in each state — use them alongside your waveform to
> verify correctness at a glance. The cycle tables in Module 9 §3 let you
> check each instruction's bus activity row-by-row against the waveform.

---

Next: **Module 7 — Testbenches and Simulation**
