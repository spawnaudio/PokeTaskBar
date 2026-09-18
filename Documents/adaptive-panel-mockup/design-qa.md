# Motion mockup QA

final result: passed

Scope: exported video concept, not a functional app implementation. No production resizing, live data, or interactive settings behavior is claimed as tested.

## Evidence

- Source visual truth: `source-assets/{focus,linear,usage,collection,settings,idle}-light.png`, native fixture renders at 400 × 640 pixels.
- Output: `adaptive-panel-mockup.mp4`, 1440 × 1000, H.264, yuv420p, 60 fps, 1,740 frames, exactly 29 seconds.
- Full-view evidence: all scene stills; inspected Focus, Linear, Usage, Collection, Settings, and idle Focus.
- Encoded-video comparison evidence: `stills/comparison-focus.png` and `stills/comparison-collection.png` place the actual exported video beside the native source.
- Density normalization: the film shows the panel at 1.25× (500 px wide). Comparison crops were reduced back to 400 px. Collection's proposed 337 pt panel is top-aligned beside its 640 pt source.
- Transition evidence: `stills/transition-midpoint.png`, decoded from the video at 3.14 seconds, shows the shell between its 640 pt and 337 pt states with the header stationary and footer moving upward.
- Full video decoded without reported errors. Stream metadata confirmed codec, dimensions, frame count, rate, duration, and pixel format.

## Required fidelity checks

- Fonts and typography: original app typography is preserved in the source content bands. No new truncation in the demonstrated short pages. Expected mild softness from enlarging 1× source screenshots and video compression.
- Spacing and layout: width and top edge remain fixed. Content coordinates do not scale during resize. Footer follows the lower edge; final states retain bottom padding and do not clip controls. Collection intentionally removes blank vertical space.
- Colors and tokens: shell and canvas use the current app palette; content uses the original renders. Minor encoded-video color differences are expected.
- Image quality and assets: original app icon, Lapras sprite, and native UI are reused. Desktop icons and pointer use macOS resources. No generated replacement art.
- Copy and content: native sample copy is retained. Film captions clearly label sample data, illustrative heights, and unimplemented behavior.

## Findings and comparison history

No actionable P0/P1/P2 visual findings in the comparison. No visual-fix iteration was needed. The first native encoder attempt failed before producing a valid movie; the final movie uses software H.264 encoding and passed decode validation.

P3: 1× fixture screenshots are slightly soft at 1.25× display scale. This is acceptable for evaluating window sizing; production UI will render natively at the screen's backing scale.

## Boundaries

The video demonstrates all root tabs, Settings, and active/idle Focus. It does not individually demonstrate every Collection segment, a populated Linear list, actual Settings scrolling, dark mode, localization, accessibility, rapid switching, or detached-window behavior. Those belong to implementation validation, documented in `README.md`.
