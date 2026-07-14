# Week 7 · Module 9 — Datapath Diagram, FSM Diagram, and Cycle Tables

This module provides three visual references that make the rest of Week 7
easier to implement and debug. Print or sketch these before writing code
and keep them next to your screen while simulating.

---

## 1. Complete datapath diagram

Every arrow is a signal path. Bold labels are the `bus_X` enables that
select which source drives `the_bus` each cycle. Register load enables
(`_ld`) are shown on the left of each register.

```
                        ┌─────────────────────────────────────────────┐
                        │           CONTROL FSM (Process 2)            │
                        │  Outputs: bus_X enables, _ld enables,        │
                        │           pc_inc, mem_we, alu_op, done_int   │
                        └──────────────────────┬──────────────────────┘
                                               │ (control signals)
          ┌────────────────────────────────────┼──────────────────────────────────┐
          │                                    ▼                                  │
          │   ┌────────┐   bus_pc    ╔══════════════════╗   bus_mbr   ┌────────┐  │
          │   │        │ ──────────► ║                  ║ ◄────────── │        │  │
  pc_inc ─┤   │   PC   │            ║    the_bus        ║             │  MBR   │ ◄┤─ mbr_ld
          │   │        │ ◄── pc_ld ─║  (16-bit shared) ║             │        │  │
          │   └────┬───┘            ║                  ║             └────┬───┘  │
          │        │ (to MAR/RAM)   ║      bus_acc ─────╫─── ACC          │      │
          │        │                ║  bus_ir_lower ────╫─── IR[11:0]     │ (to ALU,
          │        │                ║    bus_ir_se ─────╫─── sign_ext     │  to bus)
          │        │                ║     bus_alu ──────╫─── ALU result   │
          │        │                ║     bus_mem ──────╫─── RAM output   │
          │        │                ╚══════════════════╝                  │
          │        │                        │                             │
          │        │              ┌─────────┼────────────┐               │
          │        │   mar_ld ───►│   MAR   │            │  ir_ld       │
          │        │              └────┬────┘            │◄─────────────►│ IR
          │        │                   │ (addr)          │               │
          │        │              ┌────▼─────────────┐   │  acc_ld      │
          │        └──────────────►                  │   │◄─────────────►│ ACC
          │                       │   washu2_ram     │   │               │
          │                       │   (4096 × 16)    │   │               │
          │                       │                  │   │          ┌───▼───┐
          │                       │  data_in=the_bus │   │          │  ALU  │
          │                       │  data_out=       ├───┘ mbr_ld  │A=acc  │
          │                       │    mem_data_out  │◄──────────── │B=mbr  │
          │                       │  we=mem_we       │             └───────┘
          │                       │  addr=mar[11:0]  │
          │                       └──────────────────┘
          └────────────────────────────────────────────────────────────────────────
```

**Key rules to read from this diagram:**

1. Every register receives from `the_bus`. No register reads another
   register directly.
2. `the_bus` is driven by exactly one `bus_X` signal per cycle.
3. The RAM address always comes from `MAR[11:0]`.
4. The RAM write data always comes from `the_bus` (`data_in = the_bus`).
5. The ALU reads `acc` (A) and `mbr` (B) — not `the_bus`.
6. `PC` has two write paths: `pc_ld` (from bus) and `pc_inc` (incrementer).

---

## 2. FSM state transition diagram (Week 7)

```
         reset
           │
           ▼
      ┌─────────┐
      │resetState│
      └────┬────┘
           │ (always)
           ▼
      ┌────────┐
  ┌──►│ fetch1 │  MAR ← PC
  │   └────┬───┘
  │         │
  │         ▼
  │   ┌────────┐
  │   │ fetch2 │  MBR ← mem[MAR],  PC ← PC+1
  │   └────┬───┘
  │         │
  │         ▼
  │   ┌────────┐
  │   │ fetch3 │  IR ← MBR,  dispatch on mbr[15:12]
  │   └────┬───┘
  │         │
  │    ┌────┴─────────────────────────────────┐
  │    │    │           │          │           │
  │  0000  0001        0010       0011        0100
  │  HALT NEGATE      CLOAD      DLOAD      DSTORE
  │    │    │           │          │           │
  │    ▼    ▼           ▼          └────┐ ┌───┘
  │  halt1 neg1       cload1           │ │
  │         │                      ┌───▼─▼───┐
  │         ▼                      │ direct1  │  MAR ← IR[11:0]
  │        neg2                    └────┬─────┘
  │                                     │
  │                                ┌────▼─────┐
  │                                │ direct2  │  MBR ← mem[MAR]
  │                                └──┬────┬──┘
  │                                   │    │
  │                                 0011  0100
  │                                DLOAD DSTORE
  │                                   │    │
  │                               ┌───▼─┐ ┌▼──────┐
  │                               │load1│ │store1 │
  │                               └─────┘ └───────┘
  │    │        │          │          │         │
  └────┴────────┴──────────┴──────────┴─────────┘
       (all states → fetch1 to begin next instruction)
```

