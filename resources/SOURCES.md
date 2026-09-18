# Pokémon resource sources and attribution

Retrieved 18 September 2026. Files are local design references; review the original source notices when choosing assets for later UI work. The source material retains its original ownership.

## PokéAPI Sprites

- Repository: [https://github.com/PokeAPI/sprites](https://github.com/PokeAPI/sprites)
- Exact revision: [`1dce80ceb372675e9fc7e9f101b71845ef587de2`](https://github.com/PokeAPI/sprites/tree/1dce80ceb372675e9fc7e9f101b71845ef587de2)
- Downloaded: **11,175 images**, 11,177 total source files.
- Preserved notices and metadata: [`_sources/pokeapi/`](_sources/pokeapi/).

Imported all available generation-level menu icon folders for Generations III–VIII; top-level front sprites for Red/Blue, Red/Green Japan, Yellow, Gold, Silver and Crystal; Scarlet/Violet and Brilliant Diamond/Shining Pearl Pokémon icon folders; all item, badge and game-specific type folders at this revision. The enormous HOME, official artwork and Showdown collections were not downloaded. Game folders and variant names follow the source.

The upstream `LICENCE.txt` labels the repository CC0 and separately states that the image contents belong to The Pokémon Company. Its README credits community sprite contributors. Preserve that distinction when evaluating assets.

## PokéSprite

- Repository: [https://github.com/msikma/pokesprite](https://github.com/msikma/pokesprite)
- Exact revision: [`c5aaa610ff2acdf7fd8e2dccd181bca8be9fcb3e`](https://github.com/msikma/pokesprite/tree/c5aaa610ff2acdf7fd8e2dccd181bca8be9fcb3e)
- Downloaded: **10,029 images**, 10,039 total source files.
- Preserved notices and metadata: [`_sources/pokesprite/`](_sources/pokesprite/).

Imported `pokemon-gen8`, `pokemon-gen7x`, legacy `icons/pokemon`, `items`, `items-outline`, and `misc`, plus current JSON lookup data and original contributor credits. These include regular/shiny Pokémon, alternate forms, bag items, ribbons, marks, origin marks, type logos and other interface symbols.

The `pokemon-gen7x` set is an enhanced Gen VII style, padded to Gen VIII dimensions and contrast; it is stored under `styles/generation-07-enhanced`. Gen VIII includes earlier-generation fallbacks and some unofficial Legends: Arceus variants. Shiny menu sprites are custom versions. The original 40×30 legacy sprites are separate.

The README attributes sprites to Nintendo/Creatures Inc./GAME FREAK Inc. and applies MIT to code and everything else. `license.md`, `contributors.md` and `readme.md` are preserved; the software licence is not blanket permission for the sprites.

## Pokémon Icons DB

- Repository: [https://github.com/NathanPERIER/pokemon-icons-db](https://github.com/NathanPERIER/pokemon-icons-db)
- Exact revision: [`55f44c7ad7571489a858361a5b17d6fd8d6b2cd7`](https://github.com/NathanPERIER/pokemon-icons-db/tree/55f44c7ad7571489a858361a5b17d6fd8d6b2cd7)
- Downloaded: **274 images**, 277 total source files.
- Preserved notices and metadata: [`_sources/pokemon-icons-db/`](_sources/pokemon-icons-db/).

Imported only Pokémon menu icons whose National Pokédex ID is 906 or greater, both regular and shiny, into the Gen IX community folder. Earlier-generation icons and this source's type packs were omitted to reduce overlap. Full `pokemon.json` and `types.json` were retained for names and provenance, so they contain entries outside the imported subset.

The README attributes Gen IX icons to Caruban's resource pack and credits Vent, Katten, leParagon, Cesare_CBass, AlexandreV2.0, Carmanekko and GRAFAIAIMX. It identifies Pokémon sprites as Nintendo/Creatures Inc./GAME FREAK Inc. material. No standalone licence file was found at this revision.

Original pack: [Generation 9 Resource Pack](https://www.pokecommunity.com/threads/generation-9-resource-pack-v21-1.527398/).

## Pokémon Type SVG Icons

- Repository: [https://github.com/duiker101/pokemon-type-svg-icons](https://github.com/duiker101/pokemon-type-svg-icons)
- Exact revision: [`5781623f147f1bf850f426cfe1874ba56a9b75ee`](https://github.com/duiker101/pokemon-type-svg-icons/tree/5781623f147f1bf850f426cfe1874ba56a9b75ee)
- Downloaded: **18 images**, 19 total source files.
- Preserved notices and metadata: [`_sources/type-svg-icons/`](_sources/type-svg-icons/).

Imported all 18 SVG type symbols and the original README. These are scalable symbol shapes, useful for exploring compact UI badges; they are not a complete current game interface or a game-specific asset set.

No standalone licence file was found at this revision. The README describes the symbols as “for any use” and points to the original design below. This is recorded as an upstream statement, not a verified rights clearance.

Original design linked by the author: [Pokédex iOS app](https://dribbble.com/shots/4862612-Pokedex-iOS-app).

## pret / Pokémon Emerald

- Repository: [https://github.com/pret/pokeemerald](https://github.com/pret/pokeemerald)
- Exact revision: [`5eff78649e7170a877b961ef0b3da13b81a16038`](https://github.com/pret/pokeemerald/tree/5eff78649e7170a877b961ef0b3da13b81a16038)
- Downloaded: **551 images**, 891 total source files.
- Preserved notices and metadata: [`_sources/pokeemerald/`](_sources/pokeemerald/).

Imported PNGs and palette files only from `graphics/bag`, `balls`, `berries`, `battle_interface`, `frontier_pass`, `interface`, `items`, `party_menu`, `pokedex`, `pokemon_storage`, `pokenav`, `summary_screen`, `text_window`, `trainer_card`, and `types`.

This source provides raw Emerald graphics for reference: arrows, status icons, item icons, badges, party-menu elements, type labels, window borders and related UI sheets. Some subfolders explicitly include FireRed/LeafGreen variations, retained in place. Tiles and multi-frame strips may need slicing and palette interpretation; they are not all standalone transparent icons. No ROM, executable, game logic, audio or font collection was imported.

The upstream README identifies the project as an Emerald decompilation. No top-level licence granting reuse of game graphics was found. Licences for individual development tools are not licences for the game artwork.

## What the manifest records

`manifest.json` maps every local file to its source repository, pinned commit (in the source table), original path, Git blob hash, SHA-256 checksum, byte size and image dimensions where applicable. It records the CRLF checkout normalisation used to verify Emerald palette Git hashes. Images were copied unchanged; no source repository scripts were executed.

## Additional source browsers

- [PokéAPI Sprite Finder](https://pokeapi.github.io/sprites/) — browse the larger collection, including omitted artwork styles.
- [PokéSprite inventory overview](https://msikma.github.io/pokesprite/overview/inventory.html) — item categories and mappings.
- [PokéSprite miscellaneous overview](https://msikma.github.io/pokesprite/overview/misc.html) — marks, ribbons and other UI symbols.
- [Bulbagarden sprite archive](https://archives.bulbagarden.net/wiki/Category:Game_sprites) — further game graphics; linked for exploration, not bulk-downloaded here.
