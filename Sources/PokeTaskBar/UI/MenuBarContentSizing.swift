import SwiftUI

/// Measure the mounted page, not a second hidden copy that could run tasks twice.
/// Scroll views report content minus viewport; adding that difference to the
/// measured shell gives its natural height, independently of the current window.
struct MenuBarContentMeasurements: Equatable {
    enum Part: Hashable { case toolbar, canvas, footer }
    var heights: [Part: CGFloat] = [:]
    var scrollAdjustments: [UUID: CGFloat] = [:]
    var pendingScrolls: Set<UUID> = []

    var preferredHeight: CGFloat? {
        guard pendingScrolls.isEmpty, let toolbar = heights[.toolbar],
              let canvas = heights[.canvas], toolbar > 0, canvas > 0 else { return nil }
        return ceil(toolbar + canvas + (heights[.footer] ?? 0)
                    + MenuBarPanelMetrics.shellGap + scrollAdjustments.values.reduce(0, +))
    }
}

struct MenuBarContentMeasurementsKey: PreferenceKey {
    static let defaultValue = MenuBarContentMeasurements()
    static func reduce(value: inout MenuBarContentMeasurements, nextValue: () -> MenuBarContentMeasurements) {
        let next = nextValue()
        value.heights.merge(next.heights, uniquingKeysWith: { _, new in new })
        value.scrollAdjustments.merge(next.scrollAdjustments, uniquingKeysWith: { _, new in new })
        value.pendingScrolls.formUnion(next.pendingScrolls)
    }
}

private struct MenuBarContentFittingKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var menuBarContentFitting: Bool {
        get { self[MenuBarContentFittingKey.self] }
        set { self[MenuBarContentFittingKey.self] = newValue }
    }
}

extension View {
    func measureMenuBarContent(_ part: MenuBarContentMeasurements.Part) -> some View {
        background {
            GeometryReader { geometry in
                Color.clear.preference(key: MenuBarContentMeasurementsKey.self,
                                       value: .init(heights: [part: geometry.size.height]))
            }
        }
    }
}

private struct ScrollContentHeightKey: PreferenceKey {
    static let defaultValue: CGFloat? = nil
    static func reduce(value: inout CGFloat?, nextValue: () -> CGFloat?) {
        if let next = nextValue() { value = max(value ?? 0, next) }
    }
}

/// Regular scrolling everywhere; intrinsic height reporting only in the attached
/// menu-bar shell. Large lazy lists can request a full viewport without realizing
/// every offscreen row or resizing as the lazy height estimate changes on scroll.
@MainActor
struct ContentFittingScrollView<Content: View>: View {
    @Environment(\.menuBarContentFitting) private var fitting
    @State private var contentHeight: CGFloat?
    @State private var measurementID = UUID()
    var fillsViewport = false
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            content
                .background {
                    if fitting {
                        GeometryReader { geometry in
                            Color.clear.preference(key: ScrollContentHeightKey.self,
                                                   value: geometry.size.height)
                        }
                    }
                }
        }
        .onPreferenceChange(ScrollContentHeightKey.self) { contentHeight = $0 }
        .background {
            if fitting {
                GeometryReader { geometry in
                    Color.clear.preference(key: MenuBarContentMeasurementsKey.self,
                                           value: measurement(viewportHeight: geometry.size.height))
                }
            }
        }
    }

    private func measurement(viewportHeight: CGFloat) -> MenuBarContentMeasurements {
        guard let contentHeight else { return .init(pendingScrolls: [measurementID]) }
        let naturalHeight = fillsViewport ? max(contentHeight, MenuBarPanelMetrics.attachedMaxHeight) : contentHeight
        return .init(scrollAdjustments: [measurementID: naturalHeight - viewportHeight])
    }
}
