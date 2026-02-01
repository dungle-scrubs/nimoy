import Foundation

struct Value: Equatable {
    var number: Double
    var unit: Unit?
    var isCurrencyConversion: Bool = false
    
    init(_ number: Double, unit: Unit? = nil, isCurrencyConversion: Bool = false) {
        self.number = number
        self.unit = unit
        self.isCurrencyConversion = isCurrencyConversion
    }
    
    static func + (lhs: Value, rhs: Value) -> Value {
        Value(lhs.number + rhs.number, unit: lhs.unit ?? rhs.unit)
    }
    
    static func - (lhs: Value, rhs: Value) -> Value {
        Value(lhs.number - rhs.number, unit: lhs.unit ?? rhs.unit)
    }
    
    static func * (lhs: Value, rhs: Value) -> Value {
        Value(lhs.number * rhs.number, unit: lhs.unit ?? rhs.unit)
    }
    
    static func / (lhs: Value, rhs: Value) -> Value {
        guard rhs.number != 0 else { return Value(.nan) }
        return Value(lhs.number / rhs.number, unit: lhs.unit)
    }
}

class Evaluator {
    private var variables: [String: Value] = [:]
    private var sectionValues: [Value] = []  // All numeric results in current section
    private var sectionCurrencyOrder: [String] = [] // Track order of currencies
    private var inBlockComment: Bool = false
    
    init() {}
    
