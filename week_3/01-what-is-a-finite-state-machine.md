# Week 3 · Module 1 — What Is a Finite State Machine?

By the end of Week 2 you could build clocked registers and counters. Those
circuits remember *one* piece of information — a number — and update it on
every edge. This week you will build circuits that remember **which step of a
process they are in** and change behaviour accordingly. That idea — a circuit
with distinct named *states* that moves between them based on inputs — is a
**Finite State Machine (FSM)**.

FSMs are not specific to FPGAs. Every traffic light is one; every vending
machine is one; every "press 1 for English" phone menu is one. Most relevant
to this project, the WashU-2 CPU's control unit is a 17-state FSM. Everything
in this week is direct preparation for that.

---

## 1. The core idea: states, transitions, and outputs

An FSM is described by three things:

1. **A finite set of states** — distinct named situations the system can be
   in. For a traffic light: `RED`, `GREEN`, `YELLOW`. For a door lock:
   `LOCKED`, `UNLOCKED`.

2. **Transition rules** — for each state, given some input (or elapsed time),
   which state comes next. "If in RED and the timer expires, go to GREEN."

3. **Outputs** — what the circuit produces in each state, and possibly also
   depending on inputs. "While in RED, drive `red_light = '1'`."

The word *finite* means the number of states is fixed and known at design
time. A processor does not have a separate state for every possible memory
value; it has a small number of named operating modes, which is exactly what
makes it tractable.

---

## 2. Drawing a state diagram

Before writing any VHDL, draw the state diagram. It is the design; the VHDL is
a mechanical translation of it. A state diagram has:

- **Circles (or rounded boxes)** for states, each labelled with its name.
- **Arrows** for transitions, each labelled with the *condition* that triggers
  it (an input value, a timer reaching a limit).
- **One arrow with no source**, pointing at the reset/initial state.
- **Output values** written either inside the state circle (Moore) or on the
  transition arrow (Mealy) — see below.

A trivial two-state example: an FSM that flips its output every clock tick,
with no inputs.

```
   reset
     |
     v
  +------+   always    +------+
  |  S0  | ----------> |  S1  |
  |out=0 | <---------- |out=1 |
  +------+   always    +------+
```

It starts in S0 (output low), moves to S1 on every clock edge, then loops
back. Real diagrams have four to twenty states with branching conditions, but
the reading discipline is identical.

---

## 3. Moore vs Mealy: two families of FSM

There are two classic ways to connect outputs to state and input.

### Moore machine

The output depends **only on the current state**. Inputs affect transitions
but never directly affect the output.

```
 inputs --> [next-state logic] --> [state register] --> [output logic] --> outputs
                  ^                       |
                  +-----------------------+
```

The output-logic block sees only the state. Because the state changes only on
clock edges, outputs also change only on clock edges, which makes Moore
machines easy to reason about and free of output glitches.

### Mealy machine

The output depends on **both the current state and the current inputs**.

```
 inputs --> [next-state logic] --> [state register] --> [output logic] --> outputs
     |            ^                        |                  ^
     |            +------------------------+                  |
     +-------------------------------------------------------+
```

The output-logic block sees both state and input, so outputs can respond
within the current clock cycle to an input change. Mealy machines typically
need one fewer state than an equivalent Moore machine.

### Which to use

| Property | Moore | Mealy |
|---|---|---|
| Output timing | changes at clock edge | can change mid-cycle |
| Glitch risk | none | possible |
| States needed | more | fewer |
| Ease of debugging | easier | harder |
| WashU-2 CPU | mostly Moore | — |

For beginners and for the WashU-2 CPU, **prefer Moore**. The traffic light in
Module 2 is Moore. The sequence detector in Module 3 is implemented both ways
so the difference is concrete.

