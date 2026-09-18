# Original creature collection — v1

**Style: pixel art.** A growing collection of original creature mockups for PokeTaskBar.

[Open the local visual collection](index.html) · [100-creature usage and time estimate](production-estimate.md) · [Future replacement plan](../../Documents/original-creatures/plan.md)

The collection contains **15 creatures: five retained pixel designs and ten new designs**, each with a matching face-only icon. The five superseded smooth/cartoon illustrations were deleted at the user's request.

## Files

- `hero/` — full-body pixel-art concept PNGs.
- `icons/` — simplified face/head concept PNGs using the same filenames as their heroes.
- `catalog.json` — names, affinities, pair paths, batch and concept status.
- `generation-spec.json` — the exact shared hero/icon instructions, creature briefs and identity details used with built-in Image Generation.
- `generation-log.json` — generation timings and saved-file provenance for this batch.
- `asset-manifest.json` — verified image dimensions, transparency and SHA-256 checksums.
- `index.html` — offline gallery, name/affinity search, new/original filters, and light/dark preview backgrounds.

GitHub displays the previews below. To use search, filters and small-size comparisons, open `index.html` from a local checkout.

## Roster

| ID | Creature | Affinity | Concept | Hero | Face |
| --- | --- | --- | --- | --- | --- |
| 01 | Mosskip | Grove | Fern-eared woodland companion | <img src="hero/01-mosskip.png" width="128" alt="Hero concept"> | <img src="icons/01-mosskip.png" width="48" alt="Face icon"> |
| 02 | Cindillo | Ember | Glowing-armour armadillo | <img src="hero/02-cindillo.png" width="128" alt="Hero concept"> | <img src="icons/02-cindillo.png" width="48" alt="Face icon"> |
| 03 | Puddlepip | Tide | Raindrop-tailed aquatic companion | <img src="hero/03-puddlepip.png" width="128" alt="Hero concept"> | <img src="icons/03-puddlepip.png" width="48" alt="Face icon"> |
| 04 | Voltuff | Spark | Fluffy electric spider | <img src="hero/04-voltuff.png" width="128" alt="Hero concept"> | <img src="icons/04-voltuff.png" width="48" alt="Face icon"> |
| 05 | Noctuft | Dusk | Crescent-winged moth | <img src="hero/05-noctuft.png" width="128" alt="Hero concept"> | <img src="icons/05-noctuft.png" width="48" alt="Face icon"> |
| 06 | Pebblit | Stone | River-stone wombat | <img src="hero/06-pebblit.png" width="128" alt="Hero concept"> | <img src="icons/06-pebblit.png" width="48" alt="Face icon"> |
| 07 | Rimelet | Frost | Snow-drift stoat | <img src="hero/07-rimelet.png" width="128" alt="Hero concept"> | <img src="icons/07-rimelet.png" width="48" alt="Face icon"> |
| 08 | Breezlet | Wind | Breeze-crested tiny bird | <img src="hero/08-breezlet.png" width="128" alt="Hero concept"> | <img src="icons/08-breezlet.png" width="48" alt="Face icon"> |
| 09 | Sprottle | Fungi | Mushroom-quilled hedgehog | <img src="hero/09-sprottle.png" width="128" alt="Hero concept"> | <img src="icons/09-sprottle.png" width="48" alt="Face icon"> |
| 10 | Dunebble | Dune | Sand-frilled gecko | <img src="hero/10-dunebble.png" width="128" alt="Hero concept"> | <img src="icons/10-dunebble.png" width="48" alt="Face icon"> |
| 11 | Corallop | Reef | Coral-crested seahorse | <img src="hero/11-corallop.png" width="128" alt="Hero concept"> | <img src="icons/11-corallop.png" width="48" alt="Face icon"> |
| 12 | Bronzle | Metal | Copper-plated baby tapir | <img src="hero/12-bronzle.png" width="128" alt="Hero concept"> | <img src="icons/12-bronzle.png" width="48" alt="Face icon"> |
| 13 | Glimwing | Gleam | Golden-lantern firefly | <img src="hero/13-glimwing.png" width="128" alt="Hero concept"> | <img src="icons/13-glimwing.png" width="48" alt="Face icon"> |
| 14 | Gloamper | Shade | Velvet-eared small bat | <img src="hero/14-gloamper.png" width="128" alt="Hero concept"> | <img src="icons/14-gloamper.png" width="48" alt="Face icon"> |
| 15 | Thistusk | Meadow | Thistle-tufted little boar | <img src="hero/15-thistusk.png" width="128" alt="Hero concept"> | <img src="icons/15-thistusk.png" width="48" alt="Face icon"> |

## Keep the style consistent

Keep crisp, stepped outlines; visible square pixels; compact handheld-RPG proportions; limited colour ramps; and one memorable species feature. New creatures should fit beside the first five without being recolours of them.

For heroes, begin with one clear full-body idle pose. For icons, redraw only the face/head and essential identifying ears, antennae, or crest. Simplify these features so the expression remains legible at menu-bar size. Do not reduce a whole creature into a tiny icon.

Use the corresponding hero as the identity reference for every face. Keep heroes and icons paired by filename. Add the next creature to the catalogue and gallery together, retaining stable existing IDs.

## Review and refinement

These files are **enlarged static mockups**. The gallery shows face previews at 22, 32 and 48 CSS pixels, but this is not native menu-bar validation. The images have not been added to the app.

Before production, settle a native pixel grid, clean up palette and transparency where needed, export appropriate normal/Retina sizes, and test the actual menu bar in light and dark appearances. Current generated pixel art can contain small variations in pixel spacing and edge alpha; preserve the visual direction while cleaning those deliberately.

The original five pixel heroes were moved without changing their image bytes. Cindillo's retained hero includes its original ivory background. New artwork and face icons were requested with transparent backgrounds; measured file properties are recorded in `asset-manifest.json`.

Future passes can add model sheets, evolution stages, alternate palettes, and animation. Those are separate from the two static mockups per creature counted in the estimate.

Names and affinities remain working concepts. No battle system or type-matchup rules are implied.
