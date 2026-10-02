import SwiftUI
import UniformTypeIdentifiers

@MainActor
struct TaskTimelineView: View {
    @Environment(FocusSessionStore.self) private var focus
    @Environment(UsageStore.self) private var usage
    @Environment(\.colorScheme) private var scheme
    @State private var editing: TaskTimeBlock?
    @State private var dropIssueID: String?
    @State private var dropMinute: CGFloat = 0
    @State private var dropActive = false
    @State private var visibleHour: Int?
    @State private var restoringScroll = true
    private var plan: TaskPlanningStore { focus.plan }
    private var blocks: [TaskTimeBlock] {
        plan.blocks.filter { $0.day == plan.dayKey && (plan.projectFilter.isEmpty || $0.projectID == plan.projectFilter) }
            .sorted { $0.startMinute < $1.startMinute }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Day plan").font(.system(size: 17, weight: .semibold))
            Text(plan.selectedDay, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated))
                .font(.caption).foregroundStyle(.secondary)
            Text("\(blocks.reduce(0) { $0 + $1.durationMinutes }) min planned")
                .font(.caption).foregroundStyle(.secondary)
            if let error = plan.blockError ?? plan.storageError {
                Text(error).font(.caption).foregroundStyle(.orange)
            }
            if plan.canUndoBlock { Button("Undo last block change") { plan.undoBlock() }.buttonStyle(.link).font(.caption) }
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(0..<24, id: \.self) { hour in
                            HStack(alignment: .top, spacing: 8) {
                                Text(hourLabel(hour)).font(.system(size: 10)).foregroundStyle(.secondary)
                                    .frame(width: 40, alignment: .trailing)
                                Rectangle().fill(.primary.opacity(0.09)).frame(height: 1)
                            }.frame(height: 60, alignment: .top).id(hour)
                        }
                    }.scrollTargetLayout()
                    .overlay(alignment: .topLeading) {
                        GeometryReader { geometry in
                        ZStack(alignment: .topLeading) {
                            TimelineView(.periodic(from: .now, by: 60)) { context in
                                if TaskPlanningStore.dayKey(context.date) == plan.dayKey {
                                    let c = Calendar.current.dateComponents([.hour, .minute], from: context.date)
                                    Rectangle().fill(.blue.opacity(0.6)).frame(height: 1)
                                        .padding(.leading, 48).offset(y: CGFloat((c.hour ?? 0) * 60 + (c.minute ?? 0)))
                                        .allowsHitTesting(false)
                                }
                            }
                            ForEach(blocks) { block in
                                TaskTimelineBlockView(block: block, availableWidth: max(70, geometry.size.width - 50),
                                    onEdit: { editing = block })
                                    .offset(x: 50)
                            }
                            if let id = dropIssueID, let issue = usage.linearIssue(id: id) {
                                let duration = SessionXP.clampMinutes(focus.plannedMinutes)
                                var candidate = TaskTimeBlock(issueID: id, identifier: issue.identifier, title: issue.title,
                                    day: plan.dayKey, startMinute: 0, durationMinutes: duration)
                                let _ = candidate.set(start: TaskTimeBlock.snapped(Double(dropMinute)), duration: duration)
                                let conflict = plan.hasConflict(candidate)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(issue.title).lineLimit(1)
                                    Text("\(duration) min · \(candidate.timeRange)")
                                    if conflict { Text("Time conflict").foregroundStyle(.orange) }
                                }.font(.system(size: 10)).padding(8)
                                    .frame(width: max(70, geometry.size.width - 50), height: CGFloat(duration), alignment: .topLeading)
                                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 7))
                                    .overlay { RoundedRectangle(cornerRadius: 7).strokeBorder(conflict ? .orange : .secondary,
                                        style: StrokeStyle(lineWidth: 1, dash: [4])) }
                                    .offset(x: 50, y: min(CGFloat(1440 - duration), max(0, dropMinute))).allowsHitTesting(false)
                            }
                        }
                        .frame(width: geometry.size.width, height: 1440, alignment: .topLeading)
                        }
                    }
                    .coordinateSpace(name: "task-timeline")
                    .contentShape(Rectangle())
                    .onDrop(of: [UTType.text], delegate: TimelineIssueDrop(
                            issueID: dropIssueID,
                            onEnter: { y in dropActive = true; dropMinute = y },
                            onLoad: { id in if dropActive { dropIssueID = id } },
                            onMove: { y in dropMinute = y },
                            onExit: { dropActive = false; dropIssueID = nil },
                            onCommit: { id, y in
                                defer { dropActive = false; dropIssueID = nil }
                                guard let issue = usage.linearIssue(id: id) else { return false }
                                return plan.schedule(issue, start: TaskTimeBlock.snapped(Double(y)),
                                    duration: focus.plannedMinutes) != nil
                            }))
                    .padding(.top, 8).padding(.bottom, 16)
                }.scrollIndicators(.hidden).roundedScrollViewport()
                    .scrollPosition(id: $visibleHour, anchor: .top)
                    .onAppear {
                        proxy.scrollTo(plan.timelineHour, anchor: .top)
                        restoringScroll = false
                    }
                    .onChange(of: visibleHour) { _, hour in
                        if !restoringScroll, let hour { plan.timelineHour = hour }
                    }
                    .onExitCommand { dropActive = false; dropIssueID = nil }
            }
            Text("Drag an issue here, or use its Schedule menu.")
                .font(.system(size: 11)).foregroundStyle(.secondary)
        }.padding(16).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(MainWindowTheme(scheme: scheme).canvas, in: RoundedRectangle(cornerRadius: 14))
            .mainWindowBorder(cornerRadius: 14)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .sheet(item: $editing) { block in TaskBlockEditor(block: block).frame(width: 380, height: 300) }
    }
    private func hourLabel(_ hour: Int) -> String { "\(hour % 12 == 0 ? 12 : hour % 12) \(hour < 12 ? "AM" : "PM")" }
    private func clock(_ minute: Int) -> String { String(format: "%02d:%02d", minute / 60, minute % 60) }
}

