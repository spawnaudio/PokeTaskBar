import AppKit
import WebKit

/// The approved game UI runs locally; Swift owns every timer, reward and inventory mutation.
@MainActor
final class BattleWindow: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
    let webView: WKWebView
    let content: BattlePanelContent
    private let usage: UsageStore
    private let companion: CompanionStore
    private let focus: FocusSessionStore
    private let resourceURL: URL
    private var timer: Timer?
    private var itemImages: [String: String] = [:]
    private var playerImage = ""
    private var opponentImage = ""
    private var loadedIdentity = ""
    private var ready = false
    private var pendingBag = false
    private var mutating = false
    var onLayout: ((CGFloat, Bool) -> Void)?
    var onTuck: (() -> Void)?
    var onHover: ((Bool) -> Void)?

    init(usage: UsageStore, companion: CompanionStore, focus: FocusSessionStore) {
        self.usage = usage; self.companion = companion; self.focus = focus
        let resources = Bundle.main.resourceURL
            .flatMap { Bundle(url: $0.appendingPathComponent("PokeTaskBar_PokeTaskBar.bundle")) } ?? Bundle.module
        resourceURL = resources.url(forResource: "index", withExtension: "html", subdirectory: "BattleWindow")!
        let configuration = WKWebViewConfiguration()
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.setValue(false, forKey: "drawsBackground")
        content = BattlePanelContent(webView: webView, pinned: { usage.floatingTimerPinned })
        super.init()
        webView.configuration.userContentController.add(self, name: "battle")
        webView.navigationDelegate = self
        content.onHover = { [weak self] in self?.onHover?($0) }
        webView.loadFileURL(resourceURL, allowingReadAccessTo: resourceURL.deletingLastPathComponent())
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.publish() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        ready = false
        timer?.invalidate(); timer = nil
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "battle")
        webView.stopLoading()
    }

    func openBag() {
        guard ready else { pendingBag = true; return }
        webView.evaluateJavaScript("window.pokeTasksOpenBag?.()")
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        navigationAction.request.url == resourceURL ? .allow : .cancel
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.frameInfo.isMainFrame, message.frameInfo.request.url == resourceURL,
              let body = message.body as? [String: Any], let id = body["id"] as? Int,
              let action = body["action"] as? String else { return }
        Task { [weak self] in
            guard let self else { return }
            var error: String?
            switch action {
            case "ready":
                ready = true
                if pendingBag { pendingBag = false; openBag() }
            case "layout":
                if let height = body["height"] as? Int, [180, 200, 260].contains(height) {
                    onLayout?(CGFloat(height), body["input"] as? Bool ?? false)
                }
            case "pause": focus.togglePause()
            case "pin": usage.floatingTimerPinned.toggle()
            case "tuck": onTuck?()
            case "tasks": focus.openDesk()
            case "start":
                if let minutes = Self.wholeMinutes(body["minutes"]), !focus.isActive,
                   (SessionXP.minMinutes...SessionXP.maxMinutes).contains(minutes) {
                    focus.plannedMinutes = minutes
                    focus.startPomodoro()
                } else { error = "Choose 5–180 minutes while no timer is running." }
            case "potion":
                if mutating { error = "An item is already being used." }
                else if let kind = Self.potion(body["item"]) {
                    mutating = true
                    error = focus.usePotion(kind, customMinutes: Self.wholeMinutes(body["minutes"]))
                    mutating = false
                } else { error = "Choose an item from your bag." }
            case "buy":
                if let kind = Self.potion(body["item"]), companion.buy(kind) {} else { error = "Could not buy the item. Check Coins and save access." }
            case "rest":
                if mutating { error = "The task is already being finished." }
                else {
                    mutating = true
                    if !(await focus.finishBattleTask()) { error = "Could not finish the task. Try again." }
                    mutating = false
                }
            case "forfeit":
                focus.requestUnfocus()
                await focus.confirmForfeit()
            default: error = "That action is unavailable."
            }
            reply(id: id, error: error)
        }
    }

    static func wholeMinutes(_ value: Any?) -> Int? {
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID(),
              number.doubleValue.isFinite, number.doubleValue.rounded() == number.doubleValue,
              (1...Double(SessionXP.maxMinutes)).contains(number.doubleValue) else { return nil }
        return number.intValue
    }

    private static func potion(_ value: Any?) -> ItemKind? {
        FocusPotion.kinds.first { $0.spriteName == value as? String }
    }

    func publish() {
        guard ready else { return }
        refreshArtwork()
        reply(id: 0, error: nil)
    }

    private func reply(id: Int, error: String?) {
        guard ready else { return }
        var payload: [String: Any] = ["id": id, "state": snapshot()]
        if let error { payload["error"] = error }
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let text = String(data: data, encoding: .utf8) else { return }
        webView.evaluateJavaScript("window.pokeTasksReply?.(\(text))")
        refreshArtwork()
    }

    func snapshot(at now: Date = Date()) -> [String: Any] {
        let current = focus.session
        let planned = current?.plannedSeconds ?? Double(focus.plannedMinutes * 60)
        let remaining = current.map { max(0, $0.plannedSeconds - $0.displayedSeconds(at: now)) } ?? 0
        let phase = current == nil ? "idle" : remaining <= 0 ? "zero" : current?.isAccruing == true ? "running" : "paused"
        let opponent = current?.battleOpponentID ?? 94
        let names = [94: "GENGAR", 25: "PIKACHU", 43: "ODDISH"]
        let progress = companion.isEgg ? companion.eggProgress : companion.progress
        return ["phase": phase, "planned": planned, "remaining": remaining,
                "xp": (progress * 100).rounded(), "threshold": 100,
                "coins": companion.availableCoins, "opponent": 0,
                "opponentName": names[opponent] ?? "GENGAR", "opponentImage": opponentImage,
                "taskTitle": current?.issue.title ?? "", "playerName": companion.hasActive ? companion.displayName.uppercased() : companion.isEgg ? "EGG" : "TRAINER",
                "stage": companion.stageText, "playerImage": playerImage,
                "bag": Dictionary(uniqueKeysWithValues: FocusPotion.kinds.map { ($0.spriteName!, companion.itemCount($0)) }),
                "prices": Dictionary(uniqueKeysWithValues: FocusPotion.kinds.map { ($0.spriteName!, companion.price(of: $0) ?? 0) }),
                "itemImages": itemImages, "defaultMinutes": focus.plannedMinutes,
                "scale": usage.floatingTimerScale, "pinned": usage.floatingTimerPinned]
    }

    private func refreshArtwork() {
        let opponent = focus.session?.battleOpponentID ?? 94
        let identity = "\(companion.currentSpeciesID ?? 0)-\(companion.currentIsShiny)-\(companion.currentUnownForm?.rawValue ?? "")-\(companion.isEgg)-\(opponent)"
        guard loadedIdentity != identity else { return }
        loadedIdentity = identity
        Task { [weak self] in
            guard let self else { return }
            let player: Data?
            if let species = companion.currentSpeciesID {
                let back = await SpriteStore.shared.data(speciesID: species, animated: false, shiny: companion.currentIsShiny,
                                                         unownForm: companion.currentUnownForm, back: true)
                if let back { player = back }
                else { player = await SpriteStore.shared.data(speciesID: species, animated: false,
                                                              shiny: companion.currentIsShiny, unownForm: companion.currentUnownForm) }
            } else if companion.isEgg { player = await SpriteStore.shared.eggData() }
            else { player = nil }
            let frames = await SpriteLoader.animationFrames(speciesID: opponent, shiny: false)
            let fallback = frames.isEmpty ? await SpriteLoader.image(speciesID: opponent) : nil
            var items: [String: String] = [:]
            for kind in FocusPotion.kinds {
                if let name = kind.spriteName, let data = await SpriteStore.shared.data(itemName: name) {
                    items[name] = Self.dataImage(data)
                }
            }
            guard loadedIdentity == identity else { return }
            playerImage = player.map(Self.dataImage) ?? ""
            opponentImage = Self.spriteSheet(frames: Array(frames.prefix(2)).map(\.image), fallback: fallback) ?? ""
            itemImages = items
            publish()
        }
    }

    private static func dataImage(_ data: Data) -> String { "data:image/png;base64,\(data.base64EncodedString())" }

    private static func spriteSheet(frames: [NSImage], fallback: NSImage?) -> String? {
        guard let first = frames.first ?? fallback else { return nil }
        let images = [first, frames.count > 1 ? frames[1] : first]
        let sheet = NSImage(size: NSSize(width: 74, height: 148))
        sheet.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .none
        for (index, image) in images.enumerated() {
            let size = SpriteFit.size(for: image.size, box: 74)
            image.draw(in: NSRect(x: (74 - size.width) / 2, y: Double(index * 74) + (74 - size.height) / 2,
                                 width: size.width, height: size.height))
        }
        sheet.unlockFocus()
        guard let tiff = sheet.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else { return nil }
        return Self.dataImage(png)
    }
}

