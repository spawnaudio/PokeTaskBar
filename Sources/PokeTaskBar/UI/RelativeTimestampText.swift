import SwiftUI

/// Relative date label that does **not** use `Text(_, style: .relative)`.
///
/// SwiftUI's relative `Text` self-invalidates the hosting tree about once a
/// second (`requestUpdate` → `StackLayout.placeChildren`). That is the right
/// cost for a closed panel we tear down; an **open** Usage/Linear tab paid it
/// continuously. A coarse `TimelineView` keeps "2 min ago" honest without the
/// 1Hz layout hitch.
@MainActor
struct RelativeTimestampText: View {
    /// Upper bound on how often the string refreshes. Must stay > 1s
    /// (`testRelativeTimestampCadenceIsCoarse`).
    static let refreshInterval: TimeInterval = 15

    let date: Date
    @Environment(\.locale) private var locale

    var body: some View {
        TimelineView(.periodic(from: .now, by: Self.refreshInterval)) { context in
            Text(Self.string(from: date, now: context.date, locale: locale))
        }
    }

    static func string(from date: Date, now: Date, locale: Locale) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = locale
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: now)
    }
}
