import AppKit
import SwiftUI

/// Pet overlay panel. Stock `.nonactivatingPanel` cannot become key, so overlay
/// `TextField`s (session notes, check-in) swallow clicks and drop keystrokes.
final class FloatingPetPanel: NSPanel {
    var contextMenuProvider: (() -> NSMenu)?
    var onMenuTrackingChange: ((Bool) -> Void)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func sendEvent(_ event: NSEvent) {
        // Handle this before SwiftUI controls or WebKit choose their own menu.
        if event.type == .rightMouseDown || (event.type == .leftMouseDown && event.modifierFlags.contains(.control)),
           let menu = contextMenuProvider?(), let contentView {
            onMenuTrackingChange?(true)
            defer { onMenuTrackingChange?(false) }
            NSApp.activate(ignoringOtherApps: true)
            NSMenu.popUpContextMenu(menu, with: event, for: contentView)
            return
        }
        super.sendEvent(event)
    }
}

final class FloatingTimerHostingView: NSHostingView<AnyView> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// 데스크톱 위에 떠 있는 컴패니언 포켓몬 오버레이(옵트인, 설정 → 플로팅 펫).
/// - 드래그: 커스텀 `mouseDragged` (클릭과 충돌하지 않음).
/// - 클릭 → 팝오버, 우클릭 → 메뉴, 호버 → 오늘 사용량 콜아웃.
/// - Limit-alert speech bubbles grow the panel; persisted origin is the *pet*, not the panel.
/// - 에너지: 숨김·슬립 시 호스팅 트리 해제.
@MainActor
final class FloatingPetController: NSObject, NSWindowDelegate {
    enum OverlayConfirmPrompt: Equatable {
        case none, forfeit, reset
    }
    private let store: UsageStore
    private let companion: CompanionStore
    private let session: FocusSessionStore
    private let defaults: UserDefaults
    private lazy var displayMenu: FloatingDisplayMenu = {
        let menu = FloatingDisplayMenu(store: store)
        menu.language = { [weak self] in self?.companion.language ?? .systemDefault }
        menu.onOpen = { [weak self] in
            guard let self else { return }
            if self.store.floatingPetStyle == .battle && self.store.battleWindowFolded { self.expandBattleWindow() }
            else { self.onOpenPopover?() }
        }
        menu.onOpenToday = { [weak self] in self?.onOpenToday?() }
        menu.onNewIssue = { [weak self] in self?.onNewIssue?() }
        menu.onHide = { [weak self] in self?.onHide?() }
        menu.onToggleTuck = { [weak self] in self?.toggleEdgeTucking() }
        menu.tuckEnabled = { [weak self] in self?.tuckEdge != nil }
        return menu
    }()
    private var battle: BattleWindow?
    private var battleHeight: CGFloat = 180
    private var battleInput = false
    private var panel: NSPanel?
    private var timerPanel: NSPanel?
    private var timerTextInputArmed = false
    static let timerPanelIdentifier = "PokeTaskBar.DetachedTimer"
    static let timerAnchorXKey = "floatingTimerAnchorX"
    static let timerAnchorYKey = "floatingTimerAnchorY"
    private var hoverPanel: NSPanel?
    private var rewardPanel: XPRewardPanel?
    private var displayAwake = true
    private var builtAnimated: Bool?
    private var powerObserver: NSObjectProtocol?
    enum TuckEdge: String { case left, right }
    static let tuckEdgeKey = "floatingPetTuckEdge"
    static let edgePeekWidth: CGFloat = 24
    private(set) var tuckEdge: TuckEdge?
    private var edgeRevealed = false
    private var tuckTask: Task<Void, Never>?
    private var menuTracking = false
    private var applyingFrame = false

    private static let originXKey = "floatingPetOriginX"
    private static let originYKey = "floatingPetOriginY"
    private static let battleAnchorXKey = "battleWindowAnchorX"
    private static let battleAnchorYKey = "battleWindowAnchorY"

    /// Squared movement (pt²) below which a mouse-up counts as a click, not a drag.
    static let clickThresholdSquared: CGFloat = 16  // ~4pt

    /// Vertical space above the sprite for the bubble + VStack spacing (pt).
    /// Sized for two wrapped body lines + title + padding + tail (ja strings).
    static let bubbleHeadroom: CGFloat = 72
    /// Minimum panel width while a bubble is showing.
    static let bubbleMinWidth: CGFloat = 180
    /// Horizontal padding inside the bubble chrome (each side). Content + 2× this = `bubbleMinWidth`.
    static let bubbleHorizontalPadding: CGFloat = 8
    /// Fixed text column — wraps instead of growing past the panel (`bubbleMinWidth` − 16).
    static let bubbleContentWidth: CGFloat = bubbleMinWidth - (bubbleHorizontalPadding * 2)
    /// `SpeechBubbleView` body `.lineLimit`. Measure and view must share this — a
    /// headroom-only guard stays green for 3-line copy that still fits 70pt (#167).
    static let bubbleBodyLineLimit = 2
    static let islandWidth: CGFloat = 228
    static let islandHeight: CGFloat = FloatingTimerMetrics.height
    static let setupIslandHeight = FloatingTimerMetrics.height
    static let islandGap: CGFloat = 8
    /// Chevron *hit* target. Glyph stays smaller inside this frame.
    static let islandFoldChevronSize: CGFloat = 32
    /// Folded countdown (`50:00` + compact OT capsule). Wider than digits-only so OT is not clipped.
    static let islandFoldedClockWidth: CGFloat = 88
    static let islandFoldedClockHeight: CGFloat = 34
    static let compactNewIssueWidth: CGFloat = 25 // 23 pt button + 2 pt spacing
    static let compactTimerWidth = islandFoldedClockWidth + islandGap + islandFoldChevronSize + compactNewIssueWidth
    static let promptHeightZeroTime: CGFloat = 152
    static let promptHeightCheckIn: CGFloat = 176
    static let promptHeightForfeit: CGFloat = 168
    static let promptHeightReset: CGFloat = 108
    static let noteComposerHeight: CGFloat = 68

    /// Chrome size plus the signals the view actually fails on: wrap count vs
    /// `bubbleBodyLineLimit`, and single-line width vs the content column.
    struct SpeechBubbleLayout: Equatable {
        var size: NSSize
        var bodyLineCount: Int
        var unclampedTitleWidth: CGFloat
        var unclampedBodyWidth: CGFloat
        var wouldTruncate: Bool
    }

    /// AppKit 호버 콜아웃에 사용할 appearance 해석 완료 색상.
    ///
    /// 이 콜아웃은 SwiftUI가 아니라 `NSTextField`와 레이어 기반 `NSView`로 조립된다.
    /// 텍스트 필드에 semantic `NSColor`를 그대로 지정하면 뷰의 effective appearance로
    /// 해석되지만, `windowBackgroundColor.cgColor`는 현재 그리기 appearance에서 즉시
    /// 색상이 굳어진다. 세 색상을 하나의 appearance에서 함께 해석해야 글자와 외곽선이
    /// 같은 라이트/다크 모드를 유지한다.
    struct HoverCalloutColors {
        var text: NSColor
        var background: NSColor
        var border: NSColor
    }

    static func hoverCalloutColors(for appearance: NSAppearance) -> HoverCalloutColors {
        HoverCalloutColors(
            text: snapshot(NSColor.labelColor, for: appearance),
            background: snapshot(NSColor.windowBackgroundColor, for: appearance),
            border: snapshot(NSColor.separatorColor, for: appearance))
    }