@MainActor
private struct TimelineIssueDrop: DropDelegate {
    let issueID: String?
    let onEnter: @MainActor @Sendable (CGFloat) -> Void
    let onLoad: @MainActor @Sendable (String) -> Void
    let onMove: @MainActor @Sendable (CGFloat) -> Void
    let onExit: @MainActor @Sendable () -> Void
    let onCommit: @MainActor @Sendable (String, CGFloat) -> Bool
    private func read(_ info: DropInfo, completion: @escaping @MainActor @Sendable (String) -> Void) {
        guard let provider = info.itemProviders(for: [UTType.text]).first else { return }
        _ = provider.loadObject(ofClass: String.self) { value, _ in
            guard let value else { return }
            Task { @MainActor in completion(value) }
        }
    }
    func dropEntered(info: DropInfo) { onEnter(info.location.y); read(info, completion: onLoad) }
    func dropUpdated(info: DropInfo) -> DropProposal? {
        onMove(info.location.y)
        return DropProposal(operation: .copy)
    }
    func dropExited(info: DropInfo) { onExit() }
    func performDrop(info: DropInfo) -> Bool {
        let y = info.location.y
        if let issueID { _ = onCommit(issueID, y) }
        else { read(info) { _ = onCommit($0, y) } }
        return true
    }
}

