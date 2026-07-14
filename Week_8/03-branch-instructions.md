# Week 8 · Module 3 — Branch Instructions (BRANCH, BRZERO, BRPOS, BRNEG)

`fetch3` already routes all four branch opcodes to a single shared state,
`branch1` (see Week 7 Module 6 Stage A — this dispatch was written before
Week 8 even started). Your job this module is to fill in the body of
`branch1` itself.

---

## 1. Why one state serves four instructions

Look at the bus and register activity each branch type needs:

| Instruction | Bus source | Register write |
|---|---|---|
| `BRANCH`  | `IR[11:0]` (target address) | `PC` — always |
| `BRZERO`  | `IR[11:0]` | `PC` — only if `zero_flag='1'` |
| `BRPOS`   | `IR[11:0]` | `PC` — only if `pos_flag='1'` |
| `BRNEG`   | `IR[11:0]` | `PC` — only if `neg_flag='1'` |

The bus wiring is **identical** across all four — `bus_ir_lower='1'` in
every case. The only thing that differs is *whether* `pc_ld` fires, and
that depends on a flag selected by `ir_opcode`. Four nearly-identical
states would just duplicate the bus wiring three times over; one state
with an internal `case ir_opcode` on the load-enable captures the real
difference and nothing else.

This is the same reasoning behind sharing `direct1`/`direct2` across
DLOAD, DSTORE, ADD, AND, ILOAD, and ISTORE (Week 7 Module 6 Stage C) —
share the state whenever the bus source is the same and only the
side-effect changes.

---

## 2. Addressing: absolute, not relative

`bus_ir_lower` puts `IR[11:0]` **zero-extended** onto the bus (see the bus
mux in Week 7 Module 4 §3 — `(15 downto 12 => '0') & ir_addr`). This is
the same signal `direct1` uses for DLOAD/DSTORE operand addresses. So a
branch target is an **absolute** 12-bit instruction address (`0x000`–
`0xFFF`), computed the same way a data address is — not a PC-relative
offset. Keep this in mind when you hand-encode branch targets: you write
the destination address directly, not a distance to jump.

---

## 3. The flags (already declared, already wired)

These were defined combinationally back in Week 7 Module 4 and need no
changes:

```vhdl
zero_flag <= '1' when acc = x"0000"                     else '0';
pos_flag  <= '1' when acc(15) = '0' and acc /= x"0000"  else '0';
neg_flag  <= acc(15);
```

Note `pos_flag` explicitly excludes zero — `acc = 0x0000` is `zero_flag`,
never `pos_flag`. `neg_flag` is just the sign bit, so it's `'1'` for any
value with `acc(15)='1'`, zero or not (zero never has the sign bit set,
so this is unambiguous).

---

## 4. Register transfer

```
branch1:  if condition met:  PC ← IR[11:0]
          else:               PC unchanged (already incremented in fetch2)
```

If the branch is not taken, nothing happens in `branch1` beyond the
(harmless) `bus_ir_lower` drive — execution simply falls through to
`fetch1` and continues from the `PC` that `fetch2` already incremented.

---

## 5. FSM addition

Remove `branch1` from the Week 7 placeholder group and add:

```vhdl
            -- ====================================================
            -- branch1: PC ← IR[11:0], conditionally
            -- Shared by BRANCH, BRZERO, BRPOS, BRNEG.
            -- bus_ir_lower always drives the target address onto the
            -- bus; pc_ld is gated by the flag the specific opcode cares
            -- about. BRANCH itself has no condition — always taken.
            -- ====================================================
            when branch1 =>
                bus_ir_lower <= '1';    -- target address onto bus
                case ir_opcode is
                    when OP_BRANCH => pc_ld <= '1';          -- unconditional
                    when OP_BRZERO => pc_ld <= zero_flag;
                    when OP_BRPOS  => pc_ld <= pos_flag;
                    when OP_BRNEG  => pc_ld <= neg_flag;
                    when others    => pc_ld <= '0';          -- safety
                end case;
                next_state <= fetch1;
```

Remember `pc_ld` already has a default of `'0'` from the top of
`fsm_proc` (Week 7 Module 6). The `case` above only needs to *set* it
when a condition is met — but writing the explicit `when others =>
pc_ld <= '0'` keeps the branch logic self-contained and easy to read.

---

## 6. Test programs

Each program below CLOADs a value that sets a specific flag, then
branches, then either lands on a `CLOAD` that proves the jump happened
or falls through to one that proves it didn't. Encode each opcode as
`opcode & addr` on 16 bits, same as Module 2.

Opcodes used here: `BRANCH = 1001`, `BRZERO = 1010`, `BRPOS = 1011`,
`BRNEG = 1100`.

### BRANCH — unconditional, expect `acc = 0x0007`

```vhdl
0 => x"2005",   -- CLOAD 5        acc ← 0x0005
1 => x"9004",   -- BRANCH 0x004   PC ← 0x004 (always taken)
2 => x"20FF",   -- CLOAD 0xFF     (skipped)
3 => x"0000",   -- HALT           (skipped)
4 => x"2007",   -- CLOAD 7        acc ← 0x0007  (landed here)
5 => x"0000",   -- HALT
```
Encoding check: `1001 000000000100 = 0x9004` ✓

### BRZERO — taken, expect `acc = 0x0002`

```vhdl
0 => x"2000",   -- CLOAD 0        acc ← 0x0000
1 => x"A004",   -- BRZERO 0x004   zero_flag='1' → taken
2 => x"2001",   -- CLOAD 1        (skipped)
3 => x"0000",   -- HALT           (skipped)
4 => x"2002",   -- CLOAD 2        acc ← 0x0002  (landed)
5 => x"0000",   -- HALT
```

### BRZERO — not taken, expect `acc = 0x0009`

```vhdl
0 => x"2005",   -- CLOAD 5        acc ← 0x0005 (nonzero)
1 => x"A004",   -- BRZERO 0x004   zero_flag='0' → not taken
2 => x"2009",   -- CLOAD 9        acc ← 0x0009  (falls through, executes)
3 => x"0000",   -- HALT
```

### BRPOS — taken, expect `acc = 0x0003`

```vhdl
0 => x"2005",   -- CLOAD 5        acc ← 0x0005 (positive, nonzero)
1 => x"B004",   -- BRPOS 0x004    pos_flag='1' → taken
2 => x"2001",   -- (skipped)
3 => x"0000",   -- (skipped)
4 => x"2003",   -- CLOAD 3        acc ← 0x0003  (landed)
5 => x"0000",   -- HALT
```

### BRNEG — taken, expect `acc = 0x0005`

```vhdl
0 => x"2FFF",   -- CLOAD 0xFFF = CLOAD -1 (sign-extended)  acc ← 0xFFFF
1 => x"C004",   -- BRNEG 0x004    neg_flag = acc(15) = '1' → taken
2 => x"2001",   -- (skipped)
3 => x"0000",   -- (skipped)
4 => x"2005",   -- CLOAD 5        acc ← 0x0005  (landed)
5 => x"0000",   -- HALT
```

---

## 7. Compile checkpoint

- No latch warnings — every path through the `case ir_opcode` inside
  `branch1` assigns `pc_ld` (including `when others`).
- All five programs above produce the expected `acc`.
- Re-run every Week 7 test — nothing about `direct1`/`direct2` or the
  fetch cycle changed this module.

---

Next: **Module 4 — BRIND**
