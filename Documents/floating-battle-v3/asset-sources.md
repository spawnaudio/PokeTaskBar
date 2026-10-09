# Floating battle assets

Keep UI labels, timers, buttons and bars as native controls in the app. These assets are independent imagery, not baked screenshots.

| Asset | Role and display size | Source |
|---|---|---|
| `arena.png` | 346 × 88-point arena background, centered cover crop; never stretched | Generated to match the selected Emerald mockup; source output `exec-646dc3a2-d191-41e2-8910-ed9928fcc692.png` |
| `trainer.png` | Full-body trainer, 82 × 82-point slot; contain with pixel sampling | Generated against the selected trainer-idle mockup; source output `exec-c367b3ff-075a-4422-8388-303ec9734a12.png`; PNG alpha confirmed |
| `lapras-back.png` | Rear-facing sample player sprite, 88 × 88-point slot | [PokeAPI sprites](https://github.com/PokeAPI/sprites), generation III Ruby/Sapphire `back/131.png` |
| `gengar.png`, `pikachu.png`, `oddish.png` | Sample opponents, 74 × 74-point slot | [PokeAPI sprites](https://github.com/PokeAPI/sprites), generation III Emerald IDs 94, 25 and 43 |
| `animated/{gengar,pikachu,oddish}.png` | Original two-frame opponents, 74 × 74-point clipped slot | [pret/pokeemerald](https://github.com/pret/pokeemerald), pinned commit `731ad5bfd6e6f265508d0efcca0ba42f9dcf5881`; paths/palettes and checksums in `animated/sources.json` |
| Five item PNGs | Bag row 26 × 26-point slots; Full Restore form 58 × 58-point slot | [PokeAPI item sprites](https://github.com/PokeAPI/sprites/tree/master/sprites/items), names `potion`, `super-potion`, `hyper-potion`, `revive`, `full-restore` |
| `PixelifySans.ttf` | Pixel UI type, weights 400–700; test small text on Retina and 1× displays | [Google Fonts source](https://github.com/google/fonts/tree/main/ofl/pixelifysans); supplied OFL notice in `FONT-OFL.txt` |
| `chrome/*.png` | Nine-slice window, panel, button and bar frames; repeating fill bands; selection cursor | Cropped from the user’s supplied original mockup images in `references/chrome-{window,controls,bars}.png`; crop coordinates and sizes in `chrome/sources.json` |

The chrome pieces preserve the mockup pixels rather than approximating their borders with CSS. Frame centers are transparent, and labels, countdowns, inventory and bar values remain live controls. HP uses the source green fill with yellow/red hue changes at the existing thresholds. These pieces come from the generated mockups, not original Emerald UI files. The font, arena, trainer and item sprites remain the earlier prototype assets.

The sprite repository's notice is retained as `SPRITES-LICENCE.txt`. The original static sprites were downloaded intact. Animated opponents retain both original frames, decoded with their species palette and transparent index zero; CSS switches frames without redrawing them. The supplied game sprites differ from the illustrative Image Gen Pokémon in the mockups; use these actual species assets as the native integration reference. The finished app should load real active/opponent Pokémon through its existing loader instead of hard-coding these sample files.

The arena generator returned 2172 × 724 rather than 4:1. CSS uses a cover crop to fit the 346 × 88 view without distorting its aspect ratio. The center remains clear for live timer/HP/XP. The trainer is a 1254 × 1254 transparent PNG; keep the full body within the slot. Original generated outputs remain in the Codex image directory; these committed-ready copies belong to this experiment.

`public/assets` points to `../assets`, so the preview and a later native build can share this one asset folder. Vite copies these files into the static build.
