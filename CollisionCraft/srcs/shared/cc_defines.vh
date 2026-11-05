// Shared definitions used by everyone: grid size, cell layout, material IDs,
// reaction IDs, states and tuning values.

// Zi Le: mat_*, gfx_*, ui_* (materials, graphics and controls)
// Aadi: phys_* (physics engine)
// Arnav: rxn_*, game_* (reactions and game modes)

// Owner: shared

`ifndef CC_DEFINES_VH
`define CC_DEFINES_VH

// Simulation grid
// Every OLED is used in PORTRAIT orientation: 64 pixels wide, 96 pixels tall.
`define GRID_W 64
`define GRID_H 96
`define GRID_CELLS 6144

// Layout of one 16 bit cell word
//
//   15 14 | 13  | 12 11 10 | 9 8 7 6 | 5 4 3 2 1 0
//   TAG   | PAR | SHADE    | LIFE    | MATERIAL
//
//   MATERIAL : which material lives in this cell (see M_* below)
//   LIFE     : 4 bit timer. Fire burns down, steam condenses, hot stone cools.
//   SHADE    : random 0..7 chosen when the grain is born, so a pile of sand
//              is textured instead of one flat colour.
//   PAR      : "parity" flag used by the physics engine so a grain that has
//              already moved this step is not moved twice.
//   TAG      : order tag for the reaction beaker (JA). 2 = arrived in the
//              newest release, 1 = the release before, 0 = older.
//              This is how "water FIRST then lava" differs from "together".
`define C_MAT 5:0
`define C_LIFE 9:6
`define C_SHADE 12:10
`define C_PAR 13
`define C_TAG 15:14

`define TAG_OLD 2'd0
`define TAG_PREV 2'd1
`define TAG_NEW 2'd2

// Material IDs
// 1..6 are the six materials you can pour. Everything above is something
// that can only be MADE by a reaction.
`define M_EMPTY 6'd0
// pourable base materials (switch order, left to right)
`define M_WATER 6'd1
`define M_SAND 6'd2
`define M_LAVA 6'd3
`define M_METAL 6'd4
`define M_ACID 6'd5
`define M_OIL 6'd6
// reaction products
`define M_STEAM 6'd7
`define M_STONE 6'd8
`define M_OBSIDIAN 6'd9
`define M_PUMICE 6'd10
`define M_MUD 6'd11
`define M_CLAY 6'd12
`define M_RUST 6'd13
`define M_DILUTE 6'd14 // diluted acid
`define M_GLASS 6'd15
`define M_SANDSTONE 6'd16
`define M_MOLTEN 6'd17 // molten metal
`define M_INGOT 6'd18
`define M_SLAG 6'd19
`define M_FUMES 6'd20
`define M_FIRE 6'd21
`define M_SMOKE 6'd22
`define M_HYDROGEN 6'd23
`define M_SOLUTION 6'd24 // green metal salt solution
`define M_TAR 6'd25
`define M_EMULSION 6'd26
`define M_BRICK 6'd27
`define M_POTTERY 6'd28
`define M_COATED 6'd29 // oil coated metal (rust proof)
`define M_BLAST 6'd30 // short lived explosion front
`define M_SPATTER 6'd31 // acid droplets flung by "water onto acid"
`define M_WETSAND 6'd32 // riverbed sand
`define M_BEADS 6'd33 // glass beads
// special materials, never stored in RAM
`define M_SINK 6'd62 // the floor is open here, fall out of the screen
`define M_WALL 6'd63 // chamber glass / funnel / floor

// Material classes (how a material MOVES)
`define CL_EMPTY 3'd0
`define CL_STATIC 3'd1 // never moves (stone, glass, walls)
`define CL_POWDER 3'd2 // falls and piles up (sand, metal)
`define CL_LIQUID 3'd3 // falls and spreads flat (water, oil)
`define CL_GAS 3'd4 // rises and drifts (steam, smoke)
`define CL_FIRE 3'd5 // flickers upward, burns out
`define CL_BLAST 3'd6 // explosion front, expands then vanishes
`define CL_SINK 3'd7 // exit through an open floor

// Reagent chamber (JB / JC) states
`define CH_EMPTY 3'd0 // nothing in it, waiting for a switch
`define CH_POUR 3'd1 // material is pouring in through the funnel
`define CH_READY 3'd2 // full, waiting for the release button
`define CH_DISCARD 3'd3 // switch turned off: trapdoor open, dumping
`define CH_RELEASE 3'd4 // valve open, flowing down to JA
`define CH_SPENT 3'd5 // released; the switch must go down again
`define CH_HOLD 3'd6 // two switches up at once, pouring paused

