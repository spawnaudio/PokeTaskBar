import AppKit
import SwiftUI

/// Native handles accept the first click in an inactive floating panel and track
/// screen coordinates, so resizing never jumps as SwiftUI changes its layout.
struct FloatingTimerDragHandle: NSViewRepresentable {
    var mode: FloatingTimerDragView.Mode
    var width: CGFloat
    var label: String
    var onResize: (CGFloat, NSPoint) -> Void
    var onFocusChange: (Bool) -> Void

    func makeNSView(context: Context) -> FloatingTimerDragView { FloatingTimerDragView() }
    func updateNSView(_ view: FloatingTimerDragView, context: Context) {
        view.mode = mode
        view.timerWidth = width
        view.onResize = onResize
        view.onFocusChange = onFocusChange
        view.setAccessibilityElement(true)
        view.setAccessibilityRole(mode == .resize ? .slider : .button)
        view.setAccessibilityLabel(label)
        if mode == .resize { view.setAccessibilityValue(Int(width)) }
    }
}

final class FloatingTimerDragView: NSView {
    enum Mode { case move, resize }
    var mode: Mode = .move
    var timerWidth: CGFloat = FloatingTimerMetrics.defaultWidth
    var onResize: (CGFloat, NSPoint) -> Void = { _, _ in }
    var onFocusChange: (Bool) -> Void = { _ in }
    private var startPoint: NSPoint?
    private var startFrame: NSRect?
    private var startWidth: CGFloat = 0

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }
    override func becomeFirstResponder() -> Bool { onFocusChange(true); return true }
    override func resignFirstResponder() -> Bool { onFocusChange(false); return true }
    override func resetCursorRects() { addCursorRect(bounds, cursor: mode == .move ? .openHand : .resizeLeftRight) }

    override func mouseDown(with event: NSEvent) {
        startPoint = NSEvent.mouseLocation
        startFrame = window?.frame
        startWidth = timerWidth
        if mode == .move { NSCursor.closedHand.set() }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let startPoint, let startFrame else { return }
        let delta = NSPoint(x: NSEvent.mouseLocation.x - startPoint.x, y: NSEvent.mouseLocation.y - startPoint.y)
        apply(delta: delta, frame: startFrame, width: startWidth)
    }

    override func mouseUp(with event: NSEvent) {
        startPoint = nil
        startFrame = nil
        (mode == .move ? NSCursor.openHand : NSCursor.resizeLeftRight).set()
    }

    private func apply(delta: NSPoint, frame: NSRect, width: CGFloat) {
        guard let window else { return }
        if mode == .resize { onResize(width - delta.x, NSPoint(x: frame.maxX, y: frame.minY)) }
        else {
            var target = frame.offsetBy(dx: delta.x, dy: delta.y)
            let screen = NSScreen.screens.first { $0.visibleFrame.contains(NSEvent.mouseLocation) }
                ?? window.screen
            if let screen { target = FloatingTimerMetrics.constrained(target, to: screen.visibleFrame) }
            window.setFrameOrigin(target.origin)
        }
    }

    override func keyDown(with event: NSEvent) {
        guard let frame = window?.frame else { return }
        let delta: NSPoint
        switch event.keyCode {
        case 123: delta = NSPoint(x: -8, y: 0)
        case 124: delta = NSPoint(x: 8, y: 0)
        case 125 where mode == .move: delta = NSPoint(x: 0, y: -8)
        case 126 where mode == .move: delta = NSPoint(x: 0, y: 8)
        default: super.keyDown(with: event); return
        }
        apply(delta: delta, frame: frame, width: timerWidth)
    }

    override func accessibilityPerformIncrement() -> Bool {
        guard let frame = window?.frame, mode == .resize else { return false }
        onResize(timerWidth + 16, NSPoint(x: frame.maxX, y: frame.minY))
        return true
    }

    override func accessibilityPerformDecrement() -> Bool {
        guard let frame = window?.frame, mode == .resize else { return false }
        onResize(timerWidth - 16, NSPoint(x: frame.maxX, y: frame.minY))
        return true
    }
}
