# Week 4 — Starter Library

```
starter_library/
├── README.md                       # this file
├── tb_alu4.vhd                     # provided testbench for the Module 2 ALU example
├── tb_ram16x8.vhd                  # provided testbench for the Module 4 RAM example
└── tb_template_combinational.vhd   # template for writing ALU-style testbenches
```

## tb_alu4.vhd

A complete self-checking testbench for the `alu4` entity from Module 2.
Add alongside `alu4.vhd` and simulate. Uses `assert` statements — check the
ModelSim transcript panel for pass/fail messages (silence = all pass).

For **Exercise 1** (`alu4_extended`), you must write your own testbench.
This file shows the pattern; adapt it.

## tb_ram16x8.vhd

A complete testbench for the `ram16x8` entity from Module 4. Covers write,
read-back, overwrite, and `valid` timing. Use it to understand the timing
before writing your own testbench for Exercise 2 (`ram8x8`).

## tb_template_combinational.vhd

A minimal starting skeleton for testbenches of purely combinational circuits
(like ALUs). No clock generator — inputs change via `wait for N ns`. Copy,
rename, and fill in the TODO sections.

## What is NOT provided

No starter designs for Exercise 1, Exercise 2, or the optional exercise.
All three are written from scratch. The provided testbenches (`tb_alu4.vhd`
and `tb_ram16x8.vhd`) are for the **module examples**, not the exercises —
do not simply copy them; the port names and operations differ.
