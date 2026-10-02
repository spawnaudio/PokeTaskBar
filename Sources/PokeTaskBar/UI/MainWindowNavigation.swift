import SwiftUI

enum MainWindowPage: String, CaseIterable, Identifiable {
    case today, focus, issues, projects, initiatives, insights, collection, usage, settings
    static var visiblePages: [Self] { allCases.filter { $0 != .initiatives } }
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .today: "house"
        case .focus: "target"
        case .issues: "list.bullet.rectangle"
        case .projects: "folder"
        case .initiatives: "flag"
        case .insights: "chart.xyaxis.line"
        case .collection: "square.grid.2x2"
        case .usage: "chart.bar"
        case .settings: "gearshape"
        }
    }
    func title(_ l: L) -> String {
        switch self {
        case .today: l.todayDeskWindowTitle
        case .focus: l.focusTab
        case .issues: l.linearIssuesTab
        case .projects: l.linearProjectsTab
        case .initiatives: l.linearInitiativesTab
        case .insights: "Insights"
        case .collection: l.collection
        case .usage: l.usageTab
        case .settings: l.settings
        }
    }
}

/// Window navigation survives closing/reopening; it never owns a second focus session.
@MainActor @Observable
final class MainWindowNavigation {
    private(set) var page: MainWindowPage = .today
    private var backStack: [MainWindowPage] = []
    private var forwardStack: [MainWindowPage] = []
    let content = PopoverNavigation()
    var search = ""
    var projectFilter: String?
    var selectedProjectID: String?
    var selectedSpeciesID: Int?
    var selectedRecordID: String?
    var selectedStorageID: String?
    var selectedItem: ItemKind = .rareCandy
    var workspaceQueries: [MainWindowPage: String] = [:]
    var workspaceScrollIDs: [MainWindowPage: String] = [:]
    var projectExpansion: [String: Bool] = [:]
    var issueMinimization: [String: Bool] = [:]
    var issueExpansion: [String: Bool] = [:]
    var planningIssueFolded: Set<PlanningGroup> = []
    var issuesTab: LinearIssuesTab = .inProgress
    var issueSorts: [LinearIssuesTab: LinearIssueSort] = [:]
    var projectStatus = ""
    var projectSort: LinearProjectSort = .name
    var initiativeSort: LinearInitiativeSort = .name
    var workspaceSecondaryTabs: [MainWindowPage: Bool] = [:]
    var canGoBack: Bool { !backStack.isEmpty }
    var canGoForward: Bool { !forwardStack.isEmpty }

    func select(_ next: MainWindowPage) {
        let next: MainWindowPage = next == .initiatives ? .projects : next
        guard next != page else { return }
        backStack.append(page)
        forwardStack.removeAll()
        reveal(next)
    }
    func back() {
        guard let next = backStack.popLast() else { return }
        forwardStack.append(page)
        reveal(next)
    }
    func forward() {
        guard let next = forwardStack.popLast() else { return }
        backStack.append(page)
        reveal(next)
    }
    func showProjectIssues(_ project: LinearProjectSummary, tab: LinearIssuesTab? = nil) {
        projectFilter = project.id
        search = ""
        workspaceQueries[.issues] = ""
        issuesTab = tab ?? (project.issues.contains(where: LinearClient.isInProgressIssue) ? .inProgress
            : project.issues.contains(where: LinearClient.isTodoIssue) ? .todo
            : project.issues.contains(where: LinearClient.isPlannedIssue) ? .planned : .inProgress)
        select(.issues)
    }
    private func reveal(_ next: MainWindowPage) {
        page = next
        content.showSettings = next == .settings
        switch next {
        case .focus: content.tab = .focus
        case .issues, .projects, .initiatives: content.tab = .linear
        case .collection: content.tab = .collection
        case .usage: content.tab = .usage
        default: break
        }
    }
}

struct MainWindowTheme {
    let scheme: ColorScheme
    var shell: Color { value(0xEFF0F2, 0x17181B) }
    var canvas: Color { value(0xF8F8FA, 0x1F2023) }
    var surface: Color { value(0xFFFFFF, 0x292A2E) }
    var border: Color { value(0xDDE0E6, 0x383A40) }
    var selected: Color { value(0xE0E1E4, 0x303138) }
    var text: Color { value(0x242528, 0xF1F1F3) }
    var secondary: Color { value(0x696B72, 0xA2A4AD) }
    private func value(_ light: UInt32, _ dark: UInt32) -> Color {
        let hex = scheme == .dark ? dark : light
        return Color(.sRGB, red: Double((hex >> 16) & 255) / 255,
                     green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, opacity: 1)
    }
}

private struct MainWindowChromeKey: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
    var mainWindowChrome: Bool {
        get { self[MainWindowChromeKey.self] }
        set { self[MainWindowChromeKey.self] = newValue }
    }
}

@MainActor
struct MainWindowCard: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    func body(content: Content) -> some View {
        content.padding(20)
            .background(MainWindowTheme(scheme: scheme).surface,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .mainWindowBorder(cornerRadius: 12)
    }
}

@MainActor
private struct MainWindowBorder: ViewModifier {
    let cornerRadius: CGFloat
    @Environment(\.colorScheme) private var scheme
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        let theme = MainWindowTheme(scheme: scheme)
        content.overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(contrast == .increased ? theme.secondary : theme.border, lineWidth: 1)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

extension View {
    func roundedScrollViewport() -> some View {
        clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    func proximityUtility() -> some View { modifier(ProximityUtility()) }
    func mainWindowCard() -> some View { modifier(MainWindowCard()) }
    func mainWindowBorder(cornerRadius: CGFloat) -> some View {
        modifier(MainWindowBorder(cornerRadius: cornerRadius))
    }
}

@MainActor
private struct ProximityUtility: ViewModifier {
    @State private var hovering = false
    @FocusState private var focused: Bool
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func body(content: Content) -> some View {
        content.focused($focused)
            .opacity(hovering || focused || voiceOver ? 1 : 0)
            .frame(width: 36, height: 32).contentShape(Rectangle())
            .onHover { hovering = $0 }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: hovering || focused)
    }
}
