# Battle window

PokeTasks v2.5 adds a second floating-pet style. In Settings → Desktop, enable the floating pet and choose **Battle window**. Classic remains the default.

HP counts down remaining time. HP and XP have equal tracks, with no visible XP percentage. Pause freezes the clock and sprite movement and mutes the window. Zero HP waits for a choice.

- **Rest** completes the task through the existing completion and reward rules. Local tasks stay local; Linear tasks must complete successfully before settling.
- **Use a Potion** consumes one owned item and adds its full effect. A paused timer stays paused; a timer at zero resumes. The total cap is 180 minutes.
- **Forfeit** cancels the timer and pending session XP. Previously earned XP and the unfinished task remain.

The bag offers Potion (+5 minutes), Super Potion (+15), Hyper Potion (+30), Revive (+60), and Full Restore (custom whole minutes). The shop uses the existing Coins wallet and difficulty-adjusted prices. An interrupted potion save recovers as paused on restart without spending the same item twice.

Drag the header to move the window. More contains pin, screen-edge tuck and Open tasks. The existing timer scale setting scales the Battle window. Animation respects reduced motion. Pokémon and item sprites download into the existing runtime cache; the bundle includes original UI artwork and the licensed Pixelify Sans font.

The React source is in `BattleWindowWeb`. Run `npm ci && npm run build` there to update the offline UI, then `PTB_SKIP_INSTALL=1 bash scripts/rebuild-v2.5.sh` at the repository root to build the app. Generated resources are committed so normal Swift builds and CI do not require Node. `BattleWindow` hosts the local UI in the existing floating panel; Swift owns every timer and inventory action.
