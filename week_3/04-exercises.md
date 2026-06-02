# Week 3 · Module 4 — Exercises

The modules walked through a traffic light controller and a "1011" sequence
detector in full. The exercises below are **different problems** — apply the
same techniques to new scenarios from scratch.

Workflow for every exercise:

1. Draw the state diagram on paper (circles, arrows, conditions, outputs).
2. Hand-trace at least one input sequence through your diagram.
3. Only then open the editor.
4. Simulate and verify the waveform matches your hand trace.

**Testbench support.** Exercise 1 (vending machine) comes with a complete,
ready-made testbench in `starter_library/tb_vending_machine.vhd` — you write
only the design. For Exercise 2 and the optional exercise, you write the
testbench yourself by copying and adapting
`starter_library/tb_template_fsm.vhd`; writing those testbenches is part of the
exercise. No design files are provided for any exercise.

---

## Exercise 1 — Vending Machine Controller (REQUIRED)

### Background

A vending machine accepts 5p and 10p coins and dispenses a 15p item. Build the
FSM that tracks inserted money and controls the dispense and change outputs.

### Specification

```vhdl
entity vending_machine is
    port (
        clk      : in  std_logic;
        reset    : in  std_logic;
        coin5    : in  std_logic;   -- '1' for one clock cycle when 5p inserted
        coin10   : in  std_logic;   -- '1' for one clock cycle when 10p inserted
        dispense : out std_logic;   -- '1' for one cycle when item is released
        change   : out std_logic    -- '1' for one cycle when 5p change is given
    );
end vending_machine;
```

### Behaviour

- The item costs 15p.
- On each clock edge, at most one coin input is `'1'` (never both — you need
  not handle that case).
- The FSM tracks accumulated credit: 0p, 5p, 10p.
- When credit reaches exactly 15p, assert `dispense = '1'` for one cycle and
  return to 0p. No change.
- When credit reaches 20p (10p then 10p), assert both `dispense = '1'` and
  `change = '1'` for one cycle, then return to 0p.
- `dispense` and `change` are `'0'` at all other times.
- On reset, return to 0p credit with both outputs low.

### What to do

1. **Draw the state diagram.** You need states for 0p, 5p, and 10p credit, plus
   the dispense/change actions. From each credit state, work out what happens
   on `coin5`, on `coin10`, and on neither. Label outputs on each state (Moore).
2. **Implement** `vending_machine.vhd` using the two-process template.
3. **Simulate** with the provided `tb_vending_machine.vhd` (add both files to
   your Quartus project). Capture a waveform screenshot with `current_state`,
   `coin5`, `coin10`, `dispense`, and `change` all visible.

### Self-check questions (for your own understanding — not submitted)

- How many states does your FSM have? Could you reduce it?
- What happens in your design if `coin5` and `coin10` are both `'1'`? Is that a
  problem given the specification?
- `dispense` is a Moore output. Could you redesign it as Mealy? What changes?
- Why must `dispense` and `change` return to `'0'` after one cycle? What would
  a latched `'1'` do physically?

---

## Exercise 2 — "101" Non-Overlapping Sequence Detector (REQUIRED)

### Background

Same *type* of problem as the module example, with two deliberate differences
that force you to work the logic from scratch:

1. The target is **"101"** (3 bits), not "1011".
2. It uses **non-overlapping** detection: after a match, the FSM returns to the
   initial state and reuses no bits from the completed match.

### Specification

```vhdl
entity seq_det_101_nonoverlap is
    port (
        clk      : in  std_logic;
        reset    : in  std_logic;
        data     : in  std_logic;
        detected : out std_logic
    );
end seq_det_101_nonoverlap;
```

### Behaviour

- `detected = '1'` for exactly one clock cycle after `101` is fully received
  (Moore: high while in the detected state, not on the cycle the final bit
  arrives).
- Non-overlapping: after detection, the FSM unconditionally returns to
  `S_INIT`. The `1` that ended the detected `101` does not start a new match.
- On reset, return to `S_INIT` with `detected = '0'`.

### What to do

1. **Draw the state diagram** with states `S_INIT`, `S_1`, `S_10`, `S_101`.
   Remember non-overlapping means `S_101` always returns to `S_INIT`
   regardless of the next bit.
