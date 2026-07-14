# Week 8 — Starter Library

```
starter_library/
├── README.md                  ← this file
├── washu2_ram.vhd             ← 4096×16 synchronous RAM, preloaded with the
│                                 Module 6 §3 integration test program
├── washu2_cpu_reference.vhd   ← complete Week 8 reference implementation
│                                 (read AFTER writing your own — see Module 7 §"Comparing...")
└── tb_washu2_week8.vhd        ← testbench (provided — add your own assert checks)
```

This is the same three-file pattern as the Week 7 starter library, with
the RAM's default program updated and the reference implementation
extended to all 14 instructions.

---

## washu2_ram.vhd

Identical infrastructure to the Week 7 RAM (4096 × 16-bit, one-cycle
registered read latency, edit only the section marked
`-- PROGRAM: edit this initialiser`). The default initializer now holds
the Module 6 §3 integration test program instead of the Week 7 self-test,
so you can drop this file in unmodified for Exercise 4.

To run any other exercise program (Module 3, 4, or 5), replace the
initializer with that module's program before compiling.

---

## washu2_cpu_reference.vhd

The complete, working Week 8 CPU — all 22 states, all 14 instructions,
every process and concurrent statement assembled.

**Includes one fix relative to the original Week 7 wiring:** the RAM's
`addr` input is driven by a small combinational mux (`ram_addr`) instead
of being tied directly to `mar`. The original `addr => mar(11 downto
0)` wiring reads memory one state too early relative to when the RAM's
registered output actually becomes valid — it happens to still work for
the Week 7 self-test by coincidence, but breaks for real once Week 8
chains several distinct memory reads together. See Module 7's errata
section for the full explanation and the exact diff. If your own
`washu2_cpu.vhd` still has the original wiring, apply the same fix
before running the Week 8 exercises.

**Use this only to check your own implementation after you have written
it.** Reading it before attempting your own solution defeats the
purpose of the exercise, and you will not be able to explain it at the
viva if you haven't derived it yourself from the module notes. If your
own file disagrees with this one, first re-read the relevant module —
there should be no surprises here if you've followed Modules 2–5.

---

## tb_washu2_week8.vhd

A provided testbench that drives `clk`, applies reset, waits for
`done`, and includes a reset-recovery phase, following the same
structure as `tb_washu2_week7.vhd`. Add your own `assert` statements
for each exercise program you test.

Since `washu2_cpu` has no debug output ports, use ModelSim's Objects
panel to add internal signals (`current_state`, `pc`, `mar`, `mbr`,
`ir`, `acc`, `the_bus`) to the waveform manually, and drill into
`uut/ram_inst/ram_mem` in the hierarchy browser to inspect memory
contents directly (needed for the ISTORE checks in Module 5/6).
