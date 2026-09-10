/// Represents an International Standard Book Number (ISBN), the globally recognized
/// unique identifier for books and other editorial publications.
///
/// An `ISBN` always represents a 13-digit ISBN. When an ISBN-10 is parsed, it is
/// converted to the corresponding ISBN-13.
///
/// Whether a string is a valid ISBN only depends on its digits. The hyphenation
/// additionally depends on the registration ranges assigned by the International ISBN
/// Agency. For ISBNs from ranges that are unassigned or unknown to this version of the
/// library, ``hyphenated``, ``elements``, and ``groupName`` are `nil`.
public struct ISBN: Sendable, Hashable {
    /// The 13 digits of the ISBN, e.g. `9781408855898`
    private let value: UInt64

    /// Creates a new `ISBN` instance by parsing a string representation of an ISBN-10 or ISBN-13.
    ///
    /// Hyphens, dashes, and whitespace are ignored. An ISBN-10 such as `"1-4088-5589-5"` is
    /// converted to the corresponding ISBN-13 `"978-1-4088-5589-8"`.
    ///
    /// ```swift
    /// do {
    ///     let isbn = try ISBN(parsing: "1-4088-5589-0")
    /// } catch {
    ///     print(error) // "The check digit is 0, but 5 was expected."
    /// }
    /// ```
    ///
    /// - Parameter string: A string containing an ISBN-10 or ISBN-13.
    /// - Throws: A ``ParseError`` describing why `string` is not a valid ISBN.
    public init(parsing string: some StringProtocol) throws(ParseError) {
        var digits = Digits()
        for byte in string.utf8 {
            switch byte {
            case UInt8(ascii: "0")...UInt8(ascii: "9"):
                try digits.append(byte - UInt8(ascii: "0"))
            case UInt8(ascii: "X"), UInt8(ascii: "x"):
                try digits.appendCheckCharacterX()
            case UInt8(ascii: "-"), UInt8(ascii: " "):
                continue
            default:
                // Other separators like dashes and invalid characters are rare, so they are handled
                // by parsing the string character by character.
                self = try ISBN(parsingCharacters: string)
                return
            }
        }
        value = try digits.isbn13()
    }

    private init(parsingCharacters string: some StringProtocol) throws(ParseError) {
        var digits = Digits()
        for (offset, character) in string.enumerated() {
            if let asciiValue = character.asciiValue, (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(asciiValue) {
                try digits.append(asciiValue - UInt8(ascii: "0"))
            } else if character == "X" || character == "x" {
                try digits.appendCheckCharacterX()
            } else if !character.isISBNSeparator {
                throw .invalidCharacter(character, offset: offset)
            }
        }
        value = try digits.isbn13()
    }
}

extension ISBN {
    /// Validates a given string representation of an ISBN-10 or ISBN-13
    public static func isValid(_ string: some StringProtocol) -> Bool {
        (try? ISBN(parsing: string)) != nil
    }

    /// The 13 digits of the ISBN without separators, e.g. `"9781408855898"`
    public var digits: String {
        String(value)
    }

    /// The string representation with hyphens of the ISBN, e.g. `"978-1-4088-5589-8"`,
    /// or `nil` if the registration range of the ISBN is unknown
    public var hyphenated: String? {
        guard let entry = RangeTable.entry(containing: value / 10) else {
            return nil
        }
        let groupEnd = 3 + Int(entry.groupLength)
        let registrantEnd = groupEnd + Int(entry.registrantLength)
        // Writes the digits into a buffer of hyphens, leaving out a hyphen after each element.
        var utf8 = [UInt8](repeating: UInt8(ascii: "-"), count: 17)
        var remainingDigits = value
        for index in (0..<13).reversed() {
            var position = index
            if index >= 3 { position += 1 }
            if index >= groupEnd { position += 1 }
            if index >= registrantEnd { position += 1 }
            if index >= 12 { position += 1 }
            utf8[position] = UInt8(ascii: "0") + UInt8(remainingDigits % 10)
            remainingDigits /= 10
        }
        return String(decoding: utf8, as: UTF8.self)
    }

    /// The registration group name of the ISBN, e.g. `"English language"`,
    /// or `nil` if the registration range of the ISBN is unknown
    public var groupName: String? {
        RangeTable.entry(containing: value / 10).map { RangeTable.agencies[Int($0.agency)] }
    }

    /// The elements of the ISBN, or `nil` if the registration range of the ISBN is unknown
    public var elements: Elements? {
        guard let entry = RangeTable.entry(containing: value / 10) else {
            return nil
        }
        let utf8 = Array(digits.utf8)
        let groupEnd = 3 + Int(entry.groupLength)
        let registrantEnd = groupEnd + Int(entry.registrantLength)
        return Elements(
            prefix: String(decoding: utf8[0..<3], as: UTF8.self),
            group: String(decoding: utf8[3..<groupEnd], as: UTF8.self),
            registrant: String(decoding: utf8[groupEnd..<registrantEnd], as: UTF8.self),
            publication: String(decoding: utf8[registrantEnd..<12], as: UTF8.self),
            checkDigit: String(decoding: utf8[12...], as: UTF8.self)
        )
    }
}

extension ISBN: Comparable {
    public static func < (lhs: ISBN, rhs: ISBN) -> Bool {
        lhs.value < rhs.value
    }
}

extension ISBN: LosslessStringConvertible {
    /// Creates a new `ISBN` instance from a string representation of an ISBN-10 or ISBN-13,
    /// or returns `nil` if the string is not a valid ISBN.
    ///
    /// Use ``init(parsing:)`` to find out why a string is not a valid ISBN.
    public init?(_ description: String) {
        guard let isbn = try? ISBN(parsing: description) else {
            return nil
        }
        self = isbn
    }

