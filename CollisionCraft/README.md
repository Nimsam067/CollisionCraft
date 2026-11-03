# CollisionCraft: a material interaction simulator for the Basys3

Three PmodOLEDrgb screens, stood up in portrait:

```
   JB (left chamber)        JC (right chamber)
   pick a material          pick a material
   with sw15..sw10          with sw5..sw0
          \                    /
           \__ press CENTER __/
                    |
             JA (reaction beaker)
```

Every pixel is a grain in a falling-sand simulation. Grains:

- fall,
- pile up,
- flow,
- float,
- rise as gas,
- burn,
- and react with whatever they touch.

The same two materials can give different results depending on the order you add them.

---

## 1. Building it in Vivado

1. Create an RTL project for the Basys3 (part `xc7a35tcpg236-1`).
2. Add every `.v` file in this folder as a design source.
3. Add `cc_defines.vh` too. Vivado will list it as a Verilog Header.
   - If Vivado can't find it, right-click it and choose **Set Global Include**.
4. Add `CollisionCraft.xdc` as the constraints file.
5. Set `CollisionCraft_Top` as the top module.
6. Generate the bitstream and program the board.

Plug the three OLEDs into **JA, JB and JC** (top row of each header).

**Screen upside down?** Each screen's orientation is one number near the top of `CollisionCraft_Top.v`:

```verilog
localparam JB_ROTATE = 0;
localparam JC_ROTATE = 0;
localparam JA_ROTATE = 1;
```

Flip the one that's wrong between 0 and 1. If a screen is mirrored, set `MIRROR(1)` on that screen's instance.

**Timing note:** `CollisionCraft.xdc` declares the two divided clocks with `create_generated_clock`. If Vivado warns that it can't find `u_clocks/div_reg[1]/Q`, the design still works; Vivado just won't timing-check those clocks.

---

## 2. Controls

| Control | What it does |
|---|---|
| sw15 to sw10 | JB material: WATER, SAND, LAVA, METAL, ACID, OIL (left to right) |
| sw5 to sw0 | JC material: WATER, SAND, LAVA, METAL, ACID, OIL (left to right) |
| sw6 | Slow motion (30 physics steps/s instead of 120) |
| **C** (centre) | Menu: select. In the lab: **release** every READY chamber into the beaker |
| **U** | Menu: up. Free play: wipe the lab. Challenge: restart the level |
| **D** | Menu: down. In the lab: **drain** the beaker |
| **R** | Tutorial: skip step. Challenge: show a hint (costs 10 s) |
| **L** (hold 1 s) | Back to the title screen from anywhere |

### Material switches

Flip one up and that material pours into its chamber through the funnel (a fixed amount). Flip it down and the hopper drops open, dumping the contents. Only one switch per side may be up at a time; two at once pauses the pour.

### LEDs above the switches

| Pattern | Meaning |
|---|---|
| Sweeping dot | Pick a material |
| Fast blink | Pouring |
| Solid | Ready |
| Fading | Discarding |
| Strobe | Releasing |
| Double-blink | Released; flip this switch back down |
| Alternate flashing | Two switches are up |
| Breathing | Tutorial hint |

### 7-segment display

| Mode | Display |
|---|---|
| Title | `PLAY` |
| Tutorial | `t  N` (step number) |
| Free play | `15.07` = releases left . discoveries |
| Challenge | `3-75` = level - seconds left. Also `PASS`, `FAIL`, `donE` |

---

## 3. Materials and reactions

The six pourable materials are the same on both sides: **water, sand, lava, metal, acid, oil**.

How two materials meet:

- **"X first, then Y"**: X was released into the beaker in an earlier release, then Y was poured on top.
- **"together"**: both chambers were released with one press of C.

