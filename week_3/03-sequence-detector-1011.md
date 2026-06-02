# Week 3 · Module 3 — The "1011" Sequence Detector

A sequence detector watches a serial input stream (one bit per clock cycle)
and raises a flag when the last N bits match a target pattern. Here the target
is **1011**.

This is harder than the traffic light for three reasons:

1. Transitions depend on the **current input** as well as the current state,
   so you must think carefully about what partial progress to remember in each
   state.
2. There is a choice between **overlapping** and **non-overlapping** detection,
   and the state diagram differs between them.
3. You will implement it as **both** a Moore and a Mealy machine and compare
   the waveforms — the clearest way to internalise the difference.

Work the state diagrams on paper completely before opening the editor.

> **Video — 1011 sequence detector, state-diagram walkthrough:**
> [1011 Sequence Detector — Mealy (overlapping)](https://www.youtube.com/watch?v=q4pikDnQvmQ)
>
> **Video — translating a state diagram into the two-process VHDL template:**
> [Finite State Machines in VHDL — Part 1](https://www.youtube.com/watch?v=4PtWlRz60-M)

---

## 1. Understanding the problem

The input `data` is a single bit. On each rising edge one new bit arrives. The
circuit asserts `detected = '1'` when the last four bits were `1, 0, 1, 1` in
order.

### Overlapping vs non-overlapping

**Non-overlapping:** after detecting `1011`, start fresh and ignore any overlap
between the end of one match and the start of the next.

**Overlapping:** the final `1` of a detected `1011` can also be the first `1`
of the next potential match, giving faster detection on overlapping streams.

This module implements the **overlapping** version — the standard one, and the
one the exercises build on.

---

## 2. Building the state diagram

States represent **how much of the target has been matched so far** — the
longest suffix of the input that is also a prefix of `1011`.

| State | Meaning | Matched so far |
|---|---|---|
| `S_INIT` | no progress | (none) |
| `S_1`    | received `1` | "1" |
| `S_10`   | received `10` | "10" |
| `S_101`  | received `101` | "101" |
| `S_1011` | received `1011` — DETECTED | "1011" |

From each state, draw one arrow for `data='0'` and one for `data='1'`, choosing
the destination by what the new bit does to the partial match:

- **`S_INIT`:** `1` -> `S_1`; `0` -> `S_INIT`.
- **`S_1`** (have "1"): `0` -> `S_10`; `1` -> `S_1` (the new `1` restarts a
  one-bit match).
- **`S_10`** (have "10"): `1` -> `S_101`; `0` -> `S_INIT`.
- **`S_101`** (have "101"): `1` -> `S_1011` (detected); `0` -> `S_10` (the
  trailing "10" is itself a prefix).
- **`S_1011`** (just detected — overlap): `0` -> `S_10`; `1` -> `S_1`.

Draw this as proper circles and arrows on paper using the bullet list above as
the authoritative transition table. Verify by tracing the stream
`1 0 1 1 0 1 1` and confirming detection fires correctly.

---

## 3. Moore version

In the Moore version, `detected` is high **whenever the FSM is in `S_1011`**.
Because the state only updates on the edge *after* the final `1` arrives, the
output appears one clock cycle after that bit.

```vhdl
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity seq_det_moore is
    port (
        clk      : in  std_logic;
        reset    : in  std_logic;
        data     : in  std_logic;
        detected : out std_logic
    );
end seq_det_moore;

architecture rtl of seq_det_moore is
    type state_type is (S_INIT, S_1, S_10, S_101, S_1011);
    signal current_state : state_type;
    signal next_state    : state_type;
begin

    state_reg : process (clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                current_state <= S_INIT;
            else
                current_state <= next_state;
            end if;
        end if;
    end process state_reg;

    comb : process (current_state, data)
    begin
        next_state <= S_INIT;   -- defaults
        detected   <= '0';

        case current_state is

            when S_INIT =>
                if data = '1' then next_state <= S_1; else next_state <= S_INIT; end if;

            when S_1 =>
                if data = '0' then next_state <= S_10; else next_state <= S_1; end if;

            when S_10 =>
                if data = '1' then next_state <= S_101; else next_state <= S_INIT; end if;

            when S_101 =>
                if data = '1' then next_state <= S_1011; else next_state <= S_10; end if;

            when S_1011 =>
                detected <= '1';                          -- Moore output: in detected state
                if data = '0' then next_state <= S_10; else next_state <= S_1; end if;

            when others =>
                next_state <= S_INIT;

        end case;
    end process comb;

end rtl;
```

---

## 4. Mealy version

In the Mealy version, `detected` goes high **on the same cycle the final `1`
arrives** — it is a function of both the current state (`S_101`) and the input
(`data='1'`). Only 4 states are needed: there is no separate detected state,
because detection is signalled on the transition out of `S_101`.

```vhdl
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity seq_det_mealy is
    port (
        clk      : in  std_logic;
        reset    : in  std_logic;
        data     : in  std_logic;
        detected : out std_logic
    );
end seq_det_mealy;

architecture rtl of seq_det_mealy is
    type state_type is (S_INIT, S_1, S_10, S_101);
    signal current_state : state_type;
    signal next_state    : state_type;
begin

    state_reg : process (clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                current_state <= S_INIT;
            else
                current_state <= next_state;
            end if;
        end if;
    end process state_reg;

    comb : process (current_state, data)
    begin
        next_state <= S_INIT;   -- defaults
        detected   <= '0';

        case current_state is

            when S_INIT =>
                if data = '1' then next_state <= S_1; else next_state <= S_INIT; end if;

            when S_1 =>
                if data = '0' then next_state <= S_10; else next_state <= S_1; end if;

            when S_10 =>
                if data = '1' then next_state <= S_101; else next_state <= S_INIT; end if;

            when S_101 =>
                if data = '1' then
                    detected   <= '1';        -- Mealy output: on the transition
                    next_state <= S_1;        -- overlap: the '1' starts S_1
                else
                    next_state <= S_10;
                end if;

            when others =>
                next_state <= S_INIT;

        end case;
    end process comb;

end rtl;
```

---

## 5. Comparing Moore and Mealy in simulation

Run both on the same stream and compare. For input `0 0 1 0 1 1 0 1 1`:

| Cycle | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
|---|---|---|---|---|---|---|---|---|---|---|
| data           | 0 | 0 | 1 | 0 | 1 | 1 | 0 | 1 | 1 | — |
| Mealy detected | 0 | 0 | 0 | 0 | 0 | **1** | 0 | 0 | **1** | 0 |
| Moore detected | 0 | 0 | 0 | 0 | 0 | 0 | **1** | 0 | 0 | **1** |

The Mealy output fires on the cycle the final `1` arrives (cycles 6 and 9). The
Moore output fires one cycle later, when the FSM occupies `S_1011` (cycles 7
and 10). Note the second Moore detection lands on cycle 10 — one cycle past the
last data bit — so your testbench must run at least one cycle beyond the final
input to make it visible.

What to verify in the waveforms:

1. Moore `detected` is high only while `current_state = S_1011`.
2. Mealy `detected` is high only on a cycle where `current_state = S_101` and
   `data = '1'`.
3. For a near-miss stream such as `1 0 1 0 1 1`, `detected` stays low until a
   full `1011` actually completes.

---

## 6. Tracing by hand

The key skill is hand-tracing: given a stream, walk the FSM cycle by cycle and
determine when `detected` fires. Trace `1 1 0 1 1` through the Moore FSM:

| Cycle | data | State before | State after | detected |
|---|---|---|---|---|
| reset | — | S_INIT | S_INIT | 0 |
| 1 | 1 | S_INIT | S_1   | 0 |
| 2 | 1 | S_1    | S_1   | 0 |
| 3 | 0 | S_1    | S_10  | 0 |
| 4 | 1 | S_10   | S_101 | 0 |
| 5 | 1 | S_101  | S_1011| 0 (fires next cycle) |
| 6 | — | S_1011 | S_1 (overlap) | **1** |

`detected` goes high on cycle 6, the first cycle the FSM occupies `S_1011`. Do
this for at least three streams before simulating.

---

## 7. Common mistakes

**Wrong overlapping transitions from `S_1011`.** Returning to `S_INIT`
unconditionally misses the overlap. The trailing `1` of a match can begin the
next match, so `S_1011` must go to `S_10` (on `0`) or `S_1` (on `1`).

**Forgetting `data` in the sensitivity list.** The output depends on `data`
(Mealy) or transitions do (both). If `data` is missing from Process 2's
sensitivity list, the process will not re-evaluate when `data` changes:

```vhdl
comb : process (current_state)        -- wrong
comb : process (current_state, data)  -- correct
```

**Confusing which cycle detection fires.** Moore fires the cycle *after* the
last bit; Mealy fires on the same cycle. If the waveform disagrees, hand-trace
§6 against it.

---

Next: **Module 4 — Exercises**
