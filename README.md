# ISBN

A lightweight Swift library to parse, validate, and display ISBNs. The library seamlessly handles ISBN-10 by converting it automatically to ISBN-13, ensuring consistent 13-digit identifiers.

## Features

- **Parse & Validate**: Quickly check if a string or integer is a valid ISBN (10 or 13).
- **Automatic Conversion**: ISBN-10 inputs are silently upgraded to ISBN-13 under the hood.
- **Clean, Hyphenated Output**: Retrieve a properly hyphenated string representation of your ISBN.
- **GTIN-13 Support**: Initialize an ISBN using a 13-digit GTIN integer.
- **Codable**: Easily encode and decode ISBNs in Swift using Codable.
- **Sendable**: Safe to use in Swift concurrency contexts.

## Installation

Swift Package Manager
1. In Xcode, select File > Add Packages…
2. Enter the URL of the repository (e.g., https://github.com/krabauter/isbn.git).
3. Choose Add Package and the desired target.

Or, you can add it manually to your Package.swift:
```swift
dependencies: [
    .package(url: "https://github.com/krabauter/isbn.git", from: "1.0.0")
]
```
Then import ISBN in any Swift file where you want to use it:
```swift
import ISBN
```

## Usage

### Creating an ISBN from a String

```swift
// Automatically converts valid ISBN-10 to ISBN-13
if let isbn = ISBN("1-4088-5589-5") {
    print(isbn.isbnString)  // "978-1-4088-5589-8"
    print(isbn.gtin)        // 9781408855898
} else {
    print("Invalid ISBN input")
}
```

### Creating an ISBN from a GTIN (`Int`)

```swift
// Requires a valid 13-digit integer
if let isbn = ISBN(9781408855898) {
    print(isbn.isbnString) // "978-1-4088-5589-8"
} else {
    print("Invalid GTIN for ISBN")
}
```

### Validating an ISBN

```swift
if ISBN.isValid("1-4088-5589-5") {
    print("This is a valid ISBN-10, which would be converted to ISBN-13.")
} else {
    print("Not a valid ISBN.")
}
```

### Getting a Hyphenated String

```swift
if let hyphenatedISBN = ISBN.hyphenated(9781408855898) {
    print(hyphenatedISBN)  // "978-1-4088-5589-8"
}
```

### Codable Support

Since ISBN conforms to Codable, you can encode/decode it just like any other Codable type:
```swift
struct Book: Codable {
    let title: String
    let isbn: ISBN
}

let harryPotter = Book(title: "Harry Potter and the Philosopher‘s Stone", isbn: .init("978-1-4088-5589-8")!)
let data = try JSONEncoder().encode(harryPotter)
let decodedBook = try JSONDecoder().decode(Book.self, from: data)
print(decodedBook.isbn.isbnString)  // "978-1-4088-5589-8"
```

## License

MIT License

Copyright (c) 2024 Krabauter

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
