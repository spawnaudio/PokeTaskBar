# PT-v4 experiment

Branch `experiments/PT-v4` starts from Master at `59211c71281184b24f0e998a3b2d1ef4d5cc80e7`. The linked cloud worktree is `/workspace/experiments/PT-v4`.

## Pokédex

Pokédex has its own root page in the menu bar and desktop window. Collection contains Bag, Storage and Shop. Settings' representative Pokémon shortcut opens the new Pokédex.

The page uses a red device shell, green LCD, scanner controls and a numbered Gen I–V registry (#001–649). Unknown entries remain placeholders. Search supports names and numbers; region and registration filters narrow the list. Normal and shiny discoveries are tracked independently, and only reached evolution stages register. Stored partners remain registered when swapped out of training.

Registry mode browses species; Catch log includes active, stored and historical catch records. Selecting a registered species shows its exact individuals, including stored partners. Individual readouts show level, training XP, catch count, repeat-catch XP and progress toward graduation. Details reuse the existing stats, moves and evolution views. Reduced Motion uses static scanner sprites.

## Repeat catches and training

One Pokémon or egg trains at a time. To try a repeat catch, bank an unfinished normal partner by swapping a stored egg into training, then incubate the egg until it rolls the same evolution family and form.

- A normal repeat catch resumes the first matching unfinished normal partner in storage. It retains its individual ID, IVs, nature, evolution route and earned growth.
- The entire XP used to incubate that egg, including overflow, advances the resumed partner through the existing evolution and graduation rules. It also increments that individual's catch count and repeat-catch XP history.
- This consumes the egg and removes the resumed partner from storage. No second copy is created and no extra wallet XP or Coins are awarded: incubation XP was already earned.
- Shiny catches always create separate individuals. Normal catches never merge into shiny partners. Unown must match the exact letter. Unrevealed Ditto disguises never merge with the species they imitate.
- Graduated and released records are immutable. If no matching unfinished partner exists, a normal catch starts a new individual, even if that species appears in historical records.
- Existing XP awards, balance amounts, the post-graduation growth boost and the difficulty slider are retained. Changing difficulty reprices the current stage of every active/stored partner and egg so stored progress survives a swap. Individual levels retain their earned growth.

Save fields are additive: old saves default to one catch and zero repeat-catch XP. New fields survive storage, release, graduation, restart and export/import. Imported stored progress and history counters are bounded using the same limits as active progress.

Pokémon GO provides the progression inspiration: catches build resources for training, while individual Pokémon retain their own investment. GO uses family Candy and Stardust for power-ups, with Trainer XP as a separate system. PT-v4 adapts that relationship to its existing individual XP model instead of adding currencies or duplicating GO's level curve. The official [Powering Up Pokémon](https://niantic.helpshift.com/hc/en/6-pokemon-go/faq/112-powering-up-pokemon/) page could not be retrieved through this cloud environment's proxy, so current GO costs were not used as balance inputs.

## Battle page

Battle is available in the menu bar and desktop window. It hosts the existing packaged battle game and shares the live Focus session, Pokémon, XP wallet and potion bag with the floating window. Starting a new timer or choosing a new task from this page uses the existing Battle completion/reward rules. Opening Battle during an existing session preserves that session's reward policy.

The embedded game sizes itself to its page. Floating-window fold, pin, tuck and header dragging controls are removed from this surface. Leaving the page releases its WebKit bridge and artwork work while the Focus timer continues; returning creates a fresh game surface.

## Build and try on a Mac

Use macOS 14+ with Xcode/Swift 6:

```bash
cd /path/to/experiments/PT-v4
bash scripts/rebuild-v4.sh
open '/Applications/PokeTasks v4 Experiment.app'
```

The builder uses:

| Setting | Value |
|---|---|
| App name | PokeTasks v4 Experiment |
| Bundle identifier | `io.github.spawnaudio.poketasks.v4.experiment` |
| Save folder | `~/Library/Application Support/PokeTasks v4 Experiment` |
| Version | `4.0.0` |

The experiment starts with a separate profile. To try your existing Pokémon, export a save from your current app and import that copy into the experiment. Provider integrations may still read the same external CLI credentials. The local builder permits ad-hoc signing if a local signing identity is unavailable; set `PTB_REQUIRE_STABLE_SIGN=1` to require one. To assemble without installing, use `PTB_SKIP_INSTALL=1 bash scripts/rebuild-v4.sh`.

The packaged battle resources are already present; a normal Swift build does not need Node or a web rebuild.

## Validation

The Linux environment can parse the Swift sources and run the portable production-model/progression/registry checks using `bash scripts/check-repeat-catch-training.sh`. The runner typechecks its production Foundation sources in Swift 6, then runs 23 repository XCTest methods. Its Linux XCTest manifest uses Swift 5 mode because Linux XCTestCase instances are not Sendable. These checks do not compile Apple frameworks or exercise the native store/UI integration. Native regression tests are included for those paths.

With Python Playwright and Chromium installed, run `python3 scripts/verify-embedded-battle.py` to check the packaged Battle UI with a simulated native bridge. This verifies embedded controls, Choose task/Start messages and game sizing from 50–200%; it does not execute native timer or inventory mutations.

Before treating this experiment as a usable Mac build:

1. Run `swift test` and the v4 builder on macOS.
2. Check both Pokédex layouts at narrow menu-bar widths and wide/narrow desktop widths. Browse unknown entries, regions, variants, catch records and exact Unown individuals; open Details and choose a representative Pokémon.
3. Bank a normal partner, incubate a matching egg and confirm identity, XP history and progression survive save/relaunch. Try a shiny repeat, a graduated species, and a difficulty change with stored partners/eggs.
4. Start, pause and switch a Battle session; use and buy potions; leave/reopen the page and open the floating window. Confirm one shared timer and one reward/inventory mutation per action.
