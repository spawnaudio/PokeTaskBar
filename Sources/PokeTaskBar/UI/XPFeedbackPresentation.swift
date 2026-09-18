import AppKit
import QuartzCore

@MainActor
enum XPFeedbackStyle {
    static var animates: Bool {
        !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            && !ProcessInfo.processInfo.isLowPowerModeEnabled
    }

    static func color(for reward: XPReward) -> NSColor {
        NSColor(name: nil) { appearance in
            let dark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            if reward.isCompletion {
                return dark ? NSColor(srgbRed: 0.43, green: 0.90, blue: 0.59, alpha: 1)
                    : NSColor(srgbRed: 0, green: 0.36, blue: 0.20, alpha: 1)
            }
            if reward.source == .candy {
                return dark ? NSColor(srgbRed: 0.82, green: 0.65, blue: 1, alpha: 1)
                    : NSColor(srgbRed: 0.47, green: 0.22, blue: 0.68, alpha: 1)
            }
            return dark ? NSColor(srgbRed: 0.40, green: 0.90, blue: 0.89, alpha: 1)
                : NSColor(srgbRed: 0, green: 0.34, blue: 0.42, alpha: 1)
        }
    }

    static func title(for reward: XPReward) -> NSAttributedString {
        NSAttributedString(
            string: (reward.isCompletion ? "✓ " : "") + reward.text,
            attributes: [.font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold),
                         .foregroundColor: color(for: reward)])
    }

    static func pulse(on layer: CALayer, duration: TimeInterval, lift: Bool = false) {
        let opacity = CAKeyframeAnimation(keyPath: "opacity")
        opacity.values = [0, 1, 1, 0]
        opacity.keyTimes = [0, 0.12, 0.72, 1]
        opacity.duration = duration
        layer.opacity = 0
        layer.add(opacity, forKey: "xp-opacity")
        if lift {
            let rise = CABasicAnimation(keyPath: "transform.translation.y")
            rise.fromValue = 0
            rise.toValue = 12
            rise.duration = duration
            rise.timingFunction = CAMediaTimingFunction(name: .easeOut)
            layer.add(rise, forKey: "xp-rise")
        }
    }
}

/// Separate, click-through window so the receipt can float beyond the sprite bounds
/// without resizing the pet/timer or intercepting its drag and click targets.
@MainActor
final class XPRewardPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    init(reward: XPReward) {
        let label = NSTextField(labelWithAttributedString: XPFeedbackStyle.title(for: reward))
        label.sizeToFit()
        let size = NSSize(width: label.frame.width + 24, height: 30)
        super.init(contentRect: NSRect(origin: .zero, size: NSSize(width: size.width, height: 46)),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 1)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        hidesOnDeactivate = false
        ignoresMouseEvents = true
        isReleasedWhenClosed = false
        animationBehavior = .none

        let root = NSView(frame: NSRect(origin: .zero, size: frame.size))
        root.wantsLayer = true
        let badge = NSView(frame: NSRect(origin: NSPoint(x: 0, y: 2), size: size))
        badge.wantsLayer = true
        effectiveAppearance.performAsCurrentDrawingAppearance {
            badge.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.97).cgColor
            badge.layer?.borderColor = XPFeedbackStyle.color(for: reward).withAlphaComponent(0.45).cgColor
        }
        badge.layer?.cornerRadius = 15
        badge.layer?.borderWidth = 1
        label.frame.origin = NSPoint(x: 12, y: (size.height - label.frame.height) / 2)
        badge.addSubview(label)
        root.addSubview(badge)
        contentView = root
        if XPFeedbackStyle.animates, let layer = badge.layer {
            XPFeedbackStyle.pulse(on: layer, duration: 2.9, lift: true)
        }
    }

    static func anchoredFrame(size: NSSize, pet: NSRect, visibleScreen: NSRect) -> NSRect {
        let proposed = NSRect(x: pet.midX - size.width / 2,
                              y: pet.minY + pet.height * 0.45,
                              width: size.width, height: size.height)
        return FloatingTimerMetrics.constrained(proposed, to: visibleScreen)
    }

    func follow(pet: NSRect, screen: NSScreen) {
        setFrame(Self.anchoredFrame(size: frame.size, pet: pet, visibleScreen: screen.visibleFrame), display: false)
    }
}

/// A transparent screen-sized window with colour only at its edges. It never
/// activates or accepts input, and is destroyed when the transient receipt ends.
@MainActor
final class XPBoundaryGlow {
    private(set) var panel: NSPanel?

    func show(_ reward: XPReward, on screen: NSScreen?) {
        hide()
        guard XPFeedbackStyle.animates, let screen else { return }
        let panel = NSPanel(contentRect: screen.frame,
                            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        let view = NSView(frame: NSRect(origin: .zero, size: screen.frame.size))
        view.wantsLayer = true
        if let layer = view.layer {
            var color = NSColor.systemTeal.cgColor
            panel.effectiveAppearance.performAsCurrentDrawingAppearance {
                color = XPFeedbackStyle.color(for: reward).cgColor
            }
            Self.addEdges(to: layer, bounds: view.bounds, color: color)
            XPFeedbackStyle.pulse(on: layer, duration: 2.2)
        }
        panel.contentView = view
        panel.orderFrontRegardless()
        self.panel = panel
    }

    static func addEdges(to layer: CALayer, bounds: CGRect, color: CGColor) {
        let thickness: CGFloat = 18
        let edges: [(CGRect, CGPoint, CGPoint)] = [
            (CGRect(x: 0, y: 0, width: thickness, height: bounds.height), CGPoint(x: 0, y: 0.5), CGPoint(x: 1, y: 0.5)),
            (CGRect(x: bounds.width - thickness, y: 0, width: thickness, height: bounds.height), CGPoint(x: 1, y: 0.5), CGPoint(x: 0, y: 0.5)),
            (CGRect(x: 0, y: 0, width: bounds.width, height: thickness), CGPoint(x: 0.5, y: 0), CGPoint(x: 0.5, y: 1)),
            (CGRect(x: 0, y: bounds.height - thickness, width: bounds.width, height: thickness), CGPoint(x: 0.5, y: 1), CGPoint(x: 0.5, y: 0))
        ]
        for (frame, start, end) in edges {
            let edge = CAGradientLayer()
            edge.frame = frame
            edge.colors = [color.copy(alpha: 0.28)!, color.copy(alpha: 0.08)!, color.copy(alpha: 0)!]
            edge.locations = [0, 0.3, 1]
            edge.startPoint = start
            edge.endPoint = end
            layer.addSublayer(edge)
        }
        let border = CAShapeLayer()
        border.path = CGPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), cornerWidth: 10, cornerHeight: 10, transform: nil)
        border.strokeColor = color.copy(alpha: 0.35)
        border.fillColor = nil
        border.lineWidth = 2
        layer.addSublayer(border)
    }

    func hide() {
        panel?.orderOut(nil)
        panel?.contentView = nil
        panel?.close()
        panel = nil
    }
}