**How to read this during debugging:**

- If `current_state` jumps somewhere unexpected after `fetch3`, the
  `mbr(15 downto 12)` decode is wrong. Check the `when fetch3` case.
- If `current_state` goes to `load1` instead of `store1` for DSTORE,
  the `direct2` dispatch is wrong. Check the `when direct2` case arm.
- If `current_state` loops in `halt1` and never leaves, that is correct
  behaviour — HALT stays there until reset.

---

## 3. Cycle-by-cycle bus tables

For each instruction, this table shows exactly what drives the bus and
what latches from it each cycle. Compare directly against your waveform.

### Fetch cycle (all instructions)

| Cycle | State | Bus source (`bus_X='1'`) | Latches (`_ld='1'`) | Other |
|---|---|---|---|---|
| 1 | fetch1 | `bus_pc` → `pc` | `mar_ld` → MAR = PC | — |
| 2 | fetch2 | `bus_mem` → `mem_data_out` | `mbr_ld` → MBR = instruction | `pc_inc`: PC++ |
| 3 | fetch3 | `bus_mbr` → MBR value | `ir_ld` → IR = instruction | dispatch on `mbr[15:12]` |

### HALT (4 cycles total)

| Cycle | State | Bus source | Latches | Other |
|---|---|---|---|---|
| 1–3 | fetch1,2,3 | (see fetch table) | | |
| 4 | halt1 | none | none | `done_int='1'` |

### NEGATE (5 cycles total)

| Cycle | State | Bus source | Latches | Other |
|---|---|---|---|---|
| 1–3 | fetch1,2,3 | (see fetch table) | | |
| 4 | neg1 | `bus_alu` → `NOT(acc)` | `acc_ld` → ACC = NOT(old_acc) | `alu_op=ALU_NOT` |
| 5 | neg2 | `bus_alu` → `acc+1` | `acc_ld` → ACC = NOT(old_acc)+1 | `alu_op=ALU_INC` |

### CLOAD K (4 cycles total)

| Cycle | State | Bus source | Latches | Other |
|---|---|---|---|---|
| 1–3 | fetch1,2,3 | (see fetch table) | | |
| 4 | cload1 | `bus_ir_se` → sign_ext(IR[11:0]) | `acc_ld` → ACC = constant | — |

### DLOAD addr (6 cycles total)

| Cycle | State | Bus source | Latches | Other |
|---|---|---|---|---|
| 1–3 | fetch1,2,3 | (see fetch table) | | |
| 4 | direct1 | `bus_ir_lower` → IR[11:0] (zero-ext) | `mar_ld` → MAR = operand addr | — |
| 5 | direct2 | `bus_mem` → mem[MAR] | `mbr_ld` → MBR = mem[addr] | — |
| 6 | load1 | `bus_mbr` → MBR | `acc_ld` → ACC = MBR | — |

### DSTORE addr (6 cycles total)

| Cycle | State | Bus source | Latches | Other |
|---|---|---|---|---|
| 1–3 | fetch1,2,3 | (see fetch table) | | |
| 4 | direct1 | `bus_ir_lower` → IR[11:0] | `mar_ld` → MAR = operand addr | — |
| 5 | direct2 | `bus_mem` → mem[MAR] | `mbr_ld` → MBR (discarded) | — |
| 6 | store1 | `bus_acc` → ACC | `mbr_ld` → MBR = ACC | `mem_we`: writes ACC to mem[MAR] |

**Using these tables for debugging:**

Pick the failing instruction. Open the waveform. For each cycle in the
table, check:
1. Is `current_state` the expected state?
2. Is exactly the listed `bus_X` signal `'1'`?
3. Is the listed register updated with the expected value?

