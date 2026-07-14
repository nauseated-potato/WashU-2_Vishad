# Week 7 · Module 7 — Testbenches and Simulation

Testing the WashU-2 CPU follows the same pattern as the Week 5 mini-CPU
testbench, with three differences: the data width is 16 bits, the
instruction encoding is different, and you need to verify more signals
in the waveform.

---

## 1. What to test this week

Week 7 builds and tests five instructions. The default RAM initialiser in
`washu2_ram.vhd` already contains the **self-test program** from Module 9
§4 (CLOAD 5 → NEGATE → DSTORE → CLOAD 0 → DLOAD → HALT). Run this first
after completing Stage C of the FSM. It exercises all five instructions
in sequence and produces a known result (`acc = 0xFFFB`).

For incremental testing while building each stage, use the simpler programs:

| Test program | Instructions verified | When to use |
|---|---|---|
| Program A | Fetch + HALT | After Stage A (fetch cycle) |
| Program B | HALT, NEGATE | After Stage B |
| Program C | HALT, CLOAD | After Stage B |
| Program D | HALT, CLOAD, DSTORE, DLOAD | After Stage C |
| Self-test (Module 9 §4) | All five instructions | After all stages complete |

Start with Program A. Move to the next only after the previous works.
The cycle-by-cycle bus tables in **Module 9 §3** give the exact expected
state of every signal for each instruction — use those to verify your
waveform directly.

---

## 2. Encoding instructions for the test programs

Use the Week 6 ISA table. Each instruction is 16 bits:
`IR[15:12]` = opcode, `IR[11:0]` = operand/address.

**Program A — HALT only:**
```
mem[0x000] = 0x0000   -- HALT (opcode 0000, addr 000)
```

**Program B — NEGATE then HALT:**
```
mem[0x000] = 0x1000   -- NEGATE (opcode 0001, no addr)
mem[0x001] = 0x0000   -- HALT
```

**Program C — CLOAD 42 then HALT:**
```
mem[0x000] = 0x202A   -- CLOAD 42 (opcode 0010, K=0x02A=42)
mem[0x001] = 0x0000   -- HALT
```

**Program D — Load a value, store it, reload it:**
```
mem[0x000] = 0x202A   -- CLOAD 42 (ACC ← 42)
mem[0x001] = 0x4010   -- DSTORE 0x010 (mem[0x010] ← ACC)
mem[0x002] = 0x302A   -- wait -- need to load a different value first
                      -- actually: CLOAD 0 to clear ACC
mem[0x002] = 0x2000   -- CLOAD 0 (ACC ← 0, clears accumulator)
mem[0x003] = 0x3010   -- DLOAD 0x010 (ACC ← mem[0x010] = 42)
mem[0x004] = 0x0000   -- HALT
```

After HALT in Program D, `acc` should be `0x002A` (42). `mem[0x010]`
should be `0x002A`. Verify both in the waveform.

---

## 3. Encoding verification

Before simulating, decode every byte in your program by hand and check
it against the intended instruction. For Program D:

| Address | Hex | Binary | Opcode | Addr/K | Instruction |
|---|---|---|---|---|---|
| 0x000 | `0x202A` | `0010 000000101010` | `0010` = CLOAD | `0x02A` = 42 | CLOAD 42 ✓ |
| 0x001 | `0x4010` | `0100 000000010000` | `0100` = DSTORE | `0x010` | DSTORE 0x010 ✓ |
| 0x002 | `0x2000` | `0010 000000000000` | `0010` = CLOAD | `0x000` = 0 | CLOAD 0 ✓ |
| 0x003 | `0x3010` | `0011 000000010000` | `0011` = DLOAD | `0x010` | DLOAD 0x010 ✓ |
| 0x004 | `0x0000` | `0000 000000000000` | `0000` = HALT | — | HALT ✓ |

Do this check for every program before running the simulation.

---

## 4. Testbench structure

The testbench is nearly identical to the Week 5 `tb_template_datapath.vhd`,
with two adjustments: the port map has no debug ports (the WashU-2 CPU
entity only exposes `clk`, `reset`, and `done`) and you observe internal
signals through ModelSim's object panel instead.

