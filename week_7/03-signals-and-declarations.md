# Week 7 · Module 3 — Signals, Constants, and State Type

This module fills in the entire declarative region of `washu2_cpu.vhd`.
Every signal declared here corresponds directly to a row or column in the
Week 6 Module 6 control signal table. Read each section against that table
as you write.

---

## 1. The RAM: direct entity instantiation (no component declaration)

The `washu2_ram` component is provided in `starter_library/washu2_ram.vhd`.
Week 5 established the preferred style: **direct entity instantiation** using
`entity work.washu2_ram`. This requires no `component` declaration — as long
as `washu2_ram.vhd` is in the same Quartus project, `entity work.washu2_ram`
resolves automatically.

You do not need to add anything to the declarative region for the RAM. The
instantiation itself goes in the architecture body (Module 4 §1). This
section is here only to explain the RAM's interface so you know what to
connect:

```
washu2_ram ports:
    clk      : in  std_logic
    we       : in  std_logic                      -- write enable
    addr     : in  std_logic_vector(11 downto 0)  -- 12-bit address
    data_in  : in  std_logic_vector(15 downto 0)  -- write data
    data_out : out std_logic_vector(15 downto 0)  -- read data (1-cycle latency)
```

**Why 12-bit address?** The WashU-2 instruction format has a 12-bit operand
field (`IR[11:0]`), giving 2^12 = 4096 addressable locations. `pc` and `mar`
are stored as 16-bit signals but only the lower 12 bits are used as the RAM
address — see Module 4 §1 for how this is handled in the port map.

---

## 2. FSM state type

Declare an enumerated type with all states. Use the exact names from Week 6
Module 5 — this makes debugging straightforward because the waveform will
show state names, not numbers:

```vhdl
    -- ----------------------------------------------------------------
    -- FSM state type (matches Week 6 Module 5 naming exactly)
    -- ----------------------------------------------------------------
    type state_type is (
        resetState,
        fetch1, fetch2, fetch3,
        halt1,
        neg1, neg2,
        cload1,
        direct1, direct2,
        load1, add1, and1, store1,
        branch1,
        indirect1, indirect2,
        iload1, istore1,
        brind1, brind2, brind3
    );

    signal current_state : state_type := resetState;
    signal next_state    : state_type;
```

All states are declared now even though only a subset are used in Week 7.
This means the `when others` arm in the FSM (added in Week 8) will still
compile cleanly.

---

## 3. Datapath register signals

All CPU registers are 16-bit. `pc` and `mar` are used as 12-bit addresses
for the RAM, but storing them as 16-bit and truncating to 12 bits at the
point of use is cleaner than making them 12-bit throughout:

```vhdl
    -- ----------------------------------------------------------------
    -- Datapath registers (all 16-bit — matches WashU-2 architecture)
    -- ----------------------------------------------------------------
    signal acc : std_logic_vector(15 downto 0) := (others => '0');
    signal pc  : std_logic_vector(15 downto 0) := (others => '0');
    signal mar : std_logic_vector(15 downto 0) := (others => '0');
    signal mbr : std_logic_vector(15 downto 0) := (others => '0');
    signal ir  : std_logic_vector(15 downto 0) := (others => '0');
```

---

## 4. Bus and internal wire signals

`the_bus` is the single shared 16-bit bus. Every bus transfer goes through
this signal. It is driven by exactly one `bus_X` control signal at a time
(implemented as a `with ... select` multiplexer in Module 4):

```vhdl
    -- ----------------------------------------------------------------
    -- The shared bus
    -- ----------------------------------------------------------------
    signal the_bus : std_logic_vector(15 downto 0);

    -- ----------------------------------------------------------------
    -- Internal wires (combinational — no clock)
    -- ----------------------------------------------------------------
    signal alu_result   : std_logic_vector(15 downto 0);
    signal mem_data_out : std_logic_vector(15 downto 0);
    signal ir_opcode    : std_logic_vector(3 downto 0);  -- IR[15:12]
    -- NOTE: ir_opcode is only valid AFTER fetch3 completes.
    -- In fetch3, the FSM must decode from mbr(15 downto 12) instead.
    -- See Module 6 Stage A for the full explanation.
    signal ir_addr      : std_logic_vector(11 downto 0); -- IR[11:0]
    signal ir_addr_se   : std_logic_vector(15 downto 0); -- IR[11:0] sign-extended
```

