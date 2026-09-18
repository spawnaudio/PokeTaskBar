# Component sheet generation prompts

Tool: built-in Image Gen. Each independent call used its matching theme concept as an image reference.

## Shared specification

Use case: ui-mockup. Create a polished DESIGN SYSTEM COMPONENT SHEET for PokeTaskBar, a native macOS task/focus app with a Pokémon companion. This is an explicit component-catalogue request, NOT a single app screen. Show one cohesive theme per image. Use the attached theme mockup as the actual style reference: preserve its colours, materials, border language, typography character and small full-colour Lapras sprite, while composing reusable controls rather than repeating the app screenshot.

Target dimensions: 2048 x 3072 pixels portrait, high-resolution, sharp UI typography, flat front-facing artboard. Maximize actual resolution and readable text. Background is this theme's app canvas. No laptop/phone frame, no desktop scene, no page perspective, no promotional illustration. Top: clear title "[THEME] — UI elements", small subtitle "PokeTaskBar • Concept study", then six small labelled swatches "Canvas / Surface / Text / Accent / Border / Selected" and type samples "Heading / Body / 24:18". Below: an orderly three-column by four-row grid of 12 spacious component specimens. Separate groups primarily with whitespace and small section headings. Specimen groups are NOT twelve giant nested cards. Each group has a modest heading and clearly readable, generously spaced examples. All 12 groups must be present and visible; no clipping. Make each component realistic native desktop scale, not tiny illustrations. Keep body type consistent, maximum two font families; pixel/serif fonts only where the reference calls for them, never unreadable tiny text.

READING ORDER, left to right then down:
01 ACTIONS. Filled "Start focus", outlined "Open issue", plain "Cancel", destructive "Forfeit", icon-only gear. A second small row labelled "Hover", "Pressed", "Disabled", "Focus" showing the SAME compact "Start" button in these states; visibly distinguish keyboard focus with a ring, disabled with reduced contrast, not merely changed text. State captions sit outside controls.
02 NAVIGATION. Tabs "Focus / Linear / Collection / Usage" with Focus selected; separate segments "Bag / Storage / Dex / Shop" with Dex selected. Small Back arrow and an expanded/collapsed disclosure pair.
03 TEXT INPUTS. A normal labelled task field containing "Polish theme controls"; a focused field with visible focus ring; a short password field containing bullets only; one multiline note field "Add a session note…". Show field error text "Title required" below an empty invalid input if space allows. No real credentials.
04 CHOICE CONTROLS. Labelled toggle examples On and Off, checked and unchecked checkboxes, slider "Growth 75%", and a compact "Status: In progress" picker with its open menu underneath containing Todo, In progress with checkmark, Done. Native popup menus stay restrained and readable, not elaborate custom art.
05 ROWS & INSPECTOR. Two task rows "PTB-42  Polish theme controls" and "PTB-43  Review colours", one visibly selected with pin icon. Below, small property rows "Status / In progress", "Priority / High". Use quiet dividers rather than individual cards.
06 BADGES & STATUS. Small chips "Todo", "In progress", "Done", "High", "Rare". A separate inline warning with triangle "Overtime". Semantic distinctions remain clear using icons or shapes plus labels; red errors, amber warnings, green success cannot all become the accent colour.
07 PROGRESS & SCORE. XP bar at 65% with "650 / 1,000 XP"; compact "Today 2,400 XP" and "128 Coins"; a tiny simple 7-bar usage chart and a small loading spinner. No extra invented metrics, no date labels.
08 COMPANION & ITEMS. Small Lapras companion card with "Training" and progress; miniature selected Dex tile "Lapras" with full-colour pixel sprite; small egg bag/shop tile "Egg" and "10,000 Coins" and a tiny "Buy" control. Artwork stays confined to these tiles/header, never behind labels. Preserve sprite colours.
09 FOCUS TIMER. Prominent "24:18" with Pause icon and "Running"; smaller paused example "12:04" with Resume icon; overtime example "+02:10" with amber "OT" label; duration segments "15 / 25 / 45" with 25 selected. This group is a component specimen, not an enormous hero.
10 FLOATING CHROME. Compact horizontal floating island with small Lapras, "PTB-42", "24:18", Pause icon; a tiny folded countdown pill; a short speech bubble "Ready when you are"; a tooltip "Pause timer". Show shape, surface and pointer details clearly.
11 FEEDBACK & CONFIRM. A compact in-panel confirmation "Reset timer?" with "Cancel" and "Reset"; a green inline success "Note saved"; a red inline error "Could not connect" with "Retry"; amber warning "Session needs attention". Keep supportive language and semantic colours.
12 EMPTY, LOADING & LOG. Quiet empty state "No pinned task" and "Open Linear"; one skeleton task row labelled "Loading"; one session log row "Focus complete · 25 min", one note row "Next: review controls". Do not imply features beyond this app's existing tasks, settings, collection, timers, and session notes.

