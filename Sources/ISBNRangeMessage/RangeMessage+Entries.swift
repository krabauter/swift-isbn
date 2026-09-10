extension RangeMessage {
    /// A range of ISBNs whose registrant elements have the same length
    package struct Entry: Hashable, Sendable {
        /// The first 12 digits of the lowest ISBN in the range
        package var lowerBound: UInt64

        /// The first 12 digits of the highest ISBN in the range
        package var upperBound: UInt64

        /// The length of the registration group element
        package var groupLength: Int

        /// The length of the registrant element
        package var registrantLength: Int

        /// The prefix of the registration group, e.g. `978-3`
        package var prefix: String

        /// The name of the registration group, e.g. `German language`
        package var agency: String
    }

    /// Returns the assigned ranges of all registration groups sorted by their lower bounds.
    ///
    /// - Throws: A ``RangeMessageError`` if the range message is inconsistent.
    package func entries() throws -> [Entry] {
        var entries: [Entry] = []
        for group in groups {
            let elements = group.prefix.split(separator: "-", omittingEmptySubsequences: false)
            // The registration group 979-0 is reserved for International Standard Music Numbers (ISMN).
            guard elements.count == 2, elements[0] == "978" || elements[0] == "979",
                  (1...5).contains(elements[1].count), elements[1].allSatisfy(\.isASCIIDigit),
                  !(elements[0] == "979" && elements[1].hasPrefix("0")) else {
                throw RangeMessageError("Invalid prefix '\(group.prefix)'.")
            }
            guard !group.agency.isEmpty else {
                throw RangeMessageError("The registration group \(group.prefix) has no name.")
            }
            // The registrant and publication elements share the digits between the group element and the check digit.
            let availableLength = 9 - elements[1].count
            let groupStart = UInt64(elements[0] + elements[1])! * powerOfTen(availableLength)

            for rule in group.rules {
                let bounds = rule.range.split(separator: "-", omittingEmptySubsequences: false)
                guard bounds.count == 2, bounds.allSatisfy({ $0.count == 7 && $0.allSatisfy(\.isASCIIDigit) }), bounds[0] <= bounds[1] else {
                    throw RangeMessageError("Invalid range '\(rule.range)' in registration group \(group.prefix).")
                }
                guard rule.length != 0 else {
                    continue
                }
                guard (1..<availableLength).contains(rule.length) else {
                    throw RangeMessageError("Invalid registrant length \(rule.length) for the range \(rule.range) in registration group \(group.prefix).")
                }
                // The ranges are padded to seven digits; only the first `length` digits are significant.
                guard bounds[0].dropFirst(rule.length).allSatisfy({ $0 == "0" }),
                      bounds[1].dropFirst(rule.length).allSatisfy({ $0 == "9" }) else {
                    throw RangeMessageError("The range \(rule.range) in registration group \(group.prefix) doesn't align with the registrant length \(rule.length).")
                }
                let scale = powerOfTen(availableLength - rule.length)
                entries.append(Entry(
                    lowerBound: groupStart + UInt64(bounds[0].prefix(rule.length))! * scale,
                    upperBound: groupStart + (UInt64(bounds[1].prefix(rule.length))! + 1) * scale - 1,
                    groupLength: elements[1].count,
                    registrantLength: rule.length,
                    prefix: group.prefix,
                    agency: group.agency
                ))
            }
        }

        entries.sort { $0.lowerBound < $1.lowerBound }
        for (entry, next) in zip(entries, entries.dropFirst()) where entry.upperBound >= next.lowerBound {
            let groups = entry.prefix == next.prefix ? "group \(entry.prefix)" : "groups \(entry.prefix) and \(next.prefix)"
            throw RangeMessageError("Overlapping ranges in the registration \(groups).")
        }
        return entries
    }
}

private func powerOfTen(_ exponent: Int) -> UInt64 {
    (0..<exponent).reduce(1) { result, _ in result * 10 }
}

private extension Character {
    var isASCIIDigit: Bool {
        asciiValue.map { (0x30...0x39).contains($0) } ?? false
    }
}