`ir_addr_se` is the sign-extended version of the 12-bit operand field,
used by `CLOAD`. Its derivation is explained in Module 4.

---

## 5. Control signals

One signal per row and column in the Week 6 Module 6 control table:

```vhdl
    -- ----------------------------------------------------------------
    -- Bus output enables (exactly one is '1' per clock cycle)
    -- ----------------------------------------------------------------
    signal bus_pc       : std_logic;  -- PC drives bus
    signal bus_mbr      : std_logic;  -- MBR drives bus
    signal bus_acc      : std_logic;  -- ACC drives bus
    signal bus_ir_lower : std_logic;  -- IR[11:0] zero-extended drives bus
    signal bus_ir_se    : std_logic;  -- IR[11:0] sign-extended drives bus
    signal bus_alu      : std_logic;  -- ALU result drives bus
    signal bus_mem      : std_logic;  -- memory output drives bus

    -- ----------------------------------------------------------------
    -- Register load enables
    -- ----------------------------------------------------------------
    signal mar_ld : std_logic;
    signal mbr_ld : std_logic;
    signal ir_ld  : std_logic;
    signal acc_ld : std_logic;
    signal pc_ld  : std_logic;

    -- ----------------------------------------------------------------
    -- Special control signals
    -- ----------------------------------------------------------------
    signal pc_inc   : std_logic;                    -- PC ← PC + 1
    signal mem_we   : std_logic;                    -- RAM write enable
    signal alu_op   : std_logic_vector(2 downto 0); -- ALU operation
    signal done_int : std_logic;                    -- internal done flag
```

---

## 6. Flag signals

Derived combinationally from `acc`. These feed into the branch instructions
in Week 8 but are declared now:

```vhdl
    -- ----------------------------------------------------------------
    -- Condition flags (combinational from ACC)
    -- ----------------------------------------------------------------
    signal zero_flag : std_logic;  -- ACC = 0x0000
    signal pos_flag  : std_logic;  -- ACC > 0 (MSB=0 and non-zero)
    signal neg_flag  : std_logic;  -- ACC < 0 (MSB=1)
```

---

## 7. Constants

Define all opcode and ALU operation constants here, not as magic literals
scattered through the FSM. Every opcode value comes directly from the
Week 6 Module 3 ISA table:

```vhdl
    -- ----------------------------------------------------------------
    -- Instruction opcodes (IR[15:12])
    -- ----------------------------------------------------------------
    constant OP_HALT   : std_logic_vector(3 downto 0) := "0000";
    constant OP_NEGATE : std_logic_vector(3 downto 0) := "0001";
    constant OP_CLOAD  : std_logic_vector(3 downto 0) := "0010";
    constant OP_DLOAD  : std_logic_vector(3 downto 0) := "0011";
    constant OP_DSTORE : std_logic_vector(3 downto 0) := "0100";
    constant OP_ILOAD  : std_logic_vector(3 downto 0) := "0101";
    constant OP_ISTORE : std_logic_vector(3 downto 0) := "0110";
    constant OP_ADD    : std_logic_vector(3 downto 0) := "0111";
    constant OP_AND    : std_logic_vector(3 downto 0) := "1000";
    constant OP_BRANCH : std_logic_vector(3 downto 0) := "1001";
    constant OP_BRZERO : std_logic_vector(3 downto 0) := "1010";
    constant OP_BRPOS  : std_logic_vector(3 downto 0) := "1011";
    constant OP_BRNEG  : std_logic_vector(3 downto 0) := "1100";
    constant OP_BRIND  : std_logic_vector(3 downto 0) := "1101";

    -- ----------------------------------------------------------------
    -- ALU operation codes (3-bit, selects operation in ALU process)
    -- ----------------------------------------------------------------
    constant ALU_ADD    : std_logic_vector(2 downto 0) := "000";
    constant ALU_AND    : std_logic_vector(2 downto 0) := "001";
    constant ALU_NOT    : std_logic_vector(2 downto 0) := "010";
    constant ALU_INC    : std_logic_vector(2 downto 0) := "011";
    constant ALU_PASS_B : std_logic_vector(2 downto 0) := "100";
```

`ALU_PASS_B` passes the B input (the bus value) through to `alu_result`
unchanged — used by `DLOAD` and `ILOAD` to move `MBR` into `ACC` via the
ALU without any arithmetic.

