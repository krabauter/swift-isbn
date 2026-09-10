import Foundation
import ISBN
import Testing

@Suite("Parsing")
struct ParsingTests {
    @Test("Parses an ISBN-13 with separators", arguments: [
        "9781408855898",
        "978-1-4088-5589-8",
        "978 1 4088 5589 8",
        "978\u{2010}1\u{2010}4088\u{2010}5589\u{2010}8",
        "978\u{2013}1\u{2013}4088\u{2013}5589\u{2013}8",
        "\t978-1-4088-5589-8\r\n"
    ])
    func parsesISBN13(string: String) throws {
        #expect(try ISBN(parsing: string).digits == "9781408855898")
    }

    @Test("Parses substrings")
    func parsesSubstrings() throws {
        let isbns = try "978-1-4088-5589-8, 1-5266-4665-X".split(separator: ",").map { try ISBN(parsing: $0) }
        #expect(isbns.map(\.digits) == ["9781408855898", "9781526646651"])
    }

    @Test("Converts an ISBN-10 to an ISBN-13", arguments: [
        ("1-4088-5589-5", "9781408855898"),
        ("0-306-40615-2", "9780306406157"),
        ("1-5266-4665-X", "9781526646651"),
        ("1-5266-4665-x", "9781526646651"),
        // The check digit of the ISBN-13 is 0.
        ("1620466104", "9781620466100"),
        ("8762328603", "9788762328600")
    ])
    func convertsISBN10(isbn10: String, isbn13: String) throws {
        #expect(try ISBN(parsing: isbn10).digits == isbn13)
    }

    @Test("Converts ISBN-10s like a reference implementation")
    func convertsISBN10LikeReferenceImplementation() throws {
        for number in stride(from: 0, to: 1_000_000_000, by: 1_234_567) {
            let digits = String(number)
            let firstNineDigits = String(repeating: "0", count: 9 - digits.count) + digits
            let values = firstNineDigits.compactMap(\.wholeNumberValue)
            let isbn10CheckDigit = values.enumerated().reduce(0) { sum, digit in
                sum + (digit.offset + 1) * digit.element
            } % 11
            let isbn13Sum = ([9, 7, 8] + values).enumerated().reduce(0) { sum, digit in
                sum + (digit.offset.isMultiple(of: 2) ? 1 : 3) * digit.element
            }

            let isbn10 = firstNineDigits + (isbn10CheckDigit == 10 ? "X" : String(isbn10CheckDigit))
            let isbn13 = "978" + firstNineDigits + String((10 - isbn13Sum % 10) % 10)
            #expect(try ISBN(parsing: isbn10).digits == isbn13)
        }
    }

    @Test("Rejects invalid characters", arguments: [
        ("ISBN 978-1-4088-5589-8", "I", 0),
        ("978-1-4088-5589-8!", "!", 17),
        ("978_1_4088_5589_8", "_", 3),
        ("9\u{301}78-1-4088-5589-8", "9\u{301}", 0)
    ] as [(String, Character, Int)])
    func rejectsInvalidCharacters(string: String, character: Character, offset: Int) {
        #expect(throws: ISBN.ParseError.invalidCharacter(character, offset: offset)) {
            try ISBN(parsing: string)
        }
    }

    @Test("Rejects a misplaced check character X", arguments: [
        "978X306406157",
        "97814088558X8",
        "24589X1527",
        "123456789X1",
        "X"
    ])
    func rejectsMisplacedX(string: String) {
        #expect(throws: ISBN.ParseError.misplacedX) {
            try ISBN(parsing: string)
        }
    }

    @Test("Rejects an invalid number of digits", arguments: [
        ("", 0),
        ("- -", 0),
        ("140885589", 9),
        ("97814088558", 11),
        ("978140885589", 12),
        ("97814088558980", 14)
    ])
    func rejectsInvalidLength(string: String, length: Int) {
        #expect(throws: ISBN.ParseError.invalidLength(length)) {
            try ISBN(parsing: string)
        }
    }

    @Test("Rejects prefixes that aren't used for ISBNs", arguments: [
        ("9771234567003", "977"),
        ("0123456789012", "012"),
        ("979-0-2600-0043-8", "979-0")
    ])
    func rejectsInvalidPrefix(string: String, prefix: String) {
        #expect(throws: ISBN.ParseError.invalidPrefix(prefix)) {
            try ISBN(parsing: string)
        }
    }

    @Test("Rejects an invalid check digit", arguments: [
        ("978-1-4088-5589-0", "8", "0"),
        ("1-4088-5589-0", "5", "0"),
        ("1-4088-5589-X", "5", "X"),
        ("1-5266-4665-0", "X", "0")
    ] as [(String, Character, Character)])
    func rejectsInvalidCheckDigit(string: String, expected: Character, actual: Character) {
        #expect(throws: ISBN.ParseError.invalidCheckDigit(expected: expected, actual: actual)) {
            try ISBN(parsing: string)
        }
    }

    @Test("Describes parse errors")
    func describesParseErrors() {
        #expect(ISBN.ParseError.invalidCheckDigit(expected: "8", actual: "0").description == "The check digit is 0, but 8 was expected.")
        #expect(ISBN.ParseError.invalidLength(12).description == "Expected 10 or 13 digits, but found 12.")
        #expect(ISBN.ParseError.invalidPrefix("977").description == "The prefix 977 isn't used for ISBNs.")
        #expect(ISBN.ParseError.invalidPrefix("979-0").description == "The prefix 979-0 is reserved for ISMNs.")
    }

    @Test("Validation succeeds exactly if parsing succeeds", arguments: [
        "978-1-4088-5589-8",
        "1-4088-5589-5",
        "9799000000004",
        "979-0-2600-0043-8",
        "978X306406157",
        "ISBN 978-1-4088-5589-8",
        "1-4088-5589-0",
        ""
    ])
    func validationMatchesParsing(string: String) {
        let isParsable = (try? ISBN(parsing: string)) != nil
        #expect(ISBN.isValid(string) == isParsable)
        #expect((ISBN(string) != nil) == isParsable)
    }
}

