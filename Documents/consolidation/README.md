# PokeTasks consolidation — 10 October 2026

This consolidation targets `spawnaudio/PokeTaskBar`, branch `Master`, the user's PokeTasks repository. The original `chattymin/PokeTokenBar` repository is only a read-only upstream reference.

The active v3 worktree supplied the latest app implementation, tests and feature documentation. Changes already merged into `Master` were not reapplied from the older main and v2 checkouts. The v2 rebuild script, icon sources and Sunsama research were also preserved.

The requested historical artifacts fit within GitHub storage limits and remain in Git:

- `Documents/theme-concepts/v2-mockups`: mockup gallery, source screenshots and ZIP export.
- `Documents/poketasks-v2`: planning documents, native QA screenshots, recordings, logs and renderer artifacts.
- `Documents/floating-battle-v3`: browser prototype, artwork, reference sprites, original license notices and QA evidence.
- `output/pdf`: gamified-features PDF.
- `Documents/consolidation/coverage-profiles`: the three original raw coverage profiles, named by source checkout.

Historical artifacts preserve their original bytes except for 15 expired Linear download signatures removed from two asset manifests and explicit `sha256:` prefixes added to the reset-verification hashes. The original manifests remain in the local recovery snapshots. The prototype's third-party reference assets retain their original copyright/license notices; they are not new runtime assets for the native app. Local build caches and dependency directories are regenerated rather than committed.

Before consolidation, each dirty checkout was archived with a SHA-256 manifest in `.worktrees/consolidation-backups/2026-10-10/` in the primary local checkout. These recovery snapshots remain local.

Validation used the matching Xcode beta/Swift 6.4 toolchain on macOS 27.2. The native app builds and packages, its ad-hoc signature verifies, and the bundled Battle frontend rebuilds byte-for-byte. The archived browser prototype's build, four Sites distribution checks and session assertions pass.

The existing `MainWindowTests.testV2NativeIssueWhitespaceStartsDrag` fails locally with three pasteboard assertions on both untouched `origin/Master` (`e2ff6eb`) and the consolidation. It is recorded as an existing native drag-session test limitation; the test and production drag handler remain unchanged. Full-suite and CI outcomes are recorded in the consolidation PR.