```vhdl
-- tb_washu2_week7.vhd
-- Testbench for washu2_cpu, Week 7 (HALT, NEGATE, CLOAD, DLOAD, DSTORE)

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity tb_washu2_week7 is
end tb_washu2_week7;

architecture sim of tb_washu2_week7 is

    signal clk   : std_logic := '0';
    signal reset : std_logic := '1';
    signal done  : std_logic;

    constant CLK_PERIOD : time := 10 ns;

begin

    clk <= not clk after CLK_PERIOD / 2;

    uut : entity work.washu2_cpu
        port map (
            clk   => clk,
            reset => reset,
            done  => done
        );

    stimulus : process
    begin
        -- Apply reset for 3 cycles
        reset <= '1';
        wait for 3 * CLK_PERIOD;
        reset <= '0';

        -- Wait for HALT with a generous timeout
        -- Program D: 4 instructions × 4-8 cycles each + margin = ~50 cycles
        wait until done = '1' for 60 * CLK_PERIOD;

        assert done = '1'
            report "FAIL: done never asserted — CPU did not reach HALT"
            severity error;

        -- Let final state settle, then verify done holds
        wait for 5 * CLK_PERIOD;
        assert done = '1'
            report "FAIL: CPU left HALT state"
            severity error;

        -- Test reset recovery
        reset <= '1';
        wait for 2 * CLK_PERIOD;
        reset <= '0';
        wait for CLK_PERIOD;

        assert done = '0'
            report "FAIL: done should be 0 after reset"
            severity error;

        wait for 5 * CLK_PERIOD;
        report "Testbench complete." severity note;
        wait;
    end process stimulus;

end sim;
```

---

## 5. Adding internal signals to the waveform

Because `washu2_cpu` has no debug output ports, you cannot see `acc`, `pc`,
or `current_state` from the testbench directly. Instead, you add them to
ModelSim's waveform window through the hierarchy browser. Here are the
exact steps:

**Step 1 — Compile and start simulation**

In Quartus: `Tools → Run Simulation → RTL Simulation`. ModelSim opens.

**Step 2 — Find the signal panel**

ModelSim has two panels on the left side:
- **sim** (or **Instance**) panel — shows the hierarchy of instances.
  You should see `tb_washu2_week7` at the top, with `uut` below it.
- **Objects** panel — shows the signals *inside* whichever instance is
  selected in the sim panel.

If you cannot see these panels: `View → Debug Windows → Objects` and
`View → Debug Windows → Sim`.

**Step 3 — Select the DUT**

In the **sim** panel, click on `uut` (the `washu2_cpu` instance inside
the testbench). The **Objects** panel now shows all signals declared inside
`washu2_cpu` — including `current_state`, `acc`, `pc`, `the_bus`, etc.

**Step 4 — Add signals to the wave window**

In the **Objects** panel, select the signals you want (hold Ctrl to select
multiple), then right-click → **Add Wave**. Or simply drag them into the
wave window.

Add these signals for Week 7 simulation:

```
clk             ← already in wave from testbench
reset           ← already in wave from testbench
done            ← already in wave from testbench
current_state   ← shows state name (e.g., fetch1, cload1) — not a number
pc              ← set radix to Hex (see Step 5)
mar             ← set radix to Hex
mbr             ← set radix to Hex
ir              ← set radix to Hex
acc             ← set radix to Hex
the_bus         ← set radix to Hex
```

**Step 5 — Set hexadecimal display**

Binary values like `0000000000101010` are hard to read. For every data
signal (`pc`, `mar`, `mbr`, `ir`, `acc`, `the_bus`):

Right-click the signal name in the wave window → **Radix → Hexadecimal**.

Now `0000000000101010` displays as `002a` (= 42 decimal). This makes
comparing waveform values against your expected trace table much faster.

**Step 6 — Run the simulation**

In ModelSim: `Simulate → Run → Run All` (or type `run -all` in the
console). The waveform populates. Use the zoom controls to fit the whole
simulation on screen.

**Adding control signals per-instruction**

Once the basic signals are in the waveform and the fetch cycle works,
add the control signals relevant to the instruction you are currently
testing:

| Instruction | Control signals to add |
|---|---|
| Fetch cycle | `bus_pc`, `mar_ld`, `bus_mem`, `mbr_ld`, `pc_inc`, `bus_mbr`, `ir_ld` |
| HALT | `done_int` |
| NEGATE | `bus_alu`, `acc_ld`, `alu_op` |
| CLOAD | `bus_ir_se`, `acc_ld` |
| DLOAD | `bus_ir_lower`, `mar_ld`, `bus_mem`, `mbr_ld`, `bus_mbr`, `acc_ld` |
| DSTORE | `bus_ir_lower`, `mar_ld`, `bus_acc`, `mem_we` |