// Switch group selection result
`define SEL_NONE 2'd0
`define SEL_ONE 2'd1
`define SEL_CONFLICT 2'd2

// What happens to grains that fall out of the bottom of a screen
`define SINK_CLOSED 2'd0 // floor closed, nothing leaves
`define SINK_FIFO 2'd1 // grains go into the transfer pipe to JA
`define SINK_DELETE 2'd2 // grains are thrown away (discard / drain)

// Reaction IDs (used for banners, discoveries and challenge checks)
`define RX_NONE 6'd0
`define RX_OBSIDIAN 6'd1 // water first, then lava
`define RX_PUMICE 6'd2 // lava first, then water
`define RX_STONE 6'd3 // water + lava together
`define RX_RIVERBED 6'd4 // water first, then sand
`define RX_MUD 6'd5 // sand first, then water
`define RX_CLAY 6'd6 // water + sand together
`define RX_RUST 6'd7 // water and metal
`define RX_DILUTED 6'd8 // water first, then acid (the safe way)
`define RX_SPLASH 6'd9 // acid first, then water (the dangerous way)
`define RX_WARMMIX 6'd10 // water + acid together
`define RX_EMULSION 6'd11 // water + oil together
`define RX_GLASS 6'd12 // sand first, then lava
`define RX_SANDSTONE 6'd13 // lava first, then sand
`define RX_BEADS 6'd14 // sand + lava together
`define RX_MOLTEN 6'd15 // metal first, then lava
`define RX_SINKMELT 6'd16 // lava first, then metal
`define RX_SLAG 6'd17 // lava + metal together
`define RX_ACIDBOIL 6'd18 // acid first, then lava
`define RX_CRUST 6'd19 // lava first, then acid
`define RX_FUMECLOUD 6'd20 // lava + acid together
`define RX_FIRECLIMB 6'd21 // oil first, then lava
`define RX_OILFIRE 6'd22 // lava first, then oil
`define RX_FIREBALL 6'd23 // lava + oil together
`define RX_FIZZ 6'd24 // metal first, then acid
`define RX_DEEPFIZZ 6'd25 // acid first, then metal
`define RX_H2CLOUD 6'd26 // metal + acid together
`define RX_TAR 6'd27 // sand and oil
`define RX_COATED 6'd28 // metal and oil
`define RX_BRICK 6'd29 // mud + lava (3 step chain)
`define RX_POTTERY 6'd30 // clay + lava (chain)
`define RX_KABOOM 6'd31 // hydrogen meets heat
`define RX_QUENCH 6'd32 // molten metal + water
`define RX_HISS 6'd33 // fire + water
`define RX_ETCHED 6'd34 // stone + acid
`define RX_RUSTGONE 6'd35 // rust + acid
`define RX_SIZZLE 6'd36 // anything hot + water
`define RX_BLAZE 6'd37 // fire spreading through oil / tar
`define RX_TOTAL 6'd37 // how many reactions can be discovered

// Special effects a reaction can trigger
`define FX_NONE 2'd0
`define FX_FLASH 2'd1 // white screen flash
`define FX_BOOM 2'd2 // big flash + LED burst

// Game modes
`define MODE_TITLE 2'd0
`define MODE_TUTORIAL 2'd1
`define MODE_FREE 2'd2
`define MODE_CHALLENGE 2'd3

// 7 segment glyph codes (decoded in ui_seven_seg.v)
`define SG_0 5'd0
`define SG_1 5'd1
`define SG_2 5'd2
`define SG_3 5'd3
`define SG_4 5'd4
`define SG_5 5'd5
`define SG_6 5'd6
`define SG_7 5'd7
`define SG_8 5'd8
`define SG_9 5'd9
`define SG_A 5'd10
`define SG_B 5'd11 // lowercase b
`define SG_C 5'd12
`define SG_D 5'd13 // lowercase d
`define SG_E 5'd14
`define SG_F 5'd15
`define SG_H 5'd16
`define SG_I 5'd17
`define SG_L 5'd18
`define SG_N 5'd19 // lowercase n
`define SG_O 5'd20 // lowercase o
`define SG_P 5'd21
`define SG_R 5'd22 // lowercase r
`define SG_S 5'd23
`define SG_T 5'd24 // lowercase t
`define SG_U 5'd25
`define SG_Y 5'd26 // lowercase y
`define SG_DASH 5'd27
`define SG_BLANK 5'd28
`define SG_G 5'd29

// Base commands
`define CORE_HZ 25000000 // core logic clock (see clock_gen.v)
`define STEP_DIV_FAST 208333 // 25 MHz / 120 = 120 physics steps per second
`define STEP_DIV_SLOW 833333 // 30 steps per second (slow motion switch)
`define ANIM_DIV 416666 // 25 MHz / 60  = 60 Hz animation tick
`define POUR_VOLUME 13'd700 // grains poured per selection
`define BEAKER_FULL 13'd2900 // JA cell count that counts as "full"

`endif