/// Keep dragging on the header and route all game buttons/text input to WebKit.
@MainActor
final class BattlePanelContent: NSView {
    private let webView: WKWebView
    private let header: BattleHeaderDragView
    private var tracking: NSTrackingArea?
    var onHover: ((Bool) -> Void)?
    var gameSize = NSSize(width: 360, height: 180) { didSet { needsLayout = true } }
    var tuckedRight = false { didSet { needsLayout = true } }

    init(webView: WKWebView, pinned: @escaping () -> Bool) {
        self.webView = webView; self.header = BattleHeaderDragView(pinned: pinned)
        super.init(frame: .zero)
        wantsLayer = true; layer?.masksToBounds = true
        addSubview(webView); addSubview(header)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layout() {
        super.layout()
        let x = tuckedRight ? bounds.width - gameSize.width : 0
        webView.frame = NSRect(x: x, y: 0, width: gameSize.width, height: gameSize.height)
        header.frame = NSRect(x: 0, y: bounds.height - 32 * gameSize.width / 360,
                              width: bounds.width, height: 32 * gameSize.width / 360)
    }
    override func updateTrackingAreas() {
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self)
        addTrackingArea(area); tracking = area
        super.updateTrackingAreas()
    }
    override func mouseEntered(with event: NSEvent) { onHover?(true) }
    override func mouseExited(with event: NSEvent) { onHover?(false) }
}

@MainActor
private final class BattleHeaderDragView: NSView {
    private let pinned: () -> Bool
    init(pinned: @escaping () -> Bool) { self.pinned = pinned; super.init(frame: .zero) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func mouseDown(with event: NSEvent) { if !pinned() { window?.performDrag(with: event) } }
}