@MainActor
private struct TaskTimelineBlockView: View {
    let block: TaskTimeBlock
    let availableWidth: CGFloat
    let onEdit: () -> Void
    @Environment(FocusSessionStore.self) private var focus
    @Environment(UsageStore.self) private var usage
    @State private var dragStart: CGFloat?
    @State private var dragDuration: CGFloat?
    @State private var hovering = false
    @State private var dragCancelled = false
    @FocusState private var focused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var start: Int { TaskTimeBlock.snapped(Double(dragStart ?? CGFloat(block.startMinute))) }
    private var duration: Int { TaskTimeBlock.snapped(Double(dragDuration ?? CGFloat(block.durationMinutes))) }
    private var moving: Bool { dragStart != nil || dragDuration != nil }
    private var candidate: TaskTimeBlock {
        var value = block; value.set(start: start, duration: duration); return value
    }
    private var conflicting: Bool { candidate.startAt == nil || focus.plan.hasConflict(candidate, excluding: block.id) }
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(block.title).font(.system(size: 11, weight: .medium)).lineLimit(1)
            if duration >= 30 { Text(candidate.timeRange).font(.system(size: 10)).foregroundStyle(.secondary) }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8).padding(.top, 5)
        .frame(width: availableWidth, height: dragDuration ?? CGFloat(duration), alignment: .topLeading)
        .background(.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 7))
        .overlay(alignment: .leading) { Rectangle().fill(.blue).frame(width: 2) }
        .mainWindowBorder(cornerRadius: 7)
        .overlay { if moving && conflicting { RoundedRectangle(cornerRadius: 7).strokeBorder(.orange, lineWidth: 1) } }
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .contentShape(Rectangle())
        .focusable().focused($focused)
        .gesture(DragGesture(minimumDistance: 3, coordinateSpace: .named("task-timeline")).onChanged { value in
            guard !dragCancelled else { return }
            focused = true
            dragStart = min(CGFloat(1440 - duration), max(0, CGFloat(block.startMinute) + value.translation.height))
        }.onEnded { _ in finishDrag() })
        .overlay(alignment: .bottom) {
            Capsule().fill(.secondary.opacity(hovering || moving ? 0.55 : 0))
                .frame(width: 26, height: 3).padding(.vertical, 3)
                .frame(maxWidth: .infinity).contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 2, coordinateSpace: .named("task-timeline")).onChanged { value in
                    guard !dragCancelled else { return }
                    focused = true
                    dragDuration = min(CGFloat(1440 - start), max(5, min(180,
                        CGFloat(block.durationMinutes) + value.translation.height)))
                }.onEnded { _ in finishDrag() })
                .accessibilityLabel("Resize time block; use Edit for keyboard scheduling")
        }
        .overlay(alignment: .topTrailing) {
            if moving {
                Text("\(duration) min · \(candidate.timeRange)\(conflicting ? " · Time conflict" : "")")
                    .font(.system(size: 10)).padding(6)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
                    .offset(y: -30).allowsHitTesting(false)
            }
        }
        .offset(y: dragStart ?? CGFloat(start))
        .onKeyPress(.escape) {
            guard moving else { return .ignored }
            dragCancelled = true; dragStart = nil; dragDuration = nil; return .handled
        }
        .onKeyPress(.return) { onEdit(); return .handled }
        .onHover { hovering = $0 }
        .help("\(block.identifier) · \(duration) minutes · \(candidate.timeRange) · \(block.timeZoneID ?? TimeZone.current.identifier). Right-click to edit or start focus.")
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(block.title), \(duration) minutes, \(time(start)) to \(time(start + duration))")
        .accessibilityAction(named: "Edit") { onEdit() }
        .accessibilityAction(named: "Start focus") { startFocus() }
        .contextMenu {
            Menu("Start focus") {
                Button("Block duration · \(duration) min") { startFocus() }
                ForEach([25, 50, 90], id: \.self) { minutes in Button("\(minutes) minutes") { startFocus(minutes: minutes) } }
            }.disabled(usage.linearIssue(id: block.issueID).map { !TaskPlanningStore.isOpen($0) } ?? true)
            Button("Edit…", action: onEdit)
            Divider()
            Button("Delete block") { focus.plan.removeBlock(block.id) }
        }
    }
    private func finishDrag() {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.12)) {
            if !dragCancelled, moving { focus.plan.edit(block, start: start, duration: duration) }
            dragStart = nil; dragDuration = nil; dragCancelled = false
        }
    }
    private func time(_ minute: Int) -> String { String(format: "%02d:%02d", minute / 60, minute % 60) }
    private func startFocus(minutes: Int? = nil) {
        guard let issue = usage.linearIssue(id: block.issueID), TaskPlanningStore.isOpen(issue) else { return }
        focus.pin(issue, minutes: minutes ?? duration, blockID: block.id)
    }
}

@MainActor
private struct TaskBlockEditor: View {
    let block: TaskTimeBlock
    @Environment(FocusSessionStore.self) private var focus
    @Environment(UsageStore.self) private var usage
    @Environment(\.dismiss) private var dismiss
    @State private var date: Date
    @State private var duration: Int
    init(block: TaskTimeBlock) {
        self.block = block
        let parts = block.day.split(separator: "-").compactMap { Int($0) }
        var calendar = Calendar.current
        calendar.timeZone = block.timeZoneID.flatMap(TimeZone.init(identifier:)) ?? .current
        let base = parts.count == 3 ? calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])) : nil
        _date = State(initialValue: block.startAt ?? calendar.date(bySettingHour: block.startMinute / 60,
            minute: block.startMinute % 60, second: 0, of: base ?? Date()) ?? Date())
        _duration = State(initialValue: block.durationMinutes)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Edit time block").font(.title2)
            Text(block.title).lineLimit(2)
            DatePicker("Start", selection: $date, displayedComponents: [.date, .hourAndMinute])
                .environment(\.timeZone, block.timeZoneID.flatMap(TimeZone.init(identifier:)) ?? .current)
            Text(block.timeZoneID ?? TimeZone.current.identifier).font(.caption).foregroundStyle(.secondary)
            Stepper("Duration: \(duration) min", value: $duration, in: 5...180, step: 5)
            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save") {
                    var calendar = Calendar.current
                    calendar.timeZone = block.timeZoneID.flatMap(TimeZone.init(identifier:)) ?? .current
                    let c = calendar.dateComponents([.hour, .minute], from: date)
                    if focus.plan.edit(block, start: (c.hour ?? 0) * 60 + (c.minute ?? 0), duration: duration,
                                       day: TaskPlanningStore.dayKey(date, calendar: calendar)) { dismiss() }
                }.keyboardShortcut(.defaultAction)
            }
            if let error = focus.plan.blockError { Text(error).font(.caption).foregroundStyle(.orange) }
        }.padding(24)
    }
}
