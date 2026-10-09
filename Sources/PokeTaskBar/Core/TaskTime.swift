import Foundation

struct FocusActiveSegment: Codable, Equatable {
    var start: Date
    var end: Date
    var seconds: TimeInterval { max(0, end.timeIntervalSince(start)) }
    init(start: Date, end: Date) { self.start = start; self.end = end }
    private enum CodingKeys: String, CodingKey { case start, end }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // Numeric instants preserve sub-second measurement; accept the earlier ISO format.
        if let seconds = try? c.decode(Double.self, forKey: .start) { start = Date(timeIntervalSince1970: seconds) }
        else { start = try c.decode(Date.self, forKey: .start) }
        if let seconds = try? c.decode(Double.self, forKey: .end) { end = Date(timeIntervalSince1970: seconds) }
        else { end = try c.decode(Date.self, forKey: .end) }
        guard start.timeIntervalSince1970.isFinite, end.timeIntervalSince1970.isFinite,
              start >= .distantPast, end <= .distantFuture, end >= start else {
            throw DecodingError.dataCorruptedError(forKey: .end, in: c, debugDescription: "Invalid active time segment")
        }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(start.timeIntervalSince1970, forKey: .start)
        try c.encode(end.timeIntervalSince1970, forKey: .end)
    }
}

struct TaskSessionRecord: Codable, Equatable, Identifiable {
    var id: String
    var issueID: String
    var identifier: String
    var title: String
    var projectID: String?
    var projectName: String?
    var blockID: UUID?
    var segments: [FocusActiveSegment]
    var activeSeconds: TimeInterval
    var plannedSeconds: TimeInterval
    var finishedAt: Date
    var finish: FocusFinishKind
    var xp: Int
    var partial: Bool
}

enum TaskTimeReport {
    /// Legacy summaries retain elapsed time but cannot reconstruct dated active segments.
    /// Include their saved duration in totals, dated by completion; charts remain measured-only.
    static func recordedSeconds(_ records: [TaskSessionRecord], from: Date, until: Date) -> Double {
        seconds(records, from: from, until: until) + records.filter {
            $0.partial && $0.finishedAt >= from && $0.finishedAt < until
        }.reduce(0) { $0 + max(0, $1.activeSeconds) }
    }

    static func completedTaskCount(_ records: [TaskSessionRecord], awards: [LinearIssueXPRecord],
                                   from: Date, until: Date) -> Int {
        let finished = records.filter {
            $0.finishedAt >= from && $0.finishedAt < until &&
                ($0.finish == .doneOnTime || $0.finish == .doneOvertime)
        }.map(\.issueID)
        let awarded = awards.filter { $0.awardedAt >= from && $0.awardedAt < until }.map(\.id)
        return Set(finished + awarded).count
    }

    static func secondsByDay(_ records: [TaskSessionRecord], calendar: Calendar = .current) -> [String: Double] {
        activityByDay(records, calendar: calendar).mapValues { $0.seconds }
    }
    static func activityByDay(_ records: [TaskSessionRecord], calendar: Calendar = .current) -> [String: (seconds: Double, sessions: Int)] {
        var values: [String: (seconds: Double, sessions: Int)] = [:]
        for record in records where !record.partial {
            var days = Set<String>()
            for segment in record.segments {
                var start = segment.start
                while start < segment.end {
                    guard let midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: start)),
                          midnight > start else { break }
                    let end = min(midnight, segment.end)
                    let day = TaskPlanningStore.dayKey(start, calendar: calendar)
                    values[day, default: (0, 0)].seconds += end.timeIntervalSince(start)
                    if days.insert(day).inserted { values[day, default: (0, 0)].sessions += 1 }
                    start = end
                }
            }
        }
        return values
    }
    static func seconds(_ records: [TaskSessionRecord], from: Date, until: Date) -> Double {
        records.filter { !$0.partial }.reduce(0) { total, record in
            total + record.segments.reduce(0) { value, segment in
                value + max(0, min(until, segment.end).timeIntervalSince(max(from, segment.start)))
            }
        }
    }
    static func planCoverage(records: [TaskSessionRecord], blocks: [TaskTimeBlock]) -> Double? {
        let planned = blocks.reduce(0.0) { $0 + Double($1.durationMinutes * 60) }
        guard planned > 0 else { return nil }
        let covered = blocks.reduce(0.0) { value, block in
            let actual = records.filter { $0.blockID == block.id && !$0.partial }.reduce(0.0) { $0 + $1.activeSeconds }
            return value + min(Double(block.durationMinutes * 60), actual)
        }
        return covered / planned
    }
    static func csv(_ records: [TaskSessionRecord]) -> String {
        func field(_ value: String) -> String { "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
        let formatter = ISO8601DateFormatter()
        var rows = ["session_id,issue_id,identifier,title,recorded_project,active_seconds,planned_seconds,finish,finished_at_utc,timezone,partial"]
        rows += records.map { record in
            [record.id, record.issueID, record.identifier, record.title, record.projectName ?? "",
             String(record.activeSeconds), String(record.plannedSeconds), record.finish.rawValue,
             formatter.string(from: record.finishedAt), TimeZone.current.identifier, String(record.partial)]
                .map(field).joined(separator: ",")
        }
        return rows.joined(separator: "\n") + "\n"
    }
    static func duration(_ seconds: Double) -> String {
        let minutes = max(0, Int(seconds / 60))
        return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
    }
}