    private static func snapshot(_ color: NSColor, for appearance: NSAppearance) -> NSColor {
        var resolved = color
        appearance.performAsCurrentDrawingAppearance {
            resolved = NSColor(cgColor: color.cgColor) ?? color
        }
        return resolved
    }

    private var onOpenPopover: (() -> Void)?
    private var onHide: (() -> Void)?
    private var onOpenToday: (() -> Void)?
    private var onNewIssue: (() -> Void)?
    /// Rising-edge so token/bubble `sync()` does not re-activate while typing.
    private var textInputArmed = false

    init(store: UsageStore, companion: CompanionStore, session: FocusSessionStore,
         defaults: UserDefaults = .standard,
         onOpenPopover: (() -> Void)? = nil, onHide: (() -> Void)? = nil,
         onOpenToday: (() -> Void)? = nil, onNewIssue: (() -> Void)? = nil) {
        self.store = store
        self.companion = companion
        self.session = session
        self.defaults = defaults
        self.tuckEdge = defaults.string(forKey: Self.tuckEdgeKey).flatMap(TuckEdge.init(rawValue:))
        self.onOpenPopover = onOpenPopover
        self.onHide = onHide
        self.onOpenToday = onOpenToday
        self.onNewIssue = onNewIssue
        super.init()
        session.onOpenBattleBag = { [weak self] in
            guard let self else { return }
            self.store.floatingPetStyle = .battle
            self.store.floatingPetEnabled = true
            self.store.battleWindowFolded = false
            self.sync()
            self.battle?.openBag()
        }
        observeSettings()
        observePowerState()
        sync()
    }

    static func isClick(from start: NSPoint, to end: NSPoint,
                        thresholdSquared: CGFloat = clickThresholdSquared) -> Bool {
        let dx = end.x - start.x, dy = end.y - start.y
        return dx * dx + dy * dy < thresholdSquared
    }

    func setDisplayAwake(_ awake: Bool) {
        displayAwake = awake
        sync()
    }

    func showXPReward(_ reward: XPReward?) {
        rewardPanel?.orderOut(nil)
        rewardPanel?.contentView = nil
        rewardPanel?.close()
        rewardPanel = nil
        guard let reward, store.floatingPetEnabled, displayAwake,
              let panel, panel.isVisible else { return }
        let receipt = XPRewardPanel(reward: reward)
        rewardPanel = receipt
        positionXPReward()
        receipt.orderFrontRegardless()
    }

    private func positionXPReward() {
        guard let panel, let screen = panel.screen, let rewardPanel else { return }
        let size = CGFloat(store.floatingPetSize)
        let pet = store.floatingPetStyle == .battle ? panel.frame
            : NSRect(x: panel.frame.maxX - size, y: panel.frame.minY, width: size, height: size)
        rewardPanel.follow(pet: pet, screen: screen)
    }

    private func observeSettings() {
        observeLayout()
        observeHoverTooltip()
    }