`ALU_INC` computes `ACC + 1` — the second step of `NEGATE` (invert then
add 1).

---

## 8. Complete declarative region

Putting it all together, the section between `architecture rtl of washu2_cpu is`
and `begin` should now look like this (in Quartus, compile after adding all
declarations to catch any typos before proceeding to the body):

```vhdl
architecture rtl of washu2_cpu is

    -- No component declaration needed for washu2_ram.
    -- Direct entity instantiation (entity work.washu2_ram) is used
    -- in the architecture body — see Module 4 §1.

    type state_type is (
        resetState,
        fetch1, fetch2, fetch3,
        halt1,
        neg1, neg2,
        cload1,
        direct1, direct2,
        load1, add1, and1, store1,
        branch1,
        indirect1, indirect2,
        iload1, istore1,
        brind1, brind2, brind3
    );
    signal current_state : state_type := resetState;
    signal next_state    : state_type;

    signal acc : std_logic_vector(15 downto 0) := (others => '0');
    signal pc  : std_logic_vector(15 downto 0) := (others => '0');
    signal mar : std_logic_vector(15 downto 0) := (others => '0');
    signal mbr : std_logic_vector(15 downto 0) := (others => '0');
    signal ir  : std_logic_vector(15 downto 0) := (others => '0');

    signal the_bus      : std_logic_vector(15 downto 0);
    signal alu_result   : std_logic_vector(15 downto 0);
    signal mem_data_out : std_logic_vector(15 downto 0);
    signal ir_opcode    : std_logic_vector(3 downto 0);
    signal ir_addr      : std_logic_vector(11 downto 0);
    signal ir_addr_se   : std_logic_vector(15 downto 0);

    signal bus_pc       : std_logic;
    signal bus_mbr      : std_logic;
    signal bus_acc      : std_logic;
    signal bus_ir_lower : std_logic;
    signal bus_ir_se    : std_logic;
    signal bus_alu      : std_logic;
    signal bus_mem      : std_logic;

    signal mar_ld   : std_logic;
    signal mbr_ld   : std_logic;
    signal ir_ld    : std_logic;
    signal acc_ld   : std_logic;
    signal pc_ld    : std_logic;
    signal pc_inc   : std_logic;
    signal mem_we   : std_logic;
    signal alu_op   : std_logic_vector(2 downto 0);
    signal done_int : std_logic;

    signal zero_flag : std_logic;
    signal pos_flag  : std_logic;
    signal neg_flag  : std_logic;

    constant OP_HALT   : std_logic_vector(3 downto 0) := "0000";
    constant OP_NEGATE : std_logic_vector(3 downto 0) := "0001";
    constant OP_CLOAD  : std_logic_vector(3 downto 0) := "0010";
    constant OP_DLOAD  : std_logic_vector(3 downto 0) := "0011";
    constant OP_DSTORE : std_logic_vector(3 downto 0) := "0100";
    constant OP_ILOAD  : std_logic_vector(3 downto 0) := "0101";
    constant OP_ISTORE : std_logic_vector(3 downto 0) := "0110";
    constant OP_ADD    : std_logic_vector(3 downto 0) := "0111";
    constant OP_AND    : std_logic_vector(3 downto 0) := "1000";
    constant OP_BRANCH : std_logic_vector(3 downto 0) := "1001";
    constant OP_BRZERO : std_logic_vector(3 downto 0) := "1010";
    constant OP_BRPOS  : std_logic_vector(3 downto 0) := "1011";
    constant OP_BRNEG  : std_logic_vector(3 downto 0) := "1100";
    constant OP_BRIND  : std_logic_vector(3 downto 0) := "1101";

    constant ALU_ADD    : std_logic_vector(2 downto 0) := "000";
    constant ALU_AND    : std_logic_vector(2 downto 0) := "001";
    constant ALU_NOT    : std_logic_vector(2 downto 0) := "010";
    constant ALU_INC    : std_logic_vector(2 downto 0) := "011";
    constant ALU_PASS_B : std_logic_vector(2 downto 0) := "100";

begin
    -- architecture body follows in Module 4
end rtl;
```

Compile this. Fix any errors before moving to Module 4. A clean compile
at this stage means the skeleton is correct and all subsequent errors will
be in the logic, not the declarations.

---

Next: **Module 4 — The Bus, ALU, and Combinational Logic**
