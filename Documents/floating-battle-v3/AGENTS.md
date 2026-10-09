# Prototype Instructions

Run the local server yourself and open the preview in the browser available to this environment. Do not give the user server-start instructions when you can run it.

Before making substantial visual changes, use the Product Design plugin's `get-context` skill when the visual source is unclear or no longer matches the current goal. When the user gives durable prototype-specific design feedback, preferences, or decisions, record them in `AGENTS.md`.

When implementing from a selected generated mock, treat that image as the source of truth for layout, component anatomy, density, spacing, color, typography, visible content, and hierarchy.

Build app UI in `src/`. Keep `.openai/hosting.json`, `worker/index.js`, `scripts/prepare-sites-build.mjs`, and `tests/sites-worker.test.mjs` intact so the same local prototype can be handed to Sites. Before a Sites handoff, run `npm run build` and `npm run test:sites`; the build must leave `dist/client/index.html`, `dist/server/index.js`, and `dist/.openai/hosting.json`.

## Floating battle v3 decisions

HP and XP tracks have equal dimensions and aligned edges. Omit the visible XP percentage; retain its progress value for accessibility.

The user selected the compact GBA/Emerald battle mockup. Binding visual references are in `references/`; behaviour, potion prices, and native build scope are owned by `implementation-plan.md`. Use the trainer for idle, muted paused colours, the timer as HP, and real companion growth as XP. Rest finishes the task; potion use adds time and consumes one item; Forfeit cancels without pending timer XP. Keep this a browser prototype until native app implementation is requested. Preserve the existing Classic default when integrating later.

The user rolled back the October 2 Emerald UI restyle, then supplied three original mockup crops to clarify the desired buttons, HP/XP bars and window framing. Match their layered blue frame, stepped cream/blue button corners, selection cursor, dark bar outlines and shaded fills using the source-derived pieces in `assets/chrome/`. Preserve Pixelify Sans, the generated arena/trainer and original item icons. Do not reintroduce the rejected replacement font, health card or terrain. Keep subtle stepped Pokémon movement and original two-frame opponents, button hover/press feedback, and a brief potion-use flash. Freeze Pokémon motion while paused or at zero HP, and honor reduced motion.
