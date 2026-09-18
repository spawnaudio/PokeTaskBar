# Original Creature Collection — Future Replacement Plan

**Project:** PokeTaskBar

**Status:** Future concept / discussion draft — no implementation or release commitment

**Prepared:** 18 September 2026

**Art direction confirmed:** Pixel art matching the current Pokémon icons.
**Linear home:** PokeTokenBar - Adjustments

**Purpose:** Replace the active Pokémon collection with an original creature world while retaining the app’s focus, task, XP, companion, and collection experience.

## 1. The idea

A small world of original companions that grows alongside your work. Keep the appeal of discovering, hatching, training, evolving, and collecting expressive creatures. Give the world its own names, silhouettes, elemental language, lore, and visual identity.

The creatures should feel like companions, with readable personalities and a satisfying sense of growth. They should not require feeding schedules, daily maintenance, or punishment for taking time away. Focus sessions and completed work remain the app’s purpose; the creature layer makes that progress enjoyable.

**Recommended direction:** a warm, nature-and-elements world rendered in pixel art like the current Pokémon icons: simple shapes, crisp pixel clusters, dark stepped outlines, expressive faces, limited palettes, and clear colour blocking. Use original anatomy, markings, names, and evolution concepts rather than recolouring existing characters.

“Original creatures” is the working label. Decide the world name and eventual app name after the creatures have a coherent identity.

## 2. What “complete replacement” means

The finished active experience uses our own:

- Species roster, names, descriptions, elemental affinities, rarity, and evolution relationships.
- Static art, animated sprites, alternate colourways, eggs, item icons, silhouettes, and celebration imagery.
- Collection terminology, profile content, notifications, help text, onboarding, screenshots, and current marketing.
- Local catalogue and assets, without needing PokéAPI or the PokeAPI sprite repository for normal creature use.

This is more than replacing the list or swapping image URLs. Save data, selection rules, cached images, profile metadata, and special species behaviour also need deliberate treatment.

Historical upstream documentation and attribution can remain clearly labelled as historical. An untouched backup of a user’s previous collection is separate from the new active collection.

## 3. What the repository currently does

These observations come from the working tree inspected on 18 September 2026; re-check the final source before implementation.

| Area | Current dependency | Consequence |
| --- | --- | --- |
| Species and evolution | `PokeAPIClient.swift` implements `PokeProviding` and `PokemonDetailProviding` | Replace remote catalogue content through the existing provider boundaries where practical. |
| Identity and saves | `CompanionModel.swift` stores integer species IDs, evolution paths, collection entries, pending hatch IDs, storage, and representative selection | Image replacement alone would leave old identities and progression behind. |
| Asset availability | `PokemonAssets` and evolution-tree construction assume animated species IDs 1–649 | Replace the numeric cutoff with actual catalogue asset availability. |
| Rendering | `SpriteLoader.swift` fetches PNG/GIF files, eggs, and item sprites from PokeAPI’s GitHub repository | Supply local artwork, new cache identities, and dependable static fallbacks. |
| Individual profiles | `PokemonProfile.swift` stores individual identity and generated attributes; detail data includes types, abilities, moves, and battle stats | Decide which profile concepts serve a focus companion and author their replacements. |
| Special behaviour | `CompanionStore.swift` includes Ditto disguises, shiny rolls, rarity guarantees, and duplicate-hatch rules | Generalise only behaviour we intend to keep; retire Pokémon-specific rules. |
| Export/import | `SaveTransfer.swift` uses the `poketaskbar.save` envelope, currently schema 2 | Introduce and verify an explicit migration and import policy. |
| Packaging and state | `Package.swift` has no executable resource declaration; `AppStatePaths.swift` derives bundled state location from the app name | Add resource packaging and handle any rename without making existing progress appear lost. |

The repository already contains other work in progress. This proposal does not change or claim ownership of it.

## 4. Art direction and the first five concepts

Use five distinct silhouettes and personalities so the first review tests the world’s range. These names and affinities are provisional, and the five illustrations are concept mockups rather than finished game assets.

