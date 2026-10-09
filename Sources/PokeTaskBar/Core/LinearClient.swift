import Foundation

/// Completed Linear issue eligible for companion XP.
struct LinearCompletedIssue: Equatable, Sendable, Identifiable {
    var id: String
    var identifier: String
    var title: String
    var completedAt: Date
}

/// Completed Linear project eligible for a large XP packet.
struct LinearCompletedProject: Equatable, Sendable, Identifiable {
    var id: String
    var name: String
    var completedAt: Date
}

/// Per-issue Linear Done XP. First completion only — re-completing does not rewrite this.
struct LinearIssueXPRecord: Codable, Equatable, Sendable, Identifiable {
    var id: String
    var identifier: String
    var xp: Int
    var awardedAt: Date
}

/// One workflow state on a Linear team (Todo, In Progress, Done, …).
struct LinearWorkflowState: Equatable, Codable, Sendable, Identifiable {
    var id: String
    var name: String
    var type: String
    var position: Double?
}

/// Result of `issueUpdate` when changing an issue's workflow state.
struct LinearIssueStateUpdate: Equatable, Sendable {
    var id: String
    var identifier: String
    var title: String
    var stateId: String?
    var stateName: String?
    var stateType: String?
    var completedAt: Date?
    var stateColor: String? = nil
}

/// Rich Linear issue metadata for UI surfaces.
struct LinearIssueSummary: Equatable, Sendable, Identifiable {
    var id: String
    var identifier: String
    var title: String
    var issueURL: URL?
    var priority: Int?
    var estimate: Int?
    var stateId: String?
    var stateName: String?
    var stateType: String?
    var assigneeName: String?
    var assigneeEmail: String?
    var projectName: String?
    var teamName: String?
    var teamKey: String?
    var teamID: String?
    var teamStates: [LinearWorkflowState]
    var completedStateId: String?
    var labelNames: [String]
    var createdAt: Date?
    var updatedAt: Date?
    var dueDate: Date?
    var completedAt: Date?
    var descriptionText: String?
    var projectID: String? = nil
    var assigneeAvatarURL: URL? = nil
    var stateColor: String? = nil
    var projectColor: String? = nil
    var labelColors: [String: String] = [:]
    var startedAt: Date? = nil
    var cycleName: String? = nil
    var cycleNumber: Int? = nil
    var milestoneName: String? = nil
    var parentID: String? = nil
    var hasSubIssues = false
}

/// Fields the Today inspector (and tests) show from an already-fetched issue. Empty values are omitted.
enum LinearIssueInspector {
    enum Kind: Equatable {
        case status, team, project, assignee, labels, estimate, due
    }

    struct Field: Equatable {
        var kind: Kind
        var value: String
        var stateType: String? = nil
    }

    static func fields(
        for issue: LinearIssueSummary,
        dueText: (Date) -> String = { $0.formatted(.dateTime.month(.abbreviated).day()) }
    ) -> [Field] {
        var rows: [Field] = []
        if let name = issue.stateName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            rows.append(Field(kind: .status, value: name, stateType: issue.stateType))
        }
        if let team = teamLabel(issue) {
            rows.append(Field(kind: .team, value: team))
        }
        if let project = issue.projectName?.trimmingCharacters(in: .whitespacesAndNewlines), !project.isEmpty {
            rows.append(Field(kind: .project, value: project))
        }
        if let assignee = issue.assigneeName?.trimmingCharacters(in: .whitespacesAndNewlines), !assignee.isEmpty {
            rows.append(Field(kind: .assignee, value: assignee))
        }
        if !issue.labelNames.isEmpty {
            rows.append(Field(kind: .labels, value: issue.labelNames.joined(separator: ", ")))
        }
        if let estimate = issue.estimate {
            rows.append(Field(kind: .estimate, value: String(estimate)))
        }
        if let due = issue.dueDate {
            rows.append(Field(kind: .due, value: dueText(due)))
        }
        return rows
    }

    private static func teamLabel(_ issue: LinearIssueSummary) -> String? {
        let key = issue.teamKey?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let name = issue.teamName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !key.isEmpty, !name.isEmpty, key != name { return "\(key) · \(name)" }
        if !key.isEmpty { return key }
        if !name.isEmpty { return name }
        return nil
    }
}

/// Linear issue priority. 0 is none; 1 is urgent through 4 low.
enum LinearPriorityLevel: Int, CaseIterable, Sendable {
    case none = 0
    case urgent = 1
    case high = 2
    case medium = 3
    case low = 4

    static func from(_ value: Int?) -> LinearPriorityLevel {
        guard let value, let level = LinearPriorityLevel(rawValue: value) else { return .none }
        return level
    }
}

struct LinearProjectSummary: Equatable, Sendable, Identifiable {
    var id: String
    var name: String
    var url: URL?
    var statusName: String?
    var statusType: String?
    var leadName: String?
    var targetDate: Date?
    var descriptionText: String?
    var issues: [LinearIssueSummary]
    var identifier: String? = nil
    var icon: String? = nil
    var color: String? = nil
    var statusColor: String? = nil
    var health: String? = nil
    var priority: Int? = nil
    var leadAvatarURL: URL? = nil
    var startDate: Date? = nil
    var startDateResolution: String? = nil
    var targetDateResolution: String? = nil
    var issueCount: Int? = nil
    var teams: [LinearProjectBadge] = []
    var initiatives: [LinearProjectBadge] = []
    var labels: [LinearProjectBadge] = []
    var milestones: [LinearProjectBadge] = []
    var customers: [LinearProjectBadge] = []
    var issuesFullyLoaded = false
    var statusID: String? = nil
    var statusPosition: Double? = nil
    var createdAt: Date? = nil
    var updatedAt: Date? = nil

    var isCompleted: Bool { (statusType ?? statusName)?.lowercased() == "completed" }
}

/// Small named properties displayed on a project card, retaining Linear's colors and icons.
struct LinearProjectBadge: Equatable, Sendable, Identifiable {
    var id: String
    var name: String
    var icon: String? = nil
    var color: String? = nil
    var imageURL: URL? = nil
    var date: Date? = nil
    var status: String? = nil
    var groupName: String? = nil
}

struct LinearInitiativeSummary: Equatable, Sendable, Identifiable {
    var id: String
    var name: String
    var url: URL?
    var statusName: String?
    var ownerName: String?
    var targetDate: Date?
    var descriptionText: String?
    var issues: [LinearIssueSummary]
    /// Retain explicit relationships even when a linked project has no open issues.
    var projectIDs: [String] = []
    var icon: String? = nil
    var color: String? = nil
    var priority: Int? = nil
    var health: String? = nil
    var ownerAvatarURL: URL? = nil
    var leadTeam: LinearProjectBadge? = nil
    var targetDateResolution: String? = nil
    var labels: [LinearProjectBadge] = []
    var projectCount: Int? = nil
    var completedProjectCount: Int? = nil
    var activeProjectHealthCounts: [String: Int] = [:]

    var isCompleted: Bool { statusName?.lowercased() == "completed" }
}

struct LinearIssueDashboard: Equatable, Sendable {
    var completedRecent: [LinearIssueSummary]
    var inProgress: [LinearIssueSummary]
    var projects: [LinearProjectSummary]
    var initiatives: [LinearInitiativeSummary]
    var planned: [LinearIssueSummary] = []
    var todo: [LinearIssueSummary] = []
    var projectStatuses: [LinearWorkflowState] = []
    var completedPinnedInitiativeIDs: Set<String> = []
    var relatedIssues: [LinearIssueSummary] = []
}

protocol LinearHTTPClient: Sendable {
    func postGraphQL(apiKey: String, body: Data) async throws -> (status: Int, data: Data)
}

