# Week 3 · Module 6 — Debugging FSMs & Quick Reference

This module collects the most common FSM bugs, how to recognise them from the
waveform, and how to fix them. It also serves as a reference card for the
two-process template and state-diagram conventions — keep it open while coding.

---

## 1. The six most common FSM bugs

### Bug 1 — FSM stuck in the reset state

**Symptom:** `current_state` never leaves the reset state even after
`reset = '0'`; outputs stuck at reset values.

**Cause:** one of —
- `reset` is never driven low in the testbench (stays `'1'` or `'U'`);
- `current_state <= next_state` is inside the `if reset='1'` branch instead of
  the `else` branch;
- `next_state` is never assigned anything but the reset state in Process 2.

**Find it:** check `reset` in the waveform. If it never goes low, the testbench
is wrong. If it does but the state never moves, check Process 1:

```vhdl
-- WRONG: assignment in the wrong branch (unreachable)
if reset = '1' then
    current_state <= S_INIT;
    current_state <= next_state;
end if;

-- CORRECT
if reset = '1' then
    current_state <= S_INIT;
else
    current_state <= next_state;
end if;
```

### Bug 2 — Inferred latch (outputs hold stale values)

**Symptom:** an output keeps a value from a previous state when it should be
`'0'`. Quartus may warn: *"Latch inferred for signal..."*

**Cause:** the output is not assigned in every `case` branch and has no default
before the `case`.

**Fix:** assign defaults to every output before the `case`:

```vhdl
red    <= '0';
yellow <= '0';
green  <= '0';     -- safe defaults: all off
case current_state is
    when S_GREEN => green <= '1';   -- overrides default
    when S_RED   => red   <= '1';
    ...
end case;
```

### Bug 3 — Never detects, or detects on the wrong cycle

**Symptom (sequence detector):** `detected` never fires, or fires one cycle too
early or late.

**Causes:** wrong transitions in the state diagram (fix the diagram, not just
the code); Moore vs Mealy confusion (Moore fires the cycle after the last bit,
Mealy on the same cycle); `data` in the testbench not aligned to edges, so the
FSM samples the wrong bit.

**Find it:** add `current_state` to the waveform and hand-trace it against the
input. Find the first cycle where the state diverges from your diagram.

### Bug 4 — Missing sensitivity-list signal

**Symptom:** simulation behaves incorrectly when an input changes between
transitions; the combinational process does not re-evaluate when it should.

**Cause:** an input read in Process 2 is missing from its sensitivity list.

```vhdl
comb : process (current_state)         -- WRONG if data is read inside
comb : process (current_state, data)   -- CORRECT
```

A pure Moore machine with no input-dependent output needs only
`current_state`; any Mealy output or input-dependent transition requires that
input in the list.

### Bug 5 — Timer comparison off by one

**Symptom:** the FSM spends one cycle too long in each state (using
`timer = DURATION` instead of `timer = DURATION - 1`).

**Find it:** count cycles per state on the waveform. If `S_RED` lasts 6 cycles
instead of 5, the comparison is off by one. Counting from 0, the cycle where
`timer = DURATION - 1` is the DURATION-th cycle.

### Bug 6 — Missing `when others`

**Symptom:** no visible simulation bug (the simulator only visits defined
states), but synthesised hardware may power up in an undefined state and lock.

**Fix:** always include `when others => next_state <= <reset_state>;` as the
last arm. Zero cost, real safety benefit.

---

## 2. Systematic debugging workflow

When the waveform is wrong, follow this order and stop as soon as you find the
problem — do not fix several things at once.

```
Step 1 - Check reset.   Is reset going high then low? Does the FSM enter the
                        correct initial state after release?
Step 2 - Check clock.   Is the clock toggling? Does the DUT update on rising
                        edges only?
Step 3 - Add current_state to the waveform. Trace each transition cycle by
                        cycle; find the first cycle that differs from your
                        diagram.
Step 4 - Inspect that cycle in Process 2. What was the state and the inputs?
                        What should next_state have been? What did the code do?
Step 5 - Fix Process 2 first. Correct the transition/output logic; re-simulate;
                        repeat from Step 3.
Step 6 - If state is right but output is wrong: check for missing defaults
                        (Bug 2) and the sensitivity list (Bug 4).
```