Footer: "Visual exploration • Not implemented". Current date anchor September 18 2026; avoid visible dates. Align all specimens on a consistent grid with ample whitespace. Preserve the semantic meaning of controls across themes. This is one independent image of one theme's full component family, not multiple theme options.

## Theme directions

### Classic

Replace [THEME] with Classic. Append:

Theme direction: Native restrained macOS utility. Cool gray #F3F4F6 shell, white canvas, crisp charcoal text, blue accent, fine neutral dividers, 12pt continuous corners and subtly rounded controls. System sans and monospaced timer. Flat calm highly usable reference style.

### Habitat

Replace [THEME] with Habitat. Append:

Theme direction: Warm cream #F5F4E9, pale sage #E5EBDC, deep forest ink #253C32, botanical green #487454 accents. Soft modest rounded controls, quiet nature-inspired warmth. Tiny pixel shoreline ONLY inside companion tile, never decorating every component. Clear native rounded sans.

### Retro

Replace [THEME] with Retro. Append:

Theme direction: Handheld RPG inspired LCD sage #DCE6BF and #BFCB9B with dark olive #253729 ink. Crisp squared 4px corners and selective pixel-step edges. Blocky short section headings and timer, native sans for all other labels. Full colour sprites. No scanlines, no fake device shell, no texture that reduces readability.

### Pokédex

Replace [THEME] with Pokédex. Append:

Theme direction: Warm vermilion #BA343D, soft porcelain #F5F1E8, charcoal ink, cyan sensor accent. Restrained red instrument-panel borders and clipped-corner controls. Cream form fields, red primary buttons. Precise technical section labels, clean native sans body. A tiny sensor motif at the title only, no physical device or bolts.

### Midnight Observatory

Replace [THEME] with Midnight Observatory. Append:

Theme direction: Deep inky indigo #141A2B, slate-blue raised surfaces #202A40, moon-white #F0EBDC text, brass-gold #DDBA78 accent. Soft thin borders, gold primary controls. One tiny constellation detail confined to the companion tile. Elegant low-light native typography, no neon glow.

### Paper Journal

Replace [THEME] with Paper Journal. Append:

Theme direction: Warm ivory #F6F0E3, oatmeal #E8DFCF, espresso #332C28, burnt orange #B95032. Serif section headings plus very readable sans controls, minimal ink rules, nearly square flat controls, no shadows or glass. Paper grain barely perceptible and absent behind small control labels. Dark ink primary buttons.

### Ocean Glass

Replace [THEME] with Ocean Glass. Append:

Theme direction: Luminous icy aqua #E6F3F5, sea glass #D3ECEC, navy teal ink #153D48, ocean blue #087AA0. Soft frosted native surfaces, delicate white rim highlights, quiet translucency while retaining opaque legible fields and menus. Rounded native type. Water caustics only in companion tile, no heavy glass blob decoration.

### Neon Arcade

Replace [THEME] with Neon Arcade. Append:

Theme direction: Near-black aubergine #18121F, deep plum #261B31, soft lavender-white #F3EEF7 text, orchid-pink #ED71CE primary accent, cyan #64E2ED secondary accent. Crisp modest cut-corner controls, limited bright borders, restrained accent glow only. Sharp readable system sans and monospaced timer, not gimmick fonts. No scanlines, visual noise, or busy grid behind controls.

