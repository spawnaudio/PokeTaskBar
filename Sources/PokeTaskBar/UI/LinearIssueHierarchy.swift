import Foundation

/// Lift a matching child to its available parent, while preserving the caller's sort order.
enum LinearIssueHierarchy {
    static func includingAncestors(_ visible: [LinearIssueSummary], in all: [LinearIssueSummary]) -> [LinearIssueSummary] {
        let byID = Dictionary(all.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var result = visible
        var seen = Set(visible.map(\.id))
        for issue in visible {
            var parentID = issue.parentID
            while let id = parentID, let parent = byID[id], seen.insert(id).inserted {
                result.append(parent)
                parentID = parent.parentID
            }
        }
        return result
    }
    static func roots(_ visible: [LinearIssueSummary], in all: [LinearIssueSummary]) -> [LinearIssueSummary] {
        let byID = Dictionary(all.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var seen = Set<String>()
        return visible.compactMap { issue in
            var root = issue
            var path: Set<String> = [issue.id]
            while let parentID = root.parentID, let parent = byID[parentID] {
                guard path.insert(parentID).inserted else {
                    root = byID[path.min() ?? root.id] ?? root
                    break
                }
                root = parent
            }
            return seen.insert(root.id).inserted ? root : nil
        }
    }
}