> **Video — Moore vs Mealy:**
> [Finite State Machine Explained — Mealy and Moore](https://www.youtube.com/watch?v=kb-Ww8HaHuE)
> *(~14 min; both types with worked state diagrams. Watch before Module 2.)*

---

## 4. The two-process FSM template in VHDL

There are several valid ways to code an FSM (one, two, or three processes).
This course uses the **two-process template**: it separates the clocked and
combinational parts cleanly and is easy to extend. The two processes divide
the work as follows.

| Process | Name | Contains |
|---|---|---|
| 1 | State register | a single clocked `if rising_edge(clk)` moving `current_state <= next_state` |
| 2 | Combinational logic | a `case current_state is` deciding `next_state` and driving all outputs |

The declarative region (between `architecture ... is` and `begin`) holds the
enumerated state type and the two signals `current_state` and `next_state`.

The skeleton, with empty `case` arms:

```vhdl
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity my_fsm is
    port (
        clk   : in  std_logic;
        reset : in  std_logic
        -- add inputs and outputs here
    );
end my_fsm;

architecture rtl of my_fsm is

    type state_type is (S_RESET, S_A, S_B, S_C);   -- replace with your states
    signal current_state : state_type;
    signal next_state    : state_type;

begin

    -- ----------------------------------------------------------------
    -- PROCESS 1: State register.
    -- Only job: move current_state to next_state each rising edge,
    -- and force the reset state when reset = '1'. No output logic here.
    -- ----------------------------------------------------------------
    state_reg : process (clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                current_state <= S_RESET;
            else
                current_state <= next_state;
            end if;
        end if;
    end process state_reg;

    -- ----------------------------------------------------------------
    -- PROCESS 2: Combinational next-state + output logic.
    -- Sensitivity list must include current_state and every input that
    -- affects next_state or any output. Every output must get a default
    -- value before the case to avoid inferred latches.
    -- ----------------------------------------------------------------
    comb_logic : process (current_state)   -- add inputs as needed
    begin
        next_state <= current_state;       -- default: stay in current state
        -- default every output here too

        case current_state is

            when S_RESET =>
                next_state <= S_A;         -- usually move to the first real state

            when S_A =>
                null;   -- transitions and outputs go here

            when S_B =>
                null;

            when S_C =>
                null;

            when others =>
                next_state <= S_RESET;     -- safety net

        end case;
    end process comb_logic;

end rtl;
```

Three rules make this template reliable:

1. **Process 1 contains only the flip-flop** — the synchronous
   `current_state <= next_state` and the reset, nothing else.
2. **Every output gets a default value** before the `case`. Without defaults,
   VHDL infers a latch for any output not assigned in every branch, which
   synthesises as unwanted memory and causes subtle bugs.
3. **Process 2's sensitivity list includes every signal read in it.** For a
   Moore machine that is just `current_state`; for a Mealy machine it also
   includes every input that feeds the output logic.

> **Video — FSM in VHDL (VHDLwhiz):**
> [How to create a Finite-State Machine in VHDL](https://www.youtube.com/watch?v=E-qEnSp1aCk)
> *(~11 min; demonstrates a single-process style. The two-process template
> here is a cleaner equivalent that splits the clocked and combinational
> parts.)*

---

## 5. Enumerated types in VHDL

The keyword `type` defines a new data type whose values are a list of names
you choose — an **enumerated type**.

```vhdl
type state_type is (IDLE, FETCH, DECODE, EXECUTE, WRITEBACK);
signal current_state : state_type := IDLE;
```

The synthesiser assigns bit patterns to the names automatically; you work with
the names throughout and never need to know the encoding. Benefits over
integers or bit vectors:

- The compiler catches any typo immediately ("no such value").
- ModelSim shows `IDLE`, `FETCH`, ... in the waveform instead of `01`, `10`,
  making debugging far easier.
- Adding a state later is a one-line change to the type declaration.

Always use enumerated types for state variables; never represent states as raw
integers or bit vectors.

---

## 6. From state diagram to VHDL: a worked micro-example

A two-state FSM with one input `btn`: while in `IDLE`, `led = '0'`; when
`btn = '1'`, move to `ACTIVE` and `led = '1'`; stay in `ACTIVE` until
`btn = '0'`, then return to `IDLE`.

```
        btn='1'                    btn='0'
  IDLE ---------> ACTIVE          ACTIVE ---------> IDLE
  led=0          led=1
```

Translation:

```vhdl
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity btn_fsm is
    port (
        clk   : in  std_logic;
        reset : in  std_logic;
        btn   : in  std_logic;
        led   : out std_logic
    );
end btn_fsm;

architecture rtl of btn_fsm is
    type state_type is (IDLE, ACTIVE);
    signal current_state, next_state : state_type;
begin

    state_reg : process (clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                current_state <= IDLE;
            else
                current_state <= next_state;
            end if;
        end if;
    end process;

    comb : process (current_state, btn)   -- btn affects output, so it is listed
    begin
        next_state <= current_state;       -- defaults
        led        <= '0';

        case current_state is
            when IDLE =>
                led <= '0';
                if btn = '1' then
                    next_state <= ACTIVE;
                end if;

            when ACTIVE =>
                led <= '1';
                if btn = '0' then
                    next_state <= IDLE;
                end if;

            when others =>
                next_state <= IDLE;
        end case;
    end process;

end rtl;
```

The mapping is mechanical: one `when` arm per state, output assignments inside
the arm (Moore — output depends only on state), `next_state` set inside an `if`
for each outgoing condition, and a default for every output before the `case`.
Applied consistently, this translates any state diagram into working VHDL.

---

## 7. Checklist before writing any FSM

Complete this on paper before opening an editor:

- [ ] Draw the state diagram with every state named.
- [ ] Label every transition arrow with its condition.
- [ ] Write the output values in each state (Moore) or on each arrow (Mealy).
- [ ] Identify the reset/initial state.
- [ ] Write down the entity ports.
- [ ] Confirm every output is defined in every state.

A complete diagram makes the VHDL almost mechanical and lets you debug by
comparing the waveform directly against the diagram.

---

Next: **Module 2 — The Traffic Light Controller (Moore FSM)**
