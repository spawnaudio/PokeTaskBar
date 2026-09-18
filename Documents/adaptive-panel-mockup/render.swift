import AppKit

// Deterministic motion study using native SwiftUI fixture renders.
// No application source, preferences, credentials, or installed bundles are changed.
let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let width = 1440
let height = 1000
let fps: Int32 = 60
let duration = 29.0
let panelX = 820.0, panelY = 112.0, scale = 1.25

func color(_ value: UInt32, _ alpha: Double = 1) -> NSColor {
    NSColor(srgbRed: Double((value >> 16) & 255) / 255,
            green: Double((value >> 8) & 255) / 255,
            blue: Double(value & 255) / 255, alpha: alpha)
}
func box(_ rect: NSRect, _ fill: NSColor, radius: Double = 0) {
    fill.setFill()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
}
func text(_ value: String, _ x: Double, _ y: Double, _ size: Double,
          _ fill: NSColor = color(0xF3F5F8), weight: NSFont.Weight = .regular,
          maxWidth: Double = 630, lineHeight: Double? = nil) {
    let p = NSMutableParagraphStyle()
    p.lineSpacing = 4
    if let h = lineHeight { p.minimumLineHeight = h; p.maximumLineHeight = h }
    (value as NSString).draw(in: NSRect(x: x, y: y, width: maxWidth, height: 260),
        withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: weight),
                         .foregroundColor: fill, .paragraphStyle: p])
}
func symbol(_ name: String, _ rect: NSRect, tint: NSColor) {
    guard let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
        .withSymbolConfiguration(.init(pointSize: rect.height, weight: .regular)) else { return }
    let tinted = NSImage(size: image.size, flipped: false) { r in
        image.draw(in: r)
        tint.setFill(); r.fill(using: .sourceAtop)
        return true
    }
    tinted.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
}
func smooth(_ value: Double) -> Double {
    let v = min(1, max(0, value)); return v * v * (3 - 2 * v)
}

struct Page {
    let name: String
    let image: NSImage
    let contentEnd: Double
    let fittedHeight: Double
    let tabX: Double
}
func page(_ name: String, end: Double, fitted: Double, tab: Double) -> Page {
    Page(name: name, image: NSImage(contentsOf: output.appendingPathComponent("source-assets/\(name)-light.png"))!,
         contentEnd: end, fittedHeight: fitted, tabX: tab)
}
let focus = page("focus", end: 586, fitted: 640, tab: 50)
let linear = page("linear", end: 235, fitted: 290, tab: 120)
let usage = page("usage", end: 391, fitted: 446, tab: 198)
let collection = page("collection", end: 282, fitted: 337, tab: 283)
let settings = page("settings", end: 640, fitted: 640, tab: 367)
let idle = page("idle", end: 407, fitted: 462, tab: 50)

struct Scene {
    let start: Double
    let page: Page
    let h: Double
    let title: String
    let detail: String
    let label: String
}
let scenes: [Scene] = [
    Scene(start: 0, page: collection, h: 640, title: "One size leaves\na lot of space.",
          detail: "The current panel stays tall, even when\nthe page only has a little content.", label: "CURRENT · COLLECTION"),
    Scene(start: 3, page: collection, h: 337, title: "Fit the content.",
          detail: "The bottom edge moves up.\nThe header and menu-bar anchor stay put.", label: "PROPOSED · COLLECTION"),
    Scene(start: 6.2, page: focus, h: 640, title: "Room for focus.",
          detail: "A running session gets the room it needs.\nControls keep their normal size.", label: "PROPOSED · FOCUS"),
    Scene(start: 9.7, page: linear, h: 290, title: "Short page.\nShort window.",
          detail: "A setup or empty state stays compact.\nA populated list can grow, then scroll.", label: "PROPOSED · LINEAR"),
    Scene(start: 13, page: usage, h: 446, title: "A closer fit\nfor every tab.",
          detail: "Usage takes only the height it needs.\nOpen Today follows the bottom edge.", label: "PROPOSED · USAGE"),
    Scene(start: 16.3, page: collection, h: 337, title: "A tidy collection.",
          detail: "A small collection makes a small window.\nMore rows add height up to the limit.", label: "PROPOSED · COLLECTION"),
    Scene(start: 19.5, page: settings, h: 640, title: "Long pages\nscroll inside.",
          detail: "Settings keeps a comfortable height.\nThe remaining options are scrollable.", label: "PROPOSED · SETTINGS"),
    Scene(start: 22.8, page: idle, h: 462, title: "The page can\nchange size, too.",
          detail: "Focus is shorter with no active timer.\nSize follows content, not a fixed tab value.", label: "PROPOSED · IDLE FOCUS"),
    Scene(start: 26, page: collection, h: 337, title: "Same anchor.\nLess empty space.",
          detail: "A steady width. A smooth resize.\nBreathing room without the blank canvas.", label: "CONTENT-SIZED PANELS"),
]