    /// Layout / hosting — not token totals. Token polls must not `setFrame` the pet.
    private func observeLayout() {
        withObservationTracking {
            _ = store.floatingPetStyle
            _ = store.floatingPetEnabled
            _ = store.floatingDisplaysFloatOnTop
            _ = store.floatingPetIslandFolded
            _ = store.floatingTimerWidth
            if store.floatingPetStyle == .battle {
                _ = store.battleWindowScale
                _ = store.battleWindowFolded
            } else {
                _ = store.floatingPetSize
                _ = store.floatingTimerScale
            }
            _ = store.floatingTimerDetached
            _ = store.currentSpeechBubble
            _ = companion.language
            _ = session.isActive
            _ = session.pomodoroSetupOpen
            _ = session.plannedMinutes
            _ = session.prompt
            _ = session.isComposingNote
            _ = session.forfeitPrompt
            _ = session.resetPrompt
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.sync()
                self.observeLayout()
            }
        }
    }

    /// Hover tooltip only — usage refresh used to call `sync()` → `setFrame(display: true)`.
    private func observeHoverTooltip() {
        withObservationTracking {
            _ = store.todayTotalTokens
            _ = store.highestLimitUtilization
            _ = store.limitDisplayMode
            _ = companion.language
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.updateHoverTooltip()
                self.observeHoverTooltip()
            }
        }
    }

    private func observePowerState() {
        powerObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name.NSProcessInfoPowerStateDidChange, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.sync() }
        }
    }

    /// Visible pet at the same rect: skip `setFrame` / `orderFrontRegardless`
    /// (token-poll `sync` used to force a WindowServer commit every refresh).
    static func shouldApplyPanelFrame(current: NSRect, target: NSRect, isVisible: Bool) -> Bool {
        !isVisible || !current.equalTo(target)
    }

    static func shouldAnimate(lowPower: Bool) -> Bool { !lowPower }

    /// Panel size for a given pet size and bubble visibility. Pure — tested without AppKit layout.
    static func panelSize(petSize: CGFloat, showingBubble: Bool) -> NSSize {
        panelSize(petSize: petSize, showingBubble: showingBubble, hasIsland: false, prompt: .none)
    }

    /// Overlay `TextField`s (note composer, check-in) need a key window. Stock
    /// `.nonactivatingPanel` returns `canBecomeKey == false`, so keystrokes never arrive.
    static func overlayNeedsKeyWindow(composingNote: Bool, prompt: FocusPrompt) -> Bool {
        composingNote || prompt == .checkIn
    }

    static func panelSize(petSize: CGFloat, showingBubble: Bool,
                          hasIsland: Bool, prompt: FocusPrompt, composingNote: Bool = false,
                          confirm: OverlayConfirmPrompt = .none,
                          islandFolded: Bool = false,
                          showsTimerToggle: Bool = false,
                          setupIsland: Bool = false,
                          timerWidth: CGFloat = FloatingTimerMetrics.defaultWidth,
                          timerScale: CGFloat = 1) -> NSSize {
        if !hasIsland, !showsTimerToggle, !setupIsland, prompt == .none, confirm == .none {
            if showingBubble {
                return NSSize(width: max(petSize, bubbleMinWidth),
                              height: petSize + bubbleHeadroom)
            }
            return NSSize(width: petSize, height: petSize)
        }
        var promptH: CGFloat = 0
        switch confirm {
        case .forfeit: promptH = promptHeightForfeit + 8
        case .reset: promptH = promptHeightReset + 8
        case .none:
            switch prompt {
            case .none: break
            case .zeroTime: promptH = promptHeightZeroTime + 8
            case .checkIn: promptH = promptHeightCheckIn + 8
            }
        }
        let islandOn = hasIsland || setupIsland
        let folded = islandFolded && !setupIsland
        let composerH = (hasIsland && composingNote) ? noteComposerHeight : 0
        let showsToggle = islandOn || showsTimerToggle
        let chevronW: CGFloat = showsToggle ? islandFoldChevronSize + islandGap : 0
        let foldedClockW: CGFloat = (hasIsland && folded) ? islandFoldedClockWidth + islandGap + compactNewIssueWidth : 0
        let showChrome = islandOn && !folded
        let needsPromptColumn = promptH > 0 || composerH > 0
        let contentWidth = islandOn && !folded ? FloatingTimerMetrics.width(timerWidth) : islandWidth
        let contentW: CGFloat = (showChrome || needsPromptColumn) ? contentWidth + islandGap : 0
        let islandW = (contentW + foldedClockW + chevronW) * timerScale
        let chromeH: CGFloat = showChrome ? (setupIsland ? setupIslandHeight : islandHeight) : 0
        let foldedClockH: CGFloat = (hasIsland && folded) ? islandFoldedClockHeight : 0
        let column = chromeH + composerH + promptH
        let toggleH: CGFloat = showsToggle ? islandFoldChevronSize : 0
        let width = max(petSize + islandW, showingBubble ? bubbleMinWidth : petSize + islandW)
        let height = (showingBubble ? bubbleHeadroom : 0) + max(petSize, max(column, foldedClockH, toggleH) * timerScale)
        return NSSize(width: width, height: height)
    }

    static func panelOrigin(petOrigin: NSPoint, petSize: CGFloat, panelSize: NSSize) -> NSPoint {
        panelOrigin(petOrigin: petOrigin, petSize: petSize, panelSize: panelSize, hasIsland: false)
    }

    static func panelOrigin(petOrigin: NSPoint, petSize: CGFloat, panelSize: NSSize,
                            hasIsland: Bool) -> NSPoint {
        if hasIsland {
            return NSPoint(x: petOrigin.x + petSize - panelSize.width, y: petOrigin.y)
        }
        let xInset = max(0, (panelSize.width - petSize) / 2)
        return NSPoint(x: petOrigin.x - xInset, y: petOrigin.y)
    }

    static func petOrigin(panelOrigin: NSPoint, petSize: CGFloat, panelSize: NSSize) -> NSPoint {
        petOrigin(panelOrigin: panelOrigin, petSize: petSize, panelSize: panelSize, hasIsland: false)
    }

    static func petOrigin(panelOrigin: NSPoint, petSize: CGFloat, panelSize: NSSize,
                          hasIsland: Bool) -> NSPoint {
        if hasIsland {
            return NSPoint(x: panelOrigin.x + panelSize.width - petSize, y: panelOrigin.y)
        }
        let xInset = max(0, (panelSize.width - petSize) / 2)
        return NSPoint(x: panelOrigin.x + xInset, y: panelOrigin.y)
    }

    /// Measure speech-bubble chrome for a title/body at the fixed content width (wrapping).
    /// Pure AppKit typography — keeps the layout test free of SwiftUI hosting.
    static func measureSpeechBubble(title: String, body: String,
                                    contentWidth: CGFloat = bubbleContentWidth) -> NSSize {
        measureSpeechBubbleLayout(title: title, body: body, contentWidth: contentWidth).size
    }

    /// Layout the view draws: unconstrained chrome (`size`) plus wrap count and
    /// single-line widths. `size.width` is clamped to the column (cannot fail a
    /// `≤ panel.width` assert); `unclamped*Width` is the check that can.
    static func measureSpeechBubbleLayout(title: String, body: String,
                                          contentWidth: CGFloat = bubbleContentWidth) -> SpeechBubbleLayout {
        let titleFont = NSFont.systemFont(ofSize: 11, weight: .bold)
        let bodyFont = NSFont.systemFont(ofSize: 10)
        let wrap = NSSize(width: contentWidth, height: 10_000)
        let unclamped = NSSize(width: CGFloat.greatestFiniteMagnitude, height: 10_000)
        let opts: NSString.DrawingOptions = [.usesLineFragmentOrigin, .usesFontLeading]
        let titleRect = (title as NSString).boundingRect(
            with: wrap, options: opts, attributes: [.font: titleFont])
        let bodyRect = (body as NSString).boundingRect(
            with: wrap, options: opts, attributes: [.font: bodyFont])
        let unclampedTitle = (title as NSString).boundingRect(
            with: unclamped, options: opts, attributes: [.font: titleFont])
        let unclampedBody = (body as NSString).boundingRect(
            with: unclamped, options: opts, attributes: [.font: bodyFont])
        let textWidth = min(contentWidth, max(titleRect.width, bodyRect.width))
        let textHeight = ceil(titleRect.height) + 2 + ceil(bodyRect.height)
        // Match SpeechBubbleView: horizontal padding ×2, vertical 6, bottom pad 6 for the tail.
        let hPad = bubbleHorizontalPadding * 2
        let bodyLineCount = wrappedLineCount(body, font: bodyFont, width: contentWidth)
        return SpeechBubbleLayout(
            size: NSSize(width: textWidth + hPad, height: textHeight + 12 + 6),
            bodyLineCount: bodyLineCount,
            unclampedTitleWidth: unclampedTitle.width,
            unclampedBodyWidth: unclampedBody.width,
            wouldTruncate: bodyLineCount > bubbleBodyLineLimit)
    }

    /// Wrap count at `width` using the same `boundingRect` path as `size`, so a
    /// height-jump fixture and `bodyLineCount` cannot disagree.
    private static func wrappedLineCount(_ string: String, font: NSFont, width: CGFloat) -> Int {
        guard !string.isEmpty else { return 0 }
        let opts: NSString.DrawingOptions = [.usesLineFragmentOrigin, .usesFontLeading]
        let wrapped = (string as NSString).boundingRect(
            with: NSSize(width: width, height: 10_000), options: opts, attributes: [.font: font])
        let single = ("Ay" as NSString).boundingRect(
            with: NSSize(width: 10_000, height: 10_000), options: opts, attributes: [.font: font])
        let unit = max(single.height, 1)
        return max(1, Int((wrapped.height / unit).rounded()))
    }

    private func sync() {
        syncDetachedTimer()
        guard store.floatingPetEnabled, displayAwake else { hide(); return }
        show()
    }

    private var detachedTimerSize: NSSize {
        let reserved = Self.panelSize(petSize: 0, showingBubble: false,
            hasIsland: session.isActive, prompt: session.prompt,
            composingNote: session.isComposingNote, confirm: overlayConfirm,
            setupIsland: (session.pomodoroSetupOpen || store.floatingDisplayMode == .timerOnly) && !session.isActive,
            timerWidth: CGFloat(store.floatingTimerWidth))
        let scale = CGFloat(store.floatingTimerScale)
        return NSSize(width: CGFloat(store.floatingTimerWidth) * scale, height: reserved.height * scale)
    }

    private func syncDetachedTimer() {
        guard store.floatingPetStyle != .battle, store.floatingTimerDetached, displayAwake,
              session.isActive || session.pomodoroSetupOpen || store.floatingDisplayMode == .timerOnly else {
            timerPanel?.orderOut(nil)
            timerPanel?.contentView = nil
            timerTextInputArmed = false
            return
        }
        let p = timerPanel ?? makePanel()
        timerPanel = p
        p.level = store.floatingDisplaysFloatOnTop ? .floating : .normal
        p.identifier = NSUserInterfaceItemIdentifier(Self.timerPanelIdentifier)
        if !(p.contentView is NSHostingView<AnyView>) {
            p.contentView = FloatingTimerHostingView(rootView: AnyView(
                SessionIslandView(onResizeTimer: { [weak self] width, anchor in
                    self?.resizeTimer(to: width, keepingRightEdge: anchor)
                })
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .environment(store).environment(companion).environment(session)))
        }
        let size = detachedTimerSize
        let savedX = defaults.object(forKey: Self.timerAnchorXKey) as? Double
        let savedY = defaults.object(forKey: Self.timerAnchorYKey) as? Double
        let fallback = panel.map {
            NSPoint(x: $0.frame.maxX - CGFloat(store.floatingPetSize) - Self.islandFoldChevronSize - Self.islandGap * 2,
                    y: $0.frame.minY)
        } ?? Self.defaultPetOrigin(petSize: CGFloat(store.floatingPetSize))
        let anchor = NSPoint(x: savedX ?? fallback.x, y: savedY ?? fallback.y)
        let screen = NSScreen.screens.first { $0.visibleFrame.contains(NSPoint(x: anchor.x - 1, y: anchor.y)) }
            ?? panel?.screen ?? NSScreen.main
        let frame = NSRect(x: anchor.x - size.width, y: anchor.y, width: size.width, height: size.height)
        let target = screen.map { FloatingTimerMetrics.constrained(frame, to: $0.visibleFrame) } ?? frame
        if Self.shouldApplyPanelFrame(current: p.frame, target: target, isVisible: p.isVisible) {
            applyingFrame = true
            p.setFrame(target, display: true)
            applyingFrame = false
        }
        if !p.isVisible { p.orderFrontRegardless() }
        if savedX == nil || savedY == nil { persistTimerAnchor() }
        let needsKey = Self.overlayNeedsKeyWindow(composingNote: session.isComposingNote, prompt: session.prompt)
        if needsKey, !timerTextInputArmed {
            NSApp.activate(ignoringOtherApps: true)
            p.makeKeyAndOrderFront(nil)
        }
        timerTextInputArmed = needsKey
    }

    private func persistTimerAnchor() {
        guard let timerPanel, timerPanel.isVisible else { return }
        defaults.set(timerPanel.frame.maxX, forKey: Self.timerAnchorXKey)
        defaults.set(timerPanel.frame.minY, forKey: Self.timerAnchorYKey)
    }

    private var overlayIsEditing: Bool {
        store.floatingPetStyle == .battle ? (!store.battleWindowFolded && battleInput)
            : Self.overlayNeedsKeyWindow(composingNote: session.isComposingNote, prompt: session.prompt)
    }

    private var displayedTuckEdge: TuckEdge? {
        guard !edgeRevealed, !overlayIsEditing else { return nil }
        return tuckEdge
    }

    func toggleEdgeTucking() {
        tuckTask?.cancel()
        if tuckEdge != nil {
            tuckEdge = nil
        } else if let panel, let screen = panel.screen {
            let petCenter = store.floatingPetStyle == .battle ? panel.frame.midX
                : panel.frame.maxX - CGFloat(store.floatingPetSize) / 2
            tuckEdge = petCenter < screen.visibleFrame.midX ? .left : .right
        }
        defaults.set(tuckEdge?.rawValue, forKey: Self.tuckEdgeKey)
        edgeRevealed = false
        hideHoverCallout()
        sync()
    }

    private func hoverChanged(_ hovering: Bool) {
        tuckTask?.cancel()
        if hovering {
            if tuckEdge != nil, !edgeRevealed {
                edgeRevealed = true
                show()
            }
            if !menuTracking { showHoverCallout() }
        } else {
            hideHoverCallout()
            guard tuckEdge != nil, edgeRevealed else { return }
            tuckTask = Task { @MainActor [weak self] in
                // Only retry while an open popover, text editor or drag needs the overlay.
                while !Task.isCancelled {
                    do { try await Task.sleep(for: .milliseconds(350)) } catch { return }
                    guard let self, let panel = self.panel, panel.isVisible else { return }
                    guard !self.menuTracking, !self.overlayIsEditing, NSEvent.pressedMouseButtons == 0,
                          panel.childWindows?.contains(where: \.isVisible) != true
                    else { continue }
                    guard !panel.frame.contains(NSEvent.mouseLocation) else { return }
                    self.edgeRevealed = false
                    self.show()
                    return
                }
            }
        }
    }

    /// Crop at the screen boundary instead of moving a window onto an adjacent display.
    static func edgeFrame(expanded: NSRect, edge: TuckEdge, visible: NSRect,
                          petSize: CGFloat, tucked: Bool, peekWidth: CGFloat = edgePeekWidth) -> NSRect {
        let size = tucked ? NSSize(width: peekWidth, height: petSize) : expanded.size
        let frame = NSRect(x: edge == .left ? visible.minX : visible.maxX - size.width,
                           y: expanded.minY, width: size.width, height: size.height)
        return FloatingTimerMetrics.constrained(frame, to: visible)
    }

    private func petView(animated: Bool) -> AnyView {
        AnyView(FloatingPetView(animated: animated, tuckedEdge: displayedTuckEdge,
            onResizeTimer: { [weak self] width, anchor in
                self?.resizeTimer(to: width, keepingRightEdge: anchor)
            }).environment(store).environment(companion).environment(session))
    }

    private func showBattle() {
        let p = panel ?? makePanel()
        panel = p
        p.level = store.floatingDisplaysFloatOnTop ? .floating : .normal
        p.identifier = NSUserInterfaceItemIdentifier("PokeTasks.BattleWindow")
        builtAnimated = nil
        let folded = store.battleWindowFolded
        p.title = folded ? "PokeTasks · Game Boy" : "PokeTasks · Battle window"
        if folded {
            battle?.setPublishing(false)
        } else if battle == nil {
            let game = BattleWindow(usage: store, companion: companion, focus: session)
            game.onLayout = { [weak self] height, input in
                guard let self else { return }
                if self.battleHeight != height || self.battleInput != input {
                    self.battleHeight = height; self.battleInput = input
                    self.showBattle()
                }
            }
            game.onTuck = { [weak self] in self?.toggleEdgeTucking() }
            game.onHover = { [weak self] in self?.hoverChanged($0) }
            battle = game
        }
        let scale = CGFloat(store.battleWindowScale)
        let size = folded ? NSSize(width: GameBoyIcon.size.width * scale, height: GameBoyIcon.size.height * scale)
            : NSSize(width: 360 * scale, height: battleHeight * scale)
        let petSize = CGFloat(store.floatingPetSize)
        let fallback = Self.defaultPetOrigin(petSize: petSize)
        let savedX = defaults.object(forKey: Self.battleAnchorXKey) as? Double
        let savedY = defaults.object(forKey: Self.battleAnchorYKey) as? Double
        let anchor = NSPoint(x: savedX ?? (defaults.object(forKey: Self.originXKey) as? Double ?? fallback.x) + petSize,
                             y: savedY ?? defaults.object(forKey: Self.originYKey) as? Double ?? fallback.y)
        var target = NSRect(x: anchor.x - size.width, y: anchor.y, width: size.width, height: size.height)
        let screen = NSScreen.screens.first { $0.visibleFrame.intersects(target) } ?? NSScreen.main
        if let screen {
            target = FloatingTimerMetrics.constrained(target, to: screen.visibleFrame)
        }
        if savedX == nil || savedY == nil {
            defaults.set(target.maxX, forKey: Self.battleAnchorXKey)
            defaults.set(target.minY, forKey: Self.battleAnchorYKey)
        }
        if let screen, let tuckEdge {
            target = Self.edgeFrame(expanded: target, edge: tuckEdge, visible: screen.visibleFrame,
                                    petSize: size.height, tucked: displayedTuckEdge != nil,
                                    peekWidth: folded ? size.width / 2 : Self.edgePeekWidth)
        }
        if folded {
            let icon = AnyView(GameBoyIcon(scale: scale, tuckedEdge: displayedTuckEdge).environment(session))
            let hosting = p.contentView as? PetHostingView ?? PetHostingView(rootView: icon)
            hosting.rootView = icon
            hosting.hasIsland = false
            hosting.petSize = size.width
            hosting.tuckedEdge = displayedTuckEdge
            hosting.onOpenPopover = { [weak self] in self?.expandBattleWindow() }
            hosting.onAccessibilityPress = hosting.onOpenPopover
            hosting.clockSession = session
            hosting.openMenuTitle = "Open Battle window"
            hosting.movementLocked = { [weak self] in self?.store.floatingTimerPinned ?? false }
            hosting.onOpenToday = onOpenToday
            hosting.onNewIssue = onNewIssue
            hosting.canCreateIssue = { [weak self] in self?.store.canComposeLinearIssue ?? false }
            hosting.onHide = onHide
            hosting.contextMenuProvider = { [weak self] in self?.displayMenu.makeMenu() ?? NSMenu() }
            hosting.onHoverChange = { [weak self] in self?.hoverChanged($0) }
            hosting.onToggleTuck = { [weak self] in self?.toggleEdgeTucking() }
            hosting.tuckEnabled = { [weak self] in self?.tuckEdge != nil }
            hosting.languageProvider = { [weak self] in self?.companion.language ?? .en }
            hosting.onMenuTrackingChange = { [weak self] tracking in
                guard let self else { return }
                self.menuTracking = tracking
                if !tracking { self.hoverChanged(self.panel?.frame.contains(NSEvent.mouseLocation) == true) }
            }
            hosting.toolTip = "Open Battle window · Right-click to tuck at screen edge"
            hosting.setAccessibilityElement(true)
            hosting.setAccessibilityRole(.button)
            hosting.setAccessibilityLabel("Open Battle window")
            hosting.wantsLayer = true; hosting.layer?.masksToBounds = true
            if p.contentView !== hosting {
                p.contentView = hosting
                p.makeFirstResponder(hosting)
            }
        } else if let battle {
            battle.content.gameSize = size
            battle.content.tuckedRight = displayedTuckEdge == .right
            if p.contentView !== battle.content {
                p.contentView = battle.content
                p.makeFirstResponder(battle.webView)
            }
        }
        if Self.shouldApplyPanelFrame(current: p.frame, target: target, isVisible: p.isVisible) {
            applyingFrame = true; p.setFrame(target, display: true); applyingFrame = false
        }
        if !p.isVisible { p.orderFrontRegardless() }
        if !folded, battleInput, !textInputArmed {
            NSApp.activate(ignoringOtherApps: true)
            p.makeKeyAndOrderFront(nil)
        }
        textInputArmed = !folded && battleInput
        if !folded {
            battle?.setPublishing(true)
            battle?.publish()
        }
    }

    private func expandBattleWindow() {
        tuckTask?.cancel()
        edgeRevealed = tuckEdge != nil
        store.battleWindowFolded = false
        sync()
    }

    private func show() {
        if store.floatingPetStyle == .battle { showBattle(); return }
        if battle != nil {
            battle?.stop(); battle = nil; panel?.contentView = nil
            battleHeight = 180; battleInput = false
        }
        let p = panel ?? makePanel()
        panel = p
        p.level = store.floatingDisplaysFloatOnTop ? .floating : .normal
        let wantAnimated = Self.shouldAnimate(lowPower: ProcessInfo.processInfo.isLowPowerModeEnabled)
        p.title = "PokeTasks · Floating companion"
        if p.contentView == nil || builtAnimated != wantAnimated {
            let hosting = PetHostingView(rootView: petView(animated: wantAnimated))
            hosting.onOpenPopover = onOpenPopover
            hosting.onHide = onHide
            hosting.contextMenuProvider = { [weak self] in self?.displayMenu.makeMenu() ?? NSMenu() }
            hosting.onOpenToday = onOpenToday
            hosting.onNewIssue = onNewIssue
            hosting.canCreateIssue = { [weak self] in self?.store.canComposeLinearIssue ?? false }
            hosting.tuckEnabled = { [weak self] in self?.tuckEdge != nil }
            hosting.onToggleTuck = { [weak self] in self?.toggleEdgeTucking() }
            hosting.onMenuTrackingChange = { [weak self] tracking in
                guard let self else { return }
                self.menuTracking = tracking
                self.tuckTask?.cancel()
                if tracking { self.hideHoverCallout() }
                else { self.hoverChanged(self.panel?.frame.contains(NSEvent.mouseLocation) == true) }
            }
            hosting.languageProvider = { [weak self] in self?.companion.language ?? .systemDefault }
            hosting.petSize = CGFloat(store.floatingPetSize)
            hosting.hasIsland = true
            hosting.onHoverChange = { [weak self] in self?.hoverChanged($0) }
            hosting.tuckedEdge = displayedTuckEdge
            p.contentView = hosting
            builtAnimated = wantAnimated
        }
        if let hosting = p.contentView as? PetHostingView {
            if hosting.tuckedEdge != displayedTuckEdge {
                hosting.tuckedEdge = displayedTuckEdge
                hosting.rootView = petView(animated: wantAnimated)
            }
            hosting.toolTip = displayedTuckEdge == nil ? currentHoverText() : L(companion.language).floatingPetReveal
            hosting.petSize = CGFloat(store.floatingPetSize)
            hosting.hasIsland = displayedTuckEdge == nil
            hosting.setAccessibilityElement(displayedTuckEdge != nil)
            if displayedTuckEdge != nil {
                hosting.setAccessibilityRole(.button)
                hosting.setAccessibilityLabel(L(companion.language).floatingPetReveal)
            }
            hosting.onOpenToday = onOpenToday
            hosting.onNewIssue = onNewIssue
            hosting.canCreateIssue = { [weak self] in self?.store.canComposeLinearIssue ?? false }
        }
        if let hosting = p.contentView as? PetHostingView {
            hosting.onAccessibilityPress = nil
            hosting.clockSession = nil
            hosting.openMenuTitle = nil
            hosting.movementLocked = { false }
        }
        let petSize = CGFloat(store.floatingPetSize)
        let target = targetFrame(petSize: petSize, showingBubble: store.currentSpeechBubble != nil)
        if Self.shouldApplyPanelFrame(current: p.frame, target: target, isVisible: p.isVisible) {
            applyingFrame = tuckEdge != nil
            p.setFrame(target, display: true)
            applyingFrame = false
        }
        if !p.isVisible { p.orderFrontRegardless() }
        let needsKey = !store.floatingTimerDetached && Self.overlayNeedsKeyWindow(
            composingNote: session.isComposingNote, prompt: session.prompt)
        if needsKey, !textInputArmed {
            // Accessory apps ignore cooperative activate; same trap as the popover.
            NSApp.activate(ignoringOtherApps: true)
            p.makeKeyAndOrderFront(nil)
        }
        textInputArmed = needsKey
        positionXPReward()
        if hoverPanel?.isVisible == true { showHoverCallout() }
    }

    private func hide() {
        battle?.stop(); battle = nil
        battleHeight = 180; battleInput = false
        tuckTask?.cancel()
        edgeRevealed = false
        hideHoverCallout()
        showXPReward(nil)
        textInputArmed = false
        guard let p = panel else { return }
        p.orderOut(nil)
        p.contentView = nil
        builtAnimated = nil
    }

    private func updateHoverTooltip() {
        guard store.floatingPetStyle != .battle else { return }
        if let hosting = panel?.contentView as? PetHostingView {
            hosting.toolTip = displayedTuckEdge == nil ? currentHoverText() : L(companion.language).floatingPetReveal
        }
        if hoverPanel?.isVisible == true { showHoverCallout() }
    }

    private func currentHoverText() -> String {
        FloatingPetView.hoverTooltip(
            todayTokens: store.todayTotalTokens,
            limitUtilization: store.highestLimitUtilization,
            mode: store.limitDisplayMode,
            l: L(companion.language))
    }

    private func showHoverCallout() {
        guard store.floatingPetStyle != .battle, displayedTuckEdge == nil, let pet = panel, pet.isVisible else { return }
        // Don't cover an active limit bubble — the speech bubble is the priority surface.
        if store.currentSpeechBubble != nil || session.prompt != .none
            || session.forfeitPrompt != nil || session.resetPrompt
        { hideHoverCallout(); return }
        let text = currentHoverText()
        let appearance = NSApp.effectiveAppearance
        let colors = Self.hoverCalloutColors(for: appearance)
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 11)
        label.textColor = colors.text
        label.backgroundColor = .clear
        label.drawsBackground = false
        label.sizeToFit()

        let pad: CGFloat = 8
        let size = NSSize(width: label.bounds.width + pad * 2,
                          height: label.bounds.height + pad * 2)
        let container = NSView(frame: NSRect(origin: .zero, size: size))
        container.appearance = appearance
        container.wantsLayer = true
        container.layer?.backgroundColor = colors.background.cgColor
        container.layer?.cornerRadius = 8
        container.layer?.borderWidth = 0.5
        container.layer?.borderColor = colors.border.cgColor
        label.frame.origin = NSPoint(x: pad, y: pad)
        container.addSubview(label)

        let hp = hoverPanel ?? makeHoverPanel()
        hoverPanel = hp
        hp.level = store.floatingDisplaysFloatOnTop ? .floating : .normal
        hp.appearance = appearance
        hp.contentView = container
        hp.setContentSize(size)
        let petFrame = pet.frame
        hp.setFrameOrigin(NSPoint(x: petFrame.midX - size.width / 2, y: petFrame.maxY + 6))
        hp.orderFrontRegardless()
    }

    private func hideHoverCallout() {
        hoverPanel?.orderOut(nil)
        hoverPanel?.contentView = nil
    }

    private func makeHoverPanel() -> NSPanel {
        let p = NSPanel(contentRect: .zero,
                        styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.level = store.floatingDisplaysFloatOnTop ? .floating : .normal
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.hidesOnDeactivate = false
        p.isReleasedWhenClosed = false
        p.ignoresMouseEvents = true
        p.animationBehavior = .none
        return p
    }

    private var overlayConfirm: OverlayConfirmPrompt {
        if session.forfeitPrompt != nil { return .forfeit }
        if session.resetPrompt { return .reset }
        return .none
    }

    private func overlayPanelSize(petSize: CGFloat, showingBubble: Bool) -> NSSize {
        if store.floatingTimerDetached {
            return Self.panelSize(petSize: petSize, showingBubble: showingBubble,
                                  hasIsland: false, prompt: .none, showsTimerToggle: !session.isActive,
                                  timerScale: CGFloat(store.floatingTimerScale))
        }
        return Self.panelSize(petSize: petSize, showingBubble: showingBubble,
                       hasIsland: session.isActive, prompt: session.prompt,
                       composingNote: session.isComposingNote,
                       confirm: overlayConfirm,
                       islandFolded: store.floatingPetIslandFolded,
                       showsTimerToggle: true,
                       setupIsland: session.pomodoroSetupOpen && !session.isActive,
                       timerWidth: CGFloat(store.floatingTimerWidth),
                       timerScale: CGFloat(store.floatingTimerScale))
    }

    /// The left resize rail follows the pointer while the right edge and pet stay
    /// anchored. Persist that anchor before observation runs another sync.
    func resizeTimer(to proposedWidth: CGFloat, keepingRightEdge anchor: NSPoint) {
        guard let panel = store.floatingTimerDetached ? timerPanel : panel,
              session.isActive || session.pomodoroSetupOpen,
              store.floatingTimerDetached || !store.floatingPetIslandFolded else { return }
        let scale = CGFloat(store.floatingTimerScale)
        let extraWidth = panel.frame.width - CGFloat(store.floatingTimerWidth) * scale
        let screen = NSScreen.screens.first { $0.visibleFrame.intersects(panel.frame) } ?? NSScreen.main
        let available = screen.map { (anchor.x - $0.visibleFrame.minX - extraWidth) / scale } ?? FloatingTimerMetrics.maximumWidth
        store.floatingTimerWidth = Double(FloatingTimerMetrics.width(proposedWidth, available: available))
        let size = store.floatingTimerDetached ? detachedTimerSize
            : overlayPanelSize(petSize: CGFloat(store.floatingPetSize), showingBubble: store.currentSpeechBubble != nil)
        let frame = NSRect(x: anchor.x - size.width, y: anchor.y, width: size.width, height: size.height)
        applyingFrame = true
        panel.setFrame(screen.map { FloatingTimerMetrics.constrained(frame, to: $0.visibleFrame) } ?? frame, display: true)
        applyingFrame = false
        if store.floatingTimerDetached { persistTimerAnchor() }
        else { persistPetOrigin() }
    }

    private func targetFrame(petSize: CGFloat, showingBubble: Bool) -> NSRect {
        let size = overlayPanelSize(petSize: petSize, showingBubble: showingBubble)
        let petOrigin: NSPoint
        if let x = defaults.object(forKey: Self.originXKey) as? Double,
           let y = defaults.object(forKey: Self.originYKey) as? Double {
            petOrigin = NSPoint(x: x, y: y)
        } else {
            petOrigin = Self.defaultPetOrigin(petSize: petSize)
        }
        var frame = NSRect(origin: Self.panelOrigin(petOrigin: petOrigin, petSize: petSize,
                                                    panelSize: size, hasIsland: true),
                           size: size)
        if !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(frame) }) {
            let fallbackPet = Self.defaultPetOrigin(petSize: petSize)
            frame.origin = Self.panelOrigin(petOrigin: fallbackPet, petSize: petSize,
                                            panelSize: size, hasIsland: true)
        }
        if let screen = NSScreen.screens.first(where: { $0.visibleFrame.intersects(frame) }) {
            frame = FloatingTimerMetrics.constrained(frame, to: screen.visibleFrame)
            if let tuckEdge {
                frame = Self.edgeFrame(expanded: frame, edge: tuckEdge, visible: screen.visibleFrame,
                                       petSize: petSize, tucked: displayedTuckEdge != nil)
            }
        }
        return frame
    }

    private static func defaultPetOrigin(petSize: CGFloat) -> NSPoint {
        guard let visible = NSScreen.main?.visibleFrame else { return NSPoint(x: 120, y: 120) }
        return NSPoint(x: visible.maxX - petSize - 24, y: visible.minY + 24)
    }

    private func makePanel() -> FloatingPetPanel {
        let p = FloatingPetPanel(contentRect: NSRect(x: 0, y: 0, width: 200, height: 200),
                                 styleMask: [.borderless, .nonactivatingPanel],
                                 backing: .buffered, defer: false)
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.level = store.floatingDisplaysFloatOnTop ? .floating : .normal
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.isMovableByWindowBackground = false
        p.hidesOnDeactivate = false
        p.isReleasedWhenClosed = false
        p.becomesKeyOnlyIfNeeded = true
        p.allowsToolTipsWhenApplicationIsInactive = true
        p.animationBehavior = .none
        p.contextMenuProvider = { [weak self] in self?.displayMenu.makeMenu() ?? NSMenu() }
        p.onMenuTrackingChange = { [weak self, weak p] tracking in
            guard let self else { return }
            if let hosting = p?.contentView as? PetHostingView {
                hosting.onMenuTrackingChange?(tracking)
                return
            }
            self.menuTracking = tracking
            self.tuckTask?.cancel()
            if tracking { self.hideHoverCallout() }
            else { self.hoverChanged(self.panel?.frame.contains(NSEvent.mouseLocation) == true) }
        }
        p.delegate = self
        return p
    }

    func windowDidMove(_ notification: Notification) {
        guard !applyingFrame else { return }
        if let moved = notification.object as? NSWindow, moved === timerPanel {
            persistTimerAnchor()
            return
        }
        // Both the pet drag and timer drag rail route through this delegate.
        if tuckEdge != nil {
            tuckEdge = nil
            defaults.removeObject(forKey: Self.tuckEdgeKey)
            tuckTask?.cancel()
        }
        persistPetOrigin()
    }

    private func persistPetOrigin() {
        guard tuckEdge == nil, let p = panel, p.isVisible else { return }
        if store.floatingPetStyle == .battle {
            defaults.set(p.frame.maxX, forKey: Self.battleAnchorXKey)
            defaults.set(p.frame.minY, forKey: Self.battleAnchorYKey)
        } else {
            let petSize = CGFloat(store.floatingPetSize)
            let pet = Self.petOrigin(panelOrigin: p.frame.origin, petSize: petSize,
                                     panelSize: p.frame.size, hasIsland: true)
            defaults.set(Double(pet.x), forKey: Self.originXKey)
            defaults.set(Double(pet.y), forKey: Self.originYKey)
        }
        positionXPReward()
        if hoverPanel?.isVisible == true { showHoverCallout() }
    }
}

