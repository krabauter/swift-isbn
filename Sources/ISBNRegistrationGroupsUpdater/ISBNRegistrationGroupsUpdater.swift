import AsyncHTTPClient
import Foundation
import XMLCoder

@main
struct ISBNRegistrationGroupsUpdater {
    static func main() async throws {
        let request = HTTPClientRequest(url: "https://www.isbn-international.org/export_rangemessage.xml")
        let response = try await HTTPClient.shared.execute(request, timeout: .seconds(30))
        guard response.status == .ok else {
            throw ISBNRegistrationGroupsUpdaterError.invalidResponse
        }
        
        let body = try await response.body.collect(upTo: 1024 * 1024)
        let isbnRangeMessage = try XMLDecoder().decode(ISBNRangeMessage.self, from: .init(buffer: body))
        
        let registrationGroups: [String] = isbnRangeMessage.registrationGroups.compactMap { group -> String? in
            let prefixComponents = group.prefix.components(separatedBy: "-")
            guard let prefix = prefixComponents.first, let groupNumber = prefixComponents.last else {
                return nil
            }
            let rules: [String] = group.rules.compactMap { rule in
                guard rule.length > 0 else {
                    return nil
                }
                let rangeComponents = rule.range.components(separatedBy: "-")
                guard let lowerBoundString = rangeComponents.first?.prefix(rule.length),
                      let lowerBound = Int(lowerBoundString),
                      let upperBoundString = rangeComponents.last?.prefix(rule.length),
                      let upperBound = Int(upperBoundString) else {
                    return nil
                }
                return ".init(range: \(lowerBound)...\(upperBound), length: \(rule.length))"
            }
            let separator = ",\n".appending(String(repeating: " ", count: 4 * 4))
            return """
                    .init(
                        prefix: \(prefix),
                        group: \(groupNumber),
                        name: "\(group.agency)",
                        rules: [
                            \(rules.joined(separator: separator))
                        ]
                    )
            """
        }
        
        var result = "// \(isbnRangeMessage.messageSource)\n"
        result.append("// \(isbnRangeMessage.messageDate)\n\n")
        result.append("extension ISBN {\n")
        result.append("    static let registrationGroups: [RegistrationGroup] = [\n")
        result.append("\(registrationGroups.joined(separator: ",\n"))\n")
        result.append("    ]\n")
        result.append("}")
        
        var filePath = FileManager.default.currentDirectoryPath
        filePath.append("/Sources/ISBN/ISBN+RegistrationGroups.swift")
        try result.write(to: URL(fileURLWithPath: filePath), atomically: true, encoding: .utf8)
    }
}

enum ISBNRegistrationGroupsUpdaterError: Error {
    case invalidResponse
}

struct ISBNRangeMessage: Decodable {
    let messageSource: String
    let messageDate: String
    let registrationGroups: [Group]

    enum CodingKeys: String, CodingKey {
        case messageSource = "MessageSource"
        case messageDate = "MessageDate"
        case registrationGroups = "RegistrationGroups"
    }
    
    enum RegistrationGroupsCodingKeys: String, CodingKey {
        case groups = "Group"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        messageSource = try container.decode(String.self, forKey: .messageSource)
        messageDate = try container.decode(String.self, forKey: .messageDate)
        
        let registrationGroupsContainer = try container.nestedContainer(keyedBy: RegistrationGroupsCodingKeys.self, forKey: .registrationGroups)
        registrationGroups = try registrationGroupsContainer.decode([Group].self, forKey: .groups)
    }
}

struct RegistrationGroups: Decodable {
    let groups: [Group]

    enum CodingKeys: String, CodingKey {
        case groups = "Group"
    }
}

struct Group: Decodable {
    let prefix: String
    let agency: String
    let rules: [Rule]

    enum CodingKeys: String, CodingKey {
        case prefix = "Prefix"
        case agency = "Agency"
        case rules = "Rules"
    }
    
    enum RulesCodingKeys: String, CodingKey {
        case rule = "Rule"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        prefix = try container.decode(String.self, forKey: .prefix)
        agency = try container.decode(String.self, forKey: .agency)

        let rulesContainer = try container.nestedContainer(keyedBy: RulesCodingKeys.self, forKey: .rules)
        rules = try rulesContainer.decode([Rule].self, forKey: .rule)
    }
}

struct Rule: Decodable {
    let range: String
    let length: Int

    enum CodingKeys: String, CodingKey {
        case range = "Range"
        case length = "Length"
    }
}
