# Floating pet and timer concept

Status: proposal for review, not an implemented or approved application change.

The mockup continues the current menubar design in light and dark. The expanded timer sits to the left of the existing Lapras sprite, with issue identity, countdown, workflow status, progress, Pause and Mark done. Compact mode retains the countdown beside the sprite. Pet-only mode retains a small timer toggle.

Design brief: compact native SF typography, opaque neutral surfaces, restrained outlines, 6–10 pt component corners, monospaced digits, teal progress, and the original proportional pixel sprite. Secondary actions belong in note/overflow controls. Use the existing focus state and timer behavior if implemented.

References: the locally rendered `build/menu-bar-preview/focus-dark.png` and `focus-light.png`, and the existing app sprite cache. The palette follows `MenuBarTheme`.

Method: native SwiftUI/AppKit static rendering. The image-generation service rejected two attempts without producing a usable image; this PNG was rendered locally instead. The application was not modified. The temporary renderer is retained in `build/floating-overlay-mockup/concept.swift`.
