extension ISBN {
    /// The reason why a string is not a valid ISBN
    public enum ParseError: Error, Hashable, Sendable {
        /// The string contains a character that is neither a digit, the check character `X`,
        /// nor a separator. The offset is the zero-based position of the character in the string.
        case invalidCharacter(Character, offset: Int)

        /// The check character `X` appears anywhere but at the end of an ISBN-10.
        case misplacedX

        /// The string contains neither 10 nor 13 digits.
        case invalidLength(Int)

        /// The ISBN-13 starts with a prefix that isn't used for ISBNs, e.g. `977` or `979-0`,
        /// which is reserved for International Standard Music Numbers (ISMN).
        case invalidPrefix(String)

        /// The check digit doesn't match the other digits.
        case invalidCheckDigit(expected: Character, actual: Character)
    }
}

extension ISBN.ParseError: CustomStringConvertible {
    public var description: String {
        switch self {
        case let .invalidCharacter(character, offset):
            "Invalid character '\(character)' at offset \(offset)."
        case .misplacedX:
            "The check character X is only allowed at the end of an ISBN-10."
        case let .invalidLength(length):
            "Expected 10 or 13 digits, but found \(length)."
        case .invalidPrefix("979-0"):
            "The prefix 979-0 is reserved for ISMNs."
        case let .invalidPrefix(prefix):
            "The prefix \(prefix) isn't used for ISBNs."
        case let .invalidCheckDigit(expected, actual):
            "The check digit is \(actual), but \(expected) was expected."
        }
    }
}