    func evaluate(_ input: String) -> EvaluationResult? {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        
        // Empty line resets section
        if trimmed.isEmpty {
            sectionValues.removeAll()
            sectionCurrencyOrder.removeAll()
            return nil
        }
        
        // Handle block comments
        if inBlockComment {
            if let endRange = trimmed.range(of: "*/") {
                inBlockComment = false
                // Check if there's content after the comment
                let afterComment = String(trimmed[endRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                if afterComment.isEmpty {
                    return nil
                }
                // Continue evaluating content after */
                return evaluate(afterComment)
            }
            return nil
        }
        
        // Check for block comment start
        if let startRange = trimmed.range(of: "/*") {
            if let endRange = trimmed.range(of: "*/") {
                // Single line block comment
                let before = String(trimmed[..<startRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                let after = String(trimmed[endRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                let combined = (before + " " + after).trimmingCharacters(in: .whitespaces)
                if combined.isEmpty {
                    return nil
                }
                return evaluate(combined)
            } else {
                // Multi-line block comment starts
                inBlockComment = true
                let before = String(trimmed[..<startRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                if before.isEmpty {
                    return nil
                }
                return evaluate(before)
            }
        }
        
        // Skip comments and markdown headings
        if trimmed.hasPrefix("//") || trimmed.hasPrefix("#") {
            return nil
        }
        
        // Handle "X% of what is Y" pattern (reverse percentage)
        if let reverseResult = tryParseReversePercentage(trimmed) {
            return reverseResult
        }
        
        // Remove inline comments for evaluation
        let withoutComment: String
        if let commentIndex = trimmed.range(of: "//") {
            withoutComment = String(trimmed[..<commentIndex.lowerBound]).trimmingCharacters(in: .whitespaces)
        } else {
            withoutComment = trimmed
        }
        
        guard !withoutComment.isEmpty else { return nil }
        
        // Strip natural language: remove "for X", "of X", "on X" descriptive phrases
        let cleaned = stripNaturalLanguage(withoutComment)
        let lowercased = cleaned.lowercased()
        
        // Check for assignment with sum/average: "var = sum" or "var sum" or "var = sum in USD"
        if let assignResult = tryParseAssignment(lowercased, original: withoutComment) {
            return assignResult
        }
        
        // Check for "sum/average in <currency>" pattern (without assignment)
        if lowercased.hasPrefix("sum ") || lowercased.hasPrefix("total ") {
            let parts = lowercased.components(separatedBy: " ").filter { !$0.isEmpty }
            if parts.count >= 3 && (parts[1] == "in" || parts[1] == "to") {
                let targetCurrency = parts[2]
                return sumInCurrency(targetCurrency)
            }
        }
        
        if lowercased.hasPrefix("average ") || lowercased.hasPrefix("avg ") {
            let parts = lowercased.components(separatedBy: " ").filter { !$0.isEmpty }
            if parts.count >= 3 && (parts[1] == "in" || parts[1] == "to") {
                let targetCurrency = parts[2]
                return averageInCurrency(targetCurrency)
            }
        }
        
        // Built-in keywords - use section variables only
        if lowercased == "sum" || lowercased == "total" {
            return sumWithDefaultCurrency()
        }
        
        if lowercased == "average" || lowercased == "avg" {
            return averageWithDefaultCurrency()
        }
        
        if lowercased == "count" {
            return .number(Double(sectionValues.count), nil)
        }
        
        // Check if it's a variable reference or conversion
        let words = lowercased.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        
        // Single variable reference - also add to section for summing
        if words.count == 1 {
            let varName = words[0]
            if let value = variables[varName] {
                // Add to section values so it can be included in sum
                sectionValues.append(value)
                if let unit = value.unit, unit.category == .currency, !sectionCurrencyOrder.contains(unit.name) {
                    sectionCurrencyOrder.append(unit.name)
                }
                return .number(value.number, value.unit)
            }
        }
        
        // Variable conversion: "var in/as/to currency"
        if words.count == 3 && (words[1] == "in" || words[1] == "as" || words[1] == "to") {
            let varName = words[0]
            let targetName = words[2]
            
            if let value = variables[varName] {
                // Check if target is crypto
                if CryptoPriceCache.shared.isCrypto(targetName) {
                    // Convert to USD first if needed, then to crypto
                    var usdAmount = value.number
                    if let sourceUnit = value.unit, sourceUnit.category == .currency {
                        let usdUnit = UnitConverter.shared.unit(named: "usd")!
                        usdAmount = UnitConverter.shared.convert(value.number, from: sourceUnit, to: usdUnit)
                    }
                    if let cryptoAmount = CryptoPriceCache.shared.convertFromUSD(usdAmount: usdAmount, crypto: targetName) {
                        let symbol = CryptoPriceCache.shared.getSymbol(targetName)
                        return .number(cryptoAmount, Unit(name: targetName, symbol: symbol, category: .currency, factor: 1.0, symbolPosition: .after))
                    }
                }
                // Regular currency conversion
                else if let sourceUnit = value.unit, let targetUnit = UnitConverter.shared.unit(named: targetName) {
                    let converted = UnitConverter.shared.convert(value.number, from: sourceUnit, to: targetUnit)
                    return .number(converted, targetUnit)
                }
            }
        }
        
        // Crypto amount: "X BTC" or "X ETH" etc - convert to USD
        if words.count == 2 && CryptoPriceCache.shared.isCrypto(words[1]) {
            if let amount = Double(words[0]) {
                let crypto = words[1]
                if let usdValue = CryptoPriceCache.shared.convertToUSD(amount: amount, crypto: crypto) {
                    let usdUnit = UnitConverter.shared.unit(named: "usd")
                    return .number(usdValue, usdUnit)
                }
                // Check if we're fetching this price
                if CryptoPriceCache.shared.isFetching(crypto) {
                    return .text("Loading...")
                }
                return .error("Price unavailable")
            }
        }
        
        // Handle conversions: "X unit to/in/as target" or "$X to target"
        if let conversionResult = tryParseConversion(words, original: lowercased) {
            return conversionResult
        }
        
        // Skip pure text lines (no numbers or operators)
        if !containsExpression(cleaned) {
            return nil
        }
        
        let tokenizer = Tokenizer(cleaned)
        let tokens = tokenizer.tokenize()
        
        // If only EOF, it's empty
        if tokens.count <= 1 {
            return nil
        }
        
        let parser = Parser(tokens)
        guard let ast = parser.parse() else {
            return nil
        }
        
        do {
            let value = try evaluateNode(ast)
            // Track result for sum (unless it's already tracked by assignment)
            if case .assignment = ast {
                // Already tracked in evaluateNode
            } else {
                sectionValues.append(value)
                if let unit = value.unit, unit.category == .currency, !sectionCurrencyOrder.contains(unit.name) {
                    sectionCurrencyOrder.append(unit.name)
                }
            }
            return .number(value.number, value.unit, isCurrencyConversion: value.isCurrencyConversion)
        } catch let error as EvalError {
            return .error(error.message)
        } catch {
            return .error(error.localizedDescription)
        }
    }
    
    /// Parse "X% of what is Y" → Y / (X/100)
    /// Example: "20% of what is 30 cm" → 150 cm
    private func tryParseReversePercentage(_ input: String) -> EvaluationResult? {
        let pattern = try! NSRegularExpression(
            pattern: #"^(\d+(?:\.\d+)?)\s*%\s+of\s+what\s+is\s+(.+)$"#,
            options: .caseInsensitive
        )
        
        let range = NSRange(input.startIndex..., in: input)
        guard let match = pattern.firstMatch(in: input, options: [], range: range) else {
            return nil
        }
        
        guard let percentRange = Range(match.range(at: 1), in: input),
              let valueRange = Range(match.range(at: 2), in: input) else {
            return nil
        }
        
        let percentStr = String(input[percentRange])
        let valueStr = String(input[valueRange])
        
        guard let percent = Double(percentStr), percent != 0 else {
            return nil
        }
        
        // Evaluate the value part (could have units)
        if let valueResult = evaluate(valueStr) {
            switch valueResult {
            case .number(let value, let unit, _, _):
                let result = value / (percent / 100.0)
                return .number(result, unit)
            default:
                return nil
            }
        }
        
        return nil
    }
    
    private func tryParseAssignment(_ lowercased: String, original: String) -> EvaluationResult? {
        var varName: String?
        var expr: String?
        
        // Try "var = expr" syntax first
        if lowercased.contains("=") {
            let parts = original.components(separatedBy: "=")
            if parts.count == 2 {
                varName = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                    .filter { !$0.isASCII || $0.asciiValue! >= 32 } // Remove control chars
                    .lowercased()
                expr = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    .filter { !$0.isASCII || $0.asciiValue! >= 32 } // Remove control chars
                    .lowercased()
            }
        }
        // Try "var sum/average ..." syntax (space instead of =)
        else {
            let words = lowercased.components(separatedBy: " ").filter { !$0.isEmpty }
            if words.count >= 2 {
                let keyword = words[1]
                if keyword == "sum" || keyword == "total" || keyword == "average" || keyword == "avg" {
                    varName = words[0]
                    expr = words.dropFirst().joined(separator: " ")
                }
            }
        }
        
        guard let varName = varName, let expr = expr else { return nil }
        
        // Direct sum/total/average/avg
        if expr == "sum" || expr == "total" {
            let result = sumWithDefaultCurrency()
            saveResultToVariable(varName, result: result)
            return result
        }
        
        if expr == "average" || expr == "avg" {
            let result = averageWithDefaultCurrency()
            saveResultToVariable(varName, result: result)
            return result
        }
        
        // Check for "sum/average in <currency>"
        let exprParts = expr.components(separatedBy: " ").filter { !$0.isEmpty }
        if exprParts.count >= 3 && (exprParts[1] == "in" || exprParts[1] == "to") {
            let keyword = exprParts[0]
            let targetCurrency = exprParts[2]
            
            var result: EvaluationResult?
            if keyword == "sum" || keyword == "total" {
                result = sumInCurrency(targetCurrency)
            } else if keyword == "average" || keyword == "avg" {
                result = averageInCurrency(targetCurrency)
            }
            
            if let result = result {
                saveResultToVariable(varName, result: result)
                return result
            }
        }
        
        return nil
    }
    
    private func saveResultToVariable(_ varName: String, result: EvaluationResult) {
        if case .number(let value, let unit, _, _) = result {
            let val = Value(value, unit: unit)
            variables[varName] = val
            sectionValues.append(val)
        }
    }
    
    private func sumInCurrency(_ targetCurrencyName: String) -> EvaluationResult {
        let targetLower = targetCurrencyName.lowercased()
        
        // Check if target is a crypto currency
        if CryptoPriceCache.shared.isCrypto(targetLower) {
            return sumInCrypto(targetLower)
        }
        
        guard let targetUnit = UnitConverter.shared.unit(named: targetCurrencyName) else {
            return .error("Unknown currency: \(targetCurrencyName)")
        }
        
        var total: Double = 0
        
        for value in sectionValues {
            if let sourceUnit = value.unit, sourceUnit.category == .currency {
                let converted = UnitConverter.shared.convert(value.number, from: sourceUnit, to: targetUnit)
                total += converted
            } else {
                total += value.number
            }
        }
        
        return .aggregate(total, targetUnit)
    }
    
    private func sumInCrypto(_ crypto: String) -> EvaluationResult {
        // First convert everything to USD
        guard let usdUnit = UnitConverter.shared.unit(named: "usd") else {
            return .error("USD unit not found")
        }
        
        var totalUSD: Double = 0
        
        for value in sectionValues {
            if let sourceUnit = value.unit, sourceUnit.category == .currency {
                let usdValue = UnitConverter.shared.convert(value.number, from: sourceUnit, to: usdUnit)
                totalUSD += usdValue
            } else {
                totalUSD += value.number
            }
        }
        
        // Convert USD to crypto (triggers fetch if not cached)
        guard let cryptoAmount = CryptoPriceCache.shared.convertFromUSD(usdAmount: totalUSD, crypto: crypto) else {
            // Check if we're fetching this price
            if CryptoPriceCache.shared.isFetching(crypto) {
                return .text("Loading...")
            }
            return .error("\(crypto.uppercased()) price unavailable")
        }
        
        // Create a crypto unit for display
        let symbol = CryptoPriceCache.shared.getSymbol(crypto)
        let cryptoUnit = Unit(name: crypto.uppercased(), symbol: symbol, category: .currency, factor: 1.0)
        
        return .aggregate(cryptoAmount, cryptoUnit, isCurrencyConversion: true)
    }
    
    private func averageInCurrency(_ targetCurrencyName: String) -> EvaluationResult {
        let targetLower = targetCurrencyName.lowercased()
        
        // Check if target is a crypto currency
        if CryptoPriceCache.shared.isCrypto(targetLower) {
            return averageInCrypto(targetLower)
        }
        
        guard let targetUnit = UnitConverter.shared.unit(named: targetCurrencyName) else {
            return .error("Unknown currency: \(targetCurrencyName)")
        }
        
        guard !sectionValues.isEmpty else {
            return .aggregate(0, targetUnit)
        }
        
        var total: Double = 0
        
        for value in sectionValues {
            if let sourceUnit = value.unit, sourceUnit.category == .currency {
                let converted = UnitConverter.shared.convert(value.number, from: sourceUnit, to: targetUnit)
                total += converted
            } else {
                total += value.number
            }
        }
        
        return .aggregate(total / Double(sectionValues.count), targetUnit)
    }
    
    private func averageInCrypto(_ crypto: String) -> EvaluationResult {
        guard !sectionValues.isEmpty else {
            let symbol = CryptoPriceCache.shared.getSymbol(crypto)
            let cryptoUnit = Unit(name: crypto.uppercased(), symbol: symbol, category: .currency, factor: 1.0)
            return .aggregate(0, cryptoUnit)
        }
        
        // First convert everything to USD
        guard let usdUnit = UnitConverter.shared.unit(named: "usd") else {
            return .error("USD unit not found")
        }
        
        var totalUSD: Double = 0
        
        for value in sectionValues {
            if let sourceUnit = value.unit, sourceUnit.category == .currency {
                let usdValue = UnitConverter.shared.convert(value.number, from: sourceUnit, to: usdUnit)
                totalUSD += usdValue
            } else {
                totalUSD += value.number
            }
        }
        
        let avgUSD = totalUSD / Double(sectionValues.count)
        
        // Convert USD to crypto (triggers fetch if not cached)
        guard let cryptoAmount = CryptoPriceCache.shared.convertFromUSD(usdAmount: avgUSD, crypto: crypto) else {
            if CryptoPriceCache.shared.isFetching(crypto) {
                return .text("Loading...")
            }
            return .error("\(crypto.uppercased()) price unavailable")
        }
        
        // Create a crypto unit for display
        let symbol = CryptoPriceCache.shared.getSymbol(crypto)
        let cryptoUnit = Unit(name: crypto.uppercased(), symbol: symbol, category: .currency, factor: 1.0)
        
        return .aggregate(cryptoAmount, cryptoUnit, isCurrencyConversion: true)
    }
    
    private func sumWithDefaultCurrency() -> EvaluationResult {
        let (total, targetUnit) = aggregateWithDefaultCurrency(operation: .sum)
        return .aggregate(total, targetUnit)
    }
    
    private func averageWithDefaultCurrency() -> EvaluationResult {
        let (avg, targetUnit) = aggregateWithDefaultCurrency(operation: .average)
        return .aggregate(avg, targetUnit)
    }
    
    private enum AggregateOperation {
        case sum, average
    }
    
    private func aggregateWithDefaultCurrency(operation: AggregateOperation) -> (Double, Unit?) {
        // Count currency occurrences
        var currencyCounts: [String: Int] = [:]
        
        for value in sectionValues {
            if let unit = value.unit, unit.category == .currency {
                currencyCounts[unit.name, default: 0] += 1
            }
        }
        
        // Find target currency: most common, or first used if tied
        var targetUnit: Unit? = nil
        
        if !currencyCounts.isEmpty {
            let maxCount = currencyCounts.values.max() ?? 0
            let mostCommon = currencyCounts.filter { $0.value == maxCount }.map { $0.key }
            
            if mostCommon.count == 1 {
                targetUnit = UnitConverter.shared.unit(named: mostCommon[0])
            } else {
                // Tied - use first currency in order
                for currencyName in sectionCurrencyOrder {
                    if mostCommon.contains(currencyName) {
                        targetUnit = UnitConverter.shared.unit(named: currencyName)
                        break
                    }
                }
            }
        }
        
        // Aggregate and convert
        var total: Double = 0
        
        for value in sectionValues {
            if let targetUnit = targetUnit, let sourceUnit = value.unit, sourceUnit.category == .currency {
                let converted = UnitConverter.shared.convert(value.number, from: sourceUnit, to: targetUnit)
                total += converted
            } else {
                total += value.number
            }
        }
        
        switch operation {
        case .sum:
            return (total, targetUnit)
        case .average:
            let count = Double(sectionValues.count)
            return (count > 0 ? total / count : 0, targetUnit)
        }
    }
    
    private func tryParseConversion(_ words: [String], original: String) -> EvaluationResult? {
        // Find conversion keyword position
        guard let convIndex = words.firstIndex(where: { $0 == "to" || $0 == "in" || $0 == "as" }),
              convIndex > 0,
              convIndex < words.count - 1 else {
            return nil
        }
        
        let targetName = words[convIndex + 1]
        let sourceParts = Array(words[0..<convIndex])
        
        // Parse source amount and unit
        var amount: Double?
        var sourceUnitName: String?
        
        // Check for "$X" or "€X" format in first part
        if let first = sourceParts.first {
            let currencySymbols: [(String, String)] = [("$", "usd"), ("€", "eur"), ("£", "gbp"), ("¥", "jpy"), ("฿", "thb")]
            for (symbol, currency) in currencySymbols {
                if first.hasPrefix(symbol) {
                    let numStr = String(first.dropFirst())
                    amount = Double(numStr)
                    sourceUnitName = currency
                    break
                }
            }
            
            // If no currency symbol, try to parse as "X unit"
            if amount == nil {
                amount = Double(first)
                if sourceParts.count > 1 {
                    sourceUnitName = sourceParts[1]
                }
            }
        }
        
        guard let amount = amount else { return nil }
        
        // Handle crypto conversions - check if any involved crypto is being fetched
        let targetIsCrypto = CryptoPriceCache.shared.isCrypto(targetName)
        let sourceIsCrypto = sourceUnitName != nil && CryptoPriceCache.shared.isCrypto(sourceUnitName!)
        
        if targetIsCrypto && CryptoPriceCache.shared.isFetching(targetName) {
            return .text("Loading...")
        }
        if sourceIsCrypto, let src = sourceUnitName, CryptoPriceCache.shared.isFetching(src) {
            return .text("Loading...")
        }
        
        if CryptoPriceCache.shared.isCrypto(targetName) {
            // Convert to crypto
            var usdAmount = amount
            if let srcUnit = sourceUnitName, let sourceUnit = UnitConverter.shared.unit(named: srcUnit), sourceUnit.category == .currency {
                let usdUnit = UnitConverter.shared.unit(named: "usd")!
                usdAmount = UnitConverter.shared.convert(amount, from: sourceUnit, to: usdUnit)
            } else if let srcUnit = sourceUnitName, CryptoPriceCache.shared.isCrypto(srcUnit) {
                // Crypto to crypto
                if let srcUsd = CryptoPriceCache.shared.convertToUSD(amount: amount, crypto: srcUnit) {
                    usdAmount = srcUsd
                } else {
                    return .error("Price unavailable")
                }
            }
            
            if let cryptoAmount = CryptoPriceCache.shared.convertFromUSD(usdAmount: usdAmount, crypto: targetName) {
                let symbol = CryptoPriceCache.shared.getSymbol(targetName)
                return .number(cryptoAmount, Unit(name: targetName, symbol: symbol, category: .currency, factor: 1.0, symbolPosition: .after))
            }
            return .error("Price unavailable")
        }
        
        if let srcUnit = sourceUnitName, CryptoPriceCache.shared.isCrypto(srcUnit) {
            // Crypto to fiat
            if let usdAmount = CryptoPriceCache.shared.convertToUSD(amount: amount, crypto: srcUnit) {
                if let targetUnit = UnitConverter.shared.unit(named: targetName), targetUnit.category == .currency {
                    let usdUnit = UnitConverter.shared.unit(named: "usd")!
                    let converted = UnitConverter.shared.convert(usdAmount, from: usdUnit, to: targetUnit)
                    return .number(converted, targetUnit)
                }
                let usdUnit = UnitConverter.shared.unit(named: "usd")
                return .number(usdAmount, usdUnit)
            }
            return .error("Price unavailable")
        }
        
        // Regular unit conversion
        if let srcUnit = sourceUnitName, let sourceUnit = UnitConverter.shared.unit(named: srcUnit),
           let targetUnit = UnitConverter.shared.unit(named: targetName) {
            let converted = UnitConverter.shared.convert(amount, from: sourceUnit, to: targetUnit)
            let isCurrencyConversion = sourceUnit.category == .currency && targetUnit.category == .currency
            return .number(converted, targetUnit, isCurrencyConversion: isCurrencyConversion)
        }
        
        return nil
    }
    
    private func stripNaturalLanguage(_ input: String) -> String {
        var result = input
        
        // Convert word operators to symbols
        result = result.replacingOccurrences(of: " plus ", with: " + ", options: .caseInsensitive)
        result = result.replacingOccurrences(of: " minus ", with: " - ", options: .caseInsensitive)
        result = result.replacingOccurrences(of: " times ", with: " * ", options: .caseInsensitive)
        result = result.replacingOccurrences(of: " divided by ", with: " / ", options: .caseInsensitive)
        // Only replace "x" with "*" when it's between numbers (e.g., "5 x 3")
        let xPattern = try! NSRegularExpression(pattern: #"(\d)\s+x\s+(\d)"#, options: .caseInsensitive)
        result = xPattern.stringByReplacingMatches(in: result, options: [], range: NSRange(result.startIndex..., in: result), withTemplate: "$1 * $2")
        
        // Remove "for <word(s)>" phrases - e.g., "for lychee", "for moon cakes"
        // But keep "for" if it's not followed by descriptive text
        let forPattern = try! NSRegularExpression(pattern: #"\s+for\s+[a-zA-Z][a-zA-Z\s]*?(?=\s*[+\-*/]|\s*$)"#, options: .caseInsensitive)
        result = forPattern.stringByReplacingMatches(in: result, options: [], range: NSRange(result.startIndex..., in: result), withTemplate: " ")
        
        // Remove "of <descriptive>" but NOT "of" when used in "10% of 100"
        // Remove "on <word>" phrases - e.g., "on groceries"
        let onPattern = try! NSRegularExpression(pattern: #"\s+on\s+[a-zA-Z][a-zA-Z\s]*?(?=\s*[+\-*/]|\s*$)"#, options: .caseInsensitive)
        result = onPattern.stringByReplacingMatches(in: result, options: [], range: NSRange(result.startIndex..., in: result), withTemplate: " ")
        
        // Remove "from <word>" phrases
        let fromPattern = try! NSRegularExpression(pattern: #"\s+from\s+[a-zA-Z][a-zA-Z\s]*?(?=\s*[+\-*/]|\s*$)"#, options: .caseInsensitive)
        result = fromPattern.stringByReplacingMatches(in: result, options: [], range: NSRange(result.startIndex..., in: result), withTemplate: " ")
        
        // Remove descriptive words that follow numbers (like "18 apples" → "18")
        // Keep: numbers, operators, units, variables, keywords, and standalone identifiers
        let keywords = Set(["in", "to", "as", "of", "sum", "total", "average", "avg", "count"])
        let tokens = result.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        var cleanedTokens: [String] = []
        
        // Check if this is an assignment (contains =)
        let isAssignment = tokens.contains("=")
        let equalsIndex = tokens.firstIndex(of: "=") ?? tokens.endIndex
        
        var prevWasNumber = false
        
        for (index, token) in tokens.enumerated() {
            let lower = token.lowercased()
            
            // Always keep tokens before = in an assignment (variable name)
            if isAssignment && index < equalsIndex {
                cleanedTokens.append(token)
                prevWasNumber = false
                continue
            }
            
            let isNumber = Double(token) != nil || token.first?.isNumber == true
            let isOperator = ["+", "-", "*", "/", "^", "=", "(", ")"].contains(token)
            let hasCurrency = ["$", "€", "£", "¥", "฿"].contains(where: { token.contains($0) })
            let isKeyword = keywords.contains(lower)
            let isUnit = UnitConverter.shared.unit(named: lower) != nil
            let isVariable = variables[lower] != nil
            
            // Skip descriptive words that follow numbers (like "apples" in "18 apples")
            // unless they're units, keywords, or known variables
            if prevWasNumber && !isNumber && !isOperator && !hasCurrency && !isKeyword && !isUnit && !isVariable {
                // Skip this descriptive word
                continue
            }
            
            cleanedTokens.append(token)
            prevWasNumber = isNumber
        }
        result = cleanedTokens.joined(separator: " ")
        
        // Clean up multiple spaces
        let spacePattern = try! NSRegularExpression(pattern: #"\s+"#, options: [])
        result = spacePattern.stringByReplacingMatches(in: result, options: [], range: NSRange(result.startIndex..., in: result), withTemplate: " ")
        
        return result.trimmingCharacters(in: .whitespaces)
    }
    
    private func containsExpression(_ input: String) -> Bool {
        let mathPattern = try! NSRegularExpression(pattern: "[0-9$€£¥฿+\\-*/^%=]", options: [])
        let range = NSRange(input.startIndex..., in: input)
        return mathPattern.firstMatch(in: input, options: [], range: range) != nil
    }
    
    func evaluateNode(_ node: ASTNode) throws -> Value {
        switch node {
        case .number(let value):
            return Value(value)
            
        case .currency(let symbol, let value):
            let unit = UnitConverter.shared.currencyUnit(for: symbol)
            if let unit = unit, !sectionCurrencyOrder.contains(unit.name) {
                sectionCurrencyOrder.append(unit.name)
            }
            return Value(value, unit: unit)
            
        case .variable(let name):
            if let value = variables[name] {
                return value
            }
            throw EvalError("Unknown variable: \(name)")
            
        case .binaryOp(let left, let op, let right):
            let leftVal = try evaluateNode(left)
            let rightVal = try evaluateNode(right)
            
            switch op {
            case .add:
                return leftVal + rightVal
            case .subtract:
                return leftVal - rightVal
            case .multiply:
                return leftVal * rightVal
            case .divide:
                return leftVal / rightVal
            case .power:
                return Value(pow(leftVal.number, rightVal.number), unit: leftVal.unit)
            case .percentageAdd:
                let percent = rightVal.number / 100.0
                return Value(leftVal.number * (1 + percent), unit: leftVal.unit)
            case .percentageSubtract:
                let percent = rightVal.number / 100.0
                return Value(leftVal.number * (1 - percent), unit: leftVal.unit)
            }
            
        case .unaryMinus(let operand):
            let val = try evaluateNode(operand)
            return Value(-val.number, unit: val.unit)
            
        case .percentage(let operand):
            let val = try evaluateNode(operand)
            return Value(val.number / 100.0, unit: val.unit)
            
        case .percentageOf(let percent, let target):
            let pct = try evaluateNode(percent)
            let tgt = try evaluateNode(target)
            return Value((pct.number / 100.0) * tgt.number, unit: tgt.unit)
            
        case .percentageOff(let percent, let target):
            // 10% off $100 = $100 - (10% of $100) = $90
            let pct = try evaluateNode(percent)
            let tgt = try evaluateNode(target)
            let discount = (pct.number / 100.0) * tgt.number
            return Value(tgt.number - discount, unit: tgt.unit)
            
        case .asPercentOf(let numerator, let denominator):
            // $5 as a % of $10 = 50%
            let num = try evaluateNode(numerator)
            let denom = try evaluateNode(denominator)
            guard denom.number != 0 else { return Value(.nan) }
            return Value((num.number / denom.number) * 100.0, unit: nil)
            
        case .functionCall(let name, let arg):
            let val = try evaluateNode(arg)
            let result: Double
            switch name.lowercased() {
            case "sqrt":
                result = sqrt(val.number)
            case "sin":
                result = sin(val.number) // Expects radians (degrees converted in parser)
            case "cos":
                result = cos(val.number)
            case "tan":
                result = tan(val.number)
            case "ln":
                result = log(val.number) // Natural log
            case "log":
                result = log10(val.number) // Base 10 log
            case "abs":
                result = abs(val.number)
            case "floor":
                result = floor(val.number)
            case "ceil":
                result = ceil(val.number)
            case "round":
                result = round(val.number)
            default:
                throw EvalError("Unknown function: \(name)")
            }
            return Value(result, unit: val.unit)
            
        case .functionCall2(let name, let arg1, let arg2):
            let val1 = try evaluateNode(arg1)
            let val2 = try evaluateNode(arg2)
            let result: Double
            switch name.lowercased() {
            case "log":
                // log base val1 of val2
                result = log(val2.number) / log(val1.number)
            default:
                throw EvalError("Unknown function: \(name)")
            }
            return Value(result, unit: nil)
            
        case .assignment(let name, let expr):
            let value = try evaluateNode(expr)
            
            // Special handling for CSS unit configuration
            let lowerName = name.lowercased()
            if let unit = value.unit, unit.category == .css {
                switch lowerName {
                case "em":
                    // em = 14px sets the em base size
                    if unit.name == "pixel" {
                        UnitConverter.shared.emSize = value.number
                        return value
                    }
                case "rem":
                    // rem = 16px sets the rem base size
                    if unit.name == "pixel" {
                        UnitConverter.shared.remSize = value.number
                        return value
                    }
                case "ppi":
                    // ppi = 320px sets pixels per inch
                    if unit.name == "pixel" {
                        UnitConverter.shared.ppi = value.number
                        return value
                    }
                default:
                    break
                }
            }
            
            variables[name] = value
            sectionValues.append(value)
            // Track currency order
            if let unit = value.unit, unit.category == .currency, !sectionCurrencyOrder.contains(unit.name) {
                sectionCurrencyOrder.append(unit.name)
            }
            return value
            
        case .withUnit(let expr, let unitName):
            let value = try evaluateNode(expr)
            let unit = UnitConverter.shared.unit(named: unitName)
            // Track currency order
            if let unit = unit, unit.category == .currency, !sectionCurrencyOrder.contains(unit.name) {
                sectionCurrencyOrder.append(unit.name)
            }
            return Value(value.number, unit: unit)
            
        case .conversion(let expr, let targetUnitName):
            let value = try evaluateNode(expr)
            guard let sourceUnit = value.unit else {
                throw EvalError("No unit to convert from")
            }
            guard let targetUnit = UnitConverter.shared.unit(named: targetUnitName) else {
                throw EvalError("Unknown unit: \(targetUnitName)")
            }
            
            let converted = UnitConverter.shared.convert(value.number, from: sourceUnit, to: targetUnit)
            var result = Value(converted, unit: targetUnit)
            // Mark as currency conversion for visual indicator
            if sourceUnit.category == .currency && targetUnit.category == .currency {
                result.isCurrencyConversion = true
            }
            return result
        }
    }
    
    func reset() {
        variables.removeAll()
        sectionValues.removeAll()
        sectionCurrencyOrder.removeAll()
        inBlockComment = false
    }
}

struct EvalError: Error {
    let message: String
    init(_ message: String) {
        self.message = message
    }
}
