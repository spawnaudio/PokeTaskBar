import SwiftUI

@MainActor
struct LinearCardMinimizeButton: View {
    @Binding var minimized: Bool
    @Environment(CompanionStore.self) private var companion
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.12)) { minimized.toggle() }
        } label: {
            Image(systemName: minimized ? "chevron.down" : "chevron.up")
                .font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
                .frame(width: 20, height: 20).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(minimized ? companion.l.linearCardRestore : companion.l.linearCardMinimize)
        .accessibilityLabel(minimized ? companion.l.linearCardRestore : companion.l.linearCardMinimize)
        .accessibilityIdentifier("linear-card-minimize")
    }
}

/// One preference shared by issue cards in the main window, popover and containers.
@MainActor
struct LinearCardDisplayMenu: View {
    @AppStorage("linearIssueCardAllMetadata") private var allMetadata = false
    @Environment(CompanionStore.self) private var companion

    var body: some View {
        Menu {
            Picker(companion.l.linearCardMetadata, selection: $allMetadata) {
                Text(companion.l.linearCardMinimal).tag(false)
                Text(companion.l.linearCardAll).tag(true)
            }
        } label: {
            Image(systemName: "slider.horizontal.3")
        }
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
        .help(companion.l.linearCardMetadata)
        .accessibilityLabel(companion.l.linearCardMetadata)
    }
}

enum LinearCardColor {
    static func color(_ hex: String?, fallback: Color) -> Color {
        guard let hex else { return fallback }
        let value = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard value.count == 6, let rgb = UInt32(value, radix: 16) else { return fallback }
        return Color(red: Double((rgb >> 16) & 255) / 255,
                     green: Double((rgb >> 8) & 255) / 255, blue: Double(rgb & 255) / 255)
    }
}

@MainActor
struct LinearCardStatusIcon: View {
    let issue: LinearIssueSummary

    private var symbol: String {
        switch issue.stateType?.lowercased() {
        case "started": return "circle.lefthalf.filled"
        case "completed": return "checkmark.circle.fill"
        case "canceled", "cancelled": return "xmark.circle"
        case "backlog": return "circle.dashed"
        default: return "circle"
        }
    }

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(LinearCardColor.color(issue.stateColor,
                fallback: LinearWorkflowTint.color(for: issue.stateType)))
            .frame(width: 16, height: 18)
    }
}

@MainActor
struct LinearCardAssignee: View {
    let name: String?
    let avatarURL: URL?

    init(issue: LinearIssueSummary) {
        name = issue.assigneeName
        avatarURL = issue.assigneeAvatarURL
    }

    init(name: String?, avatarURL: URL?) {
        self.name = name
        self.avatarURL = avatarURL
    }

    var body: some View {
        if let name, !name.isEmpty {
            AsyncImage(url: avatarURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Text(name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined())
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.primary.opacity(0.08))
            }
            .frame(width: 18, height: 18)
            .clipShape(Circle())
            .help(name)
            .accessibilityLabel(name)
        }
    }
}

/// Neutral outlined pills keep color on the icon, matching Linear's board cards.
@MainActor
struct LinearCardPill: View {
    var text: String? = nil
    let symbol: String
    var tint: Color = .secondary
    var dot = false
    var variableValue: Double? = nil
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol, variableValue: variableValue)
                .font(.system(size: dot ? 8 : 11, weight: .medium))
                .foregroundStyle(tint)
            if let text {
                Text(text).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .padding(.horizontal, text == nil ? 5 : 8)
        .frame(height: 22)
        .overlay { Capsule().strokeBorder(.primary.opacity(contrast == .increased ? 0.4 : 0.14), lineWidth: 1) }
        .contentShape(Capsule())
        .help(text ?? "")
    }
}

