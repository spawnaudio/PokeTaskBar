import AppKit
import Charts
import SwiftUI
import UniformTypeIdentifiers

@MainActor
struct TaskInsightsView: View {
    @Environment(FocusSessionStore.self) private var focus
    @Environment(UsageStore.self) private var usage
    @Environment(\.colorScheme) private var scheme
    @State private var period = 7
    @State private var project = ""
    @State private var selectedDay: Date?
    @State private var exportError: String?
    @State private var query = ""
    private var calendar: Calendar { .current }
    private var end: Date { calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date()))! }
    private var start: Date { selectedDay.map { calendar.startOfDay(for: $0) } ?? calendar.date(byAdding: .day, value: -period, to: end)! }
    private var until: Date { selectedDay.flatMap { calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: $0)) } ?? end }
    private var records: [TaskSessionRecord] { focus.sessionRecords.filter {
        (project.isEmpty || $0.projectID == project) &&
        (query.isEmpty || ($0.title + " " + $0.identifier).localizedCaseInsensitiveContains(query))
    } }
    private var inPeriod: [TaskSessionRecord] {
        records.filter { TaskTimeReport.seconds([$0], from: start, until: until) > 0 || ($0.finishedAt >= start && $0.finishedAt < until) }
    }
    private var days: [Date] {
        let count = selectedDay == nil ? period : 1
        return (0..<count).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }
    private var completedCount: Int {
        Set(inPeriod.filter { $0.finishedAt >= start && $0.finishedAt < until &&
            ($0.finish == .doneOnTime || $0.finish == .doneOvertime) }.map(\.issueID)).count
    }
    private var plannedBlocks: [TaskTimeBlock] {
        focus.plan.blocks.filter { $0.day >= TaskPlanningStore.dayKey(start) && $0.day < TaskPlanningStore.dayKey(until) &&
            (project.isEmpty || $0.projectID == project) &&
            (query.isEmpty || ($0.title + " " + $0.identifier).localizedCaseInsensitiveContains(query)) }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ViewThatFits(in: .horizontal) {
                HStack { filters; Spacer(); exportButton }
                VStack(alignment: .leading, spacing: 8) { filters; exportButton }
            }
            TextField("Filter tasks by title or identifier…", text: $query).textFieldStyle(.roundedBorder)
            if let day = selectedDay {
                HStack { Text(day, format: .dateTime.day().month().year()); Button("Clear date") { selectedDay = nil }.buttonStyle(.link) }
            }
            if let error = exportError ?? focus.storageError { Text(error).font(.caption).foregroundStyle(.orange) }
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    metrics
                    chart.mainWindowCard()
                    heatmap.mainWindowCard()
                    taskTable.mainWindowCard()
                    if records.contains(where: \.partial) {
                        Text("Legacy history is partial. It retains the latest available summary per issue and is excluded from measured charts and coverage.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    TaskInsightsSessionNotice()
                }
            }.scrollIndicators(.hidden).roundedScrollViewport()
        }
    }
    private var filters: some View {
        HStack(spacing: 12) {
            TahoeTabBar(selection: $period, items: [TahoeTabItem(1, title: "Day"),
                TahoeTabItem(7, title: "Week"), TahoeTabItem(30, title: "Month")])
                .onChange(of: period) { _, _ in selectedDay = nil }
            Picker("Recorded project", selection: $project) {
                Text("All projects").tag("")
                ForEach(projects, id: \.id) { value in Text(value.name).tag(value.id) }
            }.labelsHidden().frame(maxWidth: 210).help("Filter by recorded project")
        }
    }
    private var projects: [(id: String, name: String)] {
        var values: [String: String] = [:]
        for record in focus.sessionRecords {
            if let id = record.projectID { values[id] = record.projectName ?? id }
        }
        return values.map { (id: $0.key, name: $0.value) }.sorted { $0.name < $1.name }
    }
    private var exportButton: some View {
        Button { export() } label: { Label("Export CSV", systemImage: "square.and.arrow.up") }
            .buttonStyle(.plain).help("Whole session records intersecting the selected period")
    }
    private var metrics: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { metricCards }
            VStack(alignment: .leading, spacing: 12) { metricCards }
        }
    }
    @ViewBuilder private var metricCards: some View {
        metric("Measured focus", TaskTimeReport.duration(TaskTimeReport.seconds(records, from: start, until: until)))
        metric("Tasks completed", "\(completedCount)")
        let coverage = TaskTimeReport.planCoverage(records: records, blocks: plannedBlocks)
        metric("Plan coverage", coverage.map { "\(Int(($0 * 100).rounded()))%" } ?? "No plan")
    }
    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.system(size: 25, weight: .semibold))
        }.frame(maxWidth: .infinity, alignment: .leading).mainWindowCard()
            .help(title == "Plan coverage" ? "Block-linked active time, capped at each block's planned duration, divided by planned time. No plan means no score." : title)
    }
    private var chart: some View {
        let records = records
        let plannedBlocks = plannedBlocks
        return VStack(alignment: .leading, spacing: 14) {
            Text("Planned and measured time").fontWeight(.medium)
            Chart {
                ForEach(days, id: \.self) { day in
                    let next = calendar.date(byAdding: .day, value: 1, to: day)!
                    let planned = Double(plannedBlocks.filter { $0.day == TaskPlanningStore.dayKey(day) }.reduce(0) { $0 + $1.durationMinutes })
                    BarMark(x: .value("Date", day, unit: .day), y: .value("Minutes", planned))
                        .foregroundStyle(by: .value("Time", "Planned"))
                        .position(by: .value("Time", "Planned"))
                    BarMark(x: .value("Date", day, unit: .day), y: .value("Minutes", TaskTimeReport.seconds(records, from: day, until: next) / 60))
                        .foregroundStyle(by: .value("Time", "Measured"))
                        .position(by: .value("Time", "Measured"))
                }
            }.chartForegroundStyleScale(["Planned": Color.gray.opacity(0.45), "Measured": Color.blue])
                .frame(height: 190)
            Text("Actual time excludes pause, sleep, and waiting at zero. Planning alone records no work.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
    private var heatmap: some View {
        let today = calendar.startOfDay(for: Date())
        let monday = calendar.date(byAdding: .day, value: -((calendar.component(.weekday, from: today) + 5) % 7), to: today)!
        let first = calendar.date(byAdding: .weekOfYear, value: -12, to: monday)!
        let data = TaskTimeReport.activityByDay(records)
        let trackingDay = calendar.startOfDay(for: focus.trackingBeganAt)
        return VStack(alignment: .leading, spacing: 12) {
            Text("Focus activity · 13 weeks").fontWeight(.medium)
            HStack(alignment: .top, spacing: 8) {
                VStack(spacing: 4) { ForEach(["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], id: \.self) { Text($0).font(.system(size: 9)).frame(height: 12) } }
                LazyHGrid(rows: Array(repeating: GridItem(.fixed(12), spacing: 4), count: 7), spacing: 4) {
                    ForEach(0..<91, id: \.self) { index in
                        let day = calendar.date(byAdding: .day, value: index, to: first)!
                        let activity = data[TaskPlanningStore.dayKey(day)]
                        let seconds = activity?.seconds ?? 0
                        let sessions = activity?.sessions ?? 0
                        let missing = day < trackingDay
                        let future = day > today
                        Button { selectedDay = day } label: {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(missing || future ? Color.secondary.opacity(0.055) : shade(seconds / 60))
                                .frame(width: 12, height: 12)
                                .overlay { if missing { RoundedRectangle(cornerRadius: 2).strokeBorder(.secondary.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [2])) } }
                        }.buttonStyle(.plain).disabled(missing || future)
                            .help("\(day.formatted(date: .complete, time: .omitted)): \(future ? "Future date" : missing ? "History unavailable" : TaskTimeReport.duration(seconds) + " · " + String(sessions) + " sessions")")
                            .accessibilityLabel("\(day.formatted(date: .complete, time: .omitted)), \(future ? "future date" : missing ? "history unavailable" : TaskTimeReport.duration(seconds) + ", " + String(sessions) + " sessions")")
                    }
                }
            }
            HStack(spacing: 6) {
                Text("Minutes").font(.caption)
                ForEach([0.0, 15, 45, 90, 150], id: \.self) { value in RoundedRectangle(cornerRadius: 2).fill(shade(value)).frame(width: 12, height: 12) }
                Text("0 · <30 · 30–59 · 60–119 · 120+").font(.system(size: 10)).foregroundStyle(.secondary)
            }
            Text("Dashed cells have unavailable history. Select a recorded day to review it.").font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private func shade(_ minutes: Double) -> Color {
        if minutes <= 0 { return .secondary.opacity(0.13) }
        return .blue.opacity(minutes < 30 ? 0.25 : minutes < 60 ? 0.45 : minutes < 120 ? 0.7 : 1)
    }
    private var taskTable: some View {
        let inPeriod = inPeriod
        let groups = Dictionary(grouping: inPeriod, by: \.issueID)
        return LazyVStack(alignment: .leading, spacing: 14) {
            HStack { Text("Tasks worked on").fontWeight(.medium); Spacer(); Text("\(inPeriod.filter { $0.finishedAt >= start && $0.finishedAt < until }.reduce(0) { $0 + $1.xp }) XP").font(.caption).foregroundStyle(.secondary) }
            if groups.isEmpty { Text("Finish or stop a focus session to record your time.").foregroundStyle(.secondary) }
            ForEach(groups.keys.sorted(), id: \.self) { id in
                let values = groups[id] ?? []
                let latest = values.max { $0.finishedAt < $1.finishedAt }
                DisclosureGroup {
                    ForEach(values.sorted { $0.finishedAt > $1.finishedAt }) { record in
                        HStack {
                            Text(record.finishedAt, format: .dateTime.day().month().hour().minute())
                            Spacer()
                            Text(TaskTimeReport.duration(record.activeSeconds))
                            Text(record.partial ? "Partial history" : finishLabel(record.finish)).foregroundStyle(.secondary)
                        }.font(.caption).padding(.vertical, 4)
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(latest?.identifier ?? "") · \(latest?.title ?? id)").lineLimit(2)
                            Text(latest?.projectName ?? "Standalone / no recorded project").font(.caption).foregroundStyle(.secondary)
                            Text(usage.linearIssue(id: id)?.stateName ?? "Unavailable in current snapshot")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(TaskTimeReport.duration(TaskTimeReport.seconds(values, from: start, until: until))).monospacedDigit()
                        Text("\(values.count) sessions").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
    private func finishLabel(_ finish: FocusFinishKind) -> String {
        switch finish { case .doneOnTime, .doneOvertime: "Completed"; case .leftInProgress: "Stopped"; case .forfeited: "Switched task" }
    }
    private func export() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "PokeTasks-session-records.csv"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try TaskTimeReport.csv(inPeriod).write(to: url, atomically: true, encoding: .utf8); exportError = nil }
        catch { exportError = "The CSV could not be saved: \(error.localizedDescription)" }
    }
}

/// Only this small label observes the live session; timer ticks leave the report alone.
@MainActor
private struct TaskInsightsSessionNotice: View {
    @Environment(FocusSessionStore.self) private var focus
    var body: some View {
        if focus.session != nil {
            Text("The running session will appear here when it finishes or stops.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}