---

## 6. Expected waveforms

### Program A (HALT only)

Register values shown are **at the start** of each cycle (before the rising
edge). The dispatch in `fetch3` uses `mbr(15 downto 12)` — not `ir_opcode`
— because `ir` is only updated at the clock edge ending `fetch3`.

```
Cycle  State       pc     mar    mbr    ir     acc    done   Notes
 1     resetState  0x000  —      —      —      0x0000  0
 2     fetch1      0x000  0x000  —      —      0x0000  0     mar←pc=0x000
 3     fetch2      0x000  0x000  0x0000 —      0x0000  0     mbr←mem[0]=0x0000; pc→0x001
 4     fetch3      0x001  0x000  0x0000 —      0x0000  0     dispatch: mbr[15:12]=0000→halt1
                                                              ir←0x0000 at edge ending this row
 5     halt1       0x001  0x000  0x0000 0x0000 0x0000  1     done='1'; ir now shows new value
 6     halt1       0x001  0x000  0x0000 0x0000 0x0000  1     stays here
```

### Program C (CLOAD 42 then HALT)

```
Cycle  State   pc     mbr    ir     acc    Notes
 1     reset   0x000  —      —      —
 2     fetch1  0x000  —      —      —      mar←0x000
 3     fetch2  0x000  0x202A —      —      mbr←mem[0]=0x202A; pc→0x001
 4     fetch3  0x001  0x202A —      —      dispatch: mbr[15:12]=0010→cload1
                                            ir←0x202A at edge ending this row
 5     cload1  0x001  0x202A 0x202A —      bus_ir_se→the_bus=0x002A; acc←0x002A at edge
 6     fetch1  0x001  0x202A 0x202A 0x002A mar←0x001
 7     fetch2  0x001  0x0000 0x202A 0x002A mbr←mem[1]=0x0000 (HALT); pc→0x002
 8     fetch3  0x002  0x0000 0x202A 0x002A dispatch: mbr[15:12]=0000→halt1
                                            ir←0x0000 at edge ending this row
 9     halt1   0x002  0x0000 0x0000 0x002A done='1'
```

Key points: `ir` updates at the clock edge ending each `fetch3` row — it
shows the OLD value during the row, and the new value in the NEXT row.
`acc` becomes `0x002A` = 42 at the edge ending `cload1` (row 5), so it
shows correctly in row 6 onward.

---

## 7. Cycle count reference for timeout calculation

Use this to set a safe timeout in your testbench:

These counts are **per-instruction** — they exclude the one-time `resetState`
cycle that occurs only once when the CPU first starts.

| Instruction | States | Cycles |
|---|---|---|
| HALT   | fetch1, fetch2, fetch3, halt1 | 4 |
| NEGATE | fetch1, fetch2, fetch3, neg1, neg2 | 5 |
| CLOAD  | fetch1, fetch2, fetch3, cload1 | 4 |
| DLOAD  | fetch1, fetch2, fetch3, direct1, direct2, load1 | 6 |
| DSTORE | fetch1, fetch2, fetch3, direct1, direct2, store1 | 6 |

For Program D (CLOAD + DSTORE + CLOAD + DLOAD + HALT):
`4 + 6 + 4 + 6 + 4 = 24 cycles` + 1 for resetState = 25 cycles total → use 35 with margin.

> **resetState:** the CPU spends one cycle in `resetState` after reset is
> released before entering `fetch1`. This adds 1 cycle to every program's
> total count.

---

## 8. Common simulation mistakes

**Mistake 1 — Program not recompiled after changing the RAM initialiser.**
If you change `washu2_ram.vhd` and re-run without recompiling, ModelSim
uses the old compiled design. Always do a full compile after any source change.

**Mistake 2 — Waveform radix left as binary.**
`ir = 0010000000101010` is hard to match against `0x202A`. Set hex radix
for all data signals before analysing.

**Mistake 3 — Checking `acc` before `cload1` completes.**
`acc` updates at the rising edge that *ends* `cload1`, not at the start
of `cload1`. In the waveform, `acc` changes one row after the `cload1` row.

**Mistake 4 — Confusing `done='1'` cycle with `halt1` entry cycle.**
`done_int <= '1'` is set in the FSM (Process 2), but it is a combinational
signal. It becomes `'1'` as soon as `current_state = halt1`, which happens
at the clock edge ending `fetch3` (when `next_state <= halt1` was set).

---

Next: **Module 8 — Exercises**
