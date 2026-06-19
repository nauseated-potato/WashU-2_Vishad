# Week 5 · Module 7 — Debugging Datapaths & Quick Reference

Debugging a complete datapath is harder than debugging a single component,
because a bug in any one piece — the FSM, the ALU, the RAM, the registers,
or the wiring between them — produces a wrong final answer with no immediate
indication of *where* the problem is. This module gives you a systematic
strategy, catalogues the most common bugs, and provides a reference card
for every new VHDL construct introduced this week.

---

## 1. The layered debugging strategy

Never debug a datapath by staring at the final output and guessing. Work
from the inside out, one layer at a time.

```
Layer 1 — Verify sub-components in isolation
  Before simulating mini_cpu, verify:
  - alu8.vhd gives correct results for ADD and PASS operations.
  - ram32x8.vhd reads back values that were written.
  If either is broken, fix it before proceeding.

Layer 2 — Verify FSM control signals
  Add the control signals as debug ports temporarily:
    dbg_alu_op, dbg_acc_ld, dbg_mem_we, dbg_pc_inc, dbg_addr_sel
  Simulate and check, for each clock cycle, that the FSM asserts exactly
  the signals from Module 2's control signal table. If any signal is
  wrong in any cycle, the bug is in the control process.

Layer 3 — Verify datapath registers
  With correct control signals confirmed, check:
  - PC increments on the right cycles.
  - IR captures the right instruction at the right cycle.
  - acc updates with the right value at the right cycle.
  Compare cycle-by-cycle against your hand-written execution trace.

Layer 4 — Verify final result
  Only after layers 1–3 are confirmed, check the final acc value and
  memory contents. If these are wrong but layers 1–3 were correct, the
  bug is in the program encoding (wrong instruction binary) or the
  memory initialiser.
```

---

## 2. The ten most common datapath bugs

### Bug 1 — IR loads stale data (using a single FETCH state)

**Symptom:** every instruction executes the *wrong* operation — often the
instruction one address behind what was expected.

**Cause:** `ir_ld='1'` is asserted in `S_FETCH1` (the same cycle that
`addr=pc` is first presented). Because the RAM read is registered,
`mem_data_out` during `S_FETCH1` still reflects the *previous* address —
so IR latches the wrong instruction. This is the core design error that
the 4-state FSM (Module 2 §5) was designed to prevent.

**Fix:** `ir_ld` must be `'0'` in `S_FETCH1` and `'1'` in `S_FETCH2`:

```vhdl
when S_FETCH1 =>
    addr_sel   <= '0';
    ir_ld      <= '0';    -- ← '0' here; mem_data_out is not yet valid
    next_state <= S_FETCH2;

when S_FETCH2 =>
    addr_sel   <= '0';
    ir_ld      <= '1';    -- ← '1' here; mem_data_out is NOW valid
    pc_inc     <= '1';
    next_state <= S_EXECUTE;
```

---

### Bug 2 — PC increments in S_FETCH1 instead of S_FETCH2

**Symptom:** every instruction appears to execute from PC+1, skipping the
first instruction entirely.

**Cause:** `pc_inc <= '1'` is set in `S_FETCH1`. This advances PC before
`addr=pc` has been held long enough for the RAM to respond, so the fetch
targets the *already-incremented* PC, not the current one.

**Fix:** `pc_inc` must only be `'1'` in `S_FETCH2` (after the RAM has
already captured `addr=pc` on the `S_FETCH1` edge):

```vhdl
when S_FETCH2 =>
    pc_inc <= '1';    -- ← correct: advance AFTER the instruction is captured
```

---

### Bug 3 — `acc_ld` or `mem_we` asserted in S_EXECUTE instead of S_WRITEBACK

**Symptom:** acc loads the wrong value (stale from the instruction fetch,
not from the operand), or STORE writes to the wrong address.

**Cause:** `acc_ld='1'` or `mem_we='1'` in `S_EXECUTE` — but
`mem_data_out` during `S_EXECUTE` still reflects `ram_mem(pc)` (the
instruction word), not `ram_mem(operand)`. The RAM only captures
`addr=operand` at the *end* of `S_EXECUTE`; the result is valid one cycle
later, in `S_WRITEBACK`.

**Fix:**

```vhdl
-- WRONG: acc_ld in S_EXECUTE reads stale mem_data_out
when S_EXECUTE =>
    addr_sel <= '1';
    acc_ld   <= '1';   -- ← BUG: mem_data_out is NOT valid here

-- CORRECT: acc_ld in S_WRITEBACK reads valid operand data
when S_EXECUTE =>
    addr_sel   <= '1';
    next_state <= S_WRITEBACK;   -- go wait for mem_data_out to settle

when S_WRITEBACK =>
    addr_sel <= '1';
    acc_ld   <= '1';   -- ← mem_data_out is NOW valid
```

---

### Bug 4 — STORE writes acc to the wrong address

