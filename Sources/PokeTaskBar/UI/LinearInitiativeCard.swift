import SwiftUI

/// Linear's two-line initiative summary, shared by the workspace and compact panel.
@MainActor
struct LinearInitiativeCard<Content: View>: View {
    let initiative: LinearInitiativeSummary
    @ViewBuilder let content: () -> Content
    @AppStorage("linearIssueCardAllMetadata") private var allMetadata = false
    @Environment(CompanionStore.self) private var companion
    @Environment(UsageStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expanded = false
    @State private var minimized = false
    @State private var hovering = false

    init(initiative: LinearInitiativeSummary, initiallyExpanded: Bool = false,
         @ViewBuilder content: @escaping () -> Content) {
        self.initiative = initiative
        self.content = content
        _expanded = State(initialValue: initiallyExpanded)
    }

    private var l: L { companion.l }
    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 10, style: .continuous) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 8) {
                Button {
                    if minimized { withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.12)) { minimized = false } }
                    else { withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.12)) { expanded.toggle() } }
                } label: {
                    Group {
                        if minimized {
                            title(compact: true)
                        } else {
                            ViewThatFits(in: .horizontal) {
                                HStack(spacing: 24) {
                                    title(compact: false).frame(minWidth: 240, idealWidth: 300, maxWidth: .infinity, alignment: .leading)
                                    HStack(spacing: 18) { properties }.fixedSize()
                                }
                                VStack(alignment: .leading, spacing: 12) {
                                    title(compact: true)
                                    LinearCardFlowLayout(spacing: 16) { properties }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(initiative.name)
                .accessibilityValue(minimized ? "Minimized" : (expanded ? "Expanded" : "Collapsed"))
                LinearCardMinimizeButton(minimized: $minimized)
                if !initiative.isCompleted {
                    LinearContainerPinButton(isPinned: store.pinnedLinearInitiativeIDs.contains(initiative.id)) {
                        store.toggleLinearInitiativePin(initiative)
                    }
                }
                if let url = initiative.url {
                    Link(destination: url) {
                        Image(systemName: "arrow.up.right.square").font(.system(size: 12))
                            .foregroundStyle(.secondary).frame(width: 20, height: 20)
                    }.help(l.linearOpenInitiative).accessibilityLabel(l.linearOpenInitiative)
                }
            }.padding(12)
            if expanded && !minimized {
                Divider().padding(.horizontal, 12)
                content().padding(12)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            shape.fill(colorScheme == .dark ? Color(red: 0.15, green: 0.155, blue: 0.16) : Color(nsColor: .controlBackgroundColor))
                .overlay { shape.fill(.primary.opacity(hovering || (expanded && !minimized) ? 0.025 : 0)) }
                .overlay { shape.strokeBorder(.primary.opacity(contrast == .increased ? 0.35 : 0.075), lineWidth: 1) }
        }
        .onHover { hovering = $0 }
        .contextMenu { if let url = initiative.url { Link(l.linearOpenInitiative, destination: url) } }
    }

    private func title(compact: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            LinearProjectIcon(icon: initiative.icon, color: initiative.color, fallback: "flag")
            VStack(alignment: .leading, spacing: 3) {
                Text(initiative.name).font(.system(size: 14))
                    .lineLimit(expanded && !minimized ? nil : (compact ? 2 : 1))
                if !minimized, let description = initiative.descriptionText, !description.isEmpty {
                    Text(description).font(.system(size: 13)).foregroundStyle(.secondary)
                        .lineLimit(expanded ? nil : (compact ? 2 : 1))
                }
                if !minimized && allMetadata {
                    LinearCardFlowLayout(spacing: 8, maximumItemWidth: 200) {
                        ForEach(initiative.labels) { label in
                            HStack(spacing: 6) {
                                Circle().fill(LinearCardColor.color(label.color, fallback: .secondary)).frame(width: 8, height: 8)
                                Text(label.name).lineLimit(1)
                            }
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .overlay { Capsule().strokeBorder(.primary.opacity(0.15)) }
                            .help([label.groupName, label.name].compactMap { $0 }.joined(separator: ": "))
                            .accessibilityLabel([label.groupName, label.name].compactMap { $0 }.joined(separator: ": "))
                        }
                        if let status = initiative.statusName {
                            Label(status, systemImage: LinearClient.matchesInitiativeActive(name: status) ? "arrowtriangle.up.circle" : "target")
                                .font(.system(size: 11)).foregroundStyle(LinearClient.matchesInitiativeActive(name: status) ? Color.yellow : .secondary)
                        }
                    }.padding(.top, 4)
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder private var properties: some View {
        Group {
            Group {
                if let priority = initiative.priority, (1...4).contains(priority) {
                    Image(systemName: priority == 1 ? "exclamationmark.square.fill" : "cellularbars",
                          variableValue: priority == 1 ? nil : Double(5 - priority) / 3)
                        .foregroundStyle(priority == 1 ? Color.orange : .secondary)
                } else { Text("—").foregroundStyle(.tertiary) }
            }.frame(width: 18).help(l.linearPriorityChip(initiative.priority))
                .accessibilityLabel(l.linearPriorityChip(initiative.priority))
            LinearCardAssignee(name: initiative.ownerName, avatarURL: initiative.ownerAvatarURL)
            if let team = initiative.leadTeam {
                HStack(spacing: 6) {
                    LinearProjectIcon(icon: team.icon, color: team.color, fallback: "person.2.fill")
                    Text(team.name)
                }.help("Lead team: \(team.name)").accessibilityLabel("Lead team: \(team.name)")
            }
            if let target = initiative.targetDate {
                Label(LinearProjectCardDate.text(target, resolution: initiative.targetDateResolution,
                    locale: companion.language.displayLocale), systemImage: "calendar")
                    .help("Target date").accessibilityLabel("Target: \(LinearProjectCardDate.text(target, resolution: initiative.targetDateResolution, locale: companion.language.displayLocale))")
            }
            if let total = initiative.projectCount, let completed = initiative.completedProjectCount {
                HStack(spacing: 6) {
                    Image(systemName: "hexagon").overlay { Image(systemName: "checkmark").font(.system(size: 7, weight: .medium)) }
                        .foregroundStyle(LinearChromeTint.project)
                    Text("\(completed) / \(total)").monospacedDigit()
                }.help("\(completed) of \(total) projects completed")
                    .accessibilityLabel("\(completed) of \(total) projects completed")
            }
            health
            if !initiative.activeProjectHealthCounts.isEmpty {
                HStack(spacing: 8) {
                    ForEach(["onTrack", "atRisk", "offTrack", "unknown"], id: \.self) { value in
                        if let count = initiative.activeProjectHealthCounts[value] {
                            HStack(spacing: 4) {
                                Circle().fill(healthColor(value)).frame(width: 7, height: 7)
                                Text("\(count)").monospacedDigit()
                            }.help("Active projects · \(healthText(value)): \(count)")
                                .accessibilityLabel("\(count) active projects: \(healthText(value))")
                        }
                    }
                }
            }
        }.font(.system(size: 12)).foregroundStyle(.secondary).fixedSize()
    }

    private var health: some View {
        let value = initiative.health ?? "unknown"
        return Image(systemName: value == "unknown" ? "circle.dotted" : "waveform.path")
            .font(.system(size: value == "unknown" ? 14 : 8, weight: .medium))
            .foregroundStyle(healthColor(value)).frame(width: 15, height: 15)
            .background(healthColor(value).opacity(value == "unknown" ? 0 : 0.16), in: Circle())
            .help("Initiative health: \(healthText(value))").accessibilityLabel("Initiative health: \(healthText(value))")
    }

    private func healthColor(_ value: String) -> Color {
        switch value { case "onTrack": .green; case "atRisk": .yellow; case "offTrack": .red; default: .secondary }
    }

    private func healthText(_ value: String) -> String {
        value == "unknown" ? "No update" : l.linearProjectHealth(value)
    }
}

@MainActor
struct LinearInitiativeProjects: View {
    let initiative: LinearInitiativeSummary
    var onViewProject: ((LinearProjectSummary) -> Void)? = nil
    let onPin: () -> Void
    @Environment(UsageStore.self) private var store
    @Environment(CompanionStore.self) private var companion

    var body: some View {
        let linked = LinearContainerOrder.pinnedFirst(
            store.linearProjects.filter { initiative.projectIDs.contains($0.id) }, ids: store.pinnedLinearProjectIDs)
        let dividerID = LinearContainerOrder.dividerID(linked, ids: store.pinnedLinearProjectIDs)
        VStack(alignment: .leading, spacing: 12) {
            ForEach(linked) { project in
                VStack(spacing: 12) {
                    if project.id == dividerID { Divider() }
                    LinearProjectCard(project: project, hiddenIssueStatuses: store.hiddenLinearIssueStatuses,
                        issuesInitiallyMinimized: true,
                        onViewIssues: onViewProject.map { action in { action(project) } }, onPin: onPin)
                }
            }
            let unrepresented = initiative.issues.filter { issue in !linked.contains { $0.id == issue.projectID } }
            if !unrepresented.isEmpty {
                let visible = LinearProjectIssueFilter.visible(unrepresented, hiding: store.hiddenLinearIssueStatuses)
                if visible.isEmpty {
                    Text(companion.l.linearProjectNoMatchingIssueStatuses).font(.caption).foregroundStyle(.secondary)
                } else {
                    LinearContainerIssuesView(issues: visible, nested: true, initiallyMinimized: true, onPin: onPin)
                }
            }
            if linked.isEmpty && unrepresented.isEmpty {
                Text(companion.l.linearContainerEmptyIssues).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