func slice(_ source: NSImage, x: Double = 0, y: Double, w: Double = 400, h: Double,
           destinationX: Double = 0, destinationY: Double, alpha: Double = 1) {
    source.draw(in: NSRect(x: destinationX, y: destinationY, width: w, height: h),
        from: NSRect(x: x, y: 640 - y - h, width: w, height: h),
        operation: .sourceOver, fraction: alpha, respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high])
}

func drawPanel(_ page: Page, h: Double, alpha: Double) {
    NSGraphicsContext.saveGraphicsState()
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.translateBy(x: panelX, y: panelY)
    ctx.scaleBy(x: scale, y: scale)
    ctx.setAlpha(alpha)
    NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: 400, height: h), xRadius: 12, yRadius: 12).addClip()
    box(NSRect(x: 0, y: 0, width: 400, height: h), color(0xF3F4F6))
    if page.name == "settings" {
        slice(page.image, y: 0, h: min(h, 640), destinationY: 0)
        // A scroll-position cue clarifies the capped, scrollable settings viewport.
        box(NSRect(x: 381, y: 68, width: 3, height: 85), color(0xA5A9B2, 0.65), radius: 1.5)
    } else {
        let canvas = NSRect(x: 8, y: 86, width: 384, height: max(0, h - 126))
        box(canvas, color(0xFFFFFF), radius: 12)
        color(0xE9EBEF).setStroke()
        let border = NSBezierPath(roundedRect: canvas.insetBy(dx: 0.5, dy: 0.5), xRadius: 12, yRadius: 12)
        border.lineWidth = 1; border.stroke()
        slice(page.image, y: 0, h: 85, destinationY: 0)
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: NSRect(x: 9, y: 87, width: 382, height: max(0, h - 128))).addClip()
        slice(page.image, x: 9, y: 87, w: 382, h: page.contentEnd - 87, destinationX: 9, destinationY: 87)
        NSGraphicsContext.restoreGraphicsState()
        slice(page.image, y: 601, h: 39, destinationY: h - 39)
    }
    NSGraphicsContext.restoreGraphicsState()
}

let appIcon = NSImage(contentsOf: output.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("assets/icon_1024.png"))!

