import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import ISBNRangeMessage

/// Updates `Data/RangeMessage.xml` and the range table of the `ISBN` library if the
/// International ISBN Agency changed the registration ranges.
@main
struct ISBNRegistrationGroupsUpdater {
    static let rangeMessageURL = URL(string: "https://www.isbn-international.org/export_rangemessage.xml")!
    static let rangeMessagePath = "Data/RangeMessage.xml"
    static let rangeTablePath = "Sources/ISBN/RangeTable+Entries.swift"

    static func main() {
        do {
            try run(Options(arguments: Array(CommandLine.arguments.dropFirst())))
        } catch {
            FileHandle.standardError.write(Data("error: \(error)\n".utf8))
            exit(1)
        }
    }

    static func run(_ options: Options) throws {
        if options.showHelp {
            print(Options.usage)
            return
        }
        guard FileManager.default.fileExists(atPath: "Package.swift") else {
            throw UpdaterError("Run the updater from the root directory of the package.")
        }

        if options.regenerate {
            let message = try RangeMessage(xml: Data(contentsOf: URL(fileURLWithPath: rangeMessagePath)))
            try RangeTableSource.generate(from: message).write(toFile: rangeTablePath, atomically: true, encoding: .utf8)
            print("Regenerated \(rangeTablePath) from \(rangeMessagePath).")
            return
        }

        let xml = RangeMessage.normalizingLineEndings(of: try load(options.input))
        let message = try RangeMessage(xml: xml)
        // Generating the range table validates the range message before any file is written.
        let rangeTable = try RangeTableSource.generate(from: message)

        var baseline = RangeMessage(groups: [])
        if FileManager.default.fileExists(atPath: rangeMessagePath) {
            baseline = try RangeMessage(xml: Data(contentsOf: URL(fileURLWithPath: rangeMessagePath)))
        }
        let diff = RangeMessageDiff(from: baseline, to: message)
        guard !diff.isEmpty else {
            print("The ISBN ranges are up to date.")
            return
        }

        try FileManager.default.createDirectory(atPath: "Data", withIntermediateDirectories: true)
        try xml.write(to: URL(fileURLWithPath: rangeMessagePath))
        try rangeTable.write(toFile: rangeTablePath, atomically: true, encoding: .utf8)
        if let path = options.releaseNotesPath {
            try diff.releaseNotes.write(toFile: path, atomically: true, encoding: .utf8)
        }
        if let path = options.commitMessagePath {
            try diff.commitMessage.write(toFile: path, atomically: true, encoding: .utf8)
        }
        print(diff.commitMessage)
    }

    static func load(_ input: String) throws -> Data {
        if let url = URL(string: input), url.scheme == "https" || url.scheme == "http" {
            return try Data(contentsOf: url)
        }
        return try Data(contentsOf: URL(fileURLWithPath: input))
    }
}

struct Options {
    static let usage = """
        USAGE: swift run ISBNRegistrationGroupsUpdater [options]

        Updates Data/RangeMessage.xml and Sources/ISBN/RangeTable+Entries.swift if the
        International ISBN Agency changed the registration ranges. Run it from the
        root directory of the package.

        OPTIONS:
          --input <path-or-url>     Read the range message from a file or URL instead of
                                    \(ISBNRegistrationGroupsUpdater.rangeMessageURL.absoluteString)
          --release-notes <path>    Write release notes in Markdown if the ranges changed
          --commit-message <path>   Write a commit message if the ranges changed
          --regenerate              Regenerate the range table from Data/RangeMessage.xml
          -h, --help                Show this help
        """

    var input = ISBNRegistrationGroupsUpdater.rangeMessageURL.absoluteString
    var releaseNotesPath: String?
    var commitMessagePath: String?
    var regenerate = false
    var showHelp = false

    init(arguments: [String]) throws {
        var arguments = arguments[...]
        while let argument = arguments.popFirst() {
            switch argument {
            case "--input":
                input = try Self.value(of: argument, from: &arguments)
            case "--release-notes":
                releaseNotesPath = try Self.value(of: argument, from: &arguments)
            case "--commit-message":
                commitMessagePath = try Self.value(of: argument, from: &arguments)
            case "--regenerate":
                regenerate = true
            case "-h", "--help":
                showHelp = true
            default:
                throw UpdaterError("Unknown argument '\(argument)'.\n\n\(Self.usage)")
            }
        }
    }

    private static func value(of option: String, from arguments: inout ArraySlice<String>) throws -> String {
        guard let value = arguments.popFirst() else {
            throw UpdaterError("Missing value for \(option).")
        }
        return value
    }
}

struct UpdaterError: Error, CustomStringConvertible {
    var description: String

    init(_ description: String) {
        self.description = description
    }
}