2. **Hand-trace** the stream `1 0 0 1 0 1 1 0 1 0 1` before writing code, in a
   table:

   | Cycle | data | State before | State after | detected |
   |---|---|---|---|---|
   | 1 | 1 | S_INIT | ? | ? |
   | 2 | 0 | ? | ? | ? |
   | ... | ... | ... | ... | ... |

3. **Implement** `seq_det_101_nonoverlap.vhd`.
4. **Write** `tb_seq_det_101.vhd` by copying `tb_template_fsm.vhd`. Requirements:
   - at least 25 clock cycles of `data`,
   - includes the stream from step 2 (or a stream containing it),
   - shows at least two detections,
   - shows at least one near-miss where progress is broken (e.g. `1 0 0`).
5. **Simulate** and confirm the waveform matches your hand trace exactly.

### Self-check questions (not submitted)

- For `1 0 1 0 1`, how many detections does the non-overlapping version
  produce? How many would an overlapping version produce?
- Draw the overlapping version. What changes in the transitions from `S_101`?
- This is Moore. Where would a Mealy version place `detected`? Sketch it.
- Why is Process 2's sensitivity list `(current_state, data)` and not just
  `(current_state)`?

---

## Optional Exercise — Combination Lock (`combo_lock`)

*Attempt only after both required exercises. There is no worked example for
this problem in the week's modules — design it from scratch.*

### Background

A lock accepts a sequence of button presses. The correct combination is
**A, B, A**. Entering it opens the lock. Any wrong button at any point rejects
until reset.

### Specification

```vhdl
entity combo_lock is
    port (
        clk      : in  std_logic;
        reset    : in  std_logic;
        btn_a    : in  std_logic;   -- '1' for one cycle when A pressed
        btn_b    : in  std_logic;   -- '1' for one cycle when B pressed
        unlocked : out std_logic;   -- '1' while lock is open
        rejected : out std_logic    -- '1' while in error/reject state
    );
end combo_lock;
```

### Behaviour

- At most one button is pressed per clock cycle.
- The unlock sequence is A, then B, then A.
- `unlocked = '1'` while the FSM is in the unlocked state; it stays unlocked
  until `reset` (no auto-lock).
- A wrong button at any step (B first; A where B was expected; any button while
  already unlocked) sends the FSM to a `REJECTED` state where `rejected = '1'`.
- The FSM stays in `REJECTED` until `reset`; presses there are ignored.
- On reset, return to the idle state with both outputs low.

### What to do

**Part A — State diagram (paper).** Suggested states: `S_IDLE`, `S_GOT_A`,
`S_GOT_AB`, `S_UNLOCKED`, `S_REJECTED`. For each, work out `btn_a='1'`,
`btn_b='1'`, and neither.

**Part B — Implementation.** `combo_lock.vhd`, two-process template.

**Part C — Testbench.** Write `tb_combo_lock.vhd` by adapting the template,
covering, each separated by a reset:

1. Correct: A -> B -> A -> `unlocked = '1'`.
2. Wrong first button: B -> `rejected = '1'`.
3. Wrong second: A -> A -> `rejected = '1'`.
4. Wrong third: A -> B -> B -> `rejected = '1'`.
5. Press while rejected: an extra A keeps the FSM in `REJECTED`.
6. Press while unlocked: A -> B -> A, then B -> `REJECTED`.

**Part D — Self-check (not submitted).**

- How many states? Could any merge?
- `unlocked` stays high until reset — Moore or Mealy? What would auto-relock
  after 3 cycles require?
- If the combination were A, B, A, B, how many states? Does the pattern matter
  (A,A,A,A vs A,B,A,B)?
- If `btn_a` stays high for 3 cycles (bounce), how does your FSM behave? How
  would you fix it?

---

## Submission Checklist

### Required
- [ ] `vending_machine.vhd` — compiles, no errors or latch warnings.
- [ ] Waveform screenshot for the vending machine (using the provided
      testbench), all signals visible.
- [ ] `seq_det_101_nonoverlap.vhd` — correct non-overlapping behaviour.
- [ ] `tb_seq_det_101.vhd` — at least 25 cycles, at least 2 detections.
- [ ] Waveform screenshot for the sequence detector, all signals visible.

### Optional
- [ ] `combo_lock.vhd` — all six test sequences handled correctly.
- [ ] `tb_combo_lock.vhd` — all six sequences from Part C included.
- [ ] Waveform screenshot showing at least the unlock path and one rejection
      path.

---

Next: **Module 5 — Testbenches for FSM Designs**