| Working name | Affinity | Visual idea | Personality and motion | Evolution direction |
| --- | --- | --- | --- | --- |
| **Mosskip** | Grove | Small cream-and-moss pika-like creature; folded fern ears, seed-shaped feet, curled fiddlehead tail | Curious and springy; ear unfurl and a small hop | The fern forms become a protective leafy mantle; retain its round face and tail curl. |
| **Cindillo** | Ember | Squat armadillo with smooth charcoal armour plates and warm amber seams; apricot face and feet | Determined and affectionate; shell rises with a breath, then a gentle ember puff | Develop a broad kiln-like shell with larger plates and a warm internal glow. |
| **Puddlepip** | Tide | Compact aqua platypus-like creature with a pale short bill and a broad translucent raindrop tail | Calm and observant; tail wobble and a relaxed blink | Tail becomes a flowing paddle-shaped crest; mature into a graceful river guardian. |
| **Voltuff** | Spark | Fluffy periwinkle jumping spider with eight short legs, a cloud-shaped body, bright eyes, and two small amber antennae | Eager and slightly clumsy; quick foot shuffle and a tiny static flicker | Develop more defined storm-cloud tufts and bold amber bands while retaining the low, friendly stance. |
| **Noctuft** | Dusk | Round plum-coloured moth with cream face fluff and broad wings bearing pale crescent markings | Quiet and reassuring; slow wing stretch and a sleepy head tilt | Wings grow into a generous moon-patterned cloak; retain the soft central body. |

Affinity is a visual and lore choice in the first version. It does not require combat, type matchups, or separate reward multipliers.

### Shared visual rules

- One dominant silhouette, one memorable identifying feature, and roughly three to five main colours.
- Friendly creature anatomy with a believable internal logic; details grow from the animal-and-element idea.
- Crisp stepped pixel outlines, deliberate pixel clusters, limited colour ramps, and expressive eyes. No smooth vector contours, watercolor finish, blur, or anti-aliased edges.
- Evolution develops the same idea; it should remain recognisably the same family.
- Alternate colourways should be deliberately art-directed and distinguishable beyond a minor hue shift.
- Design for the tiny companion view as well as the larger collection profile. If a signature feature disappears at actual display size, simplify it.

Create the five mockups directly as pixel-art sprite concepts, shown enlarged with crisp nearest-neighbour-style pixels for inspection. Keep a consistent apparent pixel scale and compact handheld-RPG proportions. These are still concept mockups: production requires a verified native-size grid, transparent backgrounds, consistent pivots and palette, and authored animation frames.

## 5. Roster and gameplay scope

**First technical pilot:** one family with two evolution stages, one egg, a standard appearance, one alternate appearance, and the minimum supporting item artwork. It must work through hatch → growth → evolution → graduation → storage/collection → selection → relaunch.

**First complete original roster:** five families with two stages each, for ten species. Introduce three-stage or branching families later, only if the smaller roster is enjoyable and the asset pipeline is manageable.

Retain the existing sources of XP, Coins, session progress, and task credit during the content replacement. Balance changes should be an explicit later decision, making it possible to judge the creature change by itself.

A small roster needs changes to collection rules:

- Favour unseen families, then allow clearly labelled repeat companions once all eligible families are discovered. The app must still hatch and train after collection completion.
- Define rarity and hatch weights directly in our catalogue. Do not invent Pokémon-style capture-rate values just to drive existing code.
- Offer only egg tiers the available roster can fulfil. Existing purchased guarantees need a documented fulfilment or compensation policy before conversion.
- Give each individual its own stable instance identity even when multiple companions share a species.
- Treat alternate appearances as an optional discovery layer, not the only way to continue using a completed collection.

**Recommended profiles:** species, affinity, short lore, rarity, stage, level/growth, discovered date, and a small personality trait. Moves, abilities, IVs, and combat stats can stay in the legacy backup; rebuilding a battle database adds little to the first focus-companion release.

Keep existing item effects initially, but give them original names and art: for example Growth Treat, Focus Tea, Prism Charm, and Nest Egg. These are naming directions, not settled replacements. Migrate stored inventory keys explicitly rather than losing stock when labels change.

Defer battles, trading, breeding, multiplayer, a marketplace, user-imported packs, a creature editor, and a large procedural generation system.

## 6. How the content would be produced

