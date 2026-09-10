import Foundation
import ISBNRangeMessage
import Testing

@Suite("Range table source")
struct RangeTableSourceTests {
    @Test("Generates the range table")
    func generatesRangeTable() throws {
        let message = try RangeMessage(xml: Data(contentsOf: Paths.fixture("EdgeCases.xml")))
        #expect(try RangeTableSource.generate(from: message) == """
            // This file is generated from Data/RangeMessage.xml by ISBNRegistrationGroupsUpdater. Do not edit it.
            // International ISBN Agency
            // Thu, 10 Sep 2026 09:23:46 BST

            extension RangeTable {
                static let agencies: [String] = [
                    "English language",
                    "China, People's Republic",
                    "Curaçao",
                ]

                static let entries: [Entry] = [
                    // 978-1 English language
                    (978_100_000_000, 978_109_999_999, 1, 2, 0),
                    (978_140_000_000, 978_154_999_999, 1, 4, 0),
                    (978_155_000_000, 978_199_999_999, 1, 5, 0),
                    // 978-7 China, People's Republic
                    (978_700_000_000, 978_709_999_999, 1, 2, 1),
                    (978_710_000_000, 978_749_999_999, 1, 3, 1),
                    // 978-99904 Curaçao
                    (978_999_040_000, 978_999_045_999, 5, 1, 2),
                    (978_999_046_000, 978_999_048_999, 5, 2, 2),
                    (978_999_049_000, 978_999_049_999, 5, 3, 2),
                ]
            }

            """)
    }

    @Test("Escapes the names of registration groups")
    func escapesNames() throws {
        let message = RangeMessage(source: "Test", date: "Today", groups: [
            .init(prefix: "978-1", agency: "Say \"Hi\" \\ Bye\nNow", rules: [.init(range: "0000000-9999999", length: 2)])
        ])
        let source = try RangeTableSource.generate(from: message)
        #expect(source.contains(#"        "Say \"Hi\" \\ Bye\nNow","#))
        #expect(source.contains("        // 978-1 Say \"Hi\" \\ Bye Now\n"))
    }
}
