# Pokémon UI design resources

A design reference collection downloaded on **18 September 2026**: **22,047 images** from **five repositories**, plus 339 Emerald palette files and upstream credits/metadata. The copied source files total **46.5 MiB**, before this catalogue and manifest; small files use more space on disk.

**[Open the visual catalogue](index.html)** to filter collections and search Pokémon names, item names or filenames. It works offline: open `index.html` in a browser, without a server or installation. Images are shown at their original proportions, with pixel-preserving rendering. Clicking one opens its local file.

## Useful starting points

| For | Start here |
| --- | --- |
| Compact Pokémon icons for task rows or menus | [Generation VIII, named regular icons](generation-08/menu-icons/pokesprite/regular/) |
| Smaller original 40×30 menu sprites | [Generation VI–VII legacy style](styles/generation-06-07-legacy/menu-icons/pokesprite/) |
| Pokémon from Scarlet/Violet | [Game icons](generation-09/scarlet-violet/pokemon-icons/pokeapi/) or [community pixel icons](generation-09/community-menu-icons/pokemon-icons-db/) |
| Inventory, rewards, shop buttons | [Items by category](cross-generation/items/pokesprite/) and [outlined variants](cross-generation/items-outlined/pokesprite/) |
| Badges, ribbons, marks, type symbols | [Badges](cross-generation/badges/pokeapi/), [miscellaneous UI](cross-generation/ui/pokesprite/), [vector type symbols](vector/type-symbols/duiker101/) |
| Game Boy Advance interface references | [Emerald cursors, status icons, bags, party menu, window borders and palettes](generation-03/emerald/ui/pret/) |

## Folder organisation

```text
resources/
  generation-01/     Red/Blue, Red/Green Japan, Yellow front sprites
  generation-02/     Gold, Silver, Crystal front sprites
  generation-03/     Menu icons; game-specific type labels; Emerald UI
  generation-04/     Menu icons; Diamond/Pearl, Platinum, HG/SS type labels
  generation-05/     Menu icons (including animated PNG strips); BW/B2W2 types
  generation-06/     Menu icons; X/Y and OR/AS type labels
  generation-07/     Menu icons; Sun/Moon, US/UM and Let's Go type labels
  generation-08/     Menu icons; BD/SP Pokémon icons; Sw/Sh and Arceus types
  generation-09/     Scarlet/Violet icons and types; community pixel icons
  styles/           Legacy Gen VI–VII and enhanced Gen VII-style sets
  cross-generation/ Items, outlined items, badges, ribbons and other UI
  vector/           18 scalable Pokémon type symbols
  _sources/         Original README, licence, credits and lookup metadata
  index.html        Offline searchable visual catalogue
  manifest.json     Per-file source path, hashes, size and image dimensions
  SOURCES.md        Source revisions, coverage and attribution notes
```

Each generation contains game-specific folders where the upstream source identifies a game. Shared `menu-icons` folders keep the upstream generation grouping; this does not imply that every icon appeared in every game in that generation. Within each collection, upstream filenames and variant folders are retained, with a source folder to distinguish overlapping collections.

## Sources collected

| Source | Images | Pinned revision |
| --- | ---: | --- |
| [PokéAPI Sprites](https://github.com/PokeAPI/sprites) | 11,175 | `1dce80ceb372` |
| [PokéSprite](https://github.com/msikma/pokesprite) | 10,029 | `c5aaa610ff2a` |
| [Pokémon Icons DB](https://github.com/NathanPERIER/pokemon-icons-db) | 274 | `55f44c7ad757` |
| [Pokémon Type SVG Icons](https://github.com/duiker101/pokemon-type-svg-icons) | 18 | `5781623f147f` |
| [pret / Pokémon Emerald](https://github.com/pret/pokeemerald) | 551 | `5eff78649e71` |

See [SOURCES.md](SOURCES.md) for the exact imported scope and original credits. This is a selection of useful image sets, not full repository clones or a claim of complete game coverage. Counts include alternative forms, directions, shiny variants, sprite strips and overlapping assets from different sources.

## Using the files later

- **PokéAPI names:** numeric Pokémon filenames use its species/form IDs; type filenames use type IDs. PokéSprite generally uses English Pokémon/item slugs. Use the catalogue for name searches and the original JSON mappings under `_sources` for lookups. The preserved metadata describes the upstream datasets, including some images outside this selection.
- **Pixel art:** preserve aspect ratio and use nearest-neighbour scaling at integer multiples when enlarging. Transparent canvas sizes vary by source.
- **Sprite strips and palettes:** some files in `animated` folders and Emerald UI folders contain multiple frames or tiles. PNG strips do not necessarily animate automatically. Emerald `.pal` files are palette references; raw UI sheets may need slicing or palette work before integration.
- **Styles and authorship:** enhanced and community sets include edits and custom shiny variants. They are labelled separately; upstream contributor credits are retained.

## Versioned design references

The repository owner has explicitly authorised tracking this curated collection in ordinary Git, without Git LFS, as a collection-specific exception to the general [contribution rules](../CONTRIBUTING.md#legal--intellectual-property). The downloaded files, catalogue, manifest and upstream notices are included. `resources/.gitignore` excludes only operating-system metadata and temporary files. The collection is outside the Swift package target and has not been added to the app bundle.

The source notes preserve the upstream ownership statements and licence distinctions; repository software licences do not automatically cover Pokémon artwork.

## Verification

All 22,403 imported files were checked against their source Git blob hashes and SHA-256 checksums. All 22,029 PNGs were fully decoded and their dimensions verified; PNG chunk checksums were validated and the 18 SVG files were parsed. Emerald palette archives apply CRLF checkout line endings; Git hash verification normalised those to LF while leaving the copied palette files unchanged.

The offline catalogue was checked in Chrome for image loading, name search, collection filters, regular/shiny lookups, pagination and a narrow mobile viewport. All links in the two local guides were checked. Before committing, the collection was rechecked against the manifest and confirmed to use ordinary Git blobs. No app build or test run was needed for this resource-only collection.