---

## 3. Two-process FSM quick-reference skeleton

```vhdl
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity NAME is
    port (
        clk   : in  std_logic;
        reset : in  std_logic
        -- inputs / outputs
    );
end NAME;

architecture rtl of NAME is
    type state_type is (S_RESET, S_A, S_B);   -- list ALL states
    signal current_state : state_type;
    signal next_state    : state_type;
begin

    -- Process 1: state register (synchronous reset)
    seq : process (clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                current_state <= S_RESET;
            else
                current_state <= next_state;
            end if;
        end if;
    end process seq;

    -- Process 2: combinational next-state + outputs
    comb : process (current_state)   -- add inputs if Mealy / input-dependent
    begin
        next_state <= current_state;     -- defaults
        -- output1 <= '0';
        -- output2 <= (others => '0');

        case current_state is
            when S_RESET =>
                next_state <= S_A;       -- usually transition immediately
            when S_A =>
                -- output1 <= '1';
                -- if condition then next_state <= S_B; end if;
                null;
            when S_B =>
                null;
            when others =>
                next_state <= S_RESET;   -- safety net
        end case;
    end process comb;

end rtl;
```

---

## 4. State-diagram checklist

Before writing code, confirm your diagram satisfies all of these:

- [ ] Every state has a name and is drawn as a circle.
- [ ] Every state has an outgoing arrow for each possible input (or an intended
      default "else stay").
- [ ] Exactly one state is marked the reset/initial state.
- [ ] Every output has a defined value in every state.
- [ ] Outputs are inside the state circle (Moore) or on the arrow (Mealy) —
      not both.
- [ ] A `when others` fallback state is identified.
- [ ] You have hand-traced at least one input sequence and verified outputs.

---

## 5. Enumerated-type rules summary

```vhdl
-- Declaration (architecture declarative region)
type my_state_t is (IDLE, RUNNING, DONE, ERROR);

-- Signals
signal state     : my_state_t := IDLE;   -- initial value optional
signal nxt_state : my_state_t;

-- Assignment and comparison use the NAME, never a bit pattern
state <= RUNNING;          -- correct
-- state <= "01";          -- compile error
if state = IDLE then ...   -- correct
-- if state = 0 then ...   -- compile error

-- Case: cover every value, plus when others
case state is
    when IDLE    => ...
    when RUNNING => ...
    when DONE    => ...
    when ERROR   => ...
    when others  => ...    -- include even when all values are listed
end case;
```

---

## 6. Key vocabulary

| Term | Meaning |
|---|---|
| State | one of a finite set of named operating modes |
| Transition | a move from one state to another, triggered by a condition |
| State diagram | a graph of states (circles) and labelled transition arrows |
| Moore machine | outputs depend only on the current state |
| Mealy machine | outputs depend on current state and current inputs |
| Enumerated type | a user-defined type whose values are a list of names |
| Sensitivity list | signals in `process(...)` that wake the process |
| Inferred latch | unintended memory from an output not assigned in every branch |
| `when others` | catch-all case arm for any unlisted state value |
| Two-process template | FSM style separating the state register from combinational logic |
| Overlapping detection | detector variant where one match's end can begin the next |

---

## 7. Recommended outside resources

- [How to create a Finite-State Machine in VHDL — VHDLwhiz](https://vhdlwhiz.com/finite-state-machine/) — comprehensive written reference.
- [Finite State Machines in VHDL — Part 1 (YouTube)](https://www.youtube.com/watch?v=4PtWlRz60-M) — state-diagram-to-code translation in the same Quartus environment.
- [FSM Explained — Mealy vs Moore (YouTube)](https://www.youtube.com/watch?v=kb-Ww8HaHuE) — worked diagrams for both types.
- [1011 Sequence Detector — Mealy overlapping (YouTube)](https://www.youtube.com/watch?v=q4pikDnQvmQ) — the exact pattern behind Module 3.

---

*That completes Week 3. State diagrams, enumerated types, the two-process
template, and Moore vs Mealy are the direct foundation for the WashU-2 CPU
control unit in Weeks 7 and 8. The traffic light and sequence detector are
small enough to hold entirely in your head; use them to build the intuition
that will carry through the 17-state CPU FSM.*
