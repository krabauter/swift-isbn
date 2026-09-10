/// Generates the Swift source of the range table of the `ISBN` library
package enum RangeTableSource {
    /// Returns the contents of `Sources/ISBN/RangeTable+Entries.swift` for the given range message.
    ///
    /// - Throws: A ``RangeMessageError`` if the range message is inconsistent.
    package static func generate(from message: RangeMessage) throws -> String {
        let entries = try message.entries()
        var agencies: [String] = []
        var agencyIndices: [String: Int] = [:]
        for entry in entries where agencyIndices[entry.agency] == nil {
            agencyIndices[entry.agency] = agencies.count
            agencies.append(entry.agency)
        }
        guard agencies.count <= Int(UInt16.max) + 1 else {
            throw RangeMessageError("The range message has more registration group names than the range table supports.")
        }

        var lines = [
            "// This file is generated from Data/RangeMessage.xml by ISBNRegistrationGroupsUpdater. Do not edit it.",
            "// \(singleLine(message.source))",
            "// \(singleLine(message.date))",
            "",
            "extension RangeTable {",
            "    static let agencies: [String] = ["
        ]
        lines += agencies.map { "        \(stringLiteral($0))," }
        lines += [
            "    ]",
            "",
            "    static let entries: [Entry] = ["
        ]
        var prefix: String?
        for entry in entries {
            if entry.prefix != prefix {
                lines.append("        // \(entry.prefix) \(singleLine(entry.agency))")
                prefix = entry.prefix
            }
            let bounds = "\(integerLiteral(entry.lowerBound)), \(integerLiteral(entry.upperBound))"
            lines.append("        (\(bounds), \(entry.groupLength), \(entry.registrantLength), \(agencyIndices[entry.agency]!)),")
        }
        lines += [
            "    ]",
            "}"
        ]
        return lines.joined(separator: "\n") + "\n"
    }

    /// Returns a Swift string literal for the string.
    private static func stringLiteral(_ string: String) -> String {
        var literal = "\""
        for scalar in string.unicodeScalars {
            switch scalar {
            case "\"":
                literal += "\\\""
            case "\\":
                literal += "\\\\"
            case "\n":
                literal += "\\n"
            case "\r":
                literal += "\\r"
            case "\t":
                literal += "\\t"
            case _ where scalar.value < 0x20 || scalar.value == 0x7F:
                literal += "\\u{\(String(scalar.value, radix: 16))}"
            default:
                literal.unicodeScalars.append(scalar)
            }
        }
        return literal + "\""
    }

    /// Returns an integer literal with underscores between groups of three digits, e.g. `978_100_000_000`.
    private static func integerLiteral(_ value: UInt64) -> String {
        let digits = Array(String(value))
        var literal = ""
        for (index, digit) in digits.enumerated() {
            if index > 0 && (digits.count - index).isMultiple(of: 3) {
                literal.append("_")
            }
            literal.append(digit)
        }
        return literal
    }

    /// Returns the string with line breaks replaced by spaces, so that it fits into a comment.
    private static func singleLine(_ string: String) -> String {
        String(string.map { $0.isNewline ? " " : $0 })
    }
}