struct URLSessionLinearClient: LinearHTTPClient {
    func postGraphQL(apiKey: String, body: Data) async throws -> (status: Int, data: Data) {
        var request = URLRequest(url: URL(string: "https://api.linear.app/graphql")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue(apiKey, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        return (status, data)
    }
}

/// Fetches recently completed Linear issues. Injectable HTTP for tests.
struct LinearClient: Sendable {
    var http: any LinearHTTPClient = URLSessionLinearClient()

    /// Issues completed at or after `since` (ISO8601).
    func fetchCompletedIssues(apiKey: String, since: Date) async throws -> [LinearCompletedIssue] {
        let dashboard = try await fetchIssueDashboard(apiKey: apiKey, completedSince: since)
        return dashboard.completedRecent.compactMap { issue in
            guard let completedAt = issue.completedAt else { return nil }
            return LinearCompletedIssue(
                id: issue.id,
                identifier: issue.identifier,
                title: issue.title,
                completedAt: completedAt)
        }
    }

    /// Recently completed projects (status type completed). Failures return [] so issue
    /// refresh is not blocked — Linear project `completedAt` filters vary by workspace.
    func fetchCompletedProjects(apiKey: String, since: Date) async throws -> [LinearCompletedProject] {
        let query = """
        query CompletedProjects($since: DateTimeOrDuration!) {
          projects(
            first: 50
            filter: { completedAt: { gte: $since } }
          ) {
            nodes { id name completedAt }
          }
        }
        """
        let payload: [String: Any] = [
            "query": query,
            "variables": ["since": ISO8601DateFormatter().string(from: since)],
        ]
        let body = try JSONSerialization.data(withJSONObject: payload)
        let (status, data): (Int, Data)
        do {
            (status, data) = try await http.postGraphQL(apiKey: apiKey, body: body)
        } catch {
            throw LinearAPIError.transport
        }
        guard (200..<300).contains(status) else { throw LinearAPIError.httpStatus(status) }
        return try Self.parseCompletedProjects(data)
    }

    /// Lightweight auth probe used by Settings key validation.
    /// We intentionally avoid the dashboard query here because large workspaces can
    /// hit transient timeouts/rate limits and look like false "invalid key" failures.
    func validateAPIKey(apiKey: String) async throws {
        let query = """
        query ValidateLinearAPIKey {
          viewer { id }
        }
        """
        let payload: [String: Any] = ["query": query]
        let body = try JSONSerialization.data(withJSONObject: payload)
        let (status, data): (Int, Data)
        do {
            (status, data) = try await http.postGraphQL(apiKey: apiKey, body: body)
        } catch {
            throw LinearAPIError.transport
        }
        if status == 401 || status == 403 { throw LinearAPIError.unauthorized }
        guard (200..<300).contains(status) else { throw LinearAPIError.httpStatus(status) }

        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LinearAPIError.decoding
        }
        if let errors = root["errors"] as? [[String: Any]], !errors.isEmpty {
            if Self.containsUnauthorizedGraphQLError(errors) {
                throw LinearAPIError.unauthorized
            }
            throw LinearAPIError.decoding
        }
        guard let dataObj = root["data"] as? [String: Any],
              let viewer = dataObj["viewer"] as? [String: Any],
              let viewerID = viewer["id"] as? String,
              !viewerID.isEmpty
        else { throw LinearAPIError.decoding }
    }

    /// Moves an issue to any workflow state via `issueUpdate` (two-way sync).
    func updateIssueState(
        apiKey: String, issueID: String, stateID: String
    ) async throws -> LinearIssueStateUpdate {
        let query = """
        mutation UpdateLinearIssueState($id: String!, $stateId: String!) {
          issueUpdate(id: $id, input: { stateId: $stateId }) {
            success
            issue {
              id
              identifier
              title
              completedAt
              state { id name type color }
            }
          }
        }
        """
        let payload: [String: Any] = [
            "query": query,
            "variables": ["id": issueID, "stateId": stateID]
        ]
        let body = try JSONSerialization.data(withJSONObject: payload)
        let (status, data): (Int, Data)
        do {
            (status, data) = try await http.postGraphQL(apiKey: apiKey, body: body)
        } catch {
            throw LinearAPIError.transport
        }
        if status == 401 || status == 403 { throw LinearAPIError.unauthorized }
        guard (200..<300).contains(status) else { throw LinearAPIError.httpStatus(status) }
        return try Self.parseIssueStateUpdate(data)
    }

    /// Sets issue priority via `issueUpdate` (0 = none, 1 urgent … 4 low).
    func updateIssuePriority(
        apiKey: String, issueID: String, priority: Int
    ) async throws {
        let query = """
        mutation UpdateLinearIssuePriority($id: String!, $priority: Int!) {
          issueUpdate(id: $id, input: { priority: $priority }) {
            success
            issue { id priority }
          }
        }
        """
        let payload: [String: Any] = [
            "query": query,
            "variables": ["id": issueID, "priority": priority]
        ]
        let body = try JSONSerialization.data(withJSONObject: payload)
        let (status, data): (Int, Data)
        do {
            (status, data) = try await http.postGraphQL(apiKey: apiKey, body: body)
        } catch {
            throw LinearAPIError.transport
        }
        if status == 401 || status == 403 { throw LinearAPIError.unauthorized }
        guard (200..<300).contains(status) else { throw LinearAPIError.httpStatus(status) }
        try Self.parseIssuePriorityUpdate(data)
    }

    /// Posts a new comment on an issue via `commentCreate`.
    func createComment(apiKey: String, issueID: String, body: String) async throws {
        let query = """
        mutation CreateLinearComment($issueId: String!, $body: String!) {
          commentCreate(input: { issueId: $issueId, body: $body }) {
            success
            comment { id }
          }
        }
        """
        let data = try await postGraphQL(
            apiKey: apiKey,
            query: query,
            variables: ["issueId": issueID, "body": body])
        try Self.parseCommentCreate(data)
    }

    /// Fetches issue panel data used by the popover.
    ///
    /// Issues stay on their own query — that payload already works. Projects and initiatives
    /// are a separate, lighter round-trip. Linear rejects any single request over 10,000
    /// complexity points; nesting `team.states` (default page 50) under
    /// `projects { issues }` and `initiatives { projects { issues } }` blows that cap,
    /// returns HTTP 400, and the old issues-only fallback looked exactly like empty
    /// Projects/Initiatives tabs while Issues still worked.
    func fetchIssueDashboard(apiKey: String, completedSince: Date,
                             pinnedInitiativeIDs: Set<String> = []) async throws -> LinearIssueDashboard {
        let sinceISO = ISO8601DateFormatter().string(from: completedSince)
        let issuesData = try await postGraphQL(
            apiKey: apiKey, query: Self.issuesOnlyQuery, variables: ["since": sinceISO])
        var dashboard = try Self.parseIssueDashboard(issuesData)

        let containerQueries = [
            Self.containersQuery,
            Self.containersSalvageQuery,
            Self.containersBareQuery,
        ]
        for query in containerQueries {
            do {
                let data = try await postGraphQL(apiKey: apiKey, query: query, variables: [:])
                if var overlay = try Self.parseContainerOverlay(data) {
                    var seenCursors = Set<String>()
                    while let cursor = overlay.nextProjectsCursor {
                        guard seenCursors.insert(cursor).inserted else { throw LinearAPIError.decoding }
                        let page = try await postGraphQL(apiKey: apiKey, query: query, variables: ["after": cursor])
                        guard let next = try Self.parseContainerOverlay(page) else { throw LinearAPIError.decoding }
                        let known = Set(overlay.projects.map(\.id))
                        overlay.projects += next.projects.filter { !known.contains($0.id) }
                        overlay.nextProjectsCursor = next.nextProjectsCursor
                    }
                    overlay.initiatives = overlay.initiatives.map { initiative in
                        var copy = initiative
                        var seen = Set(copy.issues.map(\.id))
                        copy.issues += overlay.projects.filter { initiative.projectIDs.contains($0.id) }
                            .flatMap(\.issues).filter { seen.insert($0.id).inserted }
                        copy.issues = Self.sortedByPriority(copy.issues)
                        return copy
                    }
                    dashboard = Self.merging(dashboard, overlay)
                    break
                }
            } catch LinearAPIError.httpStatus(_) {
                continue
            } catch LinearAPIError.decoding {
                continue
            }
        }
        dashboard = try await fillingMissingParents(apiKey: apiKey, dashboard: dashboard)
        dashboard = Self.hydrateTeamStates(Self.includingQueuedIssuesInContainers(dashboard))
        dashboard = try await fillingMissingTeamStates(apiKey: apiKey, dashboard: dashboard)
        for offset in stride(from: 0, to: dashboard.projects.count, by: 50) {
            let ids = dashboard.projects.dropFirst(offset).prefix(50).map(\.id)
            guard let data = try? await postGraphQL(apiKey: apiKey, query: Self.projectCardMetadataQuery,
                                                   variables: ["ids": ids]),
                  let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  (root["errors"] as? [Any] ?? []).isEmpty,
                  let dataObject = root["data"] as? [String: Any] else { continue }
            let metadata = Self.parseProjects(dataObject["projects"])
            dashboard.projects = dashboard.projects.map { project in
                guard var rich = metadata.first(where: { $0.id == project.id }) else { return project }
                rich.issues = project.issues
                return rich
            }
        }
        dashboard.projectStatuses = (try? await fetchProjectStatuses(apiKey: apiKey)) ?? []
        for offset in stride(from: 0, to: dashboard.initiatives.count, by: 10) {
            let ids = dashboard.initiatives.dropFirst(offset).prefix(10).map(\.id)
            guard let metadata = try? await fetchInitiativeCardMetadata(apiKey: apiKey, ids: ids) else { continue }
            dashboard.initiatives = dashboard.initiatives.map { initiative in
                guard var rich = metadata.first(where: { $0.id == initiative.id }) else { return initiative }
                var seen = Set(initiative.issues.map(\.id))
                rich.issues = Self.sortedByPriority(initiative.issues + dashboard.projects
                    .filter { rich.projectIDs.contains($0.id) }.flatMap(\.issues)
                    .filter { seen.insert($0.id).inserted })
                return rich
            }
        }
        // Completed initiatives leave the active/planned feed. Check pins explicitly, and
        // retain them on missing data or failures rather than treating absence as completion.
        let pinnedIDs = pinnedInitiativeIDs.sorted()
        for offset in stride(from: 0, to: pinnedIDs.count, by: 50) {
            let query = """
            query PinnedInitiativeStatuses($ids: [ID!]!) {
              initiatives(first: 50, filter: { id: { in: $ids } }) {
                nodes { id name status }
              }
            }
            """
            guard let data = try? await postGraphQL(apiKey: apiKey, query: query,
                    variables: ["ids": Array(pinnedIDs.dropFirst(offset).prefix(50))]),
                  let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  (root["errors"] as? [Any] ?? []).isEmpty,
                  let object = root["data"] as? [String: Any] else { continue }
            dashboard.completedPinnedInitiativeIDs.formUnion(
                Self.parseInitiatives(object["initiatives"]).filter(\.isCompleted).map(\.id))
        }
        return dashboard
    }

    /// Keep relationship metadata separate from issue previews and finish project pages before counting.
    func fetchInitiativeCardMetadata(apiKey: String, ids: [String]) async throws -> [LinearInitiativeSummary] {
        let data = try await postGraphQL(apiKey: apiKey, query: Self.initiativeCardMetadataQuery, variables: ["ids": ids])
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              (root["errors"] as? [Any] ?? []).isEmpty,
              let connection = (root["data"] as? [String: Any])?["initiatives"] as? [String: Any],
              var nodes = connection["nodes"] as? [[String: Any]] else { throw LinearAPIError.decoding }
        for index in nodes.indices {
            guard let id = nodes[index]["id"] as? String,
                  var projects = nodes[index]["projects"] as? [String: Any],
                  var projectNodes = projects["nodes"] as? [[String: Any]] else { throw LinearAPIError.decoding }
            var seen = Set<String>()
            while let cursor = try Self.nextCursor(projects) {
                guard seen.insert(cursor).inserted else { throw LinearAPIError.decoding }
                let page = try await postGraphQL(apiKey: apiKey, query: """
                query InitiativeCardProjects($id: String!, $after: String!) {
                  initiative(id: $id) {
                    projects(first: 100, after: $after) {
                      nodes { id status { type } health }
                      pageInfo { hasNextPage endCursor }
                    }
                  }
                }
                """, variables: ["id": id, "after": cursor])
                guard let root = try JSONSerialization.jsonObject(with: page) as? [String: Any],
                      (root["errors"] as? [Any] ?? []).isEmpty,
                      let initiative = (root["data"] as? [String: Any])?["initiative"] as? [String: Any],
                      let next = initiative["projects"] as? [String: Any],
                      let nextNodes = next["nodes"] as? [[String: Any]] else { throw LinearAPIError.decoding }
                projectNodes += nextNodes
                projects = next
            }
            nodes[index]["projects"] = ["nodes": projectNodes, "pageInfo": ["hasNextPage": false]]
        }
        return Self.parseInitiatives(["nodes": nodes])
    }

    /// Include unused custom statuses, so an empty project tab is still available.
    func fetchProjectStatuses(apiKey: String) async throws -> [LinearWorkflowState] {
        var states: [LinearWorkflowState] = []
        var cursor: String?
        var seen = Set<String>()
        repeat {
            let data = try await postGraphQL(apiKey: apiKey, query: """
            query ProjectStatuses($after: String) {
              projectStatuses(first: 100, after: $after) {
                nodes { id name type position }
                pageInfo { hasNextPage endCursor }
              }
            }
            """, variables: cursor.map { ["after": $0] } ?? [:])
            guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  (root["errors"] as? [Any] ?? []).isEmpty,
                  let connection = (root["data"] as? [String: Any])?["projectStatuses"] as? [String: Any]
            else { throw LinearAPIError.decoding }
            states += Self.parseWorkflowStates(from: ["states": connection])
            cursor = try Self.nextCursor(connection)
            if let cursor, !seen.insert(cursor).inserted { throw LinearAPIError.decoding }
        } while cursor != nil
        return states
    }

    private static func nextCursor(_ connection: [String: Any]?) throws -> String? {
        guard let page = connection?["pageInfo"] as? [String: Any], page["hasNextPage"] as? Bool == true else { return nil }
        guard let cursor = page["endCursor"] as? String, !cursor.isEmpty else { throw LinearAPIError.decoding }
        return cursor
    }

    /// Expanded projects include every non-archived issue, including completed/canceled work.
    /// Fetch separately from the board query to keep nested GraphQL complexity bounded.
    func fetchProjectIssues(apiKey: String, projectID: String) async throws -> [LinearIssueSummary] {
        var issues: [LinearIssueSummary] = []
        var cursor: String?
        var seenCursors = Set<String>()
        repeat {
            try Task.checkCancellation()
            var variables: [String: Any] = ["id": projectID]
            if let cursor { variables["after"] = cursor }
            let data = try await postGraphQL(apiKey: apiKey, query: """
            query ProjectCardIssues($id: String!, $after: String) {
              project(id: $id) {
                issues(first: 100, after: $after) {
                  nodes { \(Self.lightIssueNodeFields) labels { nodes { name color } } }
                  pageInfo { hasNextPage endCursor }
                }
              }
            }
            """, variables: variables)
            guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  (root["errors"] as? [Any] ?? []).isEmpty,
                  let connection = ((root["data"] as? [String: Any])?["project"] as? [String: Any])?["issues"] as? [String: Any],
                  let nodes = connection["nodes"] as? [[String: Any]],
                  let page = connection["pageInfo"] as? [String: Any],
                  let hasNext = page["hasNextPage"] as? Bool
            else { throw LinearAPIError.decoding }
            issues += try nodes.map(Self.parseIssueSummary)
            cursor = nil
            if hasNext {
                guard let next = page["endCursor"] as? String, !next.isEmpty,
                      seenCursors.insert(next).inserted else { throw LinearAPIError.decoding }
                cursor = next
            }
        } while cursor != nil
        var seen = Set<String>()
        let dashboard = LinearIssueDashboard(completedRecent: [], inProgress: [],
            projects: [LinearProjectSummary(id: projectID, name: "", issues: issues.filter { seen.insert($0.id).inserted })],
            initiatives: [])
        let parents = try await fillingMissingParents(apiKey: apiKey, dashboard: dashboard)
        let hydrated = try await fillingMissingTeamStates(apiKey: apiKey, dashboard: Self.hydrateTeamStates(parents))
        return Self.sortedByPriority(hydrated.projects[0].issues + hydrated.relatedIssues)
    }

    /// Load the expanded issue's children separately, without multiplying board query complexity.
    func fetchSubIssues(apiKey: String, issueID: String) async throws -> [LinearIssueSummary] {
        var issues: [LinearIssueSummary] = []
        var cursor: String?
        var seen = Set<String>()
        repeat {
            try Task.checkCancellation()
            var variables: [String: Any] = ["id": issueID]
            if let cursor { variables["after"] = cursor }
            let data = try await postGraphQL(apiKey: apiKey, query: """
            query IssueChildren($id: String!, $after: String) {
              issue(id: $id) {
                children(first: 100, after: $after) {
                  nodes { \(Self.lightIssueNodeFields) labels { nodes { name color } } }
                  pageInfo { hasNextPage endCursor }
                }
              }
            }
            """, variables: variables)
            guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  (root["errors"] as? [Any] ?? []).isEmpty,
                  let connection = ((root["data"] as? [String: Any])?["issue"] as? [String: Any])?["children"] as? [String: Any],
                  let nodes = connection["nodes"] as? [[String: Any]] else { throw LinearAPIError.decoding }
            issues += try nodes.map(Self.parseIssueSummary)
            cursor = try Self.nextCursor(connection)
            if let cursor, !seen.insert(cursor).inserted { throw LinearAPIError.decoding }
        } while cursor != nil
        let dashboard = LinearIssueDashboard(completedRecent: [], inProgress: [], projects: [], initiatives: [], relatedIssues: issues)
        let hydrated = try await fillingMissingTeamStates(apiKey: apiKey, dashboard: dashboard)
        var ids = Set<String>()
        return Self.sortedByPriority(hydrated.relatedIssues.filter { ids.insert($0.id).inserted })
    }

    private func fillingMissingParents(apiKey: String, dashboard: LinearIssueDashboard) async throws -> LinearIssueDashboard {
        var result = dashboard
        var attempted = Set<String>()
        while true {
            let all = result.completedRecent + result.inProgress + result.planned + result.todo +
                result.projects.flatMap(\.issues) + result.initiatives.flatMap(\.issues) + result.relatedIssues
            let known = Set(all.map(\.id))
            let missing = Set(all.compactMap(\.parentID)).subtracting(known).subtracting(attempted).sorted()
            guard !missing.isEmpty else { return result }
            let ids = Array(missing.prefix(50))
            attempted.formUnion(ids)
            let data = try await postGraphQL(apiKey: apiKey, query: """
            query IssueParents($ids: [ID!]!) {
              issues(first: 50, filter: { id: { in: $ids } }) {
                nodes { \(Self.lightIssueNodeFields) labels { nodes { name color } } }
              }
            }
            """, variables: ["ids": ids])
            guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  (root["errors"] as? [Any] ?? []).isEmpty,
                  let nodes = ((root["data"] as? [String: Any])?["issues"] as? [String: Any])?["nodes"] as? [[String: Any]]
            else { throw LinearAPIError.decoding }
            result.relatedIssues += try nodes.map(Self.parseIssueSummary).filter { !known.contains($0.id) }
        }
    }

    /// Nested project/initiative issues omit `team.states` (complexity). Copy states
    /// already parsed from the issues query, then look up any remaining teams once.
    private func fillingMissingTeamStates(
        apiKey: String, dashboard: LinearIssueDashboard
    ) async throws -> LinearIssueDashboard {
        let missing = Self.missingTeamIDs(in: dashboard)
        guard !missing.isEmpty else { return dashboard }
        do {
            let data = try await postGraphQL(
                apiKey: apiKey,
                query: Self.teamStatesQuery,
                variables: ["ids": missing, "first": missing.count])
            let extra = try Self.parseTeamStatesByID(data)
            return Self.assigningTeamStates(dashboard, from: extra)
        } catch LinearAPIError.unauthorized {
            throw LinearAPIError.unauthorized
        } catch {
            return dashboard
        }
    }

    func postGraphQL(apiKey: String, query: String, variables: [String: Any]) async throws -> Data {
        var payload: [String: Any] = ["query": query]
        if !variables.isEmpty { payload["variables"] = variables }
        let body = try JSONSerialization.data(withJSONObject: payload)
        let (status, data): (Int, Data)
        do {
            (status, data) = try await http.postGraphQL(apiKey: apiKey, body: body)
        } catch {
            throw LinearAPIError.transport
        }
        if status == 401 || status == 403 { throw LinearAPIError.unauthorized }
        guard (200..<300).contains(status) else { throw LinearAPIError.httpStatus(status) }
        return data
    }

    static let issueNodeFields = """
    id identifier title url description priority estimate \
    state { id name type color } assignee { name email avatarUrl } project { id name color } \
    team { id name key states { nodes { id name type position } } } \
    labels { nodes { name color } } createdAt updatedAt dueDate completedAt startedAt \
    cycle { name number } projectMilestone { name } parent { id } children(first: 1) { nodes { id } }
    """

    /// Nested project issues omit `team.states` (default page 50) so container queries
    /// stay under Linear's per-request complexity cap. Workflow states are copied from
    /// the issues query via `hydrateTeamStates`, or fetched once per missing team.
    private static let lightIssueNodeFields = """
    id identifier title url description priority estimate \
    state { id name type color } assignee { name email avatarUrl } project { id name color } \
    team { id name key } createdAt updatedAt dueDate completedAt startedAt \
    cycle { name number } projectMilestone { name } parent { id } children(first: 1) { nodes { id } }
    """

    /// One lookup for nested issues whose team never appeared on the issues query.
    private static var teamStatesQuery: String {
        """
        query TeamWorkflowStates($ids: [String!]!, $first: Int!) {
          teams(filter: { id: { in: $ids } }, first: $first) {
            nodes {
              id
              states { nodes { id name type position } }
            }
          }
        }
        """
    }

    private static var issuesOnlyQuery: String {
        let issueFields = issueNodeFields
        return """
        query IssueDashboard($since: DateTimeOrDuration!) {
          completedRecent: issues(
            filter: { completedAt: { gte: $since } }
            first: 100
          ) {
            nodes { \(issueFields) }
          }
          inProgress: issues(first: 100, filter: { state: { type: { eq: "started" }, name: { eqIgnoreCase: "In Progress" } } }) {
            nodes { \(issueFields) }
          }
          todo: issues(first: 100, filter: { state: { name: { eqIgnoreCase: "Todo" } } }) {
            nodes { \(lightIssueNodeFields) labels { nodes { name color } } }
          }
          planned: issues(first: 100, filter: { state: { name: { eqIgnoreCase: "Planned" } } }) {
            nodes { \(lightIssueNodeFields) labels { nodes { name color } } }
          }
        }
        """
    }

    /// All non-archived project statuses are included; initiative status remains an enum scalar.
    private static var containersQuery: String {
        let issueFields = lightIssueNodeFields
        return """
        query IssueContainers($after: String) {
          projects(
            first: 50
            after: $after
          ) {
            nodes {
              id
              name
              url
              description
              targetDate
              identifier icon color health priority startDate startDateResolution targetDateResolution
              currentProgress
              lead { name avatarUrl }
              status { id type name color position }
              createdAt updatedAt
              issues(
                first: 12
                filter: { state: { type: { nin: ["completed", "canceled"] } } }
              ) {
                nodes { \(issueFields) }
              }
            }
            pageInfo { hasNextPage endCursor }
          }
          initiatives(
            first: 50
            filter: { status: { in: ["Active", "Planned"] } }
          ) {
            nodes {
              id
              name
              url
              description
              targetDate
              status
              owner { name }
              projects(first: 20) {
                nodes { id name }
              }
            }
          }
        }
        """
    }

    /// Card relationships are separate from nested issues to stay below the 10,000 point cap.
    private static let projectCardMetadataQuery = """
    query ProjectCardMetadata($ids: [ID!]!) {
      projects(first: 50, filter: { id: { in: $ids } }) {
        nodes {
          id name url description identifier icon color health priority
          startDate startDateResolution targetDate targetDateResolution currentProgress createdAt updatedAt
          lead { name avatarUrl } status { id type name color position }
          teams(first: 5) { nodes { id name key icon color } }
          initiatives(first: 10) { nodes { id name icon color } }
          labels(first: 20) { nodes { id name color } }
          projectMilestones(first: 20) { nodes { id name targetDate status } }
          needs(first: 20) { nodes { customer { id name logoUrl } } }
        }
      }
    }
    """

    // ponytail: preview up to 30 labels per initiative; paginate if label-heavy workspaces need more.
    private static let initiativeCardMetadataQuery = """
    query InitiativeCardMetadata($ids: [ID!]!) {
      initiatives(first: 10, filter: { id: { in: $ids } }) {
        nodes {
          id name url description status icon color priority health targetDate targetDateResolution
          owner { name avatarUrl }
          leadTeam { id name key icon color }
          labels(first: 30) { nodes { id name color parent { name } } }
          projects(first: 100) {
            nodes { id status { type } health }
            pageInfo { hasNextPage endCursor }
          }
        }
      }
    }
    """

    /// No nested issues — used when the richer query is rejected.
    private static var containersSalvageQuery: String {
        """
        query IssueContainers($after: String) {
          projects(first: 100, after: $after) {
            nodes {
              id
              name
              url
              description
              targetDate
              lead { name }
              status { id type name position }
              createdAt updatedAt
            }
            pageInfo { hasNextPage endCursor }
          }
          initiatives(first: 50) {
            nodes {
              id
              name
              url
              description
              targetDate
              status
              owner { name }
              projects(first: 20) {
                nodes { id name }
              }
            }
          }
        }
        """
    }

    /// Last container attempt: initiative `status` as an object (schema drift from the enum scalar).
    private static var containersBareQuery: String {
        """
        query IssueContainers($after: String) {
          projects(first: 100, after: $after) {
            nodes {
              id
              name
              url
              status { id type name position }
            }
            pageInfo { hasNextPage endCursor }
          }
          initiatives(first: 50) {
            nodes {
              id
              name
              url
              status { name type }
            }
          }
        }
        """
    }

    static func parseIssueStateUpdate(_ data: Data) throws -> LinearIssueStateUpdate {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LinearAPIError.decoding
        }
        if let errors = root["errors"] as? [[String: Any]], !errors.isEmpty {
            if containsUnauthorizedGraphQLError(errors) { throw LinearAPIError.unauthorized }
            throw LinearAPIError.decoding
        }
        guard let dataObj = root["data"] as? [String: Any],
              let payload = dataObj["issueUpdate"] as? [String: Any],
              payload["success"] as? Bool == true,
              let issue = payload["issue"] as? [String: Any],
              let id = issue["id"] as? String, !id.isEmpty,
              let identifier = issue["identifier"] as? String, !identifier.isEmpty,
              let title = issue["title"] as? String, !title.isEmpty
        else { throw LinearAPIError.decoding }
        let state = issue["state"] as? [String: Any]
        return LinearIssueStateUpdate(
            id: id,
            identifier: identifier,
            title: title,
            stateId: state?["id"] as? String,
            stateName: state?["name"] as? String,
            stateType: state?["type"] as? String,
            completedAt: parseDate(issue["completedAt"]),
            stateColor: state?["color"] as? String)
    }

