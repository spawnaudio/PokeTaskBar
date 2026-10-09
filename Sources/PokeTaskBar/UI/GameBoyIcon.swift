import SwiftUI

/// Original pixel artwork, sized by the same control as the Battle window.
@MainActor
struct GameBoyIcon: View {
    static let size = CGSize(width: 80, height: 96)
    var scale: CGFloat
    var tuckedEdge: FloatingPetController.TuckEdge?
    @Environment(FocusSessionStore.self) private var session
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let size = CGSize(width: Self.size.width * scale, height: Self.size.height * scale)
        let peek = size.width / 2
        let clock = session.isActive ? session.clockDisplay().text : nil
        let paused = session.session?.userPaused == true || session.session?.phase == .paused
        Canvas { context, _ in
            let ink = Color(red: 0.03, green: 0.17, blue: 0.21)
            let shell = Color(red: 0.91, green: 0.90, blue: 0.80)
            func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ color: Color) {
                context.fill(Path(CGRect(x: x, y: y, width: w, height: h)), with: .color(color))
            }
            // Stepped corners keep the shell in the Battle window's pixel style.
            rect(14, 8, 48, 80, ink); rect(10, 12, 56, 68, ink)
            rect(14, 12, 48, 68, shell); rect(18, 10, 40, 76, shell)
            rect(14, 18, 48, 34, Color(red: 0.32, green: 0.43, blue: 0.48))
            rect(18, 22, 42, 26, ink)
            rect(20, 24, 38, 22, Color(red: 0.60, green: 0.80, blue: 0.50))
            rect(16, 30, 2, 2, .red)
            if let clock {
                context.opacity = paused ? 0.6 : 1
                context.draw(Text(clock).font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(ink), at: CGPoint(x: 39, y: 35))
                context.opacity = 1
            } else {
                rect(30, 30, 8, 8, Color(red: 0.25, green: 0.42, blue: 0.26))
                rect(22, 42, 34, 2, ink)
            }
            rect(18, 59, 18, 6, ink); rect(24, 53, 6, 18, ink)
            let purple = Color(red: 0.64, green: 0.18, blue: 0.39)
            for (x, y): (CGFloat, CGFloat) in [(44, 64), (56, 58)] {
                rect(x + 2, y, 4, 8, ink); rect(x, y + 2, 8, 4, ink)
                rect(x + 2, y + 2, 4, 4, purple)
            }
            rect(28, 78, 9, 3, ink); rect(41, 78, 9, 3, ink)
            for i in 0..<3 { rect(54 + CGFloat(i * 3), 77 - CGFloat(i * 2), 2, 4, ink) }
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .rotationEffect(.degrees(tuckedEdge == .left ? 12 : tuckedEdge == .right ? -12 : 0))
        .scaleEffect(scale)
        .frame(width: size.width, height: size.height)
        .offset(x: tuckedEdge == .left ? -peek / 2 : tuckedEdge == .right ? peek / 2 : 0)
        .frame(width: tuckedEdge == nil ? size.width : peek, height: size.height)
        .clipped()
        .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: tuckedEdge)
    }
}