func drawFrame(time: Double, context: CGContext) {
    context.translateBy(x: 0, y: Double(height)); context.scaleBy(x: 1, y: -1)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
    let i = scenes.lastIndex(where: { time >= $0.start }) ?? 0
    let scene = scenes[i], previous = scenes[max(0, i - 1)]
    let progress = i == 0 ? 1 : smooth((time - scene.start) / 0.28)
    let h = previous.h + (scene.h - previous.h) * progress

    box(NSRect(x: 0, y: 0, width: width, height: height), color(0x11151D))
    // Simplified desktop menu bar, using native symbols and the app's own icon.
    box(NSRect(x: 0, y: 0, width: width, height: 48), color(0xE6E8ED))
    symbol("apple.logo", NSRect(x: 24, y: 13, width: 18, height: 20), tint: color(0x252A34))
    text("Finder", 61, 14, 15, color(0x252A34), weight: .semibold)
    text("File     Edit     View     Go     Window     Help", 130, 14, 15, color(0x404652))
    box(NSRect(x: 1017, y: 7, width: 103, height: 34), color(0xD0D4DD), radius: 9)
    appIcon.draw(in: NSRect(x: 1026, y: 13, width: 21, height: 21), from: .zero,
                 operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
    text("24:18", 1055, 13, 17, color(0x252A34), weight: .medium)
    symbol("wifi", NSRect(x: 1142, y: 14, width: 24, height: 18), tint: color(0x252A34))
    symbol("magnifyingglass", NSRect(x: 1190, y: 14, width: 18, height: 18), tint: color(0x252A34))
    text("Fri 18 Sep  9:41", 1231, 14, 15, color(0x252A34))

    text("POKETASKBAR   /   MOTION STUDY", 78, 111, 15, color(0x8CA0B7), weight: .semibold)
    box(NSRect(x: 78, y: 183, width: 34, height: 3), color(0x63CADA), radius: 1.5)
    text(scene.label, 78, 211, 13, color(0x71D3DD), weight: .semibold)
    text(scene.title, 74, 252, 52, weight: .semibold, maxWidth: 690, lineHeight: 62)
    text(scene.detail, 78, 423, 22, color(0xA9B3C2), maxWidth: 675)

    let metricY = 551.0
    text("WIDTH", 78, metricY, 12, color(0x8CA0B7), weight: .semibold)
    text("400 pt", 78, metricY + 24, 29, weight: .medium)
    text("HEIGHT", 251, metricY, 12, color(0x8CA0B7), weight: .semibold)
    text("\(Int(h.rounded())) pt", 251, metricY + 24, 29, weight: .medium)
    text(i == 0 ? "FIXED" : (scene.page.name == "settings" ? "CAPPED" : "FITS CONTENT"),
         422, metricY + 34, 12, color(i == 0 ? 0xBEA181 : 0x71D3DD), weight: .semibold)
    text("Illustrative heights · native UI · sample data", 78, 634, 14, color(0x7E8C9F))

    // Top edge / anchor guide makes it clear that the window does not jump.
    context.setLineDash(phase: 0, lengths: [3, 5])
    context.setStrokeColor(color(0x526074, 0.65).cgColor); context.setLineWidth(1)
    context.move(to: CGPoint(x: 1070, y: 50)); context.addLine(to: CGPoint(x: 1070, y: panelY)); context.strokePath()
    context.setLineDash(phase: 0, lengths: [])
    text("anchored to the menu bar", 904, 75, 13, color(0x8CA0B7), maxWidth: 360)

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow(); shadow.shadowColor = color(0x000000, 0.5)
    shadow.shadowBlurRadius = 28; shadow.shadowOffset = NSSize(width: 0, height: -12); shadow.set()
    box(NSRect(x: panelX, y: panelY, width: 400 * scale, height: h * scale), color(0xF3F4F6), radius: 15)
    NSGraphicsContext.restoreGraphicsState()
    if progress < 1 && scene.page.name != previous.page.name {
        drawPanel(previous.page, h: h, alpha: 1)
        drawPanel(scene.page, h: h, alpha: progress)
    } else { drawPanel(scene.page, h: h, alpha: 1) }

    if i == 0 {
        box(NSRect(x: panelX + 20 * scale, y: panelY + 310 * scale,
                   width: 360 * scale, height: 260 * scale), color(0xD9EAF0, 0.65), radius: 8)
        text("Unused space", panelX + 130 * scale, panelY + 425 * scale,
             15, color(0x697F8B), weight: .medium, maxWidth: 270)
    }
    // Cursor moves between the real tab positions and clicks on each change.
    if i > 1 && i < 8 {
        let move = smooth((time - scene.start + 0.34) / 0.34)
        let px = panelX + (previous.page.tabX + (scene.page.tabX - previous.page.tabX) * move) * scale
        let py = panelY + (scene.page.name == "settings" ? 23 : 62) * scale
        let click = min(1, max(0, (time - scene.start) / 0.38))
        if click < 1 {
            color(0x39AEBE, 0.65 * (1-click)).setStroke()
            let r = 8 + click * 17
            let ring = NSBezierPath(ovalIn: NSRect(x: px-r, y: py-r, width: 2*r, height: 2*r))
            ring.lineWidth = 2; ring.stroke()
        }
        if time - scene.start < 0.9 {
            NSCursor.arrow.image.draw(in: NSRect(x: px, y: py, width: 18, height: 28), from: .zero,
                operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        }
    }

    box(NSRect(x: 78, y: 914, width: 620, height: 2), color(0x2D3644), radius: 1)
    box(NSRect(x: 78, y: 914, width: 620 * time / duration, height: 2), color(0x64C8D6), radius: 1)
    text("\(String(format: "%02d", i + 1)) / 09", 78, 936, 13, color(0x8795A7), weight: .medium)
    text("DESIGN PREVIEW  ·  NOT IMPLEMENTED", 276, 936, 12, color(0x8795A7), weight: .medium)
    NSGraphicsContext.restoreGraphicsState()
}

let cs = CGColorSpace(name: CGColorSpace.sRGB)!
func bitmap(at time: Double) -> CGContext {
    let c = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                      space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    drawFrame(time: time, context: c)
    return c
}
func writeStill(at time: Double, name: String) throws {
    let rep = NSBitmapImageRep(cgImage: bitmap(at: time).makeImage()!)
    try rep.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("stills/\(name).png"))
}
for (index, scene) in scenes.enumerated() {
    try writeStill(at: scene.start + 1, name: String(format: "%02d", index + 1) + "-" + scene.page.name)
}
if CommandLine.arguments.contains("--stills-only") { exit(0) }

let videoURL = output.appendingPathComponent("adaptive-panel-mockup.mp4")
let encoder = Process()
encoder.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/ffmpeg")
encoder.arguments = ["-hide_banner", "-loglevel", "error", "-y", "-f", "rawvideo", "-pixel_format", "rgba",
                     "-video_size", "\(width)x\(height)", "-framerate", "\(fps)", "-i", "pipe:0",
                     "-an", "-c:v", "libx264", "-preset", "fast", "-crf", "18", "-pix_fmt", "yuv420p",
                     "-movflags", "+faststart", videoURL.path]
let pipe = Pipe()
encoder.standardInput = pipe
try encoder.run()
for frame in 0..<Int(duration * Double(fps)) {
    try autoreleasepool {
        let context = bitmap(at: Double(frame) / Double(fps))
        let data = Data(bytes: context.data!, count: width * height * 4)
        try pipe.fileHandleForWriting.write(contentsOf: data)
    }
    if frame % 300 == 0 { print("Rendered \(frame)/\(Int(duration * Double(fps))) frames") }
}
try pipe.fileHandleForWriting.close()
encoder.waitUntilExit()
guard encoder.terminationStatus == 0 else { fatalError("Video export failed") }
print(videoURL.path)
