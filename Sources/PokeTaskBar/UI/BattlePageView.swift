import AppKit
import SwiftUI

/// Another view of the existing focus session, companion and inventory.
@MainActor
struct BattlePageView: View {
    @Environment(UsageStore.self) private var usage
    @Environment(CompanionStore.self) private var companion
    @Environment(FocusSessionStore.self) private var focus
    @Environment(\.popoverContentWidth) private var availableWidth
    @Environment(\.mainWindowChrome) private var mainWindowChrome
    @State private var gameHeight = BattlePageMetrics.baseHeight
    @State private var lifecycle = BattlePageLifecycle()

    var body: some View {
        let width = BattlePageMetrics.width(available: availableWidth)
        let scale = BattlePageMetrics.scale(available: availableWidth)
        ContentFittingScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if !mainWindowChrome {
                    Text(companion.l.battlePageTitle).font(.title2.weight(.semibold))
                }
                Text("Turn your focus session into a Pokémon battle.")
                    .font(.callout).foregroundStyle(.secondary)
                BattleGameSurface(usage: usage, companion: companion, focus: focus,
                                  width: width, gameHeight: $gameHeight, lifecycle: lifecycle)
                    .frame(width: width, height: gameHeight * scale)
                    .accessibilityIdentifier("embedded-battle-game")
                Text("Your timer, XP and potion bag are shared across windows.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear { lifecycle.coordinator?.start() }
        .onDisappear { lifecycle.coordinator?.stop() }
    }
}

/// Keep SwiftUI lifecycle callbacks separate from the coordinator's ownership of the native bridge.
@MainActor
final class BattlePageLifecycle {
    weak var coordinator: BattleGameSurface.Coordinator?
}

@MainActor
struct BattleGameSurface: NSViewRepresentable {
    let usage: UsageStore
    let companion: CompanionStore
    let focus: FocusSessionStore
    let width: CGFloat
    @Binding var gameHeight: CGFloat
    let lifecycle: BattlePageLifecycle

    func makeCoordinator() -> Coordinator {
        Coordinator(usage: usage, companion: companion, focus: focus)
    }

    func makeNSView(context: Context) -> NSView {
        let container = NSView(frame: .zero)
        lifecycle.coordinator = context.coordinator
        context.coordinator.container = container
        context.coordinator.configure(width: width, height: gameHeight) { gameHeight = $0 }
        context.coordinator.start()
        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.configure(width: width, height: gameHeight) { gameHeight = $0 }
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.stop()
        coordinator.container = nil
    }

    @MainActor
    final class Coordinator {
        private let usage: UsageStore
        private let companion: CompanionStore
        private let focus: FocusSessionStore
        private var width = BattlePageMetrics.baseWidth
        private var height = BattlePageMetrics.baseHeight
        private var onHeightChange: ((CGFloat) -> Void)?
        weak var container: NSView?
        private(set) var battle: BattleWindow?

        init(usage: UsageStore, companion: CompanionStore, focus: FocusSessionStore) {
            self.usage = usage; self.companion = companion; self.focus = focus
        }

        func configure(width: CGFloat, height: CGFloat, onHeightChange: @escaping (CGFloat) -> Void) {
            self.width = BattlePageMetrics.width(available: width)
            self.height = height
            self.onHeightChange = onHeightChange
            resize()
        }

        func start() {
            guard battle == nil, let container else { return }
            let battle = BattleWindow(usage: usage, companion: companion, focus: focus, presentation: .embedded)
            self.battle = battle
            battle.onLayout = { [weak self] height, _ in
                guard let self else { return }
                self.height = height
                resize()
                onHeightChange?(height)
            }
            battle.content.autoresizingMask = [.width, .height]
            container.addSubview(battle.content)
            resize()
        }

        func stop() {
            battle?.stop()
            battle?.content.removeFromSuperview()
            battle = nil
        }

        private func resize() {
            guard let battle else { return }
            let scale = width / BattlePageMetrics.baseWidth
            let size = NSSize(width: width, height: height * scale)
            battle.content.gameSize = size
            battle.content.frame = NSRect(origin: .zero, size: size)
            battle.setEmbeddedScale(scale)
            battle.content.needsLayout = true
        }
    }
}
