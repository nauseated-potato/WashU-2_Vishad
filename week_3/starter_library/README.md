# Week 3 — Starter Library

Three files are provided: two complete, ready-to-run testbenches and one
reusable template.

## Contents

```
starter_library/
├── tb_traffic_light.vhd     # complete testbench for the Module 2 worked example
├── tb_vending_machine.vhd   # complete testbench for Exercise 1
└── tb_template_fsm.vhd      # template for the testbenches you write yourself
```

## tb_traffic_light.vhd

A complete, correct testbench for the `traffic_light` design built in
Module 2. The traffic light is a worked example, not an exercise — this file
is provided so you can study a full FSM testbench (clock generator, DUT
instantiation, phased stimulus, mid-run reset) before writing your own. Add it
alongside your `traffic_light.vhd` to run it.

## tb_vending_machine.vhd

A complete testbench for Exercise 1. Add it alongside your
`vending_machine.vhd` and simulate. For the port map to compile, your entity
must use exactly these names:

```
entity vending_machine
    port (
        clk      : in  std_logic;
        reset    : in  std_logic;
        coin5    : in  std_logic;
        coin10   : in  std_logic;
        dispense : out std_logic;
        change   : out std_logic
    );
```

## tb_template_fsm.vhd

The starting point for the testbenches you write yourself —
`tb_seq_det_101.vhd` (Exercise 2) and `tb_combo_lock.vhd` (optional). Copy it,
rename it, instantiate your design, and replace the placeholder stimulus with
input aligned to clock edges using `wait until rising_edge(clk)`.

## Which testbench comes from where

| Design | Testbench |
|---|---|
| `traffic_light` (Module 2 example) | provided: `tb_traffic_light.vhd` |
| `vending_machine` (Exercise 1) | provided: `tb_vending_machine.vhd` |
| `seq_det_101_nonoverlap` (Exercise 2) | you write it, from the template |
| `combo_lock` (optional) | you write it, from the template |

## What is not provided

No design files for any exercise. The vending machine, sequence detector, and
combination lock are all written from scratch using the two-process template
from Modules 1 and 2.
