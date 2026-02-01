import Foundation

struct Page: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var content: String
    var createdAt: Date
    var modifiedAt: Date
    
    static let adjectives = ["swift", "bright", "calm", "bold", "warm", "cool", "quick", "slow", "soft", "sharp", "clear", "deep", "fair", "fond", "glad", "keen", "kind", "mild", "neat", "pure", "rare", "safe", "thin", "tiny", "vast", "wise", "cozy", "lazy", "zesty", "vivid", "lunar", "solar", "amber", "azure", "coral", "ivory", "olive", "royal", "rusty", "sandy", "silky", "smoky", "snowy", "spicy", "dusty", "foggy", "fresh", "fuzzy", "golden", "hollow", "marble"]
    
    static let nouns = ["river", "stone", "cloud", "flame", "frost", "grove", "haven", "light", "maple", "ocean", "pearl", "quill", "ridge", "spark", "storm", "tiger", "trail", "vapor", "wheat", "brook", "cedar", "delta", "ember", "fern", "glade", "harbor", "isle", "jade", "kelp", "lotus", "marsh", "nexus", "orbit", "petal", "prism", "quartz", "reef", "sage", "thorn", "umbra", "vale", "willow", "zenith", "anchor", "beacon", "canyon", "dune", "echo", "falcon"]
    
    init(id: UUID = UUID(), title: String, content: String) {
        self.id = id
        self.title = title
        self.content = content
        self.createdAt = Date()
        self.modifiedAt = Date()
    }
    
    static func newWithRandomName() -> Page {
        let adjective = adjectives.randomElement() ?? "new"
        let noun = nouns.randomElement() ?? "page"
        let name = "\(adjective)-\(noun)"
        return Page(title: name, content: "# \(name)\n")
    }
    
    mutating func updateContent(_ newContent: String) {
        content = newContent
        modifiedAt = Date()
        
        // Auto-update title from first non-empty line
        let lines = newContent.components(separatedBy: .newlines)
        if let firstLine = lines.first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) {
            var trimmed = firstLine.trimmingCharacters(in: .whitespaces)
            // Strip markdown heading symbols for display title
            if trimmed.hasPrefix("#") {
                trimmed = trimmed.replacingOccurrences(of: "^#+\\s*", with: "", options: .regularExpression)
            }
            title = String(trimmed.prefix(50))
        }
    }
}

struct LineResult: Identifiable {
    let id = UUID()
    let lineNumber: Int
    let input: String
    let result: EvaluationResult?
}

enum EvaluationResult: Equatable {
    case number(Double, Unit?, Bool, Bool)  // value, unit, isCurrencyConversion, isAggregate
    case text(String)
    case error(String)
    
    // Convenience initializer for backwards compatibility
    static func number(_ value: Double, _ unit: Unit?) -> EvaluationResult {
        return .number(value, unit, false, false)
    }
    
    static func number(_ value: Double, _ unit: Unit?, isCurrencyConversion: Bool) -> EvaluationResult {
        return .number(value, unit, isCurrencyConversion, false)
    }
    
    static func aggregate(_ value: Double, _ unit: Unit?, isCurrencyConversion: Bool = false) -> EvaluationResult {
        return .number(value, unit, isCurrencyConversion, true)
    }
    
    var displayString: String {
        switch self {
        case .number(let value, let unit, _, _):
            if let unit = unit {
                return unit.format(value)
            }
            
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 6
            formatter.minimumFractionDigits = 0
            
            return formatter.string(from: NSNumber(value: value)) ?? String(value)
            
        case .text(let str):
            return str
            
        case .error(let msg):
            return "Error: \(msg)"
        }
    }
    
    var isCurrencyConversion: Bool {
        if case .number(_, _, let isConversion, _) = self {
            return isConversion
        }
        return false
    }
    
    var isAggregate: Bool {
        if case .number(_, _, _, let isAgg) = self {
            return isAgg
        }
        return false
    }
}
