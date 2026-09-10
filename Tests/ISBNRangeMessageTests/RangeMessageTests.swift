import Foundation
import ISBNRangeMessage
import Testing

@Suite("Range message")
struct RangeMessageTests {
    let message: RangeMessage

    init() throws {
        message = try RangeMessage(xml: Data(contentsOf: Paths.fixture("EdgeCases.xml")))
    }

    @Test("Parses the header and the registration groups, but not the EAN.UCC prefixes")
    func parsesRegistrationGroups() {
        #expect(message.source == "International ISBN Agency")
        #expect(message.date == "Thu, 10 Sep 2026 09:23:46 BST")
        #expect(message.groups.map(\.prefix) == ["978-1", "978-7", "978-611", "978-99904"])
    }

    @Test("Decodes entities and trims text reported in several chunks")
    func decodesEntities() {
        #expect(message.groups.map(\.agency) == ["English language", "China, People's Republic", "Thailand", "Curaçao"])
    }

    @Test("Keeps unassigned rules")
    func keepsUnassignedRules() {
        #expect(message.groups[0].rules == [
            .init(range: "0000000-0999999", length: 2),
            .init(range: "1000000-3999999", length: 0),
            .init(range: "4000000-5499999", length: 4),
            .init(range: "5500000-9999999", length: 5)
        ])
    }

    @Test("Normalizes line endings")
    func normalizesLineEndings() {
        let xml = Data("<a>\r\n<b/>\n</a>\r\n".utf8)
        #expect(RangeMessage.normalizingLineEndings(of: xml) == Data("<a>\n<b/>\n</a>\n".utf8))
    }

    @Test("Rejects malformed XML")
    func rejectsMalformedXML() {
        #expect(throws: RangeMessageError.self) {
            try RangeMessage(xml: Data("<ISBNRangeMessage><MessageDate>".utf8))
        }
    }

    @Test("Rejects incomplete range messages", arguments: [
        (
            "<ISBNRangeMessage><MessageDate>Today</MessageDate><RegistrationGroups/></ISBNRangeMessage>",
            "The range message has no registration groups."
        ),
        (
            "<ISBNRangeMessage><RegistrationGroups><Group><Prefix>978-1</Prefix><Agency>A</Agency><Rules/></Group></RegistrationGroups></ISBNRangeMessage>",
            "The range message has no message date."
        ),
        (
            "<ISBNRangeMessage><RegistrationGroups><Group><Prefix>978-1</Prefix><Rules/></Group></RegistrationGroups></ISBNRangeMessage>",
            "Incomplete registration group at line 1."
        ),
        (
            "<ISBNRangeMessage><RegistrationGroups><Group><Prefix>978-1</Prefix><Rules><Rule><Range>0000000-9999999</Range><Length>two</Length></Rule></Rules></Group></RegistrationGroups></ISBNRangeMessage>",
            "Incomplete rule in registration group 978-1 at line 1."
        )
    ])
    func rejectsIncompleteMessages(xml: String, error: String) {
        #expect(throws: RangeMessageError(error)) {
            try RangeMessage(xml: Data(xml.utf8))
        }
    }
}

@Suite("Range message entries")
struct RangeMessageEntriesTests {
    @Test("Computes the ranges of the assigned rules")
    func entries() throws {
        let entries = try RangeMessage(xml: Data(contentsOf: Paths.fixture("EdgeCases.xml"))).entries()
        #expect(entries.map { "\($0.prefix) \($0.lowerBound)...\($0.upperBound) \($0.groupLength) \($0.registrantLength)" } == [
            "978-1 978100000000...978109999999 1 2",
            "978-1 978140000000...978154999999 1 4",
            "978-1 978155000000...978199999999 1 5",
            "978-7 978700000000...978709999999 1 2",
            "978-7 978710000000...978749999999 1 3",
            "978-99904 978999040000...978999045999 5 1",
            "978-99904 978999046000...978999048999 5 2",
            "978-99904 978999049000...978999049999 5 3"
        ])
    }

    @Test("Rejects inconsistent registration groups", arguments: [
        (
            [RangeMessage.Group(prefix: "977-1", agency: "A", rules: [.init(range: "0000000-9999999", length: 2)])],
            "Invalid prefix '977-1'."
        ),
        (
            [RangeMessage.Group(prefix: "978-123456", agency: "A", rules: [.init(range: "0000000-9999999", length: 2)])],
            "Invalid prefix '978-123456'."
        ),
        (
            [RangeMessage.Group(prefix: "979-0", agency: "A", rules: [.init(range: "0000000-9999999", length: 2)])],
            "Invalid prefix '979-0'."
        ),
        (
            [RangeMessage.Group(prefix: "978-1", agency: "", rules: [.init(range: "0000000-9999999", length: 2)])],
            "The registration group 978-1 has no name."
        ),
        (
            [RangeMessage.Group(prefix: "978-1", agency: "A", rules: [.init(range: "000000-1999999", length: 2)])],
            "Invalid range '000000-1999999' in registration group 978-1."
        ),
        (
            [RangeMessage.Group(prefix: "978-1", agency: "A", rules: [.init(range: "1999999-0000000", length: 2)])],
            "Invalid range '1999999-0000000' in registration group 978-1."
        ),
        (
            [RangeMessage.Group(prefix: "978-99904", agency: "A", rules: [.init(range: "0000000-9999999", length: 4)])],
            "Invalid registrant length 4 for the range 0000000-9999999 in registration group 978-99904."
        ),
        (
            [RangeMessage.Group(prefix: "978-1", agency: "A", rules: [.init(range: "0000001-1999999", length: 2)])],
            "The range 0000001-1999999 in registration group 978-1 doesn't align with the registrant length 2."
        ),
        (
            [RangeMessage.Group(prefix: "978-1", agency: "A", rules: [.init(range: "0000000-1999999", length: 2), .init(range: "1000000-1999999", length: 3)])],
            "Overlapping ranges in the registration group 978-1."
        ),
        (
            [
                RangeMessage.Group(prefix: "978-1", agency: "A", rules: [.init(range: "0000000-9999999", length: 2)]),
                RangeMessage.Group(prefix: "978-19", agency: "B", rules: [.init(range: "0000000-9999999", length: 2)])
            ],
            "Overlapping ranges in the registration groups 978-1 and 978-19."
        )
    ])
    func rejectsInconsistentGroups(groups: [RangeMessage.Group], error: String) {
        #expect(throws: RangeMessageError(error)) {
            try RangeMessage(groups: groups).entries()
        }
    }
}
