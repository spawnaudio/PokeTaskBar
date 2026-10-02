import AppKit
import SwiftUI

/// The same project card in the workspace list/grid, initiatives, and menu-bar panel.
@MainActor
struct LinearProjectCard: View {
    let project: LinearProjectSummary
    var hiddenIssueStatuses: Set<String> = []
    var issuesInitiallyMinimized = false
    var onViewIssues: (() -> Void)? = nil
    @Binding private var externalExpanded: Bool
    private var usesExternalExpansion: Bool
    let onPin: () -> Void
    @Environment(UsageStore.self) private var store
    @Environment(CompanionStore.self) private var companion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var localExpanded = false
    @State private var minimized = false
    @State private var hovering = false
    @State private var loading = false
    @State private var failed = false

    init(project: LinearProjectSummary, hiddenIssueStatuses: Set<String> = [], issuesInitiallyMinimized: Bool = false,
         onViewIssues: (() -> Void)? = nil, expansion: Binding<Bool>? = nil, onPin: @escaping () -> Void) {
        self.project = project
        self.hiddenIssueStatuses = hiddenIssueStatuses
        self.issuesInitiallyMinimized = issuesInitiallyMinimized
        self.onViewIssues = onViewIssues
        _externalExpanded = expansion ?? .constant(false)
        usesExternalExpansion = expansion != nil
        self.onPin = onPin
    }

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 10, style: .continuous) }
    private var l: L { companion.l }
    private var expanded: Bool {
        get { usesExternalExpansion ? externalExpanded : localExpanded }
        nonmutating set { if usesExternalExpansion { externalExpanded = newValue } else { localExpanded = newValue } }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            summary.padding(12)
                .background {
                    Button {
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.12)) {
                            if minimized { minimized = false } else { expanded.toggle() }
                        }
                    } label: {
                        Rectangle().fill(.clear).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(project.name)
                    .accessibilityValue(minimized ? "Minimized" : (expanded ? "Expanded" : "Collapsed"))
                }
            if expanded && !minimized {
                Divider().padding(.horizontal, 12)
                VStack(alignment: .leading, spacing: 8) {
                    if loading {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text(l.linearProjectLoadingIssues).font(.caption).foregroundStyle(.secondary)
                        }.padding(.top, 10)
                    } else if failed {
                        HStack {
                            Text(l.linearIssuesSyncFailed).font(.caption).foregroundStyle(.secondary)
                            Button(l.refreshNow) { Task { await loadIssues() } }.buttonStyle(.link)
                        }.padding(.top, 10)
                    }
                    if !project.issues.isEmpty || (!loading && !failed) {
                        let visible = LinearProjectIssueFilter.visible(project.issues, hiding: hiddenIssueStatuses)
                        if visible.isEmpty && !project.issues.isEmpty {
                            Text(l.linearProjectNoMatchingIssueStatuses)
                                .font(.caption).foregroundStyle(.secondary).padding(.top, 10)
                        } else {
                            LinearContainerIssuesView(issues: visible, nested: true,
                                parentProjectID: project.id,
                                includesClosed: project.issuesFullyLoaded,
                                initiallyMinimized: issuesInitiallyMinimized,
                                hiddenIssueStatuses: hiddenIssueStatuses, onPin: onPin)
                        }
                    }
                }.padding(.horizontal, 12).padding(.bottom, 12)
                .task(id: store.linearIssuesUpdatedAt) { await loadIssues() }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            shape.fill(colorScheme == .dark ? Color(red: 0.15, green: 0.155, blue: 0.16) : Color(nsColor: .controlBackgroundColor))
                .overlay { shape.fill(.primary.opacity(hovering || (expanded && !minimized) ? 0.025 : 0)) }
                .overlay { shape.strokeBorder(.primary.opacity(contrast == .increased ? 0.35 : 0.075), lineWidth: 1) }
        }
        .contentShape(shape)
        .onHover { hovering = $0 }
        .contextMenu {
            Button(expanded ? "Fold project" : "Unfold project") { expanded.toggle() }
            Button(minimized ? "Show details" : "Hide details") { minimized.toggle() }
            if let url = project.url { Link(l.linearOpenProject, destination: url) }
            if let onViewIssues { Button(l.linearIssuesTab, action: onViewIssues) }
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                if let identifier = project.identifier {
                    LinearIssueIDButton(identifier: identifier, url: project.url,
                                        style: .system(size: 12), padded: false)
                        .help(l.linearOpenProject)
                }
                Spacer(minLength: 4)
                if let health = project.health { healthIcon(health) }
                Image(systemName: statusSymbol)
                    .overlay {
                        if project.statusType == "started" {
                            Image(systemName: "clock").font(.system(size: 7))
                        }
                    }
                    .foregroundStyle(LinearCardColor.color(project.statusColor, fallback: .secondary))
                    .help(project.statusName ?? project.statusType ?? l.linearStatusUnknown)
                    .accessibilityLabel(project.statusName ?? project.statusType ?? l.linearStatusUnknown)
                if let priority = project.priority, priority > 0 {
                    Image(systemName: priority == 1 ? "exclamationmark.square.fill" : "cellularbars",
                          variableValue: priority == 1 ? nil : Double(5 - priority) / 3)
                        .foregroundStyle(priority == 1 ? Color.orange : .secondary)
                        .help(l.linearPriorityChip(priority)).accessibilityLabel(l.linearPriorityChip(priority))
                } else {
                    Text("---").foregroundStyle(.secondary).accessibilityLabel(l.linearPriorityChip(nil))
                }
                LinearCardAssignee(name: project.leadName, avatarURL: project.leadAvatarURL)
                if !project.isCompleted {
                    LinearContainerPinButton(isPinned: store.pinnedLinearProjectIDs.contains(project.id)) {
                        store.toggleLinearProjectPin(project)
                    }
                }
            }.font(.system(size: 13)).frame(minHeight: 18)

            HStack(alignment: .top, spacing: 7) {
                LinearProjectIcon(icon: project.icon, color: project.color, fallback: "square.dashed")
                Text(project.name).font(.system(size: 14))
                    .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                    .help(project.name)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .allowsHitTesting(false)
                LinearCardMinimizeButton(minimized: $minimized)
            }
            if !minimized {
                if let description = project.descriptionText, !description.isEmpty {
                    Text(description).font(.system(size: 13)).foregroundStyle(.secondary)
                        .lineSpacing(2).lineLimit(2).help(description)
                        .fixedSize(horizontal: false, vertical: true).allowsHitTesting(false)
                }
                metadata.padding(.top, 4).allowsHitTesting(false)
                HStack {
                    if let count = project.issueCount {
                        Text(l.linearProjectIssueCount(count))
                    } else if project.issuesFullyLoaded {
                        Text(l.linearProjectIssueCount(project.issues.count))
                    } else {
                        Text(l.linearProjectPreviewCount(project.issues.count))
                    }
                    Spacer()
                    if hovering || expanded {
                        Image(systemName: "chevron.down").font(.system(size: 9, weight: .medium))
                            .rotationEffect(.degrees(expanded ? 180 : 0))
                    }
                }.font(.system(size: 12)).foregroundStyle(.secondary).padding(.top, 3).allowsHitTesting(false)
            }
        }
    }

    private var metadata: some View {
        VStack(alignment: .leading, spacing: 8) {
            LinearCardFlowLayout(spacing: 10, maximumItemWidth: 240) {
                if project.startDate != nil || project.targetDate != nil {
                    HStack(spacing: 10) {
                        if let start = project.startDate { Text(dateText(start, resolution: project.startDateResolution)) }
                        if project.startDate != nil && project.targetDate != nil { Image(systemName: "arrow.right") }
                        if let target = project.targetDate { Text(dateText(target, resolution: project.targetDateResolution)) }
                    }.fixedSize()
                }
                ForEach(project.teams) { team in badge(team, fallback: "person.2.fill") }
            }
            if let initiative = project.initiatives.first {
                HStack(spacing: 10) {
                    badge(initiative, fallback: "flag").frame(maxWidth: 210, alignment: .leading)
                    if project.initiatives.count > 1 { Text("+\(project.initiatives.count - 1)") }
                }.help(project.initiatives.map(\.name).joined(separator: "\n"))
            }
            if !project.labels.isEmpty || currentMilestone != nil {
                LinearCardFlowLayout(spacing: 10, maximumItemWidth: 280, truncatesToRemainingWidth: false) {
                    ForEach(project.labels) { label in
                        HStack(spacing: 5) {
                            Circle().fill(LinearCardColor.color(label.color, fallback: .secondary)).frame(width: 9, height: 9)
                            Text(label.name).lineLimit(1)
                        }.help(label.name)
                    }
                    if let milestone = currentMilestone {
                        HStack(spacing: 8) {
                            Image(systemName: "diamond").foregroundStyle(milestone.status == "overdue" ? Color.red : .yellow)
                            Text(milestone.name).lineLimit(1)
                            if let date = milestone.date { Text(dateText(date)).fixedSize() }
                        }.help(milestone.name)
                    }
                }
            }
            if !project.customers.isEmpty {
                LinearCardFlowLayout(spacing: 8, maximumItemWidth: 260) {
                    ForEach(project.customers) { customer in badge(customer, fallback: "building.2.crop.circle.fill") }
                }
            }
        }.font(.system(size: 12)).foregroundStyle(.secondary)
    }

    private var currentMilestone: LinearProjectBadge? {
        project.milestones.filter { $0.status != "done" && $0.status != "completed" }
            .sorted {
                let a = $0.date ?? .distantFuture, b = $1.date ?? .distantFuture
                if a != b { return a < b }
                return ($0.status == "next") && ($1.status != "next")
            }.first
    }

    private func badge(_ item: LinearProjectBadge, fallback: String) -> some View {
        HStack(spacing: 7) {
            if let url = item.imageURL {
                AsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: {
                    Image(systemName: fallback)
                }.frame(width: 16, height: 16).clipShape(Circle())
            } else {
                LinearProjectIcon(icon: item.icon, color: item.color, fallback: fallback)
            }
            Text(item.name).lineLimit(1)
        }.help(item.name)
    }

    private func dateText(_ date: Date, resolution: String? = nil) -> String {
        LinearProjectCardDate.text(date, resolution: resolution, locale: companion.language.displayLocale)
    }

    private var statusSymbol: String {
        switch project.statusType?.lowercased() {
        case "started": "hexagon"
        case "completed": "checkmark.hexagon.fill"
        case "canceled": "xmark"
        case "paused": "pause.circle"
        default: "circle.dotted"
        }
    }

    private func healthIcon(_ health: String) -> some View {
        let tint: Color = health == "onTrack" ? .green : health == "atRisk" ? .orange : .red
        return Image(systemName: health == "onTrack" ? "waveform.path" : "exclamationmark")
            .font(.system(size: 8, weight: .semibold)).foregroundStyle(tint)
            .frame(width: 14, height: 14).background(tint.opacity(0.15), in: Circle())
            .help(l.linearProjectHealth(health)).accessibilityLabel(l.linearProjectHealth(health))
    }

    private func loadIssues() async {
        guard !project.issuesFullyLoaded else { return }
        loading = true; failed = false
        defer { loading = false }
        do { try await store.loadLinearProjectIssues(projectID: project.id) }
        catch is CancellationError { }
        catch { if !Task.isCancelled { failed = true } }
    }
}

