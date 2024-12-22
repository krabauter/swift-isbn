import Foundation

/// Represents an International Standard Book Number, the unique identification of books and other independent publications with editorial content.

public struct ISBN {

}

extension ISBN {
    /// Validates a given string representation of an ISBN
    public static func isValid(_ isbn: String) -> Bool {
        let isbn = isbn.filter(\.isISBNSave)
        if isbn.count == 13 {
            return isbn.calculateISBNChecksum() % 10 == 0
        } else if isbn.count == 10 {
            return isbn.calculateISBN10Checksum() % 11 == 0
        }
        return false
    }
    
    /// Validates a given GTIN representation of an ISBN
    public static func isValid(_ gtin: Int) -> Bool {
        isValid(String(gtin))
    }
}

private extension Character {
    var isISBNSave: Bool {
        let isbnSaveCharacters = CharacterSet(charactersIn: "0123456789X")
        return self.unicodeScalars.allSatisfy {
            isbnSaveCharacters.contains($0)
        }
    }
    
    var isbnValue: Int? {
        if self == "X" { return 10 }
        return Int(String(self))
    }
}

private extension String {
    func calculateISBNChecksum() -> Int {
        self.compactMap(\.isbnValue)
            .enumerated()
            .map({ $0.offset & 1 == 1 ? 3 * $0.element : $0.element })
            .reduce(0, +)
    }
    
    func calculateISBN10Checksum() -> Int {
        self.compactMap(\.isbnValue)
            .enumerated()
            .map({ ($0.offset + 1) * $0.element })
            .reduce(0, +)
    }
    
    func cleanedISBN() -> String {
        var isbn = self.filter(\.isISBNSave)
        if isbn.count == 10 {
            isbn = String("978\(isbn)".dropLast())
            isbn = "\(isbn)\((10 - (isbn.calculateISBNChecksum() % 10) % 10))"
        }
        return isbn
    }
    
    func toInt() -> Int {
        compactMap(\.wholeNumberValue).reduce(0, { $0 * 10 + $1 })
    }
}