1. **Write a compact art bible.** Set proportions, outlines, palette rules, eyes, shading, anatomy, evolution logic, and examples of acceptable small-size simplification.
2. **Review the five concepts.** Pick the world’s strongest direction and one pilot family. Judge silhouette, personality, family resemblance, and suitability beside work UI.
3. **Create a model sheet for the pilot.** Front, side, rear, expression references, palette, relative size, and both evolution stages.
4. **Build the actual sprite assets.** Use a consistent transparent canvas, foot baseline, optical scale, and framing across frames. Prototype at a 96 × 96 canvas because the current loader references padded 96px static art; confirm the right size in the app before making it a standard.
5. **Animate sparingly.** First deliver a short idle loop and a celebration reaction or reuse a shared celebration effect. Walking, sleeping, and more elaborate evolution transitions come later when a real surface uses them.
6. **Make variants and shared artwork.** Alternate palettes, eggs, unknown-species silhouettes, and replacement item icons.
7. **Export and inspect.** Transparent PNG for stills; GIF is compatible with the current animation path. Test alpha edges and colour limitations before deciding whether a different animation format is justified.
8. **Package the approved assets.** Keep editable source files, exported files, author/source notes, palette references, and version information together.

For ten species, even a minimal package means 10 normal stills + 10 alternate stills + 10 normal idle loops + 10 alternate idle loops: **40 exported files before eggs, items, and effects**. Concept illustrations are additional. Animation consistency is likely to be a major production task.

Generated art can explore directions quickly. The selected designs still need consistent model sheets, deliberate sprite cleanup, and frame-by-frame review. A beautiful mockup is not evidence of production readiness.

## 7. The smallest useful technical change

Use a bundled, versioned catalogue and local assets. Start with ordinary data files and the existing companion store; a general-purpose content marketplace or plugin engine is unnecessary.

### Catalogue data

Each species needs a stable identity, family identity, display order, localised name/description, affinity, rarity/hatch weight, stage/evolution links, growth settings, and asset references. Asset metadata should state available variants, canvas/pivot, frame timing where required, and content version.

Use a catalogue namespace plus stable species keys, such as `original:mosskip-01`. Keep user-visible numbering separate from identity. Old numeric Pokémon IDs belong to a legacy namespace. Never reuse an old number to silently turn one saved species into another.

The exact Swift representation should be settled during the pilot. A temporary adapter can reuse the existing provider seams while persisted identity and caches gain a catalogue namespace; avoid renaming every Pokémon-named symbol in one large change.

### Integration sequence

1. Add the small original catalogue and validate its references.
2. Reuse/adapt `PokeProviding` for species and evolution; adjust the detail path for the chosen simpler profiles.
3. Add local asset loading and include catalogue/version/species/variant in asset cache keys.
4. Replace the 1–649 animation assumption with manifest-driven asset checks.
5. Route hatch pools and rarity guarantees through the original catalogue.
6. Disable Ditto-specific behaviour for this catalogue and remove it from the final active experience unless an original equivalent is intentionally designed.
7. Update collection, storage, companion selection, profile views, menu-bar pet, floating pet, notifications, and localisation.
8. Package resources through SwiftPM and the actual app build/release scripts, then test the installed bundle.

Missing animation should fall back to the same creature’s static image; missing art should use an original neutral placeholder. Unknown saved identities should remain recoverable records, never be silently deleted.

## 8. Existing collections and migration

**Recommended default: preserve the old collection as an exportable legacy archive and begin a separate original collection.** A many-to-one mapping from hundreds of Pokémon into ten original species would misrepresent ownership and collapse different companions.

Before any conversion, show a concrete preview: what is carried forward, what is archived, what happens to the current companion, and how to restore the backup.

Carry forward:

- Earned XP/Coins and spending totals without awarding them a second time.
- Inventory or explicit equivalent items with the same usable value.
- Linear issue/project credit ledgers so completed work cannot earn rewards twice.
- Focus/session history, preferences, and other non-creature progress.

Archive:

- The complete old collection, individual identities and profile values, evolution paths, active companion, stored companions, and representative selection.
- A dated pre-migration save in its original format, independently of any simplified archive view.

For the active slot, recommend letting the user select an original starter and transferring the current companion’s **normalised growth progress**, rather than replaying all lifetime XP. Specify and test the conversion formula, stage boundaries, rounding, and any capped surplus before release. An egg retains its progress and paid rarity guarantee only if the new pool can honour it; otherwise present a clear equivalent or refund choice.

The archive is read-only and does not require remote Pokémon art or metadata to browse its summary or export the untouched backup. New active UI uses only original creatures. Users who want their original save back restore it using a compatible build.

