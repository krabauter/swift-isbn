# Swift ISBN

A lightweight Swift library to parse, validate, and hyphenate ISBN identifiers. The library converts ISBN-10 automatically to ISBN-13, ensuring consistent 13-digit identifiers.

## Features

- **Parse & Validate**: Check whether a string is a valid ISBN and find out why it isn't.
- **Automatic Conversion**: ISBN-10 inputs are converted to ISBN-13.
- **Hyphenation**: Split an ISBN into its elements based on the registration ranges of the International ISBN Agency, which are updated automatically.
- **Value Type**: `ISBN` is `Hashable`, `Comparable`, `Codable`, `Sendable`, and `LosslessStringConvertible`.
- **No Dependencies**: The library doesn't even depend on Foundation.

## Installation

Swift Package Manager
1. In Xcode, select File > Add Packages…
2. Enter the URL of the repository (e.g., https://github.com/krabauter/swift-isbn.git).
3. Choose Add Package and the desired target.

Or, you can add it manually to your Package.swift:
```swift
dependencies: [
    .package(url: "https://github.com/krabauter/swift-isbn.git", from: "3.0.0")
]
```
Then import ISBN in any Swift file where you want to use it:
```swift
import ISBN
```

## Usage

### Parsing an ISBN

```swift
// Automatically converts valid ISBN-10 to ISBN-13
let isbn = try ISBN(parsing: "1-4088-5589-5")
print(isbn.digits)       // "9781408855898"
print(isbn.hyphenated!)  // "978-1-4088-5589-8"
print(isbn)              // "978-1-4088-5589-8"
```

Hyphens, dashes, and whitespace are ignored. Any other character makes the string invalid.

### Handling Invalid Input

`init(parsing:)` throws an `ISBN.ParseError` that describes why a string is not a valid ISBN:

```swift
do {
    let isbn = try ISBN(parsing: input)
} catch ISBN.ParseError.invalidCheckDigit(let expected, let actual) {
    print("The check digit is \(actual), but \(expected) was expected. Is there a typo?")
} catch {
    print(error)  // e.g. "Expected 10 or 13 digits, but found 12."
}
```

If you don't need the reason, use the failable initializer or `isValid(_:)`:

```swift
let isbn = ISBN("978-1-4088-5589-8")       // ISBN?
let isbns = strings.compactMap(ISBN.init)  // [ISBN]
ISBN.isValid("1-4088-5589-0")              // false
```

### Elements and Registration Group

```swift
let isbn = try ISBN(parsing: "978-1-4088-5589-8")
print(isbn.groupName!)            // "English language"
print(isbn.elements!.registrant)  // "4088"
```

### Unassigned Registration Ranges

Whether an ISBN is valid only depends on its digits. Hyphenating it additionally requires its registration range, which the International ISBN Agency assigns over time. For ISBNs from ranges that are unassigned or unknown to the installed version of the library, `hyphenated`, `elements`, and `groupName` are `nil`, and `description` falls back to the digits:

```swift
let isbn = try ISBN(parsing: "9799000000004")
print(isbn.hyphenated as Any)  // nil
print(isbn)                    // "9799000000004"
```

### Codable Support

An ISBN is encoded as its `description`. Decoding accepts every string that `init(parsing:)` accepts, and the decoding error contains the reason for an invalid ISBN:

```swift
struct Book: Codable {
    let title: String
    let isbn: ISBN
}

do {
    let book = try JSONDecoder().decode(Book.self, from: data)
} catch DecodingError.dataCorrupted(let context) {
    print(context.debugDescription)  // "Invalid ISBN '978-1-4088-5589-0': The check digit is 0, but 8 was expected."
    let reason = context.underlyingError as? ISBN.ParseError
}
```

## Registration Ranges

The hyphenation is based on the range message of the International ISBN Agency in [`Data/RangeMessage.xml`](Data/RangeMessage.xml), from which `Sources/ISBN/RangeTable+Entries.swift` is generated.

A scheduled workflow checks for changed ranges every Monday. If the registration ranges changed, it updates both files, runs the tests, and publishes a patch release whose notes list the changed registration groups. It only does so if the library hasn't changed since the latest release, so release other changes first.

To update the ranges manually, run the updater from the root directory of the package:

```bash
swift run ISBNRegistrationGroupsUpdater
```

Run `swift run ISBNRegistrationGroupsUpdater --help` for all options.

## Migrating from 2.x

- `ISBN(_:)` now succeeds for every valid ISBN, including ISBNs from unassigned ranges. Use `try ISBN(parsing:)` to find out why a string is invalid.
- `isbnString` is replaced by `hyphenated`, which is `nil` for unassigned ranges, and `description`, which falls back to the digits. `digits` returns the ISBN without hyphens.
- `ISBN.hyphenated(_:)` is removed. Use `ISBN(string)?.hyphenated` instead.
- `elements` and `groupName` are optional.
- Strings containing characters other than digits, hyphens, dashes, and whitespace, such as `"ISBN 978-1-4088-5589-8"`, are no longer valid.
- ISBN-10s whose ISBN-13 has the check digit 0 were converted to 14 digits, and an `X` was accepted anywhere in an ISBN. Both are fixed.

## License

MIT License

Copyright (c) 2025 Krabauter

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
