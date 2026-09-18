import AppKit

enum MenuBarIcon {
    /// Preserve the classic red-and-white colours in every menu-bar appearance.
    @MainActor
    static let pokeBall: NSImage = {
        let image = NSImage(size: NSSize(width: 24, height: 22), flipped: false) { _ in
            let outline = NSBezierPath(ovalIn: NSRect(x: 5, y: 3, width: 16, height: 16))
            NSColor.white.setFill()
            outline.fill()
            NSGraphicsContext.saveGraphicsState()
            outline.addClip()
            NSColor(srgbRed: 0.91, green: 0.19, blue: 0.23, alpha: 1).setFill()
            NSRect(x: 5, y: 11, width: 16, height: 8).fill()
            NSGraphicsContext.restoreGraphicsState()

            NSColor(srgbRed: 0.12, green: 0.13, blue: 0.15, alpha: 1).setStroke()
            outline.lineWidth = 1.5
            outline.stroke()

            let band = NSBezierPath()
            band.move(to: NSPoint(x: 5, y: 11))
            band.line(to: NSPoint(x: 21, y: 11))
            band.lineWidth = 1.5
            band.stroke()

            let center = NSRect(x: 10, y: 8, width: 6, height: 6)
            let button = NSBezierPath(ovalIn: center)
            NSColor.white.setFill()
            button.fill()
            button.lineWidth = 1.5
            button.stroke()
            return true
        }
        image.isTemplate = false
        image.accessibilityDescription = "Poké Ball"
        return image
    }()
}
