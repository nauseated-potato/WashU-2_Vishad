# Week 3 · Module 5 — Testbenches for FSM Designs

A combinational testbench (Week 1) applied inputs, waited, and read outputs. A
clocked-register testbench (Week 2) added a clock generator. An FSM testbench
adds two more concerns:

1. **You must observe the state, not just the outputs.** Outputs alone often
   do not reveal *why* the FSM behaved a certain way; making `current_state`
   visible in simulation is essential.
2. **Input sequences must be designed deliberately.** A counter testbench
   mostly needs time to pass. An FSM testbench needs crafted patterns that
   exercise every transition, including tricky ones such as a partial match
   being broken and resumed.

This module covers both, then presents the complete worked testbench for the
traffic light controller (provided in the starter library so you can study a
full, correct example).

---

## 1. Making internal signals visible in ModelSim

By default the waveform shows only entity ports. Internal signals — including
`current_state` — must be added explicitly.

1. After compiling, open the simulation.
2. In the *Objects* (or *Design*) panel, expand the DUT hierarchy.
3. Drag `current_state` into the Wave window, or right-click -> *Add to Wave*.
4. Re-run the simulation.

The state then appears in the waveform as its enumerated name (`S_RED`,
`S_GREEN`, ...) rather than a bit vector — one of the main advantages of
enumerated types, and what makes FSM waveforms self-documenting.

Use this mechanism rather than adding a debug output port to the entity. An
internal enumerated type is not in scope outside the architecture, so a port
of that type would not be usable from the testbench without extra package
machinery — dragging the internal signal in the simulator is simpler and
changes nothing about the design.

---

## 2. Designing the stimulus

A good FSM testbench covers three categories:

**A — Basic operation.** Does the FSM reach the correct initial state after
reset, with the expected outputs?

**B — Happy path.** Drive the inputs that step the FSM through its complete
normal sequence. For the traffic light, wait long enough for a full 14-cycle
rotation. For a sequence detector, send a full target sequence and verify
detection.

**C — Edge cases and recovery.** A near-miss (e.g. `1 0 1 0` for a `1011`
detector); reset asserted mid-sequence; an overlapping sequence that should
fire twice; for the traffic light, reset mid-rotation and confirm it returns to
`S_RED`. Design these by asking: *what is the most likely implementation
mistake, and what input would expose it?*

---

## 3. The `wait until rising_edge(clk)` pattern

For precise per-cycle stimulus — essential for sequence detectors — prefer
`wait until rising_edge(clk)` over `wait for N ns`:

```vhdl
-- less precise: may drift relative to edges
data <= '1';
wait for 10 ns;
data <= '0';
wait for 10 ns;

-- precise: one bit per cycle, changed just after the edge
wait until rising_edge(clk); data <= '1';
wait until rising_edge(clk); data <= '0';
```

The second form changes `data` immediately after a rising edge, giving the DUT
a full setup time before the next edge samples it — matching how real serial
data is presented. To apply the sequence `1 0 1 1` one bit per cycle:

```vhdl
wait until rising_edge(clk); data <= '1';
wait until rising_edge(clk); data <= '0';
wait until rising_edge(clk); data <= '1';
wait until rising_edge(clk); data <= '1';
wait until rising_edge(clk);   -- let the state update after the last bit
-- (Moore) current_state should now be S_1011 and detected = '1'
```

---

## 4. Worked testbench — Traffic Light Controller

The complete testbench below is provided as
`starter_library/tb_traffic_light.vhd`. The traffic light is a worked example
(Module 2), not an exercise, so this file is given purely as a fully correct
testbench to study before you write your own. Read every section.

```vhdl
-- tb_traffic_light.vhd
-- Complete testbench for the traffic_light entity from Module 2.
-- Tests: (a) reset enters S_RED with red='1';
--        (b) two full 14-cycle rotations are visible;
--        (c) a mid-rotation reset returns the FSM to S_RED.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity tb_traffic_light is
end tb_traffic_light;

architecture sim of tb_traffic_light is

    signal clk    : std_logic := '0';
    signal reset  : std_logic := '1';
    signal red    : std_logic;
    signal yellow : std_logic;
    signal green  : std_logic;

    constant CLK_PERIOD : time := 10 ns;

begin

    clk <= not clk after CLK_PERIOD / 2;

    uut : entity work.traffic_light
        port map (
            clk    => clk,
            reset  => reset,
            red    => red,
            yellow => yellow,
            green  => green
        );

    stimulus : process
    begin
        -- Phase 1: hold reset; expect red='1', yellow='0', green='0'.
        reset <= '1';
        wait for 3 * CLK_PERIOD;

        -- Phase 2: release reset; run two full rotations (28 cycles).
        reset <= '0';
        wait for 28 * CLK_PERIOD;

        -- Phase 3: assert reset mid-rotation; FSM snaps back to S_RED.
        reset <= '1';
        wait for 2 * CLK_PERIOD;
        reset <= '0';

        -- Phase 4: one more rotation to confirm recovery.
        wait for 14 * CLK_PERIOD;

        wait for 5 * CLK_PERIOD;
        wait;   -- end simulation
    end process stimulus;

end sim;
```

Studying this file is the recommended preparation for writing your own
testbenches: it shows the clock generator, the DUT instantiation, the phased
stimulus, and the closing settle-and-`wait` pattern in one correct piece.

---

## 5. Template for your own testbenches

The starter file `starter_library/tb_template_fsm.vhd` is the starting point
for the testbenches you write yourself — `tb_seq_det_101.vhd` for Exercise 2
and `tb_combo_lock.vhd` for the optional exercise. Copy it, rename it,
instantiate your design, and replace the placeholder stimulus with input
aligned to clock edges using the `wait until rising_edge(clk)` pattern from §3.

(The vending-machine exercise does not need this template — its testbench,
`tb_vending_machine.vhd`, is already provided complete.)

---

## 6. What good waveform output looks like

For the **traffic light**, the screenshot should include
`clk`, `reset`, `current_state`, `red`, `yellow`, `green`, and span 40+ clock
cycles (two-plus rotations and the reset test). Mark where reset is applied,
one complete 14-cycle rotation, and the mid-simulation reset returning to
`S_RED`.

For a **sequence detector**, include `clk`, `reset`, `data`, `current_state`,
`detected`, and span 25+ cycles. Mark each cycle where `detected = '1'` and
confirm it corresponds to a valid pattern ending in the `data` stream. Remember
(from Module 3 §5) that a Moore detection can land one cycle *after* the final
data bit, so run the simulation at least one cycle past the last input.

---

## 7. Common testbench mistakes for FSMs

**Not enough input data.** A detector testbench that sends only the target
once sees a single detection. Send 25+ bits to exercise a detection, a
near-miss, a mid-sequence reset, and (for overlapping detectors) an overlap.

**Data changing exactly on the clock edge.** Using `wait for 10 ns` with a
10 ns period lands changes on the edge, risking ambiguous sampling. Use
`wait until rising_edge(clk); data <= ...;` so data changes just after the
edge.

**Ending the simulation too early.** If the stimulus ends immediately after the
last input, a Moore detection (one cycle later) is never captured. Always close
with `wait for 5 * CLK_PERIOD; wait;`.

**Forgetting `current_state` in the wave window.** The output alone does not
explain the FSM's path; always add `current_state` so you can trace it.

---

Next: **Module 6 — Debugging FSMs & Reference**
