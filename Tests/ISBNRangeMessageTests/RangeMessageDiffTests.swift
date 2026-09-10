import ISBNRangeMessage
import Testing

@Suite("Range message diff")
struct RangeMessageDiffTests {
    let message = RangeMessage(date: "Mon, 7 Sep 2026 08:00:00 BST", groups: [
        .init(prefix: "978-0", agency: "English language", rules: [
            .init(range: "0000000-1999999", length: 2),
            .init(range: "2000000-9999999", length: 0)
        ]),
        .init(prefix: "978-81", agency: "India", rules: [
            .init(range: "9750000-9799999", length: 3)
        ]),
        .init(prefix: "978-86", agency: "Srpska", rules: [
            .init(range: "0000000-2999999", length: 2)
        ]),
        .init(prefix: "979-12", agency: "Italy", rules: [
            .init(range: "2000000-2999999", length: 3)
        ])
    ])

    @Test("Ignores the message date")
    func ignoresMessageDate() {
        var newMessage = message
        newMessage.date = "Thu, 10 Sep 2026 09:23:46 BST"
        #expect(RangeMessageDiff(from: message, to: newMessage).isEmpty)
    }

    @Test("Ignores unassigned ranges and the order of rules")
    func ignoresUnassignedRangesAndRuleOrder() {
        var newMessage = message
        newMessage.groups[0].rules = [
            .init(range: "5000000-9999999", length: 0),
            .init(range: "2000000-4999999", length: 0),
            .init(range: "0000000-1999999", length: 2)
        ]
        newMessage.groups.append(.init(prefix: "978-611", agency: "Thailand", rules: [
            .init(range: "0000000-9999999", length: 0)
        ]))
        #expect(RangeMessageDiff(from: message, to: newMessage).isEmpty)
    }

    @Test("Describes added, removed, renamed, and modified registration groups")
    func describesChanges() {
        var newMessage = message
        newMessage.groups[1].rules = [
            .init(range: "9750000-9769999", length: 3),
            .init(range: "9770000-9799999", length: 4)
        ]
        newMessage.groups[2].agency = "Serbia"
        newMessage.groups.removeLast()
        newMessage.groups.append(.init(prefix: "978-9905", agency: "Nepal", rules: [
            .init(range: "0000000-5999999", length: 1)
        ]))

        let diff = RangeMessageDiff(from: message, to: newMessage)

        #expect(diff.commitMessage == """
            Update ISBN ranges

            - 978-81 India
            - 978-86 Serbia (renamed from Srpska)
            - 978-9905 Nepal (new)
            - 979-12 Italy (removed)

            """)
        #expect(diff.releaseNotes == """
            ### Update ISBN ranges

            - 978-81 India
            - 978-86 Serbia (renamed from Srpska)
            - 978-9905 Nepal (new)
            - 979-12 Italy (removed)

            <details>
            <summary>Changed ranges</summary>

            #### 978-81 India

            ```diff
            - 978-81-975–979
            + 978-81-975–976
            + 978-81-9770–9799
            ```

            #### 978-9905 Nepal

            ```diff
            + 978-9905-0–5
            ```

            #### 979-12 Italy

            ```diff
            - 979-12-200–299
            ```

            </details>

            """)
    }

    @Test("Omits the details if only names changed")
    func omitsDetailsForRenames() {
        var newMessage = message
        newMessage.groups[2].agency = "Serbia"
        #expect(RangeMessageDiff(from: message, to: newMessage).releaseNotes == """
            ### Update ISBN ranges

            - 978-86 Serbia (renamed from Srpska)

            """)
    }
}