final class PetHostingView: NSHostingView<AnyView> {
    var contextMenuProvider: (() -> NSMenu)?
    var onOpenPopover: (() -> Void)?
    var onAccessibilityPress: (() -> Void)?
    var clockSession: FocusSessionStore?
    var openMenuTitle: String?
    var movementLocked: () -> Bool = { false }
    var onHide: (() -> Void)?
    var onOpenToday: (() -> Void)?
    var onNewIssue: (() -> Void)?
    var canCreateIssue: () -> Bool = { false }
    var onHoverChange: ((Bool) -> Void)?
    var onToggleTuck: (() -> Void)?
    var onMenuTrackingChange: ((Bool) -> Void)?
    var tuckEnabled: () -> Bool = { false }
    var tuckedEdge: FloatingPetController.TuckEdge?
    var languageProvider: () -> AppLanguage = { .systemDefault }
    var hasIsland = false
    var petSize: CGFloat = 96

    private var mouseDownScreen: NSPoint?
    private var originAtDown: NSPoint?
    private var didDrag = false
    private var forwardingToSwiftUI = false
    private var petHoverTrackingArea: NSTrackingArea?

    override var mouseDownCanMoveWindow: Bool { false }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func menu(for event: NSEvent) -> NSMenu? {
        if let contextMenuProvider { return contextMenuProvider() }
        return onAccessibilityPress == nil ? super.menu(for: event) : makeContextMenu()
    }