    /// The hyphenated ISBN, or its digits if the registration range of the ISBN is unknown
    public var description: String {
        hyphenated ?? digits
    }
}

extension ISBN: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        do {
            self = try ISBN(parsing: string)
        } catch {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Invalid ISBN '\(string)': \(error)",
                underlyingError: error
            ))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}

extension ISBN {
    public struct Elements: Sendable, Hashable {
        /// The prefix element of the ISBN; either 978 or 979
        public let prefix: String

        /// The registration group element of the ISBN
        public let group: String

        /// The registrant element of the ISBN as a string because it may have a leading zero
        public let registrant: String

        /// The publication element of the ISBN as a string because it may have a leading zero
        public let publication: String

        /// The check digit element of the ISBN
        public let checkDigit: String

        /// Returns a string by concatenating the elements of the ISBN with the given separator
        public func joined(separator: String = "-") -> String {
            [prefix, group, registrant, publication, checkDigit].joined(separator: separator)
        }
    }
}

/// The digits of an ISBN-10 or ISBN-13 while it is parsed
private struct Digits {
    private var count = 0
    private var number: UInt64 = 0
    private var hasCheckCharacterX = false

    mutating func append(_ digit: UInt8) throws(ISBN.ParseError) {
        guard !hasCheckCharacterX else {
            throw .misplacedX
        }
        if count < 13 {
            number = number * 10 + UInt64(digit)
        }
        count += 1
    }

    mutating func appendCheckCharacterX() throws(ISBN.ParseError) {
        guard !hasCheckCharacterX, count == 9 else {
            throw .misplacedX
        }
        hasCheckCharacterX = true
        count += 1
    }

    /// Returns the 13 digits of the ISBN, converting an ISBN-10 to an ISBN-13.
    func isbn13() throws(ISBN.ParseError) -> UInt64 {
        switch count {
        case 13:
            let prefix = number / 10_000_000_000
            guard prefix == 978 || prefix == 979 else {
                let digits = String(prefix)
                throw .invalidPrefix(String(repeating: "0", count: 3 - digits.count) + digits)
            }
            // The registration group 979-0 is reserved for International Standard Music Numbers (ISMN).
            guard number / 1_000_000_000 != 9790 else {
                throw .invalidPrefix("979-0")
            }
            let expected = Self.isbn13CheckDigit(for: number / 10)
            guard number % 10 == expected else {
                throw .invalidCheckDigit(expected: Character(checkDigit: expected), actual: Character(checkDigit: number % 10))
            }
            return number
        case 10:
            let firstNineDigits = hasCheckCharacterX ? number : number / 10
            let actual = hasCheckCharacterX ? 10 : number % 10
            let expected = Self.isbn10CheckDigit(for: firstNineDigits)
            guard actual == expected else {
                throw .invalidCheckDigit(expected: Character(checkDigit: expected), actual: Character(checkDigit: actual))
            }
            let firstTwelveDigits = 978_000_000_000 + firstNineDigits
            return firstTwelveDigits * 10 + Self.isbn13CheckDigit(for: firstTwelveDigits)
        default:
            throw .invalidLength(count)
        }
    }

    /// Returns the check digit of an ISBN-13 with the given first 12 digits.
    private static func isbn13CheckDigit(for firstTwelveDigits: UInt64) -> UInt64 {
        var remainingDigits = firstTwelveDigits
        var sum: UInt64 = 0
        for position in 0..<12 {
            // The digits are weighted 1, 3, 1, 3, … from the left, so the rightmost one has the weight 3.
            sum += (position.isMultiple(of: 2) ? 3 : 1) * (remainingDigits % 10)
            remainingDigits /= 10
        }
        return (10 - sum % 10) % 10
    }

    /// Returns the check digit of an ISBN-10 with the given first 9 digits, where 10 represents `X`.
    private static func isbn10CheckDigit(for firstNineDigits: UInt64) -> UInt64 {
        var remainingDigits = firstNineDigits
        var sum: UInt64 = 0
        for weight in (1...9).reversed() {
            sum += UInt64(weight) * (remainingDigits % 10)
            remainingDigits /= 10
        }
        return sum % 11
    }
}

private extension Character {
    /// Whether the character may separate the digits of an ISBN
    var isISBNSeparator: Bool {
        switch self {
        case "-", "\u{2010}", "\u{2011}", "\u{2012}", "\u{2013}":
            true
        default:
            isWhitespace
        }
    }

    init(checkDigit: UInt64) {
        self = checkDigit == 10 ? "X" : Character(Unicode.Scalar(UInt8(0x30 + checkDigit)))
    }
}