| Pair | X first, then Y | Y first, then X | Together |
|---|---|---|---|
| Water, Lava | **Obsidian** | **Pumice** (floats!) | **Stone** + steam |
| Water, Sand | **Riverbed** (wet sand) | **Mud** | **Clay** |
| Water, Acid | **Diluted** (safe) | **Splashback!** | Warm mix |
| Water, Metal | Slow **rust** | Slow rust | Fast rust |
| Water, Oil | layers | layers | **Emulsion** |
| Sand, Lava | **Glass** | **Sandstone** | **Glass beads** |
| Sand, Oil | **Tar** | sinks through | Tar |
| Lava, Metal | **Sink melt** | **Meltdown** | **Slag** + molten metal |
| Lava, Acid | **Crust** + fumes | **Acid boil** | **Fume cloud** |
| Lava, Oil | **Oil fire** | **Fire climb** | **FIREBALL** |
| Metal, Acid | **Fizz** (hydrogen) | **Deep fizz** | **H2 cloud** |
| Metal, Oil | **Coated** metal (won't rust) | same | same |

Chains you can build in the beaker:

- mud + lava → **brick**
- clay + lava → **pottery**
- hydrogen + fire or lava → **kaboom**
- molten metal + water → **quench**
- fire + water → **hiss**
- stone + acid → **etched**
- rust + acid → **rust gone**
- anything glowing hot + water → **sizzle**
- fire spreads through oil and tar → **blaze**

That makes 37 discoveries in all.

---

## 4. Who owns what

Every file starts with an `OWNER:` line. Filename prefixes make the split obvious.

### Shared (everyone)

| File | Job |
|---|---|
| `cc_defines.vh` | The contract: cell format, material and reaction IDs, states, tuning knobs |
| `CollisionCraft_Top.v` | Wires everything together |
| `clock_gen.v` | 25 MHz core clock, 6.25 MHz OLED clock, power-on reset |
| `Oled_Display.v` | Given OLED driver (unmodified) |
| `CollisionCraft.xdc` | Pins |

### Person 1: Materials, Graphics & Controls (`mat_*`, `gfx_*`, `ui_*`)

| File | Job |
|---|---|
| `mat_properties.v` | Each material's class, density, flow, lifetime, glow |
| `mat_names.v` | Names, 3-letter codes, descriptions, signature colours |
| `mat_switch_select.v` | 6 switches → selection, plus the 6 PWM-animated LEDs |
| `gfx_chamber_geometry.v` | Funnels, hopper, beaker: the solid walls physics bounces off |
| `gfx_material_shader.v` | How each material looks (speckle, ripples, lava crawl, glow, transparency) |
| `gfx_reagent_screen.v` | JB/JC screen: name card, status line, glassware |
| `gfx_reaction_screen.v` | JA screen: title/menu, header, banner, message box, gauge, flash |
| `gfx_oled_mapper.v` | Portrait rotation and pixel look-ahead |
| `gfx_text_line.v`, `gfx_font_rom.v` | Text rendering and the 5x7 font |
| `ui_debounce.v`, `ui_seven_seg.v` | Buttons and 7-segment display |

### Person 2: Physics Engine (`phys_*`)

| File | Job |
|---|---|
| `phys_engine.v` | The falling-sand engine: inject → sweep → read neighbours → decide → write |
| `phys_move_rules.v` | Powder / liquid / gas / fire movement, density and buoyancy |
| `phys_grid_ram.v` | Dual-port block RAM, one per screen |
| `phys_emitter.v` | Pours a fixed volume with per-material pour styles |
| `phys_chamber_ctrl.v` | Chamber life cycle: pour, hold, ready, release, discard, spent |
| `phys_beaker_ctrl.v` | Drain valve of the beaker |
| `phys_transfer_fifo.v` | The pipe from JB/JC down into JA |
| `phys_step_timer.v` | 120 Hz physics heartbeat |
| `phys_lfsr.v` | Random numbers |

### Person 3: Interactions & Game Logic (`rxn_*`, `game_*`)

| File | Job |
|---|---|
| `rxn_table.v` | **The reaction rulebook**, with order-aware contexts |
| `rxn_self.v` | Things that change on their own (steam condenses, fire burns out, metal solidifies) |
| `rxn_names.v` | Banner text for each reaction |
| `rxn_tracker.v` | Discoveries, banner choice, explosion flash, target counting, fill level |
| `game_fsm.v` | Title menu, mode switching, release gating, recipe line, title demo |
| `game_tutorial.v` | 7-step guided tutorial |
| `game_freeplay.v` | Sandbox with 15 releases and beaker capacity |
| `game_challenge.v`, `game_levels.v` | 10 "make this material" levels with timer and stars |

---

## 5. How the physics works (short version)

- Each screen is a 64 x 96 grid. Each cell is a 16-bit word:

  | Bits | Field |
  |---|---|
  | 5:0 | material |
  | 9:6 | life timer |
  | 12:10 | shade |
  | 13 | parity |
  | 15:14 | order tag |

- 120 times a second, the engine visits every cell from the **bottom row up**. For each grain it reads its 10 neighbours from RAM, then in one clock cycle decides, in order:
  1. Does it change by itself? (`rxn_self`)
  2. Does it react with a random neighbour? (`rxn_table`)
  3. Where does it move? (`phys_move_rules`)

  Then it writes back at most two cells.
- Walls are not stored in RAM. `gfx_chamber_geometry` computes them, so opening a valve is free and the renderer draws exactly what the physics collides with.
- **Order tags:** grains arriving in the beaker get tag 2. Just before each new release, an "ageing" step counts every tag down (2 → 1 → 0). So when two grains meet, `rxn_table` can tell which one was there first.

---

## 6. Tuning

Everything adjustable is in `cc_defines.vh`:

- Physics speed: `STEP_DIV_*`
- Pour size: `POUR_VOLUME`
- Beaker capacity: `BEAKER_FULL`

Material behaviour lives in `mat_properties.v`, reaction speeds (the `prob` column) in `rxn_table.v`, and challenge goals in `game_levels.v`.
