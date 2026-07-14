# Week 8 · Module 7 — Debugging Reference

The eight Week 7 bugs (see `week7/08-exercises-and-debugging.md`) still
apply — bus contention, latch inference, IR/PC not updating, and so on.
This module covers the bugs specific to the nine instructions added in
Week 8. Work through Module 6's exercises first; come back here when
something doesn't match the expected trace.

---

## Errata: a Week 7 addressing bug that affects every Week 8 instruction

**This was found and fixed while preparing these materials — it is not
something students introduce, and it isn't specific to Week 8. It's
flagged here because Week 8 is where it stops being maskable by
coincidence.**

The Week 7 RAM instantiation ties `addr` directly to `mar`:

```vhdl
-- Buggy (Week 7 as originally written):
addr => mar(11 downto 0),
```

`mar` is a *registered* value — it only updates at a clock edge. So
during the state that loads `mar` (e.g. `fetch1`, `direct1`), the RAM
still sees the **old** address for that entire cycle; the new address
isn't visible to the RAM until the following state. Combined with the
RAM's own one-cycle registered read latency, this means the value a
`bus_mem` + `*_ld` pair captures in the *very next* state is always the
result of the address from **two states back**, not the address just
latched.

For the Week 7 self-test, this happens to go unnoticed: the specific
addresses reused across instructions coincidentally produce the right
final `acc`, and the program halts via the FSM's `others => halt1`
catch-all on a garbage decoded opcode rather than by genuinely decoding
`HALT` at address 5 — it still asserts `done`, so the testbench's `wait
until done='1'` passes without ever checking *why*. Once Week 8 chains
several genuinely different memory reads together (ADD, BRIND, ILOAD,
ISTORE), the coincidences run out and the wrong data shows up for real.

**The fix** — a combinational mux that presents the *incoming* address
during the state that loads `mar`, and `mar` itself during the state
that reads it:

```vhdl
signal ram_addr : std_logic_vector(11 downto 0);
...
ram_addr <= the_bus(11 downto 0) when mar_ld = '1' else mar(11 downto 0);
...
ram_inst : entity work.washu2_ram
    port map (
        clk      => clk,
        we       => mem_we,
        addr     => ram_addr,   -- was: mar(11 downto 0)
        data_in  => the_bus,
        data_out => mem_data_out
    );
```

This is already applied in `starter_library/washu2_cpu_reference.vhd`.
Since every single- and double-indirection sequence in the whole CPU
(`fetch1`/`fetch2`, `direct1`/`direct2`, `indirect1`/`indirect2`,
`brind1`/`brind2`) follows the same "load MAR, then read" shape, this
one change fixes all of them at once — it does not require adding any
new states or changing any of the module-by-module FSM code you wrote
in Modules 2–5.

**If your own `washu2_cpu.vhd` was written against the original Week 7
`addr => mar(11 downto 0)` wiring, apply this same one-line-plus-mux
change before running the Module 6 exercises** — otherwise ADD, BRIND,
and ILOAD/ISTORE will intermittently return stale data the way the
trace above shows, and you'll spend time debugging the wrong thing.

---

## The six most common Week 8 bugs

**Bug 1 — A conditional branch always taken, or never taken**

Symptom: `BRZERO`/`BRPOS`/`BRNEG` behaves like `BRANCH` (always jumps),
or never jumps at all.

Cause: `pc_ld` in `branch1` was hardwired to `'1'` instead of gated by
the flag, or the `case ir_opcode` arm for that specific opcode is
missing (falls into `when others => pc_ld <= '0'`, so it can never
branch).

Fix: re-check Module 3 §5 — each opcode must map to its *own* flag
signal, and `OP_BRANCH` is the only unconditional one.

```vhdl
when branch1 =>
    bus_ir_lower <= '1';
    case ir_opcode is
        when OP_BRANCH => pc_ld <= '1';
        when OP_BRZERO => pc_ld <= zero_flag;   -- not '1'
        when OP_BRPOS  => pc_ld <= pos_flag;
        when OP_BRNEG  => pc_ld <= neg_flag;
        when others    => pc_ld <= '0';
    end case;