/// Measures each pill at its natural width, capped to keep long names from taking a whole row.
struct LinearCardFlowLayout: Layout {
    var spacing: CGFloat = 4
    var maximumItemWidth: CGFloat = 160
    var truncatesToRemainingWidth = true

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrangement(width: proposal.width ?? 320, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangement(width: bounds.width, subviews: subviews)
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                                  proposal: ProposedViewSize(frame.size))
        }
    }

    private func arrangement(width: CGFloat, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        let width = max(0, width)
        var frames: [CGRect] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for view in subviews {
            var size = view.sizeThatFits(ProposedViewSize(width: min(width, maximumItemWidth), height: nil))
            // Long project/label names can share a row by truncating to its remaining room.
            if truncatesToRemainingWidth, x > 0, x + size.width > width, width - x >= 110 {
                size = view.sizeThatFits(ProposedViewSize(width: width - x, height: nil))
            }
            if x > 0, x + size.width > width {
                x = 0; y += rowHeight + spacing; rowHeight = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return (CGSize(width: width, height: y + rowHeight), frames)
    }
}

@MainActor
struct LinearCardMetadata: View {
    let issue: LinearIssueSummary
    let allMetadata: Bool
    var parentProjectID: String? = nil
    var showsIdentifier = false
    @Environment(CompanionStore.self) private var companion

    var body: some View {
        LinearCardFlowLayout(maximumItemWidth: allMetadata ? 160 : 220) {
            if showsIdentifier {
                LinearIssueIDButton(identifier: issue.identifier, url: issue.issueURL,
                                    style: .system(size: 12), padded: false)
            }
            LinearPriorityButton(issue: issue, iconOnly: true)
            if allMetadata, let started = issue.startedAt {
                let end = issue.completedAt ?? Date()
                let days = max(0, Calendar.current.dateComponents([.day], from: started, to: end).day ?? 0)
                LinearCardPill(text: "\(days)d", symbol: "stopwatch")
                    .accessibilityLabel("\(days) days in progress")
            }
            if let rawDue = issue.dueDate {
                let due = LinearCardDate.localDay(rawDue)
                LinearCardPill(text: dueText(due), symbol: "calendar",
                               tint: Calendar.current.startOfDay(for: due) < Calendar.current.startOfDay(for: Date()) ? .red : .orange)
                    .accessibilityLabel("\(companion.l.todayDeskDueLabel): \(dueText(due))")
            }
            if allMetadata, let number = issue.cycleNumber {
                LinearCardPill(text: String(number), symbol: "circle.dotted.circle", tint: .indigo)
                    .help(issue.cycleName ?? "Cycle \(number)")
            }
            if let project = issue.projectName, !project.isEmpty,
               parentProjectID == nil || issue.projectID != parentProjectID {
                LinearCardPill(text: project, symbol: "rectangle.topthird.inset.filled",
                               tint: LinearCardColor.color(issue.projectColor, fallback: .green))
            }
            if allMetadata {
                if let milestone = issue.milestoneName, !milestone.isEmpty {
                    LinearCardPill(text: milestone, symbol: "diamond", tint: .yellow)
                }
                if let estimate = issue.estimate {
                    LinearCardPill(text: String(estimate), symbol: "scalemass")
                        .accessibilityLabel("\(companion.l.todayDeskEstimateLabel): \(estimate)")
                }
                if let team = issue.teamKey ?? issue.teamName, !team.isEmpty {
                    LinearCardPill(text: team, symbol: "person.2")
                        .help(issue.teamName ?? team)
                }
                ForEach(Array(issue.labelNames.enumerated()), id: \.offset) { _, name in
                    LinearCardPill(text: name, symbol: "circle.fill",
                                   tint: LinearCardColor.color(issue.labelColors[name], fallback: .secondary), dot: true)
                }
            }
        }
    }

    private func dueText(_ date: Date) -> String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: companion.language.rawValue)
        formatter.doesRelativeDateFormatting = true
        formatter.dateStyle = .medium
        if calendar.isDateInToday(date) || calendar.isDateInTomorrow(date) || calendar.isDateInYesterday(date) {
            return formatter.string(from: date)
        }
        formatter.setLocalizedDateFormatFromTemplate("MMM d")
        return formatter.string(from: date)
    }
}

enum LinearCardDate {
    /// Linear date-only values arrive at UTC midnight; translate their components into the user's calendar.
    static func localDay(_ date: Date, calendar: Calendar = .current) -> Date {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar.date(from: utc.dateComponents([.year, .month, .day], from: date)) ?? date
    }
}

@MainActor
struct LinearCardDates: View {
    let issue: LinearIssueSummary
    @Environment(CompanionStore.self) private var companion

    var body: some View {
        LinearCardFlowLayout(maximumItemWidth: 200) {
            if let created = issue.createdAt {
                Text("\(companion.l.linearCardCreated) \(created.formatted(.dateTime.month(.abbreviated).day()))")
            }
            if let updated = issue.updatedAt {
                Text("\(companion.l.linearCardUpdated) \(updated.formatted(.dateTime.month(.abbreviated).day()))")
            }
        }
        .font(.system(size: 12)).foregroundStyle(.secondary)
    }
}