@Suite("Hyphenation")
struct HyphenationTests {
    @Test("Hyphenates ISBNs", arguments: [
        ("9781408855898", "978-1-4088-5589-8", "English language"),
        ("9781781100769", "978-1-78110-076-9", "English language"),
        ("9780000000002", "978-0-00-000000-2", "English language"),
        ("9783161484100", "978-3-16-148410-0", "German language"),
        ("9788762328600", "978-87-623-2860-0", "Denmark"),
        ("9789950000001", "978-9950-00-000-1", "Palestine"),
        ("9789990400007", "978-99904-0-000-7", "Curaçao"),
        ("9791090636071", "979-10-90636-07-1", "France"),
        ("9798602401615", "979-8-6024-0161-5", "United States")
    ])
    func hyphenates(digits: String, hyphenated: String, groupName: String) throws {
        let isbn = try ISBN(parsing: digits)
        #expect(isbn.hyphenated == hyphenated)
        #expect(isbn.description == hyphenated)
        #expect(isbn.groupName == groupName)
    }

    @Test("Provides the elements")
    func elements() throws {
        let elements = try #require(try ISBN(parsing: "1-4088-5589-5").elements)
        #expect(elements.prefix == "978")
        #expect(elements.group == "1")
        #expect(elements.registrant == "4088")
        #expect(elements.publication == "5589")
        #expect(elements.checkDigit == "8")
        #expect(elements.joined(separator: " ") == "978 1 4088 5589 8")
    }

    @Test("Doesn't hyphenate ISBNs from unassigned ranges")
    func unassignedRange() throws {
        let isbn = try ISBN(parsing: "9799000000004")
        #expect(isbn.hyphenated == nil)
        #expect(isbn.elements == nil)
        #expect(isbn.groupName == nil)
        #expect(isbn.description == "9799000000004")
    }
}

@Suite("Conformances")
struct ConformanceTests {
    @Test("Equality and hashing don't depend on the input format")
    func equality() throws {
        let isbn10 = try ISBN(parsing: "1-4088-5589-5")
        let isbn13 = try ISBN(parsing: "978-1-4088-5589-8")
        #expect(isbn10 == isbn13)
        #expect(Set([isbn10, isbn13]).count == 1)
    }

    @Test("ISBNs are ordered by their digits")
    func comparable() throws {
        let isbns = try ["9791090636071", "9780306406157", "9781408855898"].map { try ISBN(parsing: $0) }
        #expect(isbns.sorted().map(\.digits) == ["9780306406157", "9781408855898", "9791090636071"])
    }

    @Test("The description can be parsed again", arguments: ["1-4088-5589-5", "9799000000004"])
    func losslessStringConvertible(string: String) throws {
        let isbn = try #require(ISBN(string))
        #expect(ISBN(isbn.description) == isbn)
    }

    @Test("The failable initializer returns nil for invalid ISBNs")
    func failableInitializer() {
        #expect(ISBN("978-1-4088-5589-0") == nil)
        #expect(["978-1-4088-5589-8", "invalid", "1-4088-5589-5"].compactMap(ISBN.init).count == 2)
    }
}

@Suite("Codable")
struct CodableTests {
    private struct Book: Codable, Equatable {
        let isbn: ISBN
    }

    @Test("Encodes the description", arguments: [
        ("1-4088-5589-5", #"{"isbn":"978-1-4088-5589-8"}"#),
        ("9799000000004", #"{"isbn":"9799000000004"}"#)
    ])
    func encodesDescription(string: String, json: String) throws {
        let data = try JSONEncoder().encode(Book(isbn: ISBN(parsing: string)))
        #expect(String(decoding: data, as: UTF8.self) == json)
    }

    @Test("Decodes ISBN-10s and ISBN-13s", arguments: ["978-1-4088-5589-8", "9781408855898", "1-4088-5589-5"])
    func decodes(string: String) throws {
        let book = try JSONDecoder().decode(Book.self, from: Data(#"{"isbn":"\#(string)"}"#.utf8))
        #expect(book == Book(isbn: try ISBN(parsing: "9781408855898")))
    }

    @Test("The decoding error contains the reason")
    func decodingErrorContainsReason() throws {
        do {
            _ = try JSONDecoder().decode(Book.self, from: Data(#"{"isbn":"978-1-4088-5589-0"}"#.utf8))
            Issue.record("Decoding an invalid ISBN succeeded")
        } catch DecodingError.dataCorrupted(let context) {
            #expect(context.codingPath.map(\.stringValue) == ["isbn"])
            #expect(context.debugDescription == "Invalid ISBN '978-1-4088-5589-0': The check digit is 0, but 8 was expected.")
            #expect(context.underlyingError as? ISBN.ParseError == ISBN.ParseError.invalidCheckDigit(expected: "8", actual: "0"))
        }
    }
}