    static func parseIssuePriorityUpdate(_ data: Data) throws {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LinearAPIError.decoding
        }
        if let errors = root["errors"] as? [[String: Any]], !errors.isEmpty {
            if containsUnauthorizedGraphQLError(errors) { throw LinearAPIError.unauthorized }
            throw LinearAPIError.decoding
        }
        guard let dataObj = root["data"] as? [String: Any],
              let payload = dataObj["issueUpdate"] as? [String: Any],
              payload["success"] as? Bool == true,
              let issue = payload["issue"] as? [String: Any],
              let id = issue["id"] as? String, !id.isEmpty
        else { throw LinearAPIError.decoding }
        _ = id
    }

    static func parseCommentCreate(_ data: Data) throws {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LinearAPIError.decoding
        }
        if let errors = root["errors"] as? [[String: Any]], !errors.isEmpty {
            if containsUnauthorizedGraphQLError(errors) { throw LinearAPIError.unauthorized }
            throw LinearAPIError.decoding
        }
        guard let dataObj = root["data"] as? [String: Any],
              let payload = dataObj["commentCreate"] as? [String: Any],
              payload["success"] as? Bool == true,
              let comment = payload["comment"] as? [String: Any],
              let id = comment["id"] as? String, !id.isEmpty
        else { throw LinearAPIError.decoding }
    }

    /// XP is granted only when an issue *enters* a completed state.
    static func creditedCompletion(
        wasCompleted: Bool,
        update: LinearIssueStateUpdate
    ) -> LinearCompletedIssue? {
        guard !wasCompleted, (update.stateType ?? "").lowercased() == "completed" else {
            return nil
        }
        return LinearCompletedIssue(
            id: update.id,
            identifier: update.identifier,
            title: update.title,
            completedAt: update.completedAt ?? Date())
    }

    static func parseCompleteIssue(_ data: Data) throws -> LinearCompletedIssue {
        let update = try parseIssueStateUpdate(data)
        return LinearCompletedIssue(
            id: update.id,
            identifier: update.identifier,
            title: update.title,
            completedAt: update.completedAt ?? Date())
    }

    static func parseIssueDashboard(_ data: Data) throws -> LinearIssueDashboard {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LinearAPIError.decoding
        }
        if let errors = root["errors"] as? [[String: Any]], !errors.isEmpty {
            if containsUnauthorizedGraphQLError(errors) { throw LinearAPIError.unauthorized }
        }
        guard let dataObj = root["data"] as? [String: Any],
              let completedPayload = dataObj["completedRecent"] as? [String: Any],
              let completedNodes = completedPayload["nodes"] as? [[String: Any]],
              let inProgressPayload = dataObj["inProgress"] as? [String: Any],
              let inProgressNodes = inProgressPayload["nodes"] as? [[String: Any]]
        else { throw LinearAPIError.decoding }

        let completed = try completedNodes.map(parseIssueSummary)
        let inProgress = try inProgressNodes
            .map(parseIssueSummary)
            .filter(isInProgressIssue)
        let plannedNodes = (dataObj["planned"] as? [String: Any])?["nodes"] as? [[String: Any]] ?? []
        let planned = try plannedNodes.map(parseIssueSummary).filter(isPlannedIssue)
        let todoNodes = (dataObj["todo"] as? [String: Any])?["nodes"] as? [[String: Any]] ?? []
        let todo = try todoNodes.map(parseIssueSummary).filter(isTodoIssue)
        let projects = parseProjects(dataObj["projects"])
        let initiatives = parseInitiatives(dataObj["initiatives"])
        return hydrateTeamStates(
            LinearIssueDashboard(
                completedRecent: sortedByPriority(completed),
                inProgress: sortedByPriority(inProgress),
                projects: keptProjects(projects),
                initiatives: keptInitiatives(initiatives),
                planned: sortedByPriority(planned),
                todo: sortedByPriority(todo)))
    }

    private struct LinearContainerOverlay {
        var projects: [LinearProjectSummary]
        var initiatives: [LinearInitiativeSummary]
        var nextProjectsCursor: String?
    }

    /// Nil means this payload is incomplete (field error / missing collections) — try the next query.
    private static func parseContainerOverlay(_ data: Data) throws -> LinearContainerOverlay? {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LinearAPIError.decoding
        }
        if let errors = root["errors"] as? [[String: Any]], !errors.isEmpty {
            if containsUnauthorizedGraphQLError(errors) { throw LinearAPIError.unauthorized }
            if containerAttemptFailed(errors: errors, data: root["data"] as? [String: Any]) {
                return nil
            }
        }
        guard let dataObj = root["data"] as? [String: Any] else { return nil }
        let hasProjects = (dataObj["projects"] as? [String: Any])?["nodes"] is [[String: Any]]
        let hasInitiatives = (dataObj["initiatives"] as? [String: Any])?["nodes"] is [[String: Any]]
        guard hasProjects || hasInitiatives else { return nil }

        let projects = parseProjects(dataObj["projects"])
        let initiatives = parseInitiatives(
            dataObj["initiatives"],
            projectIssuesByID: projectIssueIndex(projects))
        return LinearContainerOverlay(
            projects: keptProjects(projects),
            initiatives: keptInitiatives(initiatives),
            nextProjectsCursor: try nextCursor(dataObj["projects"] as? [String: Any]))
    }

    private static func merging(
        _ dashboard: LinearIssueDashboard,
        _ overlay: LinearContainerOverlay
    ) -> LinearIssueDashboard {
        var copy = dashboard
        copy.projects = overlay.projects
        copy.initiatives = overlay.initiatives
        return copy
    }

    /// Container queries return a small preview. Include Todo and Planned issues fetched by the
    /// status query even when they fall outside that preview, matching stable IDs.
    static func includingQueuedIssuesInContainers(_ dashboard: LinearIssueDashboard) -> LinearIssueDashboard {
        func merged(_ issues: [LinearIssueSummary], projectIDs: Set<String>) -> [LinearIssueSummary] {
            let queued = (dashboard.planned + dashboard.todo).filter { issue in
                issue.projectID.map { projectIDs.contains($0) } == true
            }
            let queuedIDs = Set(queued.map(\.id))
            return sortedByPriority(issues.filter { !queuedIDs.contains($0.id) } + queued)
        }
        var copy = dashboard
        copy.projects = dashboard.projects.map { project in
            var next = project
            next.issues = merged(project.issues, projectIDs: [project.id])
            return next
        }
        copy.initiatives = dashboard.initiatives.map { initiative in
            var next = initiative
            next.issues = merged(initiative.issues, projectIDs: Set(initiative.projectIDs))
            return next
        }
        return copy
    }

    private static func keptProjects(_ projects: [LinearProjectSummary]) -> [LinearProjectSummary] {
        projects
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private static func keptInitiatives(
        _ initiatives: [LinearInitiativeSummary]
    ) -> [LinearInitiativeSummary] {
        initiatives
            .filter { shouldKeepInitiative(name: $0.statusName) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private static func projectIssueIndex(
        _ projects: [LinearProjectSummary]
    ) -> [String: [LinearIssueSummary]] {
        var map: [String: [LinearIssueSummary]] = [:]
        for project in projects { map[project.id] = project.issues }
        return map
    }

    private static func containerAttemptFailed(errors: [[String: Any]], data: [String: Any]?) -> Bool {
        for error in errors {
            if let extensions = error["extensions"] as? [String: Any],
               let code = (extensions["code"] as? String)?.uppercased(),
               code.contains("COMPLEXITY") || code == "RATELIMITED"
            {
                return true
            }
            if let message = error["message"] as? String {
                let normalized = message.lowercased()
                if normalized.contains("too complex") || normalized.contains("query complexity") {
                    return true
                }
            }
            if let path = error["path"] as? [Any], let field = path.first as? String,
               field == "projects" || field == "initiatives"
            {
                let nodes = (data?[field] as? [String: Any])?["nodes"]
                if nodes == nil { return true }
            }
        }
        return false
    }

    static func hydrateCompletedStateIDs(_ dashboard: LinearIssueDashboard) -> LinearIssueDashboard {
        hydrateTeamStates(dashboard)
    }

    static func hydrateTeamStates(_ dashboard: LinearIssueDashboard) -> LinearIssueDashboard {
        var byTeam: [String: [LinearWorkflowState]] = [:]
        func ingest(_ issues: [LinearIssueSummary]) {
            for issue in issues {
                guard let teamID = issue.teamID, !issue.teamStates.isEmpty else { continue }
                byTeam[teamID] = issue.teamStates
            }
        }
        ingest(dashboard.completedRecent)
        ingest(dashboard.inProgress)
        ingest(dashboard.planned)
        ingest(dashboard.todo)
        ingest(dashboard.relatedIssues)
        for project in dashboard.projects { ingest(project.issues) }
        for initiative in dashboard.initiatives { ingest(initiative.issues) }
        return assigningTeamStates(dashboard, from: byTeam)
    }

    static func missingTeamIDs(in dashboard: LinearIssueDashboard) -> [String] {
        var seen = Set<String>()
        var ids: [String] = []
        func walk(_ issues: [LinearIssueSummary]) {
            for issue in issues {
                guard let teamID = issue.teamID, issue.teamStates.isEmpty,
                      seen.insert(teamID).inserted
                else { continue }
                ids.append(teamID)
            }
        }
        walk(dashboard.completedRecent)
        walk(dashboard.inProgress)
        walk(dashboard.planned)
        walk(dashboard.todo)
        walk(dashboard.relatedIssues)
        for project in dashboard.projects { walk(project.issues) }
        for initiative in dashboard.initiatives { walk(initiative.issues) }
        return ids
    }

    static func assigningTeamStates(
        _ dashboard: LinearIssueDashboard,
        from byTeam: [String: [LinearWorkflowState]]
    ) -> LinearIssueDashboard {
        guard !byTeam.isEmpty else { return dashboard }

        func fill(_ issues: [LinearIssueSummary]) -> [LinearIssueSummary] {
            issues.map { issue in
                var copy = issue
                if copy.teamStates.isEmpty,
                   let teamID = issue.teamID,
                   let states = byTeam[teamID],
                   !states.isEmpty
                {
                    copy.teamStates = states
                }
                if copy.completedStateId == nil {
                    copy.completedStateId = completedStateID(from: copy.teamStates)
                }
                return copy
            }
        }

        var copy = dashboard
        copy.completedRecent = fill(dashboard.completedRecent)
        copy.inProgress = fill(dashboard.inProgress)
        copy.planned = fill(dashboard.planned)
        copy.todo = fill(dashboard.todo)
        copy.relatedIssues = fill(dashboard.relatedIssues)
        copy.projects = dashboard.projects.map { project in
            var next = project
            next.issues = fill(project.issues)
            return next
        }
        copy.initiatives = dashboard.initiatives.map { initiative in
            var next = initiative
            next.issues = fill(initiative.issues)
            return next
        }
        return copy
    }

    static func parseTeamStatesByID(_ data: Data) throws -> [String: [LinearWorkflowState]] {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LinearAPIError.decoding
        }
        if let errors = root["errors"] as? [[String: Any]], !errors.isEmpty {
            if containsUnauthorizedGraphQLError(errors) { throw LinearAPIError.unauthorized }
            throw LinearAPIError.decoding
        }
        guard let dataObj = root["data"] as? [String: Any] else { throw LinearAPIError.decoding }
        let nodes = ((dataObj["teams"] as? [String: Any])?["nodes"] as? [[String: Any]]) ?? []
        var map: [String: [LinearWorkflowState]] = [:]
        for node in nodes {
            guard let id = node["id"] as? String, !id.isEmpty else { continue }
            let states = parseWorkflowStates(from: node)
            if !states.isEmpty { map[id] = states }
        }
        return map
    }

    static func sortedWorkflowStates(_ states: [LinearWorkflowState]) -> [LinearWorkflowState] {
        let allPositioned = states.allSatisfy { $0.position != nil }
        return states.sorted { a, b in
            if allPositioned, let pa = a.position, let pb = b.position, pa != pb {
                return pa < pb
            }
            let ta = workflowTypeRank(a.type)
            let tb = workflowTypeRank(b.type)
            if ta != tb { return ta < tb }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }

    static func workflowTypeRank(_ type: String) -> Int {
        switch type.lowercased() {
        case "triage": return 0
        case "backlog": return 1
        case "unstarted": return 2
        case "started": return 3
        case "completed": return 4
        case "canceled", "cancelled": return 5
        default: return 6
        }
    }

    static func sortedByPriority(_ issues: [LinearIssueSummary]) -> [LinearIssueSummary] {
        issues.sorted { a, b in
            let pa = prioritySortValue(a.priority)
            let pb = prioritySortValue(b.priority)
            if pa != pb { return pa < pb }
            let ua = a.updatedAt ?? .distantPast
            let ub = b.updatedAt ?? .distantPast
            if ua != ub { return ua > ub }
            return a.identifier < b.identifier
        }
    }

    static func isInProgressContainer(name: String?, type: String?) -> Bool {
        let blocked: Set<String> = [
            "completed", "canceled", "cancelled", "planned", "backlog", "paused"
        ]
        let typeToken = type?.lowercased()
        let nameToken = name?.lowercased()
        if let typeToken {
            if blocked.contains(typeToken) { return false }
            if typeToken == "started" || typeToken == "active" { return true }
        }
        guard let nameToken, !nameToken.isEmpty else { return false }
        if blocked.contains(nameToken) { return false }
        return nameToken == "started" || nameToken == "active" || nameToken == "in progress"
    }

    /// Planned is a workspace status name, not every Todo/backlog workflow state.
    static func isPlannedIssue(_ issue: LinearIssueSummary) -> Bool {
        let type = issue.stateType?.lowercased()
        return type != "completed" && type != "canceled" && type != "cancelled"
            && statusTokens(name: issue.stateName, type: nil).contains("planned")
    }

    /// Todo is a named status, not the entire unstarted/backlog category.
    static func isTodoIssue(_ issue: LinearIssueSummary) -> Bool {
        let type = issue.stateType?.lowercased()
        return type != "completed" && type != "canceled" && type != "cancelled"
            && statusTokens(name: issue.stateName, type: nil).contains("todo")
    }

    /// Other started states, such as Waiting or In Review, belong outside this named tab.
    static func isInProgressIssue(_ issue: LinearIssueSummary) -> Bool {
        issue.stateType?.lowercased() == "started" && statusTokens(name: issue.stateName, type: nil).contains("in progress")
    }

    /// Linear workspaces often use a custom project status named Production.
    static func matchesProjectProduction(name: String?, type: String?) -> Bool {
        statusTokens(name: name, type: type).contains {
            $0 == "production" || $0 == "in production"
        }
    }

    static func matchesProjectInProgressTab(name: String?, type: String?) -> Bool {
        guard !matchesProjectProduction(name: name, type: type) else { return false }
        return isInProgressContainer(name: name, type: type)
    }

    static func matchesInitiativeActive(name: String?) -> Bool {
        (name ?? "").lowercased() == "active"
    }

    static func matchesInitiativePlanned(name: String?) -> Bool {
        (name ?? "").lowercased() == "planned"
    }

    static func shouldKeepInitiative(name: String?) -> Bool {
        matchesInitiativeActive(name: name) || matchesInitiativePlanned(name: name)
    }

    private static func statusTokens(name: String?, type: String?) -> [String] {
        [name, type].compactMap { token in
            let trimmed = token?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
            return trimmed.isEmpty ? nil : trimmed
        }
    }

    static func completedStateID(from team: [String: Any]?) -> String? {
        completedStateID(from: parseWorkflowStates(from: team))
    }

    static func completedStateID(from states: [LinearWorkflowState]) -> String? {
        let completed = states.filter { $0.type.lowercased() == "completed" }
        if let done = completed.first(where: { $0.name.lowercased() == "done" }) {
            return done.id
        }
        return completed.first?.id
    }

    static func parseWorkflowStates(from team: [String: Any]?) -> [LinearWorkflowState] {
        let nodes = ((team?["states"] as? [String: Any])?["nodes"] as? [[String: Any]]) ?? []
        let parsed: [LinearWorkflowState] = nodes.compactMap { node in
            guard let id = node["id"] as? String, !id.isEmpty,
                  let name = node["name"] as? String, !name.isEmpty
            else { return nil }
            return LinearWorkflowState(
                id: id,
                name: name,
                type: (node["type"] as? String) ?? "",
                position: parseDouble(node["position"]))
        }
        return sortedWorkflowStates(parsed)
    }

    private static func parseProjects(_ raw: Any?) -> [LinearProjectSummary] {
        let nodes = ((raw as? [String: Any])?["nodes"] as? [[String: Any]]) ?? []
        return nodes.compactMap { node in
            guard let id = node["id"] as? String, !id.isEmpty,
                  let name = node["name"] as? String, !name.isEmpty
            else { return nil }
            let status = parsedStatus(node["status"] ?? node["state"])
            let issues = openIssues(from: node["issues"])
            func badges(_ key: String) -> [LinearProjectBadge] {
                let nodes = (node[key] as? [String: Any])?["nodes"] as? [[String: Any]] ?? []
                var seen = Set<String>()
                return nodes.compactMap { raw in
                    let value = key == "needs" ? (raw["customer"] as? [String: Any] ?? [:]) : raw
                    guard let id = value["id"] as? String, let name = value["name"] as? String,
                          !name.isEmpty, seen.insert(id).inserted else { return nil }
                    return LinearProjectBadge(id: id, name: key == "teams" ? (value["key"] as? String ?? name) : name,
                        icon: value["icon"] as? String, color: value["color"] as? String,
                        imageURL: (value["logoUrl"] as? String).flatMap(URL.init(string:)),
                        date: parseDate(value["targetDate"]), status: value["status"] as? String)
                }
            }
            return LinearProjectSummary(
                id: id,
                name: name,
                url: (node["url"] as? String).flatMap(URL.init(string:)),
                statusName: status.name,
                statusType: status.type,
                leadName: (node["lead"] as? [String: Any])?["name"] as? String,
                targetDate: parseDate(node["targetDate"]),
                descriptionText: node["description"] as? String,
                issues: sortedByPriority(issues),
                identifier: node["identifier"] as? String,
                icon: node["icon"] as? String, color: node["color"] as? String,
                statusColor: (node["status"] as? [String: Any])?["color"] as? String,
                health: node["health"] as? String, priority: node["priority"] as? Int,
                leadAvatarURL: ((node["lead"] as? [String: Any])?["avatarUrl"] as? String).flatMap(URL.init(string:)),
                startDate: parseDate(node["startDate"]),
                startDateResolution: node["startDateResolution"] as? String,
                targetDateResolution: node["targetDateResolution"] as? String,
                issueCount: (node["currentProgress"] as? [String: Any])?["scopeCount"] as? Int,
                teams: badges("teams"), initiatives: badges("initiatives"), labels: badges("labels"),
                milestones: badges("projectMilestones"), customers: badges("needs"),
                statusID: (node["status"] as? [String: Any])?["id"] as? String,
                statusPosition: parseDouble((node["status"] as? [String: Any])?["position"]),
                createdAt: parseDate(node["createdAt"]), updatedAt: parseDate(node["updatedAt"]))
        }
    }

    private static func parseInitiatives(
        _ raw: Any?,
        projectIssuesByID: [String: [LinearIssueSummary]] = [:]
    ) -> [LinearInitiativeSummary] {
        let nodes = ((raw as? [String: Any])?["nodes"] as? [[String: Any]]) ?? []
        return nodes.compactMap { node in
            guard let id = node["id"] as? String, !id.isEmpty,
                  let name = node["name"] as? String, !name.isEmpty
            else { return nil }
            let status = parsedStatus(node["status"] ?? node["state"])
            let projectConnection = node["projects"] as? [String: Any]
            var projectIDs = Set<String>()
            let projectNodes = (projectConnection?["nodes"] as? [[String: Any]] ?? []).filter {
                guard let id = $0["id"] as? String else { return false }
                return projectIDs.insert(id).inserted
            }
            let complete = (projectConnection?["pageInfo"] as? [String: Any])?["hasNextPage"] as? Bool == false
            // Linear rolls up reported health even for planned/completed projects; a started
            // project without an update gets the gray indicator. Unstarted/no-update work is blank.
            let active = projectNodes.filter { $0["health"] is String || parsedStatus($0["status"]).type == "started" }
            let healthCounts = Dictionary(grouping: active) { $0["health"] as? String ?? "unknown" }.mapValues(\.count)
            let team = node["leadTeam"] as? [String: Any]
            let labels = ((node["labels"] as? [String: Any])?["nodes"] as? [[String: Any]] ?? []).compactMap { label -> LinearProjectBadge? in
                guard let id = label["id"] as? String, let name = label["name"] as? String else { return nil }
                return LinearProjectBadge(id: id, name: name, color: label["color"] as? String,
                    groupName: (label["parent"] as? [String: Any])?["name"] as? String)
            }
            var issues: [LinearIssueSummary] = []
            var seen = Set<String>()
            for project in projectNodes {
                if let projectID = project["id"] as? String,
                   let extras = projectIssuesByID[projectID]
                {
                    for issue in extras where seen.insert(issue.id).inserted {
                        issues.append(issue)
                    }
                }
                for issue in openIssues(from: project["issues"]) where seen.insert(issue.id).inserted {
                    issues.append(issue)
                }
            }
            return LinearInitiativeSummary(
                id: id,
                name: name,
                url: (node["url"] as? String).flatMap(URL.init(string:)),
                statusName: status.name ?? status.type,
                ownerName: (node["owner"] as? [String: Any])?["name"] as? String,
                targetDate: parseDate(node["targetDate"]),
                descriptionText: node["description"] as? String,
                issues: sortedByPriority(issues),
                projectIDs: projectNodes.compactMap { $0["id"] as? String },
                icon: node["icon"] as? String, color: node["color"] as? String,
                priority: node["priority"] as? Int, health: node["health"] as? String,
                ownerAvatarURL: ((node["owner"] as? [String: Any])?["avatarUrl"] as? String).flatMap(URL.init(string:)),
                leadTeam: (team?["id"] as? String).map { LinearProjectBadge(id: $0,
                    name: team?["key"] as? String ?? team?["name"] as? String ?? "",
                    icon: team?["icon"] as? String, color: team?["color"] as? String) },
                targetDateResolution: node["targetDateResolution"] as? String, labels: labels,
                projectCount: complete ? projectNodes.count : nil,
                completedProjectCount: complete ? projectNodes.filter { parsedStatus($0["status"]).type == "completed" }.count : nil,
                activeProjectHealthCounts: complete ? healthCounts : [:])
        }
    }

    private static func openIssues(from raw: Any?) -> [LinearIssueSummary] {
        let nodes = ((raw as? [String: Any])?["nodes"] as? [[String: Any]]) ?? []
        return nodes.compactMap { try? parseIssueSummary($0) }
            .filter {
                let type = $0.stateType?.lowercased()
                return type != "completed" && type != "canceled"
            }
    }

    private static func parsedStatus(_ raw: Any?) -> (name: String?, type: String?) {
        if let text = raw as? String { return (text, text) }
        if let object = raw as? [String: Any] {
            return (object["name"] as? String, object["type"] as? String ?? object["name"] as? String)
        }
        return (nil, nil)
    }

    static func parseIssueSummary(_ node: [String: Any]) throws -> LinearIssueSummary {
        guard let id = node["id"] as? String, !id.isEmpty,
              let identifier = node["identifier"] as? String, !identifier.isEmpty,
              let title = node["title"] as? String, !title.isEmpty
        else { throw LinearAPIError.decoding }

        let state = node["state"] as? [String: Any]
        let assignee = node["assignee"] as? [String: Any]
        let project = node["project"] as? [String: Any]
        let team = node["team"] as? [String: Any]
        let labels = ((node["labels"] as? [String: Any])?["nodes"] as? [[String: Any]]) ?? []
        let labelNames = labels.compactMap { $0["name"] as? String }
        let teamStates = parseWorkflowStates(from: team)

        return LinearIssueSummary(
            id: id,
            identifier: identifier,
            title: title,
            issueURL: (node["url"] as? String).flatMap(URL.init(string:)),
            priority: parseInt(node["priority"]),
            estimate: parseInt(node["estimate"]),
            stateId: state?["id"] as? String,
            stateName: state?["name"] as? String,
            stateType: state?["type"] as? String,
            assigneeName: assignee?["name"] as? String,
            assigneeEmail: assignee?["email"] as? String,
            projectName: project?["name"] as? String,
            teamName: team?["name"] as? String,
            teamKey: team?["key"] as? String,
            teamID: team?["id"] as? String,
            teamStates: teamStates,
            completedStateId: completedStateID(from: teamStates),
            labelNames: labelNames,
            createdAt: parseDate(node["createdAt"]),
            updatedAt: parseDate(node["updatedAt"]),
            dueDate: parseDate(node["dueDate"]),
            completedAt: parseDate(node["completedAt"]),
            descriptionText: node["description"] as? String,
            projectID: project?["id"] as? String,
            assigneeAvatarURL: (assignee?["avatarUrl"] as? String).flatMap(URL.init(string:)),
            stateColor: state?["color"] as? String,
            projectColor: project?["color"] as? String,
            labelColors: labels.reduce(into: [:]) { colors, label in
                if let name = label["name"] as? String, let color = label["color"] as? String {
                    colors[name] = color
                }
            },
            startedAt: parseDate(node["startedAt"]),
            cycleName: (node["cycle"] as? [String: Any])?["name"] as? String,
            cycleNumber: parseInt((node["cycle"] as? [String: Any])?["number"]),
            milestoneName: (node["projectMilestone"] as? [String: Any])?["name"] as? String,
            parentID: (node["parent"] as? [String: Any])?["id"] as? String,
            hasSubIssues: !(((node["children"] as? [String: Any])?["nodes"] as? [Any]) ?? []).isEmpty)
    }

    private static func prioritySortValue(_ priority: Int?) -> Int {
        guard let priority, priority > 0 else { return Int.max }
        return priority
    }

    private static func parseInt(_ raw: Any?) -> Int? {
        (raw as? Int) ?? (raw as? NSNumber)?.intValue
    }

    private static func parseDouble(_ raw: Any?) -> Double? {
        if let value = raw as? Double { return value }
        if let value = raw as? Int { return Double(value) }
        return (raw as? NSNumber)?.doubleValue
    }

    private static func parseDate(_ raw: Any?) -> Date? {
        guard let raw = raw as? String, !raw.isEmpty else { return nil }
        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plainISO = ISO8601DateFormatter()
        if let value = withFractional.date(from: raw) ?? plainISO.date(from: raw) {
            return value
        }
        let dayOnly = DateFormatter()
        dayOnly.locale = Locale(identifier: "en_US_POSIX")
        dayOnly.timeZone = TimeZone(secondsFromGMT: 0)
        dayOnly.dateFormat = "yyyy-MM-dd"
        return dayOnly.date(from: raw)
    }

    static func containsUnauthorizedGraphQLError(_ errors: [[String: Any]]) -> Bool {
        for error in errors {
            if let extensions = error["extensions"] as? [String: Any],
               let code = extensions["code"] as? String {
                let normalized = code.lowercased()
                if normalized.contains("auth") || normalized.contains("unauthorized")
                    || normalized.contains("forbidden")
                {
                    return true
                }
            }
            if let message = error["message"] as? String {
                let normalized = message.lowercased()
                if normalized.contains("unauthorized") || normalized.contains("forbidden")
                    || normalized.contains("invalid token") || normalized.contains("invalid api key")
                    || normalized.contains("authentication") || normalized.contains("auth token")
                {
                    return true
                }
            }
        }
        return false
    }

    /// Pure parser — unit-tested without network.
    static func parseCompletedIssues(_ data: Data) throws -> [LinearCompletedIssue] {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataObj = root["data"] as? [String: Any],
              let issues = dataObj["issues"] as? [String: Any],
              let nodes = issues["nodes"] as? [[String: Any]]
        else { throw LinearAPIError.decoding }

        return try nodes.compactMap { node in
            guard let id = node["id"] as? String, !id.isEmpty,
                  let identifier = node["identifier"] as? String, !identifier.isEmpty,
                  let title = node["title"] as? String, !title.isEmpty,
                  let completedAt = parseDate(node["completedAt"])
            else { throw LinearAPIError.decoding }
            return LinearCompletedIssue(
                id: id, identifier: identifier, title: title, completedAt: completedAt)
        }
    }

    static func parseCompletedProjects(_ data: Data) throws -> [LinearCompletedProject] {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataObj = root["data"] as? [String: Any],
              let projects = dataObj["projects"] as? [String: Any],
              let nodes = projects["nodes"] as? [[String: Any]]
        else { throw LinearAPIError.decoding }

        return try nodes.compactMap { node in
            guard let id = node["id"] as? String, !id.isEmpty,
                  let name = node["name"] as? String, !name.isEmpty
            else { throw LinearAPIError.decoding }
            let completedAt = parseDate(node["completedAt"]) ?? Date(timeIntervalSince1970: 0)
            return LinearCompletedProject(id: id, name: name, completedAt: completedAt)
        }
    }
}

/// Pure reward math for Linear completions → companion XP.
enum LinearRewards {
    /// XP per newly completed issue (also shop XP → Coins).
    static let xpPerIssue = 2_000_000
    /// Completing a project is a big packet, not another issue-sized tick.
    static let xpPerProject = 20_000_000
    /// How far back to look for completions on each poll.
    static let lookbackDays = 14
    /// Cap persisted credited IDs so saves stay bounded.
    static let maxCreditedIDs = 500

    struct Outcome: Equatable {
        var xp: Int
        var creditedIDs: [String]
        /// True when this was the first successful poll (seed without XP).
        var seeded: Bool
        var newlyCredited: [LinearCompletedIssue]
    }

    /// Deduped grant. First successful poll (`seeded == false`) records IDs with 0 XP
    /// so already-done issues do not dump a backfill.
    static func evaluate(
        issues: [LinearCompletedIssue],
        alreadyCredited: [String],
        seeded: Bool
    ) -> Outcome {
        var credited = alreadyCredited
        var creditedSet = Set(alreadyCredited)
        let fresh = issues.filter { !creditedSet.contains($0.id) }
        guard seeded else {
            for issue in fresh {
                credited.append(issue.id)
                creditedSet.insert(issue.id)
            }
            credited = Array(credited.suffix(maxCreditedIDs))
            return Outcome(xp: 0, creditedIDs: credited, seeded: true, newlyCredited: [])
        }
        guard !fresh.isEmpty else {
            return Outcome(xp: 0, creditedIDs: credited, seeded: true, newlyCredited: [])
        }
        for issue in fresh {
            credited.append(issue.id)
        }
        credited = Array(credited.suffix(maxCreditedIDs))
        let xp = fresh.count * xpPerIssue
        return Outcome(xp: xp, creditedIDs: credited, seeded: true, newlyCredited: fresh)
    }

    struct ProjectOutcome: Equatable {
        var xp: Int
        var creditedIDs: [String]
        var seeded: Bool
        var newlyCredited: [LinearCompletedProject]
    }

    static func evaluateProjects(
        projects: [LinearCompletedProject],
        alreadyCredited: [String],
        seeded: Bool
    ) -> ProjectOutcome {
        var credited = alreadyCredited
        var creditedSet = Set(alreadyCredited)
        let fresh = projects.filter { !creditedSet.contains($0.id) }
        guard seeded else {
            for project in fresh {
                credited.append(project.id)
                creditedSet.insert(project.id)
            }
            credited = Array(credited.suffix(maxCreditedIDs))
            return ProjectOutcome(xp: 0, creditedIDs: credited, seeded: true, newlyCredited: [])
        }
        guard !fresh.isEmpty else {
            return ProjectOutcome(xp: 0, creditedIDs: credited, seeded: true, newlyCredited: [])
        }
        for project in fresh {
            credited.append(project.id)
        }
        credited = Array(credited.suffix(maxCreditedIDs))
        return ProjectOutcome(
            xp: fresh.count * xpPerProject,
            creditedIDs: credited,
            seeded: true,
            newlyCredited: fresh)
    }

    static func mergedCreditedIDs(_ a: [String], _ b: [String]) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for id in a + b {
            if seen.insert(id).inserted { out.append(id) }
        }
        return Array(out.suffix(maxCreditedIDs))
    }

    /// Persist XP only for issues that actually received it (`newlyCredited`). First id wins.
    static func appendingXPRecords(
        existing: [LinearIssueXPRecord],
        newlyCredited: [LinearCompletedIssue]
    ) -> [LinearIssueXPRecord] {
        var seen = Set(existing.map(\.id))
        var out = existing
        for issue in newlyCredited {
            guard seen.insert(issue.id).inserted else { continue }
            out.append(LinearIssueXPRecord(
                id: issue.id,
                identifier: issue.identifier,
                xp: xpPerIssue,
                awardedAt: issue.completedAt))
        }
        return Array(out.suffix(maxCreditedIDs))
    }

    static func mergingXPRecords(
        _ a: [LinearIssueXPRecord],
        _ b: [LinearIssueXPRecord]
    ) -> [LinearIssueXPRecord] {
        var seen = Set<String>()
        var out: [LinearIssueXPRecord] = []
        for record in a + b {
            if seen.insert(record.id).inserted { out.append(record) }
        }
        return Array(out.suffix(maxCreditedIDs))
    }

    static func xpRecord(in records: [LinearIssueXPRecord], id: String) -> LinearIssueXPRecord? {
        records.first { $0.id == id && $0.xp > 0 }
    }
}
