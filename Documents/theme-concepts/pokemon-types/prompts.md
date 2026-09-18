# Pokémon-type theme prompts

Tool: built-in Image Gen.

## Screen template

Create a realistic, production-quality UI theme mockup for PokeTaskBar, a native macOS menu-bar productivity app with a Pokémon companion. One screen, one Pokémon-type theme. Target 1024 x 1280 portrait pixels. Reference image is the previous Classic concept: use its same layout and function hierarchy ONLY, replacing its colours, component treatments and Lapras mascot according to the type brief. Do not merely tint the screenshot. The result must feel like a coherent native desktop utility with theme-specific typography, borders, surfaces, and control shapes.

Fill canvas with one app panel, no device or browser frame, no external illustration. Precise content: PokeTaskBar header; Focus selected, Linear, Collection, Usage, gear; small full-colour pixel-art [POKEMON] sprite with its name and "Training"; simple XP bar labelled "650 / 1,000 XP"; "Today 2,400 XP" and "Coins 128"; section "ACTIVE ISSUE", identifier "PTB-42", title "Polish theme controls", status "In progress"; large aligned monospaced "24:18"; primary "Pause" with two vertical bars, secondary "Open issue"; bottom "Open Today" and discreet "[TYPE] type" theme label. Use exactly this content, no invented levels, stats, streaks or added navigation.

A small tasteful elemental motif may live ONLY in the companion strip; main task and text surfaces remain quiet and legible. Preserve full-colour Pokémon sprite identity, do not recolour it to match the theme. Do not show Lapras unless specified. Native readable body text and max two fonts. Use spacing and grouping, then thin separators, before cards or shadows; no nested cards. Strong contrast and clear interactive states. Current date anchor September 18 2026; no visible dates needed. Static concept, not implemented.

## Component sheet template

Create a polished PokeTaskBar design-system COMPONENT SHEET for the [TYPE] Pokémon-type theme. This is an explicit catalogue of UI elements, not a single app screen. Target 2048 x 3072 portrait, sharp readable typography, maximize resolution.

Image 1 is THIS TYPE'S newly generated screen: faithfully use its palette, material, corners, font character, elemental motif and full-colour [POKEMON] mascot. Image 2 is the Classic component sheet: use its neat three-column by four-row specimen layout and coverage ONLY, NOT its blue palette, Lapras, or its incorrect pause icon on Start buttons. This is one theme per image.

Title "[TYPE] — UI elements"; subtitle "PokeTaskBar • Pokémon-type theme". Header includes six labelled colour swatches Canvas, Surface, Text, Accent, Border, Selected, plus Heading, Body and 24:18 typography samples. Below it show twelve spacious labelled specimen groups in reading order:
01 ACTIONS: primary "Start focus" with a PLAY TRIANGLE (never pause), outlined "Open issue", plain "Cancel", destructive red "Forfeit", gear icon; small Start button states labelled Hover, Pressed, Disabled, Focus. All Start states use play; focus has visible ring.
02 NAVIGATION: Focus / Linear / Collection / Usage with Focus selected; Bag / Storage / Dex / Shop with Dex selected; Back and disclosure open/closed.
03 TEXT INPUTS: Task title "Polish theme controls", focused text field with ring, masked password dots, multiline "Add a session note…", invalid empty field with red "Title required".
04 CHOICE CONTROLS: BOTH visible On and Off toggle switches, checked/unchecked checkboxes, "Growth 75%" slider, Status picker with open menu Todo / In progress checked / Done.
05 ROWS & INSPECTOR: selected pinned "PTB-42  Polish theme controls" row and normal "PTB-43  Review colours"; property rows Status / In progress and Priority / High.
06 BADGES & STATUS: Todo, In progress, Done, High, Rare, plus an amber Overtime label with warning symbol. Colour plus icon/label, not colour alone.
07 PROGRESS & SCORE: 65% progress "650 / 1,000 XP", "Today 2,400 XP", "128 Coins", tiny seven-bar usage chart, loading spinner.
08 COMPANION & ITEMS: small [POKEMON] companion Training card and XP bar; selected Dex tile for [POKEMON]; tiny Egg item card "10,000 Coins" with Buy. Correct full-colour pixel sprites, elemental motif confined to this area.
09 FOCUS TIMER: Running 24:18 with Pause bars; Paused 12:04 with Resume play triangle; amber overtime +02:10 and OT; duration segments 15 / 25 / 45 with 25 selected.
10 FLOATING CHROME: compact island with tiny [POKEMON], PTB-42, 24:18, Pause bars; folded countdown pill; speech bubble "Ready when you are"; tooltip "Pause timer".
11 FEEDBACK & CONFIRM: small "Reset timer?" confirmation, neutral explanatory text "Return to the planned duration." with Cancel and Reset; green Note saved; red Could not connect / Retry; amber Session needs attention. Red error, green success, amber warning remain distinct in every theme.
12 EMPTY, LOADING & LOG: No pinned task / Open Linear; one skeleton Loading row; "Focus complete · 25 min" log; "Next: review controls" note.