    override func accessibilityRole() -> NSAccessibility.Role? {
        onAccessibilityPress == nil ? super.accessibilityRole() : .button
    }

    override func accessibilityValue() -> Any? {
        guard let clockSession else { return super.accessibilityValue() }
        return clockSession.isActive ? clockSession.clockDisplay().text : "No active timer"
    }

    override func accessibilityPerformPress() -> Bool {
        if let onAccessibilityPress { onAccessibilityPress(); return true }
        guard tuckedEdge != nil else { return super.accessibilityPerformPress() }
        onHoverChange?(true)
        return true
    }

    static func isClick(from start: NSPoint, to end: NSPoint,
                        thresholdSquared: CGFloat = FloatingPetController.clickThresholdSquared) -> Bool {
        FloatingPetController.isClick(from: start, to: end, thresholdSquared: thresholdSquared)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        // Keep SwiftUI's own tracking areas: the strip and its buttons use onHover.
        if let petHoverTrackingArea { removeTrackingArea(petHoverTrackingArea) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil)
        petHoverTrackingArea = area
        addTrackingArea(area)
    }

    override func mouseEntered(with event: NSEvent) {
        if event.trackingArea === petHoverTrackingArea { onHoverChange?(true) }
        else { super.mouseEntered(with: event) }
    }
    override func mouseExited(with event: NSEvent) {
        if event.trackingArea === petHoverTrackingArea { onHoverChange?(false) }
        else { super.mouseExited(with: event) }
    }