/// Linear decorative icons use platform equivalents; emoji retain their original glyph.
@MainActor
struct LinearProjectIcon: View {
    var icon: String?
    var color: String?
    var fallback: String

    var body: some View {
        Group {
            if let icon, icon.unicodeScalars.contains(where: { $0.properties.isEmojiPresentation || $0.value == 0xFE0F }) {
                Text(icon)
            } else {
                Image(systemName: symbol)
            }
        }.font(.system(size: 14)).foregroundStyle(LinearCardColor.color(color, fallback: .secondary))
            .frame(width: 16, height: 18).accessibilityHidden(true)
    }

    private var symbol: String {
        guard let icon else { return fallback }
        if NSImage(systemSymbolName: icon, accessibilityDescription: nil) != nil { return icon }
        switch icon {
        case "Home": return "house.fill"
        case "Calendar": return "calendar"
        case "Education": return "graduationcap.fill"
        case "Terminal": return "terminal.fill"
        case "Refresh": return "arrow.triangle.2.circlepath"
        case "Mountain": return "mountain.2.fill"
        case "Cube", "Box": return "shippingbox.fill"
        case "Grid": return "square.grid.3x3.fill"
        case "TextParagraph": return "text.alignleft"
        case "Conversation": return "bubble.left.and.bubble.right.fill"
        case "Network": return "network"
        case "Bolt": return "bolt.fill"
        case "Bank": return "building.columns.fill"
        case "Golf": return "flag.checkered"
        case "FaceStarEyes": return "face.smiling"
        case "GitHub": return "chevron.left.forwardslash.chevron.right"
        case "Rocket": return "paperplane.fill"
        case "Globe": return "globe"
        case "Target": return "target"
        default: return fallback
        }
    }
}

enum LinearProjectCardDate {
    static func text(_ date: Date, resolution: String? = nil, locale: Locale = .current,
                     calendar: Calendar = .current) -> String {
        let day = LinearCardDate.localDay(date, calendar: calendar)
        let year = calendar.component(.year, from: day)
        let month = calendar.component(.month, from: day)
        switch resolution {
        case "year": return String(year)
        case "quarter": return "Q\((month - 1) / 3 + 1) \(year)"
        case "halfYear": return "H\((month - 1) / 6 + 1) \(year)"
        default:
            let formatter = DateFormatter()
            formatter.calendar = calendar; formatter.timeZone = calendar.timeZone; formatter.locale = locale
            formatter.setLocalizedDateFormatFromTemplate(resolution == "month" ? "MMM yyyy" : "MMM d")
            return formatter.string(from: day)
        }
    }
}