Footer "Visual exploration • Not implemented". No unrelated new controls or invented feature labels. All twelve groups must fit, no clipped last row. Fine group dividers and whitespace, no unnecessary twelve-card nesting. Readable system sans body even for stylised themes; two fonts max. Preserve matching theme; don't recolour every semantic badge into its accent. Neutral modal text, no claim of lost session data. All button state examples are illustrative. Current date anchor September 18 2026, no visible dates.

## Type directions

### Normal

Companion: Eevee

Soft linen studio: warm ivory #F4F0E7 canvas, oatmeal #DDD5C5 shell, cocoa #39342F ink, warm taupe #8D7968 accent. Matte paper-soft surfaces, 10px quietly rounded controls, elegant unembellished system sans, fine warm rules. Tiny woven-fabric motif confined to companion strip. Comfortable neutral everyday style; distinctly tactile, not plain default gray.

### Fire

Companion: Charmander

Ember forge: dark warm basalt #241A19 canvas, lifted charcoal #352724 surfaces, ivory #FFF0DD ink, vivid ember #F57B3A primary accent and muted red-orange edges. Crisp chamfered 7px controls, thin ember keylines, monospaced clock. Subtle warm ember/firelight in companion strip only. Restrained premium warmth, no flame behind task text or dramatic full-screen fire.

### Water

Companion: Squirtle

Deep tidal blue: rich deep-ocean #102F46 canvas, blue #19465D raised surfaces, seafoam-white #E4F7F5 ink, bright turquoise #55D4D1 accent. Smooth rounded controls with quiet ripple contours, soft blue dividers, cool crisp system sans. Small pixel tidal pool or concentric ripple in companion strip only. Dark aquatic style, distinctly deeper than Ocean Glass.

### Electric

Companion: Lapras (revised from Pikachu after two unsuccessful character-specific generations)

Volt at night: graphite #212126 canvas, deep charcoal #303036 surfaces, warm ivory #FFF7DB ink, saturated electrical yellow #F1D54E accents. Crisp cut corners, exact thin yellow keylines, segmented XP, subtle tiny circuit traces only beside companion. Dark primary buttons in yellow fill with black labels. Energetic but legible, no bright pink.

Final Electric screen prompt (reference: Neon Arcade):

Create a new ELECTRIC TYPE theme mockup for the PokeTaskBar app using the attached screen as its content and layout reference. This is an interface colour and material exploration. Portrait 1024x1280. Keep the existing Lapras character, app navigation and exact task/timer content. Change all pink and cyan decorative accents to vivid electrical yellow, use dark graphite surfaces and warm ivory text, crisp modest cut-corner controls and small circuit-line details only beside Lapras. Preserve semantic colours where meaningful. Dark ink on the yellow Pause button. Rename the footer to 'Electric type'. No extra controls, new characters, dramatic effects or text. Keep all labels readable and every element fully visible. One realistic native macOS utility screen, not a poster.

### Grass

Companion: Lapras (revised from Bulbasaur after two unsuccessful character-specific generations)

Fresh greenhouse: pale leaf #F0F5E7 canvas, sage #DCE8CD shell, forest #234D35 ink, leaf-green #588E45 accent. Gently leaf-rounded asymmetric detail on companion card only; simple soft rectangle controls and botanical fine dividers. Bright clean native sans, small leaf-vein detail in companion strip. Quiet morning garden, no image under body text.

### Ice

Companion: Alolan Vulpix

Polar crystal: snow-white #F4FBFE canvas, frost-blue #D7EAF2 shell, arctic navy #25465D ink, icy blue #68ACD0 accent and pale lavender secondary note. Fine faceted 6px corners and frost-white hairline edges, restrained translucency with solid legible fields. Small crystal/snowflake motif in companion strip. Crisp airy high-contrast winter daylight.

### Fighting

Companion: Machop

Dojo discipline: warm unbleached #F3E7D5 canvas, muted clay #E0C4A7 shell, deep oxblood #592F2F ink, vermilion #BA5342 accent. Strong flat squared 4px controls, bold sturdy sans headings, disciplined rules and a narrow wrapping-band motif in companion strip. Athletic precision, calm capable work tool, no arena, violence or distressed grunge.

### Poison

Companion: Ekans

