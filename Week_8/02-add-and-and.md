# Week 8 · Module 2 — ADD and AND

ADD and AND share the `direct1`/`direct2` path already implemented in Week 7,
then branch into `add1` or `and1` where the ALU performs the operation.
Before writing the FSM arms, one change to the ALU process is required.

---

## 1. Required ALU change: B input from `the_bus` to `mbr`

In Week 7 the ALU used `the_bus` as its B input. That worked because:
- `NEGATE` (`ALU_NOT`, `ALU_INC`) ignores B entirely.
- `DLOAD`'s `load1` uses `bus_mbr='1'`, making `the_bus = mbr`, so
  `ALU_PASS_B` correctly returned `mbr` via the bus.

For `add1`, the FSM asserts `bus_alu='1'` (ALU result drives the bus).
If the ALU reads `the_bus` as B, and `the_bus = alu_result`, the circuit
becomes `alu_result = acc + alu_result` — a circular dependency.
ModelSim will show `'X'` on `alu_result` and `the_bus`.

**The fix:** change the ALU B input from `the_bus` to `mbr` directly.
MBR already holds the operand (loaded in `direct2`), so `acc + mbr` is
correct. Two changes in `washu2_cpu.vhd`:

**Change 1 — sensitivity list:**
```vhdl
-- Week 7:
alu_proc : process (acc, the_bus, alu_op)

-- Week 8:
alu_proc : process (acc, mbr, alu_op)
```

**Change 2 — replace `the_bus` with `mbr` inside `alu_proc`:**
```vhdl
    alu_proc : process (acc, mbr, alu_op)
    begin
        case alu_op is
            when ALU_ADD =>
                alu_result <= std_logic_vector(unsigned(acc) + unsigned(mbr));
            when ALU_AND =>
                alu_result <= acc and mbr;
            when ALU_NOT =>
                alu_result <= not acc;
            when ALU_INC =>
                alu_result <= std_logic_vector(unsigned(acc) + to_unsigned(1, 16));
            when ALU_PASS_B =>
                alu_result <= mbr;
            when others =>
                alu_result <= (others => '0');
        end case;
    end process alu_proc;
```

This does not break Week 7 instructions: `NEGATE` ignores B; `DLOAD`'s
`load1` uses `bus_mbr='1'` + `acc_ld='1'` directly (bypassing the ALU).

---

## 2. Register transfer sequences

**ADD addr:**
```
direct1:  MAR ← IR[11:0]
direct2:  MBR ← mem[MAR]
add1:     ACC ← ACC + MBR   (ALU computes, result drives bus, ACC latches)
```

**AND addr:**
```
direct1:  MAR ← IR[11:0]
direct2:  MBR ← mem[MAR]
and1:     ACC ← ACC AND MBR
```

---

## 3. FSM additions

The `direct2` case already exists. Confirm it routes ADD and AND correctly:

```vhdl
            when direct2 =>
                bus_mem    <= '1';
                mbr_ld     <= '1';
                case ir_opcode is
                    when OP_DLOAD  => next_state <= load1;
                    when OP_DSTORE => next_state <= store1;
                    when OP_ADD    => next_state <= add1;     -- routes here
                    when OP_AND    => next_state <= and1;     -- routes here
                    when OP_ILOAD  => next_state <= indirect1;
                    when OP_ISTORE => next_state <= indirect1;
                    when others    => next_state <= fetch1;
                end case;
```

Remove `add1 | and1` from the placeholder block and add:

```vhdl
            -- ====================================================
            -- add1: ACC ← ACC + MBR
            -- ====================================================
            when add1 =>
                alu_op     <= ALU_ADD;
                bus_alu    <= '1';
                acc_ld     <= '1';
                next_state <= fetch1;

            -- ====================================================
            -- and1: ACC ← ACC AND MBR
            -- ====================================================
            when and1 =>
                alu_op     <= ALU_AND;
                bus_alu    <= '1';
                acc_ld     <= '1';
                next_state <= fetch1;
```

---

## 4. Test programs

**ADD test — expected `acc = 0x002F` (47 = 5 + 42):**
```vhdl
0  => x"202A",   -- CLOAD 42      acc ← 0x002A
1  => x"4010",   -- DSTORE 0x010  mem[16] ← 0x002A
2  => x"2005",   -- CLOAD 5       acc ← 0x0005
3  => x"7010",   -- ADD 0x010     acc ← 5 + 42 = 47 = 0x002F
4  => x"0000",   -- HALT
16 => x"0000",   -- data slot
```

Encoding `ADD 0x010`: opcode `0111`, addr `0x010`:
`0111 000000010000` = `0x7010` ✓

**AND test — expected `acc = 0x00F0`:**
```vhdl
0  => x"20FF",   -- CLOAD 0xFF    acc ← 0x00FF
1  => x"4010",   -- DSTORE 0x010  mem[16] ← 0x00FF
2  => x"20F0",   -- CLOAD 0xF0    acc ← 0x00F0
3  => x"8010",   -- AND 0x010     acc ← 0x00F0 AND 0x00FF = 0x00F0
4  => x"0000",   -- HALT
16 => x"0000",   -- data slot
```

Encoding `AND 0x010`: opcode `1000`, addr `0x010`:
`1000 000000010000` = `0x8010` ✓

Verify: `0x00F0 AND 0x00FF = 0x00F0` ✓

---

## 5. Compile checkpoint

- No latch warnings.
- ADD test: `acc = 0x002F`.
- AND test: `acc = 0x00F0`.
- All Week 7 tests still pass.

---

Next: **Module 3 — Branch Instructions**