**Symptom:** `mem_we='1'` fires but the value lands at address 0 instead
of `ir_operand`.

**Cause:** `mem_we='1'` is asserted while `addr_sel='0'` (PC drives the
address), so the write goes to the PC address, not the operand address.

**Fix:** `mem_we` must only fire in `S_WRITEBACK` where `addr_sel='1'`
has been stable since `S_EXECUTE` — giving the RAM a full cycle with the
correct address before the write:

```vhdl
when S_WRITEBACK =>
    addr_sel <= '1';   -- operand address; stable since S_EXECUTE edge
    mem_we   <= '1';   -- ← write NOW, address has been valid for 1 cycle
```

---

### Bug 5 — HALT opcode not matched / CPU loops forever

**Symptom:** after the HALT instruction is fetched, the CPU returns to
`S_FETCH1` and fetches the next memory location (`"00000000"` = LOAD 0x00).
`done` is never asserted.

**Cause:** the `when OP_HALT` arm in the `S_EXECUTE` case is missing, or
`OP_HALT` has the wrong constant value.

**Fix:** verify `OP_HALT = "011"` and that the HALT bytes in the RAM
initialiser use opcode bits `011` in the correct bit positions:

```vhdl
-- HALT = 0x60 = 01100000
-- bits[7:5] = 011 = OP_HALT ✓
3 => "01100000",   -- correct
3 => "11000000",   -- WRONG: bits shifted
```

In `S_EXECUTE`, the HALT arm must NOT go to `S_WRITEBACK` (there is no
operand to fetch):

```vhdl
when S_EXECUTE =>
    case ir_opcode is
        when OP_LOAD | OP_ADD | OP_STORE => next_state <= S_WRITEBACK;
        when OP_HALT                      => next_state <= S_HALT;   -- ← skip WRITEBACK
        when others                       => next_state <= S_FETCH1;
    end case;
```

---

### Bug 6 — ALU_PASS not implemented in `alu8`

**Symptom:** LOAD puts a wrong value into acc — often `0x00` or the sum
of acc and mem_data_out.

**Cause:** `alu8.vhd` does not handle op `"111"` (ALU_PASS), which the
LOAD implementation relies on to pass `mem_data_out` straight to the
output.

**Fix:** check `alu8.vhd`:
```vhdl
when "111" => result_int <= b;   -- pass B (= mem_data_out) through unchanged
```

---

### Bug 7 — `addr_sel` not held `'1'` through S_WRITEBACK

**Symptom:** LOAD or ADD loads the value at address 0 (the instruction)
rather than the operand address, even though `S_EXECUTE` looks correct.

**Cause:** `addr_sel` defaults back to `'0'` in `S_WRITEBACK` (no
explicit assignment), so `addr=pc` again — and the RAM re-captures
`ram_mem(pc)` rather than `ram_mem(operand)`.

**Fix:** explicitly set `addr_sel <= '1'` in the `S_WRITEBACK` arm:

```vhdl
when S_WRITEBACK =>
    addr_sel <= '1';   -- ← must be explicit; default is '0'
    -- then case on ir_opcode for acc_ld / mem_we
```

---

### Bug 8 — Wrong instruction encoding in the RAM initialiser

**Symptom:** the CPU reaches an unexpected state, executes an unrecognised
opcode, or stores a result at the wrong address.

**Cause:** a bit error in the RAM initialiser.

**Fix:** decode every byte back to its mnemonic using the Module 4 §1
encoding table and verify each one matches the intended instruction:

```vhdl
-- Decode check for: 1 => "00110001"
-- bits[7:5] = 001 → ADD
-- bits[4:0] = 10001 → addr 17 = 0x11
-- Instruction: ADD 0x11  ✓

-- Decode check for: 2 => "01010010"
-- bits[7:5] = 010 → STORE
-- bits[4:0] = 10010 → addr 18 = 0x12
-- Instruction: STORE 0x12  ✓
```

---

### Bug 9 — Latch inferred for a control signal

**Symptom:** Quartus warning: *"Latch inferred for signal ..."*

**Cause:** a control signal (`acc_ld`, `mem_we`, `ir_ld`, etc.) is not
assigned in every branch of the FSM `case` statement, and no default is
set before the `case`.

**Fix:** add defaults for every control signal before the `case` (as shown
in Module 3 §8):

```vhdl
-- Defaults — prevent latches
acc_ld <= '0'; ir_ld <= '0'; mem_we <= '0';
pc_inc <= '0'; addr_sel <= '0'; done_int <= '0';
alu_op <= ALU_PASS;
case state is ...
```

---

### Bug 10 — Reset returns to S_FETCH1 but PC not cleared

**Symptom:** after reset, the CPU starts executing from a non-zero address.

**Cause:** the `registers` process resets `state` but not `pc`.

**Fix:**
```vhdl
if reset = '1' then
    state <= S_FETCH1;         -- ← correct initial state
    pc    <= (others => '0');  -- ← MUST clear PC
    ir    <= (others => '0');
    acc   <= (others => '0');
end if;
```