Amethyst laboratory: dark aubergine #24192F canvas, plum #382342 raised surfaces, pale lilac #F1DEF7 text, orchid #BF78D6 accent plus a tiny acid-lime #CEE17A secondary detail. Clean elongated capsules, thin violet borders and delicate specimen markings. Small abstract liquid-drop motif in companion strip. Elegant curious chemistry mood, no skulls, hazardous gore, or overpowering slime.

### Ground

Companion: Sandshrew

Desert strata: warm sand #F0DFBF canvas, ochre #DAC099 shell, dark earth #513B2A ink, sun-baked terracotta #AD6A40 accent. Matte layered surfaces, sturdy 6px rounded rectangles, fine horizontal stratum lines, legible grounded humanist sans. Tiny dune contour in companion strip only. Sunlit earthy and quiet, no gritty noisy texture.

### Flying

Companion: Pidgey

Open sky: cloud-white #F5F9FC canvas, powder-blue #DFEBF8 shell, deep slate-blue #314E73 ink, cornflower #759FDB accent. Long airy capsule controls, subtle sky gradients only in empty header space, extra breathing room, light thin rules. Small feather/windline motif beside companion. Effortless native legibility, no clouds behind text.

### Psychic

Companion: Abra

Astral mind: rich indigo-plum #241B38 canvas, violet #382849 surfaces, very pale pink #F9E8F3 ink, saturated rose #E985B7 accent with lilac #AD9FEB secondary. Smooth concentric orbital outlines and pill controls; clean geometric sans and calm aligned timer. Tiny orbital rings confined to companion header. Thoughtful cosmic energy, distinct from gold Midnight Observatory and cyan Neon Arcade.

### Bug

Companion: Caterpie

Field study: creamy chartreuse-white #F2F3DB canvas, light olive #DEE3B6 shell, dark moss #38451F ink, lively chartreuse #8EAA39 accent. Neatly segmented progress indicators, compact softly angular 6px controls, micro leaf-vein geometry in companion strip. Precise friendly naturalist notebook, sharper lime/olive rather than Grass's leafy green.

### Rock

Companion: Geodude

Granite workshop: pale limestone #EAE6DE canvas, stone #D4CBBB shell, charcoal-umber #413E36 ink, ochre-bronze #A38A4C accent. Flat quarry-block geometry, bevel-free squared controls with 3px corners, substantial but restrained dividing rules. Very subtle mineral fleck only in companion strip, all reading surfaces smooth. Architectural calm, no fake 3D boulders surrounding controls.

### Ghost

Companion: Gastly

Lavender dusk: smoky violet #211D32 canvas, raised dusk #342C49 surfaces, soft lilac-white #ECE5FC ink, spectral lavender #AD93DE accent with tiny seafoam #95CBBE details. Soft quiet rounded controls, faint hazy halo confined to companion strip, subtle dashed or fading separators sparingly. Friendly mysterious twilight; legible still surfaces, no horror, no wisps behind task text.

### Dragon

Companion: Dratini

Royal scale: regal navy #171F39 canvas, sapphire #273252 surfaces, warm pearl #F3ECD9 text, antique gold #D5B673 accent with royal violet #8E78CD secondary. Elegant modest angular corners, slender double-rule accents on companion header, orderly subtle scale geometry there only. Majestic precise UI, solid typography, no weapons, castle scenes, heavy fantasy scrollwork or tiny serif text.

### Dark

Companion: Umbreon

Nocturne: nearly black charcoal #171719 canvas, graphite #272629 surfaces, warm pearl #EEE9DF text, muted moon-gold #B7A575 accent. Restrained matte controls, barely rounded 8px corners, quiet high-contrast selection and thin warm neutral rules. One small crescent/ring detail beside companion. Understated monochrome and gold; distinguish from Dragon by removing heraldic geometry and blue-violet colour.

### Steel

Companion: Magnemite

Precision alloy: light cool-silver #EDF0F2 canvas, brushed-gray #D9DFE3 shell, gunmetal #2C3841 text, desaturated steel-blue #5C8493 accent. Clean 6px machined corners, exact 1px borders, flat panels with restrained metallic gradient only in shell, technical mono labels and readable native sans body. Tiny rivet-free concentric instrument marking by companion. Refined precision, no industrial clutter.

### Fairy

Companion: Clefairy

Rose quartz: blush-white #FFF4F5 canvas, petal-pink #F0DDE8 shell, dark mulberry #633D5C ink, raspberry-rose #BC709F accent, whisper of lilac. Soft 14px rounded controls, delicate fine borders, one tiny star-petal sparkle detail in companion strip, polished rounded sans. Gentle magical warmth, grown-up and readable, no glitter shower, heart overload, pastel low contrast, or cartoon toy controls.