```

---

**Bug 2 — BRIND jumps to the address in the instruction, not the value stored there**

Symptom: after `BRIND 0x010`, execution resumes at instruction `0x010`
itself rather than at the address `mem[0x010]` contains.

Cause: `brind3` uses `bus_ir_lower` instead of `bus_mbr` — i.e. it's
loading `PC` from the instruction's address field directly, skipping
the indirection entirely.

Fix: `brind3` must assert `bus_mbr='1'` — `PC` latches from `MBR`
(the value `brind2` read from memory), never from `IR` directly.

---

**Bug 3 — ILOAD loads the pointer value instead of the real data**

Symptom: `acc` ends up holding the *address* stored in the pointer
slot (e.g. `0x0030`) rather than the data at that address (e.g.
`0x002A`).

Cause: `indirect1` and `indirect2` were merged into one state, or
`indirect1` used `bus_ir_lower` instead of `bus_mbr` (re-loading `MAR`
from the instruction's address field again instead of from the pointer
value already sitting in `MBR`).

Fix: confirm the four-state chain is intact and `indirect1` specifically
uses `bus_mbr`, not `bus_ir_lower`:

```vhdl
when indirect1 =>
    bus_mbr <= '1';   -- NOT bus_ir_lower
    mar_ld  <= '1';
```

---

**Bug 4 — ISTORE writes to the pointer slot instead of the real target**

Symptom: `mem[0x020]` (the pointer slot) gets overwritten with `acc`,
and `mem[0x030]` (the intended target) is untouched.

Cause: `istore1` fired directly after `direct2`, skipping
`indirect1`/`indirect2` — so `MAR` still holds the address from
`direct1` (`0x020`) rather than the dereferenced target (`0x030`).

Fix: verify `direct2`'s dispatch sends `OP_ISTORE` to `indirect1`, not
directly to `istore1` — this routing was set up in Week 7; confirm it
wasn't accidentally changed while adding Week 8 states.

---

**Bug 5 — "Duplicate choice in case statement" at compile time**

Symptom: Quartus/ModelSim compile error naming a state (e.g. `add1`)
as a duplicate choice.

Cause: the state has its own `when` arm now (Modules 2–5) but is also
still listed in the old Week 7 placeholder group (Module 6 §1).

Fix: delete the placeholder block entirely once every state in it has
been given its own arm — don't remove states from it one at a time and
forget the final cleanup pass.

---

**Bug 6 — Latch warning on `pc_ld` specifically**

Symptom: latch inferred only for `pc_ld`, nothing else.

Cause: almost always the inner `case ir_opcode` inside `branch1` (or
the one inside `indirect2`) is missing its `when others` arm.

Fix: always give any inner `case` a `when others` arm, even when the
outer `fsm_proc` default should theoretically make it redundant — some
toolchains still flag it without one.

---

## Systematic debugging workflow

```
1. Does it compile without errors?  Fix all errors first (Bug 5 first).
2. Does it compile without warnings?  Fix latch warnings (Bug 6) next.
3. Run Module 3's five branch programs.
   - Taken case wrong?  → Bug 1.
   - Not-taken case wrong? → Bug 1 (check the default / when others arm).
4. Run Module 4's BRIND program.
   - Lands at the address field itself, not mem[addr]? → Bug 2.
5. Run Module 5's ILOAD/ISTORE programs.
   - ACC holds the pointer, not the data? → Bug 3.
   - Wrong memory cell overwritten? → Bug 4.
6. Run Module 6's integration test.
   - If everything above passed individually but the integration test
     still fails, suspect a state-sharing interaction: check that
     direct2's dispatch table and indirect2's dispatch table both list
     every opcode that should route through them (Module 5 §3).
7. Compare your waveform against starter_library/washu2_cpu_reference.vhd
   ONLY after exhausting the above — see the file's header comment.
```

---

## Comparing against the reference implementation

`starter_library/washu2_cpu_reference.vhd` is the complete, working
Week 8 CPU. Use it the same way you used the Week 7 reference: **only
after** you've written your own and are stuck on a specific bug you
can't isolate with the workflow above. If your behavior differs from
the reference, don't just copy the reference's arm — find the module
section that explains *why* that arm is written the way it is, and
correct your understanding, not just your code.

---

Next: **Module 8 — Report Guidelines**
