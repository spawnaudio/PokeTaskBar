import Foundation

/// The embedded game fits its page independently of the floating window's saved scale.
enum BattlePageMetrics {
    static let baseWidth: CGFloat = 360
    static let baseHeight: CGFloat = 180
    static let taskPickerHeight: CGFloat = 380

    static func width(available: CGFloat) -> CGFloat {
        guard available.isFinite else { return baseWidth }
        return min(720, max(180, available))
    }

    static func scale(available: CGFloat) -> CGFloat {
        width(available: available) / baseWidth
    }
}
