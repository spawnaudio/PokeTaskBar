<div align="center">

<img src="assets/icon.png" width="128" alt="PokeTaskBar icon">

# PokeTaskBar v1

**Gamified Linear work, with a Pokémon companion. Token usage is a side addition that becomes XP.**

[![macOS](https://img.shields.io/badge/macOS-14%2B-0969da)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-6-f05138)](https://swift.org)
[![License](https://img.shields.io/badge/license-MIT-3fb950)](LICENSE)

**English** · [한국어](README.ko.md) · [日本語](README.ja.md)

</div>

PokeTaskBar v1 is a **new macOS menu-bar app**, pivoted from [spawnaudio/spawn-PokeTokenBar](https://github.com/spawnaudio/spawn-PokeTokenBar) (PokeTokenBar v3). It is **not** a rename of PokeTokenBar v3.

The original usage-tracker README (English / 한국어 / 日本語) stays archived under [`Documents/original-PokeTokenBar/`](Documents/original-PokeTokenBar/). This page is the product: Linear-first scoring, XP / Coins, and companion storage.

It is still an unofficial, non-commercial Pokémon fan project. See [License & disclaimer](#license--disclaimer).

## This is not PokeTokenBar v3

Leave v3 installed if you already have it. PokeTaskBar v1 uses its own name, bundle id, app path, and save folder.

| | PokeTokenBar v3 (untouched) | **PokeTaskBar v1 (this repo)** |
|---|---|---|
| Display name | `PokeTokenBar v3` | **`PokeTaskBar v1`** |
| Bundle id | `io.github.chattymin.poketokenbar.v3` | **`io.github.spawnaudio.poketaskbar.v1`** |
| App | `/Applications/PokeTokenBar v3.app` | `/Applications/PokeTaskBar v1.app` |
| Saves | `~/Library/Application Support/PokeTokenBar v3` | `~/Library/Application Support/PokeTaskBar v1` |
| GitHub | [spawnaudio/spawn-PokeTokenBar](https://github.com/spawnaudio/spawn-PokeTokenBar) | [spawnaudio/PokeTaskBar](https://github.com/spawnaudio/PokeTaskBar) |
| Rebuild | `./scripts/rebuild-v3.sh` | **`./scripts/rebuild-v1.sh`** |

This tree does **not** ship `rebuild-v2.sh` / `rebuild-v3.sh`. Rebuild with `./scripts/rebuild-v1.sh` only.

## Product pivot

**Center of gravity: gamified task / project management.** Linear is the main integration (issues, projects, Focus, Today). The menu bar and Today UI lead with work, **score**, and the Pokémon companion — not a usage dashboard.

AI token & usage stays as a **side addition**. The usage pipeline is still there. Surfaces change:

- Token usage converts **1:1 into XP**.
- The **Token usage** page (today / week / month / limits / cost) still says **Tokens**.
- **Every other page** says **XP**, not Tokens.

Completing work grants XP (and therefore Coins). Completing a **project** is a **large XP packet**, not another issue-sized tick.

```
token usage  --1:1-->  XP  --÷1000-->  Coins (shop)
Linear work          -->  XP  --÷1000-->  Coins
project complete     -->  BIG XP      --÷1000-->  Coins
```

## Economy

- All XP earned is also shop currency, converted to **Coins**.
- `Coins = floor(XP / 1000)`.
- Shop items show **Requires N Coins** (never Tokens, never XP).
- Hatch / evolve / shop numbers sit behind `EconomyScale` (1% of the official PokeTokenBar integers, then shop prices ÷ 1000 into Coins).

Seed shop prices:

| Item | Coins |
|---|---:|
| Mint | 1,000 |
| Rare Candy | 5,000 |
| Pokémon Egg | 10,000 |
| Uncommon Egg | 25,000 |
| Shiny Charm | 30,000 |
| Rare Egg | 40,000 |

**Mint** is an **XP multiplier for a set time** (seed: **2× for 30 minutes**). It is not a nature reroll. Using it does not change identity, shiny, or evolution stage.

## Companion rules

- Eggs are bag/shop items, like candy. They can be stored.
- Buying an egg does **not** release the current Pokémon. The egg goes to **Pokémon Storage**.
- **Pokémon Storage** banks eggs and mid-evolution / not-yet-graduated partners so they can still be trained later.
- **One** Pokémon training at a time. Swap with storage anytime (active → storage, stored → training).
- Already-caught species cannot hatch again unless the new hatch would be **shiny**.
- **Graduated** Pokémon cannot be trained. They get a trophy label on the Dex card.

## Surfaces

| Surface | Job | Not this surface |
|---|---|---|
| Menu-bar popover | Focus, Linear, Collection (Bag / Storage / Dex / Shop), Token usage last | Not the timer workspace |
| Floating pet + island | Always-visible companion and session clock | Not Projects / Initiatives |
| Today window | Hero timer, pin list, session + check-in log, score | Not bag / dex / shop |

Optional Linear API key (plaintext JSON under Application Support, mode `0600`). First successful poll **seeds IDs with 0 XP** so existing Done issues and completed projects do not explode the meter.

## Build

macOS 14+, Xcode / Swift 6.

```bash
swift build
swift test
./scripts/rebuild-v1.sh    # /Applications/PokeTaskBar v1.app
```

Linux Cloud Agent can install a Swift toolchain and edit sources; it cannot build the app (Apple frameworks). See `CLAUDE.md`.

## Privacy

On-device usage reads and outbound hosts for AI CLIs are unchanged from the archived [original README](Documents/original-PokeTokenBar/README.md#privacy--permissions).

Linear is optional: `api.linear.app` GraphQL for issues and projects you already see in Linear (no prompts, no repo paths, no token-usage logs). The key is local, mode `0600`. Revoke it in Linear if you stop using the integration. Time-open XP is local wall-clock only.

## License & disclaimer

**MIT** — see [LICENSE](LICENSE). MIT covers this project's original source only.

This remains an **unofficial, non-commercial fan project**, not affiliated with Nintendo, Game Freak, Creatures Inc., or The Pokémon Company. Pokémon names, characters, and imagery are their trademarks. Runtime species data and sprites still come from [PokéAPI](https://pokeapi.co); they are not bundled in the app.

Product lineage: [chattymin/PokeTokenBar](https://github.com/chattymin/PokeTokenBar) → [spawnaudio/spawn-PokeTokenBar](https://github.com/spawnaudio/spawn-PokeTokenBar) (v3) → this app. Upstream READMEs are in [`Documents/original-PokeTokenBar/`](Documents/original-PokeTokenBar/). PokeTokenBar v3 is left intact.
