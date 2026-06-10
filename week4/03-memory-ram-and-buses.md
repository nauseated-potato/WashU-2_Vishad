# Week 4 · Module 3 — Memory: RAM, ROM, and How Hardware Stores Data

The ALU computes. Memory *remembers*. A CPU without memory cannot store
intermediate results, cannot hold the program it is running, and cannot
communicate data between instructions. This module explains how hardware
memory works from first principles, then shows how to describe a synchronous
RAM in VHDL.

> **Video — How computer memory works (TED-Ed, 5 min):**
> [How computer memory works — Kanawat Senanan](https://www.youtube.com/watch?v=p3q5zWCw8J4)
> *(Visual, concept-level — good before reading this module)*
>
> **Video — VHDL RAM implementation (FPGA tutorial):**
> [Implementing RAM in VHDL](https://www.youtube.com/watch?v=m4s3gYDEcAY)
> *(Covers single-port synchronous RAM, the same type built in Module 4)*

---

## 1. RAM vs ROM

**RAM (Random Access Memory):** can be both read and written. "Random
access" means any address can be accessed in the same time as any other —
unlike a tape or sequential storage. The VHDL designs in this course are
all RAM.

**ROM (Read-Only Memory):** can only be read. In FPGAs, ROM is typically
implemented using a `case` statement that maps address to a constant value
(a lookup table). The WashU-2 CPU's program is stored in a ROM-like
structure.

**Volatile vs non-volatile:** most RAM loses its content when power is
removed (volatile). The FPGA's built-in block RAMs are volatile. The
configuration flash is non-volatile.

---

## 2. How RAM works: address, data, and control signals

Every RAM has the same interface, regardless of size:

| Signal | Direction | Purpose |
|---|---|---|
| `addr` | in | Selects which memory location to access |
| `data` | in/out | The value being written or read |
| `we` (write enable) | in | `'1'` → write this cycle; `'0'` → read |
| `clk` | in | Synchronises the operation to a clock edge |

The **address width** determines how many locations the RAM has:
an N-bit address gives 2^N locations.

The **data width** determines how many bits are stored per location.

For a **16×8 RAM**: 16 locations (4-bit address → `2^4 = 16`) each storing
8 bits (1 byte).

```
Address 0000: [  byte 0  ]
Address 0001: [  byte 1  ]
...
Address 1111: [  byte 15 ]
```

This is exactly the RAM used in the WashU-2 CPU for data storage.

---

## 3. Synchronous vs asynchronous RAM

**Asynchronous RAM:** the output changes immediately when the address
changes, with no clock. Old SRAMs (static RAM chips) work this way. Easy
to reason about for small designs, but causes problems at high speed because
of signal propagation delays.

**Synchronous RAM:** the output (on read) is captured at the rising clock
edge, and writes also occur at the rising edge. All modern FPGA block RAMs
are synchronous. The Cyclone IV on the DE10-Lite has dedicated block RAM
(M9K blocks) that the synthesiser infers automatically when it recognises
the synchronous RAM pattern.

The rule for inferring block RAM in Quartus: write the process such that
**both read and write are inside `if rising_edge(clk) then`**. If either
is outside, Quartus falls back to LUT-based RAM, which is wasteful.

---

## 4. Read-during-write behaviour

When `we='1'` and a read is requested at the same address, two behaviours
are possible:

**Write-first (new data):** the output shows the *newly written* data on
that same clock edge.

**Read-first (old data):** the output shows the *old* data stored at that
address before the write updates it.

Quartus block RAMs can be configured for either. The standard template for
this course uses **read-first** (the read happens before the write takes
effect), which is the most common and easiest to reason about:

```vhdl
if rising_edge(clk) then
    if we = '1' then
        ram(to_integer(unsigned(addr))) <= data_in;
    end if;
    data_out <= ram(to_integer(unsigned(addr)));  -- reads old value if same addr
end if;
```

---

## 5. The array type: `type ram_type is array ...`

A RAM in VHDL is declared using an **array type** — a type whose elements
are accessed by index (address). This is how you declare a 16×8 RAM:

```vhdl
-- Step 1: define the type
type ram_type is array (0 to 15) of std_logic_vector(7 downto 0);
-- "An array of 16 elements, each an 8-bit std_logic_vector, indexed 0..15"

-- Step 2: declare a signal of that type
signal ram_mem : ram_type;
```

To access element N: `ram_mem(N)`.
To write address 3 with value `"10110010"`:

```vhdl
ram_mem(3) <= "10110010";
```

To read address 7 into an output:

```vhdl
data_out <= ram_mem(7);
```

In practice the address comes from a port signal, not a literal. Because
`addr` is `std_logic_vector`, convert it to `integer` for the array index:

```vhdl
data_out <= ram_mem(to_integer(unsigned(addr)));
```

---

## 6. Memory initialisation

When the FPGA powers up, RAM contents are undefined (could be anything).
For simulation and for the WashU-2 CPU, it is useful to pre-load the RAM
with known values. VHDL allows initialising an array type signal at
declaration:

```vhdl
signal ram_mem : ram_type := (
    0  => "00000001",  -- address 0 holds 1
    1  => "00000010",  -- address 1 holds 2
    2  => "00000011",  -- address 2 holds 3
    others => (others => '0')  -- all other addresses hold 0
);
```

The `others` clause fills in any unspecified elements. For simulation,
always initialise; for synthesis, the synthesiser may or may not preserve
the initial values depending on the target device and settings.

---

## 7. Tri-state buffers and bidirectional buses

The WashU-2 CPU uses a **bidirectional data bus**: a single set of wires
that carries data in both directions — from RAM to CPU (read) or from CPU
to RAM (write). This is common in real bus architectures.

In VHDL, a bidirectional bus uses `std_logic` signals with a **tri-state
buffer**. A tri-state buffer has three output states:
- `'0'` — drive low
- `'1'` — drive high
- `'Z'` — **high-impedance**: the driver disconnects; the bus floats

The `'Z'` (high-Z) state is what makes a bidirectional bus possible: when
a device is not driving the bus, it sets its output to `'Z'`, so multiple
devices can share the same wires without short-circuiting.

```
CPU side:          RAM side:
           ┌──────────────────────┐
  data_in ─┤ tri-state buffer     ├─ shared bus ─── data_out (from RAM)
           │ enabled when writing │
           └──────────────────────┘
```

In VHDL, `'Z'` is a valid `std_logic` value. The bidirectional port uses
mode `inout`:

```vhdl
port (
    data_bus : inout std_logic_vector(7 downto 0)  -- bidirectional
);
```

Driving it:

```vhdl
-- When writing: drive the bus
data_bus <= cpu_data_out;

-- When reading: disconnect (tri-state), let the RAM drive
data_bus <= (others => 'Z');

-- Reading from the bus (regardless of who is driving):
cpu_data_in <= data_bus;
```

The `'Z'` state is only meaningful in simulation and for FPGA I/O pins.
Internal FPGA signals cannot actually be tri-stated — on-chip buses use
multiplexers instead. For this week's RAM design, the bidirectional port
uses `inout`, and the testbench must handle driving the bus correctly from
both sides.

> **Video — Tri-state buffers and bus contention explained:**
> [Tri-State Buffers & Bus Design](https://www.youtube.com/watch?v=3uXD_JFdqCM)
> *(Explains why 'Z' is needed, what bus contention looks like, and how to avoid it)*

---

## 8. Summary: memory concepts checklist

Before starting Module 4, you should be able to answer these:

1. What is the difference between RAM and ROM?
2. A 16×8 RAM has a 4-bit address. What determines each of those numbers?
3. What happens to RAM contents when the FPGA loses power?
4. Why does synchronous RAM have better timing properties than asynchronous?
5. What does `'Z'` mean in VHDL, and when would you use it?
6. Why can't two devices both drive a bus to `'1'` and `'0'` simultaneously?

---

Next: **Module 4 — Building the 16×8 RAM with Bidirectional Bus**
