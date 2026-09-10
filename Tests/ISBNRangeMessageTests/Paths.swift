import Foundation

enum Paths {
    private static let testsDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    private static let packageDirectory = testsDirectory.deletingLastPathComponent().deletingLastPathComponent()

    static let rangeMessage = packageDirectory.appendingPathComponent("Data/RangeMessage.xml")
    static let rangeTable = packageDirectory.appendingPathComponent("Sources/ISBN/RangeTable+Entries.swift")

    static func fixture(_ name: String) -> URL {
        testsDirectory.appendingPathComponent("Fixtures").appendingPathComponent(name)
    }
}
