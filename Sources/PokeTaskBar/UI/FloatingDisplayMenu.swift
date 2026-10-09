import AppKit

/// One native menu for the pet, timer, Battle window and folded Game Boy.
@MainActor
final class FloatingDisplayMenu: NSObject {
    private let store: UsageStore
    var language: () -> AppLanguage = { .systemDefault }
    var onOpen: (() -> Void)?
    var onOpenToday: (() -> Void)?
    var onNewIssue: (() -> Void)?
    var onHide: (() -> Void)?
    var onToggleTuck: (() -> Void)?
    var tuckEnabled: () -> Bool = { false }

    init(store: UsageStore) { self.store = store }

    func makeMenu() -> NSMenu {
        let l = L(language())
        let menu = NSMenu()
        menu.autoenablesItems = false
        add(store.floatingPetStyle == .battle && store.battleWindowFolded
            ? "Open Battle window" : l.floatingPetMenuOpen, to: menu, action: #selector(open))
        add(l.todayDeskMenuOpen, to: menu, action: #selector(openToday))
        add(l.newLinearIssue, to: menu, action: #selector(newIssue)).isEnabled = store.canComposeLinearIssue
        menu.addItem(.separator())
        for (mode, title) in [(UsageStore.FloatingDisplayMode.battle, "Battle Window Mode"),
                              (.classic, "Classic Floating Pet Mode"),
                              (.timerOnly, "Floating Timer Only Mode")] {
            let item = add(title, to: menu, action: #selector(selectMode(_:)))
            item.tag = mode.rawValue
            item.state = store.floatingDisplayMode == mode ? .on : .off
        }
        menu.addItem(.separator())
        switch store.floatingDisplayMode {
        case .battle:
            addSize("Battle Window / Game Boy Size", value: store.battleWindowScale,
                    range: FloatingTimerMetrics.scaleRange, step: 0.05, suffix: "%", multiplier: 100,
                    to: menu) { [weak store] in store?.battleWindowScale = $0 }
        case .classic:
            addSize("Pet Size", value: store.floatingPetSize, range: 48...384, step: 8,
                    suffix: "px", multiplier: 1, to: menu) { [weak store] in store?.floatingPetSize = $0 }
            addTimerSize(to: menu)
        case .timerOnly:
            addTimerSize(to: menu)
        }
        menu.addItem(.separator())
        add("Float on Top", to: menu, action: #selector(toggleFloatOnTop)).state =
            store.floatingDisplaysFloatOnTop ? .on : .off
        if store.floatingPetEnabled {
            let tuck = add(l.floatingPetMenuTuck, to: menu, action: #selector(toggleTuck))
            tuck.state = tuckEnabled() ? .on : .off
        }
        add(store.floatingDisplayMode == .timerOnly ? "Turn off floating timer" : l.floatingPetMenuHide,
            to: menu, action: #selector(hide))
        return menu
    }

    private func addTimerSize(to menu: NSMenu) {
        addSize("Floating Timer Size", value: store.floatingTimerScale,
                range: FloatingTimerMetrics.scaleRange, step: 0.05, suffix: "%", multiplier: 100,
                to: menu) { [weak store] in store?.floatingTimerScale = $0 }
    }

    @discardableResult
    private func add(_ title: String, to menu: NSMenu, action: Selector) -> NSMenuItem {
        let item = menu.addItem(withTitle: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    private func addSize(_ title: String, value: Double, range: ClosedRange<Double>, step: Double,
                         suffix: String, multiplier: Double, to menu: NSMenu,
                         onChange: @escaping (Double) -> Void) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.view = FloatingSizeMenuView(title: title, value: value, range: range, step: step,
                                         suffix: suffix, multiplier: multiplier, onChange: onChange)
        menu.addItem(item)
    }

    @objc private func selectMode(_ sender: NSMenuItem) {
        guard let mode = UsageStore.FloatingDisplayMode(rawValue: sender.tag) else { return }
        store.floatingDisplayMode = mode
    }
    @objc private func open() { onOpen?() }
    @objc private func openToday() { onOpenToday?() }
    @objc private func newIssue() { onNewIssue?() }
    @objc private func toggleTuck() { onToggleTuck?() }
    @objc private func toggleFloatOnTop() { store.floatingDisplaysFloatOnTop.toggle() }
    @objc private func hide() {
        if store.floatingDisplayMode == .timerOnly { store.floatingTimerDetached = false }
        else { store.floatingPetEnabled = false; onHide?() }
    }
}

@MainActor
final class FloatingSizeMenuView: NSView {
    let slider: NSSlider
    private let valueLabel = NSTextField(labelWithString: "")
    private let step: Double
    private let suffix: String
    private let multiplier: Double
    private let onChange: (Double) -> Void

    init(title: String, value: Double, range: ClosedRange<Double>, step: Double,
         suffix: String, multiplier: Double, onChange: @escaping (Double) -> Void) {
        self.step = step; self.suffix = suffix; self.multiplier = multiplier; self.onChange = onChange
        slider = NSSlider(value: value, minValue: range.lowerBound, maxValue: range.upperBound,
                          target: nil, action: nil)
        super.init(frame: NSRect(x: 0, y: 0, width: 292, height: 58))
        let label = NSTextField(labelWithString: title)
        label.font = .menuFont(ofSize: 12)
        label.frame = NSRect(x: 20, y: 34, width: 220, height: 18)
        valueLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        valueLabel.alignment = .right
        valueLabel.frame = NSRect(x: 242, y: 34, width: 40, height: 18)
        slider.frame = NSRect(x: 20, y: 7, width: 262, height: 24)
        slider.isContinuous = true
        slider.target = self; slider.action = #selector(handleSizeChange)
        slider.setAccessibilityLabel(title)
        addSubview(label); addSubview(valueLabel); addSubview(slider)
        updateValue()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func handleSizeChange() {
        slider.doubleValue = (slider.doubleValue / step).rounded() * step
        updateValue()
        onChange(slider.doubleValue)
    }
    private func updateValue() {
        let text = "\(Int((slider.doubleValue * multiplier).rounded()))\(suffix)"
        valueLabel.stringValue = text
        slider.setAccessibilityValue(text)
    }
}
