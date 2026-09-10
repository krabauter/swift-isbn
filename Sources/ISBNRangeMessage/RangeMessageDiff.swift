/// The changes between two range messages that affect the hyphenation of ISBNs
///
/// Changes of the message date or of unassigned ranges don't affect the hyphenation and are ignored.
package struct RangeMessageDiff: Equatable, Sendable {
    package enum Change: Equatable, Sendable {
        case added(RangeMessage.Group)
        case removed(RangeMessage.Group)
        case modified(old: RangeMessage.Group, new: RangeMessage.Group)
    }

    /// The changed registration groups in the order of their prefixes
    package var changes: [Change]

    package var isEmpty: Bool {
        changes.isEmpty
    }

    package init(from old: RangeMessage, to new: RangeMessage) {
        let oldGroups = old.assignedGroups
        let newGroups = new.assignedGroups
        // Prefixes don't overlap, so ordering their digits lexicographically orders the groups like their ranges.
        let prefixes = Set(oldGroups.keys).union(newGroups.keys).sorted { $0.filter(\.isNumber) < $1.filter(\.isNumber) }
        changes = []
        for prefix in prefixes {
            switch (oldGroups[prefix], newGroups[prefix]) {
            case (nil, let new?):
                changes.append(.added(new))
            case (let old?, nil):
                changes.append(.removed(old))
            case (let old?, let new?) where old != new:
                changes.append(.modified(old: old, new: new))
            default:
                break
            }
        }
    }
}

extension RangeMessageDiff {
    /// A commit message listing the changed registration groups
    package var commitMessage: String {
        (["Update ISBN ranges", ""] + summary).joined(separator: "\n") + "\n"
    }

    /// Release notes in Markdown listing the changed registration groups and their changed ranges
    package var releaseNotes: String {
        var lines = ["### Update ISBN ranges", ""] + summary
        let rangeChanges = changes.compactMap { $0.rangeChanges }
        if !rangeChanges.isEmpty {
            lines += ["", "<details>", "<summary>Changed ranges</summary>"]
            for (title, diff) in rangeChanges {
                lines += ["", "#### \(title)", "", "```diff"] + diff + ["```"]
            }
            lines += ["", "</details>"]
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private var summary: [String] {
        changes.map { change in
            switch change {
            case let .added(group):
                "- \(group.prefix) \(group.agency) (new)"
            case let .removed(group):
                "- \(group.prefix) \(group.agency) (removed)"
            case let .modified(old, new) where old.agency != new.agency:
                "- \(new.prefix) \(new.agency) (renamed from \(old.agency))"
            case let .modified(_, new):
                "- \(new.prefix) \(new.agency)"
            }
        }
    }
}

private extension RangeMessage {
    /// The registration groups by prefix with their assigned rules in ascending order
    var assignedGroups: [String: Group] {
        var assignedGroups: [String: Group] = [:]
        for group in groups {
            let rules = group.rules.filter { $0.length > 0 }.sorted { $0.range < $1.range }
            if !rules.isEmpty {
                assignedGroups[group.prefix] = Group(prefix: group.prefix, agency: group.agency, rules: rules)
            }
        }
        return assignedGroups
    }
}

private extension RangeMessageDiff.Change {
    var groups: (old: RangeMessage.Group?, new: RangeMessage.Group?) {
        switch self {
        case let .added(group):
            (nil, group)
        case let .removed(group):
            (group, nil)
        case let .modified(old, new):
            (old, new)
        }
    }

    /// The title and the lines of a diff of the assigned ranges, or `nil` if the ranges didn't change
    var rangeChanges: (title: String, diff: [String])? {
        let (old, new) = groups
        guard let group = new ?? old else {
            return nil
        }
        let oldRules = Set(old?.rules ?? [])
        let newRules = Set(new?.rules ?? [])
        let removed = oldRules.subtracting(newRules).map { rule in
            (lowerBound: rule.range.prefix(7), order: 0, line: "- \(group.prefix)-\(rule.registrants)")
        }
        let added = newRules.subtracting(oldRules).map { rule in
            (lowerBound: rule.range.prefix(7), order: 1, line: "+ \(group.prefix)-\(rule.registrants)")
        }
        guard !removed.isEmpty || !added.isEmpty else {
            return nil
        }
        let diff = (removed + added)
            .sorted { ($0.lowerBound, $0.order) < ($1.lowerBound, $1.order) }
            .map { $0.line }
        return ("\(group.prefix) \(group.agency)", diff)
    }
}

private extension RangeMessage.Rule {
    /// The registrant elements of the rule, e.g. `975–979`
    var registrants: String {
        let bounds = range.split(separator: "-")
        guard bounds.count == 2 else {
            return range
        }
        let lower = bounds[0].prefix(length)
        let upper = bounds[1].prefix(length)
        return lower == upper ? String(lower) : "\(lower)–\(upper)"
    }
}