---

## 3. Systematic signal tracing: the waveform checklist

When your simulation produces a wrong result, work through this checklist
in order. Stop at the first discrepancy — that is where the bug is.

For each instruction, the four-cycle pattern is:

```
Cycle N+0 (S_FETCH1):
  □ addr = pc   (addr_sel='0')
  □ ir_ld = '0', pc_inc = '0'   ← nothing latches yet
  □ mem_we = '0', acc_ld = '0'

Cycle N+1 (S_FETCH2):
  □ mem_data_out = ram_mem(pc)   ← NOW valid
  □ ir_ld = '1'                  ← IR captures the instruction
  □ pc_inc = '1'                 ← PC advances to pc+1
  □ addr_sel = '0', mem_we = '0', acc_ld = '0'

Cycle N+2 (S_EXECUTE):
  □ IR holds the correct instruction — verify binary against RAM initialiser
  □ addr = ir_operand   (addr_sel='1')   ← operand address presented
  □ ir_ld = '0', pc_inc = '0'
  □ acc_ld = '0', mem_we = '0'   ← nothing latches; RAM is capturing operand

Cycle N+3 (S_WRITEBACK):
  □ mem_data_out = ram_mem(ir_operand)   ← operand value NOW valid
  □ addr_sel = '1'   (must stay '1' — see Bug 7)
  □ acc_ld = '1' for LOAD and ADD; '0' for STORE
  □ mem_we = '1' for STORE only
  □ ALU op: PASS for LOAD, ADD for ADD, don't-care for STORE

  After this cycle:
  □ acc holds the new value (for LOAD/ADD)
  □ ram_mem(ir_operand) holds acc value (for STORE)
  □ state → S_FETCH1

--- then the same four-cycle pattern repeats for the next instruction ---

HALT (3 cycles):
  □ S_FETCH1, S_FETCH2 as normal
  □ S_EXECUTE: opcode=HALT → next_state = S_HALT (no S_WRITEBACK)
  □ S_HALT: done='1', pc_inc='0', no writes, loops here
```

---

## 4. New VHDL constructs this week — quick reference

### Structural design: direct entity instantiation

This course uses **direct entity instantiation** — no `component`
declaration needed. As long as all `.vhd` files are added to the same
Quartus project, `entity work.X` resolves automatically.

```vhdl
-- Direct entity instantiation (recommended — used in mini_cpu.vhd):
inst_name : entity work.my_component
    port map (
        clk     => clk,
        data_in => my_signal,
        result  => my_result
    );
```

### Conditional signal assignment (concurrent)

```vhdl
-- Two-way mux
addr <= std_logic_vector(pc) when addr_sel = '0' else ir_operand;

-- Three-way mux
output <= val_a when sel = "00"
     else val_b when sel = "01"
     else val_c;
```

### Unsigned increment

```vhdl
signal pc : unsigned(4 downto 0);
pc <= pc + 1;          -- increment
pc <= (others => '0'); -- reset to zero
```

### `wait until` with timeout (in testbenches)

```vhdl
-- Wait up to 20 clock periods for 'done' to go high:
wait until done = '1' for 20 * CLK_PERIOD;

-- If done is still '0' after timeout, continue (check with assert):
assert done = '1' report "Timeout: done never asserted" severity error;
```

---

## 5. Recommended resources

**Datapath and control unit concepts:**
- [Simple CPU Design — Datapath and Control (YouTube, 2023)](https://www.youtube.com/watch?v=yl8vPW5hydQ)
  *The exact architecture of this week's mini-datapath, explained visually*

**VHDL structural design (component instantiation):**
- [VHDL Structural Design — VHDLwhiz](https://vhdlwhiz.com/structural-vhdl/)
  *Written tutorial on component declarations, port maps, and the `work` library*

**Ben Eater's 8-bit CPU series (YouTube):**
- [Building an 8-bit CPU — Ben Eater playlist](https://www.youtube.com/playlist?list=PLowKtXNTBypGqImE405J2565dvjafglHU)
  *The same concepts as this week, built on breadboards. Watching episodes
  1–5 will solidify your understanding of fetch-execute-decode deeply.*

**Understanding the accumulator architecture:**
- [Accumulator-based CPU — Wikipedia](https://en.wikipedia.org/wiki/Accumulator_(computing))
  *Short conceptual article placing this week's work in historical context*

---

*Week 5 complete. You have built a working stored-program computer in VHDL —
a circuit that fetches instructions, decodes them, executes them on an
accumulator through an ALU, and stores results to memory. The WashU-2 CPU
in Weeks 7 and 8 extends exactly this architecture with more instructions,
a larger address space, and a full 17-state FSM. Every concept from this
week — the signal map, the control table, the fetch-execute cycle, the
timing relationship between FETCH and EXECUTE — appears again, unchanged
in principle, at that larger scale.*
