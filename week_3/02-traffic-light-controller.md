# Week 3 · Module 2 — The Traffic Light Controller (Moore FSM)

The traffic light controller is the classic first FSM example because everyone
already knows the behaviour, so all attention can go to the new VHDL concepts.
It exercises state diagrams, enumerated types, Moore-style output assignment,
and the two-process template in a single short design. This module walks from
blank page to working simulation in steps; read every step before writing
code.

> **Video — Traffic Light Controller FSM in VHDL:**
> [Foundations of a Traffic Light Controller FSM](https://www.youtube.com/watch?v=bME7_HA_iE8)
> *(Walks through the same problem; worth watching alongside reading.)*

---

## 1. The specification

Design a controller for one set of lights (red, yellow, green) that cycles
automatically on a timer — no sensor input in this version.

| State | Lights on | Duration |
|---|---|---|
| `S_RED`     | Red          | 5 clock cycles |
| `S_RED_YEL` | Red + Yellow | 2 clock cycles |
| `S_GREEN`   | Green        | 5 clock cycles |
| `S_YELLOW`  | Yellow       | 2 clock cycles |

After `S_YELLOW` the cycle repeats from `S_RED`.

Ports:

```vhdl
entity traffic_light is
    port (
        clk    : in  std_logic;
        reset  : in  std_logic;
        red    : out std_logic;
        yellow : out std_logic;
        green  : out std_logic
    );
end traffic_light;
```

---

## 2. Step 1 — Draw the state diagram

Four states, each with its outputs, cycling in order:

```
   reset
     |
     v
  +---------+   5 cyc    +-----------+   2 cyc    +---------+
  |  S_RED  |----------> | S_RED_YEL |----------> | S_GREEN |
  | R=1     |            | R=1 Y=1   |            | G=1     |
  +---------+            +-----------+            +---------+
       ^                                               |
       |                                               | 5 cyc
       |                  2 cyc                         v
       |             +----------+                  (to S_YELLOW)
       +-------------| S_YELLOW |<-----------------------+
                     | Y=1      |
                     +----------+
```

Outputs are written beside each state — this is a Moore machine, so outputs
depend only on which state the FSM is in.

---

## 3. Step 2 — The timer problem

Transitions happen after a number of clock cycles, not immediately, so the FSM
must count how long it has been in the current state. The standard solution is
a **timer counter** alongside the FSM: count up each clock edge, reset to zero
when the state changes, and make the transition condition check
`timer = DURATION - 1`.

Define the durations as constants:

```vhdl
constant RED_TIME     : integer := 5;
constant RED_YEL_TIME : integer := 2;
constant GREEN_TIME   : integer := 5;
constant YELLOW_TIME  : integer := 2;
```

The timer is a plain `integer` because it is only compared against constants,
never driven to a port:

```vhdl
signal timer : integer range 0 to 15 := 0;
```

The `range 0 to 15` tells the synthesiser the signal needs only 4 bits rather
than a full 32-bit integer.

---

## 4. Step 3 — Managing the timer across both processes

The timer is a registered value (it must hold between edges), so it lives in
the state-register process. The decision of when to reset it depends on whether
the state is about to change, which the combinational process determines via
`next_state`. The cleanest approach for this module keeps the timer in
Process 1 and detects a transition with `next_state /= current_state`:

```vhdl
state_reg : process (clk)
begin
    if rising_edge(clk) then
        if reset = '1' then
            current_state <= S_RED;
            timer         <= 0;
        else
            current_state <= next_state;
            if next_state /= current_state then
                timer <= 0;          -- entering a new state: reset timer
            else
                timer <= timer + 1;  -- staying: count up
            end if;
        end if;
    end if;
end process;
```

The combinational process uses `timer` to decide transitions:

```vhdl
comb : process (current_state, timer)
begin
    next_state <= current_state;     -- default: stay
    case current_state is
        when S_RED =>
            if timer = RED_TIME - 1 then
                next_state <= S_RED_YEL;
            end if;
        -- ... etc.
    end case;
end process;
```

This couples `timer` to the state-register logic, which is fine for this
week's work. More advanced designs sometimes use a separate timer module or a
`timer_expired` flag.

---

## 5. Complete VHDL source

Study this against the explanation above before copying it; every line maps to
a concept from this module or Module 1.

```vhdl
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity traffic_light is
    port (
        clk    : in  std_logic;
        reset  : in  std_logic;
        red    : out std_logic;
        yellow : out std_logic;
        green  : out std_logic
    );
end traffic_light;

architecture rtl of traffic_light is

    type state_type is (S_RED, S_RED_YEL, S_GREEN, S_YELLOW);
    signal current_state : state_type;
    signal next_state    : state_type;

    signal timer : integer range 0 to 15 := 0;

    constant RED_TIME     : integer := 5;
    constant RED_YEL_TIME : integer := 2;
    constant GREEN_TIME   : integer := 5;
    constant YELLOW_TIME  : integer := 2;

begin

    -- PROCESS 1: state register + timer
    state_reg : process (clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                current_state <= S_RED;
                timer         <= 0;
            else
                current_state <= next_state;
                if next_state /= current_state then
                    timer <= 0;
                else
                    timer <= timer + 1;
                end if;
            end if;
        end if;
    end process state_reg;

    -- PROCESS 2: next-state + Moore outputs (depend only on current_state)
    comb_logic : process (current_state, timer)
    begin
        -- defaults: stay, all lights off
        next_state <= current_state;
        red        <= '0';
        yellow     <= '0';
        green      <= '0';

        case current_state is

            when S_RED =>
                red <= '1';
                if timer = RED_TIME - 1 then
                    next_state <= S_RED_YEL;
                end if;

            when S_RED_YEL =>
                red    <= '1';
                yellow <= '1';
                if timer = RED_YEL_TIME - 1 then
                    next_state <= S_GREEN;
                end if;

            when S_GREEN =>
                green <= '1';
                if timer = GREEN_TIME - 1 then
                    next_state <= S_YELLOW;
                end if;

            when S_YELLOW =>
                yellow <= '1';
                if timer = YELLOW_TIME - 1 then
                    next_state <= S_RED;
                end if;

            when others =>
                next_state <= S_RED;

        end case;
    end process comb_logic;

end rtl;
```

---

## 6. Reading the waveform

After reset is released you should observe:

1. `current_state = S_RED`, with `red = '1'`, `yellow = '0'`, `green = '0'`.
2. After 5 cycles, a transition to `S_RED_YEL` with both `red` and `yellow`
   high.
3. After 2 more cycles, `S_GREEN` with only `green` high.
4. After 5 cycles, `S_YELLOW` with only `yellow` high.
5. After 2 cycles, the sequence repeats from `S_RED`.

Total cycle length: 5 + 2 + 5 + 2 = 14 clock cycles per full rotation.

---

## 7. Common mistakes

**Missing `others` arm.** Always include `when others => next_state <= S_RED;`
as a safety net so an undefined state returns to a known one rather than
locking up.

**Missing output default -> inferred latch.** If an output is not assigned in
every branch and has no default before the `case`, VHDL infers a latch and the
output holds a stale value. The fix is to assign every output a default
(`red <= '0'; yellow <= '0'; green <= '0';`) before the `case`.

**Timer comparison off by one.** Using `timer = RED_TIME` instead of
`timer = RED_TIME - 1` keeps the FSM one cycle too long in each state. Counting
from 0, the cycle where `timer = DURATION - 1` is the DURATION-th cycle; verify
by counting edges on the waveform.

**Output logic in Process 1.** Assigning outputs inside the clocked process
makes them registered (one cycle late) and breaks the separation of concerns.
Keep all output assignments in Process 2.

---

## 8. Extension: a pedestrian button

Once the basic design works, add an input `ped_req`. When `ped_req = '1'`
during `S_GREEN`, the FSM should move to `S_YELLOW` immediately rather than
waiting the full 5 cycles. Use the state-diagram process: draw the new arrow
first, then add the condition to the `when S_GREEN` arm of Process 2.

---

Next: **Module 3 — The "1011" Sequence Detector (Moore and Mealy)**
