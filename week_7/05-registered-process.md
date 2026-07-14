# Week 7 · Module 5 — The Registered Process

Process 1 is the clocked process. Its only job is to update registers and
the FSM state on each rising clock edge. It does not decide *what* to do —
that is Process 2's job. It simply executes whatever the control signals say.

This separation is the same two-process pattern from Week 3 (FSMs) and
Week 5 (mini-CPU), now applied at larger scale.

---

## 1. Structure

```vhdl
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
```

---

## 2. Every register receives from `the_bus`

Notice that every register — MAR, MBR, IR, ACC, and PC (via `pc_ld`) —
latches from `the_bus`, not from individual sources. This is the bus
architecture working: the FSM selects a source by asserting one `bus_X`
signal, which drives `the_bus` combinationally (Module 4 §3), and then
asserts the corresponding `_ld` signal to latch it.

For example, in `fetch1`:
- FSM sets `bus_pc='1'` → `the_bus = pc` (combinational, Module 4 §3)
- FSM sets `mar_ld='1'`
- At the rising edge: `mar <= the_bus` = `mar <= pc` ✓

You never write `mar <= pc` directly in the process. You write
`mar <= the_bus` and let the bus selection handle which value arrives.

---

## 3. The PC increment

PC is the only register with two possible sources: the bus (for branch
instructions in Week 8) and the dedicated incrementer. The `if/elsif`
structure ensures they cannot both fire simultaneously:

```vhdl
if pc_ld = '1' then
    pc <= the_bus;        -- branch: load new address from bus
elsif pc_inc = '1' then
    pc <= std_logic_vector(unsigned(pc) + 1);  -- normal: increment
end if;
```

`pc_ld` takes priority over `pc_inc`. In practice, the FSM never asserts
both simultaneously — `pc_inc` is asserted in `fetch2` for all
instructions, and `pc_ld` is asserted in `branch1` only for branch
instructions (Week 8). The priority is a safety measure, not a daily
occurrence.

The increment uses `unsigned(pc) + 1` because `std_logic_vector` does not
support `+` directly — the same cast pattern used in every week since Week 4.

---

## 4. Why `mbr` receives from `the_bus` even in `fetch2`?

In `fetch2`, the control table shows `bus_mem='1'` and `mbr_ld='1'`.
This means:
- `the_bus = mem_data_out` (memory output drives the bus)
- `mbr <= the_bus` (MBR latches from the bus)

So `mbr <= mem_data_out` effectively — but expressed through the bus, not
as a direct wire. This is consistent with the bus architecture: every
transfer goes via `the_bus`, even transfers from memory.

---

## 5. Reset

The reset is **synchronous** (inside `if rising_edge(clk)`). This matches
the Week 5 mini-CPU and is the safer option for FPGA synthesis — an
asynchronous reset (in the sensitivity list) is harder to constrain in
Quartus's timing analyser.

All registers reset to `(others => '0')` = `0x0000`. The FSM resets to
`resetState`. The `resetState` → `fetch1` transition is handled in the
FSM combinational process (Process 2, Module 6): `resetState` simply sets
`next_state <= fetch1` with no other activity.

---

## 6. Compile checkpoint

After adding Process 1, compile. You should now have:
- No errors.
- Warnings about signals driven by Process 1 but not yet read (e.g.,
  `current_state`, `acc`, `pc`). These disappear when Process 2 is added.

Do not proceed until the compile is clean of errors.

---

Next: **Module 6 — The Control FSM**
