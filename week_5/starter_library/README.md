# Week 5 — Starter Library

```
starter_library/
├── README.md                  ← this file
├── alu8.vhd                   ← 8-bit ALU (provided — use as-is)
├── ram32x8.vhd                ← 32×8 RAM with program initialiser (edit to load your program)
└── tb_template_datapath.vhd   ← testbench template for mini_cpu
```

---

## alu8.vhd — 8-bit ALU

A direct extension of the Week 4 `alu4` to 8-bit operands. Supports:

| op    | Operation |
|-------|-----------|
| `"000"` | ADD (a + b) |
| `"001"` | SUB (a − b) |
| `"010"` | AND |
| `"011"` | OR  |
| `"100"` | NOT a |
| `"101"` | NEGATE (−a) |
| `"110"` | XOR |
| `"111"` | PASS (output = b, used for LOAD) |

**Do not modify this file.** Use it as-is for both the required exercise
and the optional SUB extension (which uses op `"001"`).

---

## ram32x8.vhd — 32×8 Synchronous RAM

A 32-location × 8-bit synchronous RAM with a pre-loaded program
initialiser. **This is the file you edit** to load your program for each
exercise.

Find the section marked `-- PROGRAM: edit this initialiser` and replace
the placeholder contents with your encoded instructions and data.

The RAM uses separate `data_in` and `data_out` ports (no bidirectional bus)
for simplicity. One-cycle read latency applies (same as Week 4).

**Port summary:**
```
clk      : in  std_logic
we       : in  std_logic
addr     : in  std_logic_vector(4 downto 0)
data_in  : in  std_logic_vector(7 downto 0)
data_out : out std_logic_vector(7 downto 0)
```

---

## tb_template_datapath.vhd — Testbench Template

A starting skeleton for `mini_cpu` testbenches. The clock generator, reset
phase, and `wait until done` pattern are pre-written. Fill in the TODO
sections with your specific assert checks.

Copy this to `tb_mini_cpu_ex1.vhd` (or `tb_mini_cpu_sub.vhd` for the
optional exercise), rename the entity, and fill in:
- The port map (include the debug ports you added to `mini_cpu`).
- The expected final values for `dbg_acc` and `dbg_pc`.

---

## What is NOT provided

- `mini_cpu.vhd` — you write this, following Module 3.
- Testbenches for the exercises — you write these, following Module 5.
- Any solved version of the exercises.
