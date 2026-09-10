import Foundation
import ISBN
import ISBNRangeMessage
import Testing

@Suite("Range table consistency")
struct RangeTableConsistencyTests {
    let message: RangeMessage

    init() throws {
        message = try RangeMessage(xml: Data(contentsOf: Paths.rangeMessage))
    }

    @Test("The range table is generated from Data/RangeMessage.xml")
    func rangeTableIsUpToDate() throws {
        let generated = try RangeTableSource.generate(from: message)
        let checkedIn = try String(contentsOf: Paths.rangeTable, encoding: .utf8)
        #expect(generated == checkedIn, "Run `swift run ISBNRegistrationGroupsUpdater --regenerate` to update the range table.")
    }

    @Test("The hyphenation matches the ranges of Data/RangeMessage.xml at their bounds")
    func hyphenationMatchesRangeMessage() throws {
        let entries = try message.entries()
        for (index, entry) in entries.enumerated() {
            for firstTwelveDigits in [entry.lowerBound, entry.upperBound] {
                let isbn = try ISBN(parsing: isbn13(firstTwelveDigits))
                let elements = try #require(isbn.elements, "\(isbn.digits) has no elements")
                #expect("\(elements.prefix)-\(elements.group)" == entry.prefix)
                #expect(elements.registrant.count == entry.registrantLength)
                #expect(isbn.groupName == entry.agency)
            }

            // The ISBNs right outside a range are unknown, unless they belong to an adjacent range.
            let startsBlock = index == 0 || entries[index - 1].upperBound + 1 != entry.lowerBound
            if startsBlock, let isbn = try? ISBN(parsing: isbn13(entry.lowerBound - 1)) {
                #expect(isbn.hyphenated == nil, "\(isbn.digits) is outside of the ranges")
            }
            let endsBlock = index == entries.count - 1 || entries[index + 1].lowerBound != entry.upperBound + 1
            if endsBlock, let isbn = try? ISBN(parsing: isbn13(entry.upperBound + 1)) {
                #expect(isbn.hyphenated == nil, "\(isbn.digits) is outside of the ranges")
            }
        }
    }
}

/// Returns the ISBN-13 with the given first 12 digits and the matching check digit.
private func isbn13(_ firstTwelveDigits: UInt64) -> String {
    let digits = String(firstTwelveDigits).compactMap(\.wholeNumberValue)
    let sum = digits.enumerated().reduce(0) { sum, digit in
        sum + (digit.offset.isMultiple(of: 2) ? 1 : 3) * digit.element
    }
    return "\(firstTwelveDigits)\((10 - sum % 10) % 10)"
}
