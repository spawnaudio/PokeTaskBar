# Mocking up 100 creatures — usage and time

Planning estimate for **100 distinct creatures, each with one full-body pixel-art hero and one face icon**. It excludes evolution stages, alternate palettes, animation, native sprite cleanup and app implementation.

## Image volume

- From zero: **200 first-pass image generations**.
- Allow 20–40% extra generations for revisions: **240–280 calls total**.
- This collection contains 15 hero/icon pairs, leaving **85 pairs** to reach 100.
- Remaining first passes: **170 calls**, or approximately **204–238 calls with the same revision allowance**.
- This batch adds **25 images**: 10 new heroes and 15 face icons. The five original pixel heroes are reused.

One image-generation call per hero and one per icon keeps each creature independently editable. Icons use their hero as the identity reference; changing a hero's defining facial features can require an icon revision too.

## A manageable weekly pace

| Pace | Generations/week including revision allowance | Weeks from zero to 100 | Weeks after this 15-creature batch |
| --- | --- | --- | --- |
| 5 creature pairs/week | 12–14 | 20 | 17 |
| **10 creature pairs/week** | **24–28** | **10** | **9** |
| 20 creature pairs/week | 48–56 | 5 | 5 |

These are whole-week rounded targets, not automatic schedules. Work can pause without creating a backlog.

## Time allowance

The first measured stage created 10 heroes plus five icons in **539 seconds (about 9 minutes)** with up to five calls in progress. Individual call-to-saved-file times varied, including queueing and file handling. Later observations are recorded in the completed-batch section below.

At that first-stage throughput, 240–280 generations alone would take approximately **2.4–2.8 hours** of batched elapsed time. Allow **3–5 hours** for generation as a practical planning range because speed, queueing and revision complexity vary. Running every image sequentially would be substantially slower.

Add approximately **4–8 hours of review, brief refinement and pair checks** across 100 creatures as a planning assumption, roughly 2.5–5 minutes per pair. A reasonable combined project allowance is **about 8–15 hours**, spread over several weeks. Some review can overlap generation.

For the recommended ten pairs per week, set aside **roughly 45–90 minutes a week**, preferably in two short sessions: one to explore heroes, one to check/refine icons and choose favourites. The final schedule depends on how selective the review becomes.

## How this affects weekly Codex usage

Image generation draws from the same general Codex allowance as ordinary work. OpenAI says image-generation turns use the allowance about 3–5 times faster on average than comparable turns without image generation; the result depends on image size and quality. This is not a fixed percentage or fixed credit cost per image. [Official OpenAI usage guidance](https://learn.chatgpt.com/docs/pricing#how-does-image-generation-count-toward-usage-limits)

The available account meter reports whole-account weekly usage, not a per-image bill. Other active tasks and delayed meter updates can affect the observed change. Any estimate based on this batch should be treated as a provisional planning allowance, then calibrated against another batch.

No API billing, extra credits, subscription upgrade, or weekly automation is part of this task.

## Completed-batch measurement

The batch is complete: **27 attempted generations, 26 successful outputs, and 25 selected new images**. One initial icon attempt failed and was successfully retried; one icon was refined to remove extra wings. Combined with five retained heroes, the collection now has **15 hero/icon pairs (30 PNGs)**.

The measured generation stages took **539 + 439 + 91 = 1,069 seconds, about 18 minutes**, with up to five calls in progress. This excludes time between stages spent planning, reviewing, organizing and publishing. Scaling this batch to 240–280 attempts gives roughly 2.6–3.1 hours of generation-stage time; keep the broader **3–5 hour** generation allowance and **8–15 hour** overall mockup estimate.

For this account's current allowance, a provisional budget is **roughly 20–30% of the weekly allowance for ten new hero/icon pairs**, including some revisions. At five pairs, provisionally budget 10–15%; at twenty, 40–60%. These are rough extrapolations from the whole-account meter during this batch, including other active work, not measured per-image charges or guaranteed percentages. Recheck after the next batch before relying on them; a different plan, quality, model or workload can change the result.

All 30 PNGs are enlarged concept images. The icons have transparent backgrounds; the original Cindillo hero retains its ivory background. Native pixel cleanup, export sizes and menu-bar testing remain separate production work.