The first row where something disagrees is where the bug is.

---

## 4. Self-test program

Load this program to verify all five Week 7 instructions before writing
your own exercise programs. If this program gives the wrong result,
there is a bug in the CPU — do not move to the exercises until it passes.

**Program:**
```
Address 0x000: CLOAD 5       → 0x2005
Address 0x001: NEGATE        → 0x1000
Address 0x002: DSTORE 0x010  → 0x4010
Address 0x003: CLOAD 0       → 0x2000   (clear ACC to prove DLOAD works independently)
Address 0x004: DLOAD 0x010   → 0x3010
Address 0x005: HALT          → 0x0000
Address 0x010: 0x0000        (data slot — written by DSTORE)
```

**Encoding verification:**

| Address | Instruction | Binary | Hex |
|---|---|---|---|
| 0x000 | CLOAD 5 | `0010 000000000101` | `0x2005` |
| 0x001 | NEGATE | `0001 000000000000` | `0x1000` |
| 0x002 | DSTORE 0x010 | `0100 000000010000` | `0x4010` |
| 0x003 | CLOAD 0 | `0010 000000000000` | `0x2000` |
| 0x004 | DLOAD 0x010 | `0011 000000010000` | `0x3010` |
| 0x005 | HALT | `0000 000000000000` | `0x0000` |

**Expected results after HALT:**
```
ACC        = 0xFFFB   (−5 in 16-bit two's complement)
mem[0x010] = 0xFFFB   (stored by DSTORE)
PC         = 0x0006   (incremented past HALT in fetch2)
done       = '1'
```

Verify: `NOT(0x0005) = 0xFFFA`, `0xFFFA + 1 = 0xFFFB` ✓
And: `0x0005 + 0xFFFB = 0x10000` → lower 16 bits = `0x0000` ✓

**RAM initialiser:**
```vhdl
signal ram_mem : ram_type := (
    0   => x"2005",   -- CLOAD 5
    1   => x"1000",   -- NEGATE
    2   => x"4010",   -- DSTORE 0x010
    3   => x"2000",   -- CLOAD 0
    4   => x"3010",   -- DLOAD 0x010
    5   => x"0000",   -- HALT
    16  => x"0000",   -- data slot (0x010 = 16 decimal)
    others => x"0000"
);
```

---

## 5. Testbench assertions for bus safety

Add these assertions to `tb_washu2_week7.vhd` after the existing checks.
They fire immediately in simulation if the CPU violates the one-driver-per-
cycle bus rule or drives PC from two sources at once. Catching these early
saves significant debugging time.

```vhdl
    -- --------------------------------------------------------
    -- Bus safety monitor process
    -- Checks on every rising edge that at most one bus driver
    -- is active and PC is not double-driven.
    -- Requires washu2_cpu's internal signals to be visible.
    -- If you have NOT added debug ports, add these signals to
    -- the waveform via ModelSim's Objects panel instead and
    -- visually check for 'X' on the_bus.
    -- --------------------------------------------------------
    -- NOTE: these assertions work only if you add debug output
    -- ports for the bus_X signals (similar to Week 5 debug ports).
    -- The pattern is shown here for reference; adapt to your
    -- actual port names.
    --
    -- bus_monitor : process
    -- begin
    --     wait until rising_edge(clk);
    --
    --     -- Count active bus drivers (should be 0 or 1)
    --     assert (
    --         (to_integer(unsigned'(""
    --             & dbg_bus_pc & dbg_bus_mbr & dbg_bus_acc
    --             & dbg_bus_ir_lower & dbg_bus_ir_se
    --             & dbg_bus_alu & dbg_bus_mem))
    --         ) <= 1
    --     report "BUS CONTENTION: more than one bus driver active"
    --     severity error;
    --
    --     -- PC must not be both loaded from bus and incremented
    --     assert not (dbg_pc_ld = '1' and dbg_pc_inc = '1')
    --     report "PC CONFLICT: pc_ld and pc_inc both asserted"
    --     severity error;
    --
    -- end process bus_monitor;
```

Since `washu2_cpu` has no debug ports in the base design, the easiest
way to apply these checks is to observe `the_bus` in ModelSim: if it ever
shows `'X'`, bus contention has occurred. The `'X'` value is ModelSim's
way of showing two conflicting drivers — add `the_bus` to your waveform
and check it stays `'0'` or a valid value at all times.
