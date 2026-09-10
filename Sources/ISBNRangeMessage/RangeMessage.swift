import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

/// The registration ranges of ISBNs as published by the International ISBN Agency in `RangeMessage.xml`
package struct RangeMessage: Hashable, Sendable {
    /// A registration group, e.g. `978-3` for the German language
    package struct Group: Hashable, Sendable {
        /// The EAN.UCC prefix and the registration group element separated by a hyphen, e.g. `978-3`
        package var prefix: String

        /// The name of the registration group, e.g. `German language`
        package var agency: String

        /// The rules for the registrant elements of the registration group
        package var rules: [Rule]

        package init(prefix: String, agency: String, rules: [Rule]) {
            self.prefix = prefix
            self.agency = agency
            self.rules = rules
        }
    }

    /// A range of registrant elements with the same length
    package struct Rule: Hashable, Sendable {
        /// The range of the seven digits following the registration group element, e.g. `0000000-1999999`
        package var range: String

        /// The length of the registrant elements in the range, or 0 if the range is not assigned
        package var length: Int

        package init(range: String, length: Int) {
            self.range = range
            self.length = length
        }
    }

    /// The source of the range message, e.g. `International ISBN Agency`
    package var source: String

    /// The date of the range message, which is the time it was exported by the International ISBN Agency
    package var date: String

    /// The registration groups of the range message
    package var groups: [Group]

    package init(source: String = "", date: String = "", groups: [Group]) {
        self.source = source
        self.date = date
        self.groups = groups
    }
}

/// An error in a range message
package struct RangeMessageError: Error, Equatable, CustomStringConvertible {
    package var description: String

    package init(_ description: String) {
        self.description = description
    }
}

extension RangeMessage {
    /// Parses a range message from its XML representation.
    package init(xml: Data) throws {
        let delegate = ParserDelegate()
        let parser = XMLParser(data: xml)
        parser.delegate = delegate
        guard parser.parse() else {
            throw delegate.error ?? RangeMessageError(
                "Malformed range message at line \(parser.lineNumber): \(parser.parserError?.localizedDescription ?? "unknown error")"
            )
        }
        guard let date = delegate.date else {
            throw RangeMessageError("The range message has no message date.")
        }
        guard !delegate.groups.isEmpty else {
            throw RangeMessageError("The range message has no registration groups.")
        }
        self.init(source: delegate.source ?? "", date: date, groups: delegate.groups)
    }

    /// Returns the XML with Windows line endings replaced by Unix line endings.
    package static func normalizingLineEndings(of xml: Data) -> Data {
        Data(String(decoding: xml, as: UTF8.self).replacingOccurrences(of: "\r\n", with: "\n").utf8)
    }
}

private final class ParserDelegate: NSObject, XMLParserDelegate {
    private(set) var source: String?
    private(set) var date: String?
    private(set) var groups: [RangeMessage.Group] = []
    private(set) var error: RangeMessageError?

    private var path: [String] = []
    private var text = ""
    private var prefix: String?
    private var agency: String?
    private var rules: [RangeMessage.Rule] = []
    private var range: String?
    private var length: String?

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?,
        attributes: [String: String] = [:]
    ) {
        path.append(elementName)
        text = ""
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        // The text of an element may be reported in several chunks, e.g. around entities like `&apos;`.
        text += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        text = ""
        defer { path.removeLast() }

        // Elements are matched by their path, since `EAN.UCCPrefixes` uses the same element names as `RegistrationGroups`.
        switch path.joined(separator: "/") {
        case "ISBNRangeMessage/MessageSource":
            source = value
        case "ISBNRangeMessage/MessageDate":
            date = value
        case "ISBNRangeMessage/RegistrationGroups/Group/Prefix":
            prefix = value
        case "ISBNRangeMessage/RegistrationGroups/Group/Agency":
            agency = value
        case "ISBNRangeMessage/RegistrationGroups/Group/Rules/Rule/Range":
            range = value
        case "ISBNRangeMessage/RegistrationGroups/Group/Rules/Rule/Length":
            length = value
        case "ISBNRangeMessage/RegistrationGroups/Group/Rules/Rule":
            guard let range, let length = length.flatMap({ Int($0) }) else {
                return fail(parser, "Incomplete rule in registration group \(prefix ?? "?") at line \(parser.lineNumber).")
            }
            rules.append(RangeMessage.Rule(range: range, length: length))
            self.range = nil
            self.length = nil
        case "ISBNRangeMessage/RegistrationGroups/Group":
            guard let prefix, let agency else {
                return fail(parser, "Incomplete registration group at line \(parser.lineNumber).")
            }
            groups.append(RangeMessage.Group(prefix: prefix, agency: agency, rules: rules))
            self.prefix = nil
            self.agency = nil
            rules = []
        default:
            break
        }
    }

    private func fail(_ parser: XMLParser, _ message: String) {
        error = RangeMessageError(message)
        parser.abortParsing()
    }
}
