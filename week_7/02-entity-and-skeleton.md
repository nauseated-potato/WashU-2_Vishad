# Week 7 · Module 2 — Entity, Ports, and Architecture Skeleton

This module gets the file compiling with nothing inside it yet — just the
entity, libraries, and an empty architecture. Starting here means any typo
in the structural boilerplate is caught immediately, before it is buried
under hundreds of lines of signal declarations.

---

## 1. Libraries

The WashU-2 CPU needs `STD_LOGIC_1164` for signal types and `NUMERIC_STD`
for arithmetic (same as every week since Week 4):

```vhdl
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
```

---

## 2. Entity

The CPU entity has three ports. The program to execute is stored inside the
RAM component, so no instruction input is needed externally:

```vhdl
entity washu2_cpu is
    port (
        clk   : in  std_logic;
        reset : in  std_logic;
        done  : out std_logic    -- '1' when HALT instruction reached
    );
end washu2_cpu;
```

This is identical in structure to the Week 5 `mini_cpu` entity — the
interface to the outside world is the same regardless of how many
instructions are supported internally.

---

## 3. Architecture opening

```vhdl
architecture rtl of washu2_cpu is

    -- signal and constant declarations go here (Module 3)

begin

    -- concurrent statements and processes go here (Modules 4-6)

end rtl;
```

At this point the file should compile with no errors (an empty architecture
is legal VHDL). Compile now and confirm before proceeding.

---

## 4. What goes between `is` and `begin`

The declarative region will contain, in this order:

1. *(No component declaration needed — direct entity instantiation is used, see Module 3 §1.)*
2. **FSM state type** — the enumerated type for all ~17 states.
3. **State signals** — `current_state` and `next_state`.
4. **Datapath register signals** — `acc`, `pc`, `mar`, `mbr`, `ir`.
5. **Bus signals** — `the_bus` (the shared bus wire) and all `bus_X` enables.
6. **Internal wires** — `alu_result`, `mem_data_out`, `ir_opcode`, `ir_addr`.
7. **Control signals** — all `_ld`, `_inc`, `mem_we`, `alu_op`, `done_int`.
8. **Constants** — opcode values, ALU operation codes.
9. **Flag signals** — `zero_flag`, `pos_flag`, `neg_flag`.

Module 3 covers all of these in detail.

---

## 5. What goes between `begin` and `end rtl`

The architecture body will contain, in this order:

1. **RAM instantiation** — `entity work.washu2_ram port map (...)`.
2. **Bus multiplexer** — a concurrent `with ... select` that drives `the_bus`.
3. **IR field extraction** — two concurrent assignments splitting `ir`.
4. **ALU** — a combinational process computing `alu_result`.
5. **Flag logic** — three concurrent signal assignments from `acc`.
6. **Register process** (Process 1) — clocked; updates all registers and state.
7. **Control FSM** (Process 2) — combinational; sets all control signals.
8. **Output driver** — `done <= done_int;`.

Modules 4–6 cover each of these in detail.

---

## 6. Full skeleton to start from

Copy this exactly into `washu2_cpu.vhd` and confirm it compiles before
reading Module 3:

```vhdl
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity washu2_cpu is
    port (
        clk   : in  std_logic;
        reset : in  std_logic;
        done  : out std_logic
    );
end washu2_cpu;

architecture rtl of washu2_cpu is

    -- ================================================================
    -- DECLARATIONS (fill in following Module 3)
    -- ================================================================

begin

    -- ================================================================
    -- ARCHITECTURE BODY (fill in following Modules 4-6)
    -- ================================================================

    done <= '0';    -- placeholder: remove when done_int is wired up

end rtl;
```

The `done <= '0'` placeholder stops Quartus complaining about an
undriven output. Replace it in Module 6 once `done_int` exists.

---

Next: **Module 3 — Signals, Constants, and State Type**
