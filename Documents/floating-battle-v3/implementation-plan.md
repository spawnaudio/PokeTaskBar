# Floating battle — v3 implementation plan

Status: interactive prototype and asset preparation. The native application has not been changed or installed by this experiment.

Worktree: `experiments/PokeTasks-v3`, branch `codex/poketasks-v3`, based on committed `Master` at `d8ea1016`. Existing uncommitted edits were not copied into it.

## Agreed experience

- Add a second floating-pet style, **Battle window**, with **Classic** remaining the default.
- Use the selected compact GBA/Emerald design, 360 × 180 points. Bag and shop temporarily expand to 360 × 260; Full Restore uses 360 × 200, anchored at the same position.
- Match the supplied mockup crops for layered window framing, stepped buttons with selection cursors, and shaded HP/XP bars. Keep the original font, generated arena/trainer and item icons. Preserve subtle stepped Pokémon movement and original opponent frame changes, button hover/press feedback, and a brief potion-use flash. Pause/zero HP freeze Pokémon motion; reduced motion disables animation.
- Idle shows the user as the trainer, with **A new Task wants to Battle!** and no opponent.
- During a session, show the active training Pokémon and one random wild opponent representing the task. Choose the opponent once per session; retain it across pause, potion use, and restoration.
- HP is remaining countdown / total planned duration. Display the numeric timer too. Use green above 50%, yellow above 20%, red at or below 20%; zero is an empty red outline.
- XP shows existing companion growth progress. Potion use does not grant XP.
- Paused uses approximately 50% grayscale with muted colors and a **Resume** action. HP and the clock stop moving.
- At zero, wait for an explicit choice. Dialogue: **Time’s Up! Rest, Use a Potion, or Forfeit**. No faint animation or automatic overtime.
- **Rest** finishes the task. For Linear tasks, mark completed through the existing completion path and settle rewards only after success. For local tasks, finish the local session without a Linear write. Rest is task completion, not a break cycle.
- **Forfeit** cancels the timer, leaves the task unfinished, and grants none of the pending timer reward. Already-earned companion XP is retained. Show the existing loss confirmation before cancelling.
- **Use a Potion** opens the owned-item bag during any active countdown: running, paused, or zero HP. It consumes one item and adds exact remaining minutes. A paused timer remains paused; zero HP returns to running.

| Item | Additional time | Base Coins |
|---|---:|---:|
| Potion | 5 min | 100 |
| Super Potion | 15 min | 300 |
| Hyper Potion | 30 min | 600 |
| Revive | 60 min | 1,200 |
| Full Restore | Custom whole minutes | 3,600 |

Apply the existing shop difficulty multiplier to these base prices. Full Restore means extra time, not a replacement total or a full HP refill.

## Edge-state defaults demonstrated in the prototype

- Show every item, its effect, and owned count. A zero count disables **Use item**, with a Shop shortcut.
- Validate before consumption. Reject zero, negative, fractional, invalid, or excessive custom minutes. Cancel and Escape consume nothing.
- Keep the current 180-minute total planned-time cap. Reject a fixed potion if its **entire** boost cannot fit; do not charge for a partial effect. Bound custom time to available headroom.
- Failed task completion retains the active timer and pending reward, offering retry or return. Preserve the current pause/running state.
- Return to trainer idle after Rest or Forfeit. Keep the same opponent when navigating through the bag or More.
- Truncate long task titles in the header; retain the full text for accessibility and tooltip. Keep the opponent name and all actions visible.

## Native build sequence

1. **Optional view and window shell.** Add a persisted Classic/Battle style beside current floating-pet settings. Reuse `FloatingPetController` and the existing panel lifecycle. Build one battle view with live `FocusSessionStore` values. Drag from the header; forward buttons and text input to their controls. Reuse pin, screen clamping, edge tuck/reveal, and the existing alarm behaviour. Only resize on view/scale changes, never every timer tick.
2. **Live artwork and growth.** Extend the existing sprite loader minimally for rear-facing sprites, with facing included in cache keys and a front-facing fallback. Use the active training Pokémon, including shiny/form identity, rather than the representative mascot. Use the existing companion growth/egg progress. Proposed fallback: show the existing egg sprite while hatching; show the trainer when no trainee exists, with the timer still usable. The prototype uses a sample Lapras. Store only the opponent identity needed to keep a session stable after restoration. Use the generated arena/trainer and supplied sprites listed in `asset-sources.md`; use the mockup-derived frame, button and bar pieces in `assets/chrome/`, preserving the original font and live native text and bar values. Drive sprite frames only while visible and running, freeze them on pause/expiry, and honor the system's reduced-motion preference. The browser's short stepped idle loop is an added product animation, not a claim to reproduce the game's full animation engine.
3. **Consumable items.** Add five `ItemKind` cases and the existing shop/bag/localization switch entries. Reuse Coins, inventory, quantity selection, and final Purchase. Add one shared potion-use operation that verifies an active session, ownership, full-effect headroom, and custom input before deducting inventory and extending the timer. Persist both results with error handling. Prevent double-use while a transaction is in flight.
4. **Wire the final actions.** Reuse completion and Forfeit operations. Preserve pause when a potion extends time; the current `FocusTick.addRemaining` clears `userPaused` and accepts clamped partial additions, so it cannot be called unchanged for paid items. Keep Classic behaviour compatible. For game sessions, settle reward at completion and avoid introducing an overtime reward path that could pay XP before Forfeit. If a user changes style during an existing overtime session, preserve settled rewards and the underlying timer rather than clawing back growth/evolution.
5. **Focused verification.** Exercise the actual battle view and native panel, not just a timer subview. Verify start, pause/resume, expiry without settlement, every potion, paused and zero-HP use, custom cancel/invalid input, cap rejection without consumption, duplicate-use prevention, completion failure/retry, local completion without Linear calls, Forfeit without reward, and restoration. Check long/localized text, offline/missing sprites, keyboard focus, header-only dragging, edge peek, screen movement and scale. Build without replacing the installed app until the native prototype is ready for review.

## Prototype scope and proof

The browser prototype uses in-memory sample inventory, Coins, a sample level/progress threshold, three sample opponents, and a demo local-task XP cadence. It does not connect to Linear, purchase real items, save application state, implement native window movement, or prove native integration. The later app must use its existing stores and settlement logic rather than transplanting this demo model.

- Start/stop preview: `npm run dev -- --host 127.0.0.1 --port 4173 --strictPort`.
- Flow check: `node tests/session.test.mjs`.
- Build check: `npm run build`.
- Browser evidence and design comparison: `design-qa.md` and `evidence/`.
- Visual truth: selected mockups in `references/`.
- Assets and source/usage notes: `assets/` and `asset-sources.md`.

### Remaining native decisions

The first native pass must verify the proposed egg/no-trainee fallback and safe recovery if timer and bag persistence fail between writes. These are integration details; the prototype does not simulate a durable cross-store transaction. Validate real text-entry focus on the nonactivating macOS panel before adopting its Full Restore form.
