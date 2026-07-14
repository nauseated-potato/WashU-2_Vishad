# Week 7 — Starter Library

```
starter_library/
├── README.md                  ← this file
├── washu2_ram.vhd             ← 4096×16 synchronous RAM (edit program initialiser only)
├── washu2_cpu_reference.vhd   ← complete reference implementation (read AFTER writing your own)
└── tb_washu2_week7.vhd        ← testbench (provided — add your own assert checks)
```

---

## washu2_ram.vhd

A 4096-location × 16-bit synchronous RAM. Works identically to the
`ram32x8.vhd` from Week 5, scaled up to 16-bit data and 12-bit address.

**Edit only the section marked `-- PROGRAM: edit this initialiser`.**
Replace the placeholder content with your encoded instructions and data.

Port summary:
```
clk      : in  std_logic
we       : in  std_logic
addr     : in  std_logic_vector(11 downto 0)
data_in  : in  std_logic_vector(15 downto 0)
data_out : out std_logic_vector(15 downto 0)
```

One-cycle registered read latency — the same rule as every week since
Week 4. The FSM's three-state fetch cycle (`fetch1`/`fetch2`/`fetch3`)
is designed around this latency.

---

## washu2_cpu_reference.vhd

The complete, working Week 7 CPU implementation — all five instructions,
all processes, all concurrent statements assembled.

**Use this only to check your own implementation after you have written it.**
Reading it before attempting your own solution defeats the purpose of the
exercise. The module notes tell you every design decision; there should be
no surprises in this file if you have read the modules carefully.

---

## tb_washu2_week7.vhd

A provided testbench that drives `clk`, applies reset, and waits for
`done`. Add your own `assert` statements for each program you test, following
the patterns in Module 7.

Since `washu2_cpu` has no debug output ports, use ModelSim's Objects panel
to add internal signals (`current_state`, `pc`, `mar`, `mbr`, `ir`, `acc`,
`the_bus`) to the waveform manually. See Module 7 §5 for the exact steps.