### Required migration properties

- Explicit versioned transformation, separate from forgiving ordinary save decoding.
- Backup must succeed before conversion; write the new state atomically.
- Running migration twice must not duplicate rewards, items, or creatures.
- Cover active eggs, partial evolution, completed collections, stored eggs/companions, alternate forms, pending hatch selections, and missing/unknown IDs.
- Clear only obsolete creature caches and selections after a verified conversion; preserve the backup.
- Import older exports through the same migration path; reject unsupported future schemas clearly.
- Define rollback boundaries: restoring the pre-migration backup loses subsequent original-world progress unless exported separately. Do not promise automatic merging in the pilot.

If the app is renamed, explicitly migrate the app-name-derived data folder and relevant preferences. A new display name must not launch an apparently empty save. Keep credentials and Linear connection state intact.

## 9. Delivery stages and decision gates

| Stage | Deliverable | Gate before continuing |
| --- | --- | --- |
| A — Direction | This plan, five concepts, and a compact art bible | Choose one coherent style and one pilot family. |
| B — Art proof | Two-stage family, static assets, idle loops, variants, egg | Readable and appealing at actual app sizes in light and dark appearances. |
| C — Playable pilot | Local catalogue, bundled assets, full companion loop using isolated test saves | Works offline after a fresh install; relaunch, storage, selection, and collection completion work. |
| D — Migration proof | Versioned converter, preview, backups, import/export fixtures, restore procedure | No unexplained loss or duplicate credit across representative existing saves. |
| E — Roster production | Five complete families and supporting original content | All entries and assets pass the same checks; small-roster hatch behaviour remains useful. |
| F — Full switch | Original content becomes the active/default experience; current branding and copy updated | Installed build passes functional, visual, migration, and packaging checks. |

Use outcomes rather than a calendar promise. Estimate production after the two-stage pilot reveals the cost of one finished family. Do not start producing dozens of creatures before that evidence exists.

A temporary development switch can help compare catalogues. Shipping two indefinitely supported creature systems is a separate product decision, not a requirement of this plan.

## 10. Acceptance and validation

A full replacement is ready when:

- A clean install can hatch, grow, evolve, graduate, store, select, and display original creatures offline.
- Normal creature use makes no PokéAPI or PokeAPI sprite requests, including eggs, shop items, profiles, prefetching, and fallback paths.
- All catalogue IDs are unique; evolution links resolve and contain no cycles; hatch pools and offered egg guarantees have valid candidates.
- Completing the small roster does not create an endless reroll or blocked hatch.
- Missing animations and optional variant art have safe, consistent fallbacks.
- Sprites remain legible in the actual menu bar, companion panel, collection grid, profile, and floating pet, with stable sizing and no clipping or frame jitter.
- Reduced Motion/static presentation works; animation stops when appropriate and does not create a new background CPU cost.
- English, Korean, and Japanese interfaces have original terminology and deliberate name fallbacks.
- Existing save fixtures preserve financial/gameplay balances, credited work, history, storage records, and backup recoverability; repeat migration/import cannot mint rewards.
- A renamed app resolves the existing state correctly, and both development and installed builds include the same required assets.
- Current UI, release screenshots, app icon, onboarding, and outward-facing copy consistently represent the original world.

For implementation, run the repository’s macOS build and `scripts/test-gate.sh`, with focused tests for catalogue validation, progression, migration, and asset fallback. Inspect real runtime behaviour and before/after captures; passing logic tests alone does not validate artwork or animation.

**Validation of this document:** based on source inspection and the existing Linear project. No app changes, runtime creature tests, migration tests, or performance measurements were performed for this planning task.

## 11. Decisions to revisit when the work begins

1. Which concept best defines the world, and which family should be the pilot?
2. Pixel art is confirmed. Settle the native sprite dimensions, palette limits, and animation budget after testing one family.
3. Accept the recommended legacy archive + new collection approach, or design an explicit opt-in conversion policy?
4. Keep the recommended lightweight profiles, or justify specific additional attributes?
5. Choose final creature/world/app names after reviewing the designs and checking name availability and asset provenance.

**First future action:** select one of the five concepts and make its two-stage model sheet plus one actual-size idle sprite. That will make the next engineering and art decisions concrete.