    private var spriteRect: NSRect {
        NSRect(x: bounds.width - petSize, y: 0, width: petSize, height: petSize)
    }

    private func isInteractiveIsland(_ point: NSPoint) -> Bool {
        hasIsland && point.x < bounds.width - petSize
    }

    override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.control) {
            showContextMenu(event)
            return
        }
        let local = convert(event.locationInWindow, from: nil)
        if isInteractiveIsland(local) {
            forwardingToSwiftUI = true
            super.mouseDown(with: event)
            return
        }
        forwardingToSwiftUI = false
        mouseDownScreen = NSEvent.mouseLocation
        originAtDown = window?.frame.origin
        didDrag = false
    }

    override func mouseDragged(with event: NSEvent) {
        if forwardingToSwiftUI {
            super.mouseDragged(with: event)
            return
        }
        guard !movementLocked(), let window, let start = mouseDownScreen, let origin = originAtDown else { return }
        let now = NSEvent.mouseLocation
        if !Self.isClick(from: start, to: now) { didDrag = true }
        window.setFrameOrigin(NSPoint(x: origin.x + (now.x - start.x),
                                      y: origin.y + (now.y - start.y)))
    }

    override func mouseUp(with event: NSEvent) {
        if forwardingToSwiftUI {
            forwardingToSwiftUI = false
            super.mouseUp(with: event)
            return
        }
        defer {
            mouseDownScreen = nil
            originAtDown = nil
            didDrag = false
        }
        guard !didDrag, let start = mouseDownScreen else { return }
        if Self.isClick(from: start, to: NSEvent.mouseLocation) {
            onOpenPopover?()
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        showContextMenu(event)
    }

    private func showContextMenu(_ event: NSEvent) {
        onMenuTrackingChange?(true)
        defer { onMenuTrackingChange?(false) }
        NSApp.activate(ignoringOtherApps: true)
        NSMenu.popUpContextMenu(makeContextMenu(), with: event, for: self)
    }

    func makeContextMenu() -> NSMenu {
        if let contextMenuProvider { return contextMenuProvider() }
        let l = L(languageProvider())
        let menu = NSMenu(title: "")
        menu.autoenablesItems = false
        let open = menu.addItem(withTitle: openMenuTitle ?? l.floatingPetMenuOpen,
                                action: #selector(handleOpen(_:)), keyEquivalent: "")
        open.target = self
        open.isEnabled = true
        let today = menu.addItem(withTitle: l.todayDeskMenuOpen,
                                 action: #selector(handleOpenToday(_:)), keyEquivalent: "")
        today.target = self
        today.isEnabled = true
        let create = menu.addItem(withTitle: l.newLinearIssue,
                                  action: #selector(handleNewIssue(_:)), keyEquivalent: "")
        create.target = self
        create.isEnabled = canCreateIssue()
        menu.addItem(.separator())
        let tuck = menu.addItem(withTitle: l.floatingPetMenuTuck,
                                action: #selector(handleToggleTuck(_:)), keyEquivalent: "")
        tuck.target = self
        tuck.state = tuckEnabled() ? .on : .off
        tuck.isEnabled = true
        let hide = menu.addItem(withTitle: l.floatingPetMenuHide,
                                action: #selector(handleHide(_:)), keyEquivalent: "")
        hide.target = self
        hide.isEnabled = true
        return menu
    }

    @objc func handleOpen(_ sender: Any?) { onOpenPopover?() }
    @objc func handleOpenToday(_ sender: Any?) { onOpenToday?() }
    @objc func handleNewIssue(_ sender: Any?) { onNewIssue?() }
    @objc func handleHide(_ sender: Any?) { onHide?() }
    @objc func handleToggleTuck(_ sender: Any?) { onToggleTuck?() }
}

@MainActor
struct FloatingPetView: View {
    var animated: Bool = true
    var tuckedEdge: FloatingPetController.TuckEdge?
    var onResizeTimer: (CGFloat, NSPoint) -> Void = { _, _ in }
    @Environment(UsageStore.self) private var store
    @Environment(CompanionStore.self) private var companion
    @Environment(FocusSessionStore.self) private var session

    var body: some View {
        if let tuckedEdge {
            sprite
                // A slice beside the center stays visible even for narrow or padded sprites.
                .offset(x: (tuckedEdge == .right ? 1 : -1) * FloatingPetController.edgePeekWidth / 2)
                .frame(width: FloatingPetController.edgePeekWidth)
                .clipped()
        } else {
            expandedContent
        }
    }

    private var sprite: some View {
        let size = CGFloat(store.floatingPetSize)
        let subject = companion.representativeSubject
        return SpriteView(speciesID: subject.speciesID, size: subject.speciesID == nil ? size * 0.5 : size, animated: animated,
                          shiny: subject.isShiny, minFrameDelay: store.animationQuality.frameFloor,
                          unownForm: subject.unownForm)
            .frame(width: size, height: size)
    }

    private var expandedContent: some View {
        VStack(spacing: 8) {
            if let bubble = store.currentSpeechBubble {
                SpeechBubbleView(bubble: bubble)
                    .transition(.scale(scale: 0.8, anchor: .bottom).combined(with: .opacity))
                    .zIndex(1)
            }

            HStack(alignment: .bottom, spacing: FloatingPetController.islandGap * CGFloat(store.floatingTimerScale)) {
                if !store.floatingTimerDetached || !session.isActive {
                    timerContent
                        .scaledFloatingTimer(size: timerContentSize, scale: CGFloat(store.floatingTimerScale))
                }
                sprite.zIndex(0)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .animation(animated ? .spring(response: 0.3, dampingFraction: 0.7) : nil,
                   value: store.currentSpeechBubble)
    }

    private var timerContentSize: NSSize {
        let attached = !store.floatingTimerDetached
        let size = FloatingPetController.panelSize(petSize: 0, showingBubble: false,
            hasIsland: attached && session.isActive, prompt: attached ? session.prompt : .none,
            composingNote: attached && session.isComposingNote,
            confirm: !attached ? .none : session.forfeitPrompt != nil ? .forfeit : session.resetPrompt ? .reset : .none,
            islandFolded: store.floatingPetIslandFolded, showsTimerToggle: true,
            setupIsland: attached && session.pomodoroSetupOpen && !session.isActive,
            timerWidth: CGFloat(store.floatingTimerWidth))
        return NSSize(width: size.width - FloatingPetController.islandGap, height: size.height)
    }

    private var timerContent: some View {
        HStack(alignment: .bottom, spacing: FloatingPetController.islandGap) {
            if !store.floatingTimerDetached && (session.isActive || session.pomodoroSetupOpen) {
                if showsIslandColumn {
                    SessionIslandView(onResizeTimer: onResizeTimer)
                }
                if store.floatingPetIslandFolded && session.isActive {
                    FloatingCompactTimer()
                }
            }
            if (!store.floatingTimerDetached && !store.floatingPetIslandFolded) || !session.isActive {
                islandFoldChevron
            }
        }
    }

    private var showsIslandColumn: Bool {
        if session.pomodoroSetupOpen { return true }
        if !store.floatingPetIslandFolded { return true }
        return session.forfeitPrompt != nil
            || session.resetPrompt
            || session.prompt != .none
            || session.isComposingNote
    }

    private var islandFoldChevron: some View {
        let l = companion.l
        let setup = session.pomodoroSetupOpen
        let folded = store.floatingPetIslandFolded || (!session.isActive && !setup)
        let help: String = {
            if session.isActive { return folded ? l.expandTimer : l.collapseTimer }
            if setup { return l.cancel }
            return l.pomoTimer
        }()
        let symbol = session.isActive ? (folded ? "chevron.left" : "chevron.right")
            : setup ? "xmark" : "timer"
        return FloatingPetTimerToggle(symbol: symbol, label: help) {
            if session.isActive {
                store.floatingPetIslandFolded.toggle()
            } else if setup {
                session.cancelPomodoroSetup()
            } else {
                session.openPomodoroSetup()
                store.floatingPetIslandFolded = false
            }
        }
    }

    static func hoverTooltip(todayTokens: Int, limitUtilization: Double?,
                             mode: UsageStore.LimitDisplayMode, l: L) -> String {
        let usage = TokenFormatter.grouped(todayTokens)
        if let pct = limitUtilization {
            let text = TokenFormatter.percent(UsageStore.displayPercent(pct, mode: mode))
            return l.floatingPetHoverWithLimit(usage, mode == .remaining ? l.percentRemaining(text) : text)
        }
        return l.floatingPetHoverTokensOnly(usage)
    }
}

/// Transient speech bubble. Width is capped so copy wraps instead of clipping the panel.
@MainActor
private struct SpeechBubbleView: View {
    let bubble: UsageStore.SpeechBubble

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(bubble.title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(bubble.isCritical ? .red : .primary)
            Text(bubble.body)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .lineLimit(FloatingPetController.bubbleBodyLineLimit)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: FloatingPetController.bubbleContentWidth, alignment: .leading)
        .padding(.horizontal, FloatingPetController.bubbleHorizontalPadding)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))
                .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
        )
        .overlay(
            Path { path in
                path.move(to: CGPoint(x: 10, y: 0))
                path.addLine(to: CGPoint(x: 20, y: 0))
                path.addLine(to: CGPoint(x: 15, y: 6))
                path.closeSubpath()
            }
            .fill(Color(nsColor: .windowBackgroundColor))
            .offset(y: 5),
            alignment: .bottom
        )
        .padding(.bottom, 6)
    }
}
