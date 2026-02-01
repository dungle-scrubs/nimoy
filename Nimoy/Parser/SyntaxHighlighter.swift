import AppKit

class SyntaxHighlighter {
    
    // Colors
    static let commentColor = NSColor(calibratedRed: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
    static let numberColor = NSColor(calibratedRed: 0.9, green: 0.8, blue: 0.4, alpha: 1.0)
    static let unitColor = NSColor(calibratedRed: 0.4, green: 0.8, blue: 0.8, alpha: 1.0)
    static let keywordColor = NSColor(calibratedRed: 0.6, green: 0.7, blue: 0.9, alpha: 1.0)
    static let variableColor = NSColor(calibratedRed: 0.95, green: 0.95, blue: 0.95, alpha: 1.0)
    static let operatorColor = NSColor(calibratedRed: 0.7, green: 0.7, blue: 0.7, alpha: 1.0)
    static let currencyColor = NSColor(calibratedRed: 0.6, green: 0.9, blue: 0.6, alpha: 1.0)
    
    static let keywords = Set(["to", "in", "as", "of", "plus", "minus", "times", "divided", "by", "and", "sum", "total", "average", "avg", "count", "half", "quarter", "third", "double", "triple"])
    
    static let units = Set(["km", "m", "cm", "mm", "mi", "mile", "miles", "ft", "feet", "foot", "inch", "inches", "yd", "yard", "yards",
                            "kg", "g", "mg", "lb", "lbs", "pound", "pounds", "oz", "ounce", "ounces", "ton", "tons",
                            "s", "sec", "secs", "second", "seconds", "min", "mins", "minute", "minutes", "hr", "hrs", "hour", "hours", "day", "days", "week", "weeks", "month", "months", "year", "years",
                            "b", "kb", "mb", "gb", "tb", "byte", "bytes", "kilobyte", "megabyte", "gigabyte", "terabyte",
                            "l", "ml", "liter", "liters", "litre", "litres", "gal", "gallon", "gallons", "cup", "cups", "pt", "pint", "pints",
                            "usd", "eur", "gbp", "jpy", "chf", "thb", "cny", "krw", "inr", "euro", "euros", "dollar", "dollars", "yen", "baht", "franc", "francs",
                            "celsius", "fahrenheit", "kelvin",
                            // Crypto
                            "btc", "eth", "sol", "doge", "xrp", "ada", "dot", "matic", "link", "uni", "avax", "atom", "ltc", "etc", "xlm", "algo", "near", "ftm", "bnb", "usdt", "usdc",
                            "bitcoin", "ethereum", "solana", "dogecoin", "ripple", "cardano", "polkadot", "chainlink", "uniswap", "avalanche", "cosmos", "litecoin", "stellar", "algorand", "fantom"])
    
    static func highlight(_ text: String, font: NSFont, lineHeight: CGFloat) -> NSAttributedString {
        let attributed = NSMutableAttributedString(string: text)
        let fullRange = NSRange(location: 0, length: text.utf16.count)
        
        // Paragraph style for line height
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.minimumLineHeight = lineHeight
        paragraphStyle.maximumLineHeight = lineHeight
        
        // Default attributes
        attributed.addAttribute(.font, value: font, range: fullRange)
        attributed.addAttribute(.foregroundColor, value: variableColor, range: fullRange)
        attributed.addAttribute(.paragraphStyle, value: paragraphStyle, range: fullRange)
        
        // First pass: handle block comments /* */
        highlightBlockComments(in: attributed)
        
        // Second pass: line by line
        let lines = text.components(separatedBy: "\n")
        var currentLocation = 0
        var inBlockComment = false
        
        for line in lines {
            let lineRange = NSRange(location: currentLocation, length: line.utf16.count)
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            // Check if we're in a block comment
            if inBlockComment {
                attributed.addAttribute(.foregroundColor, value: commentColor, range: lineRange)
                if line.contains("*/") {
                    inBlockComment = false
                }
                currentLocation += line.utf16.count + 1
                continue
            }
            
            // Check for block comment start
            if line.contains("/*") {
                if line.contains("*/") {
                    // Single line block comment - highlight just the comment part
                    if let startRange = line.range(of: "/*"), let endRange = line.range(of: "*/") {
                        let commentStart = line.distance(from: line.startIndex, to: startRange.lowerBound)
                        let commentEnd = line.distance(from: line.startIndex, to: endRange.upperBound)
                        let commentNSRange = NSRange(location: currentLocation + commentStart, length: commentEnd - commentStart)
                        attributed.addAttribute(.foregroundColor, value: commentColor, range: commentNSRange)
                        
                        // Highlight before comment
                        if commentStart > 0 {
                            let beforeComment = String(line[..<startRange.lowerBound])
                            highlightExpression(beforeComment, in: attributed, startingAt: currentLocation, font: font)
                        }
                        // Highlight after comment
                        let afterComment = String(line[endRange.upperBound...])
                        if !afterComment.isEmpty {
                            let afterStart = currentLocation + commentEnd
                            highlightExpression(afterComment, in: attributed, startingAt: afterStart, font: font)
                        }
                    }
                } else {
                    // Block comment starts, highlight from /* to end of line
                    if let startRange = line.range(of: "/*") {
                        let commentStart = line.distance(from: line.startIndex, to: startRange.lowerBound)
                        let commentNSRange = NSRange(location: currentLocation + commentStart, length: line.utf16.count - commentStart)
                        attributed.addAttribute(.foregroundColor, value: commentColor, range: commentNSRange)
                        
                        // Highlight before comment
                        if commentStart > 0 {
                            let beforeComment = String(line[..<startRange.lowerBound])
                            highlightExpression(beforeComment, in: attributed, startingAt: currentLocation, font: font)
                        }
                    }
                    inBlockComment = true
                }
                currentLocation += line.utf16.count + 1
                continue
            }
            
            // Check for markdown headings (treat as comments)
            if trimmedLine.hasPrefix("#") {
                attributed.addAttribute(.foregroundColor, value: commentColor, range: lineRange)
            }
            // Check for // comments
            else if let commentRange = line.range(of: "//") {
                let commentStart = line.distance(from: line.startIndex, to: commentRange.lowerBound)
                let commentNSRange = NSRange(location: currentLocation + commentStart, length: line.utf16.count - commentStart)
                attributed.addAttribute(.foregroundColor, value: commentColor, range: commentNSRange)
                
                if commentStart > 0 {
                    let beforeComment = String(line[..<commentRange.lowerBound])
                    highlightExpression(beforeComment, in: attributed, startingAt: currentLocation, font: font)
                }
            } else {
                highlightExpression(line, in: attributed, startingAt: currentLocation, font: font)
            }
            
            currentLocation += line.utf16.count + 1
        }
        
        return attributed
    }
    
    private static func highlightBlockComments(in attributed: NSMutableAttributedString) {
        let text = attributed.string
        var searchStart = text.startIndex
        
        while let startRange = text.range(of: "/*", range: searchStart..<text.endIndex) {
            if let endRange = text.range(of: "*/", range: startRange.upperBound..<text.endIndex) {
                let nsRange = NSRange(startRange.lowerBound..<endRange.upperBound, in: text)
                attributed.addAttribute(.foregroundColor, value: commentColor, range: nsRange)
                searchStart = endRange.upperBound
            } else {
                // No closing */, highlight to end
                let nsRange = NSRange(startRange.lowerBound..<text.endIndex, in: text)
                attributed.addAttribute(.foregroundColor, value: commentColor, range: nsRange)
                break
            }
        }
    }
    
    private static func highlightExpression(_ text: String, in attributed: NSMutableAttributedString, startingAt offset: Int, font: NSFont) {
        let pattern = #"(\$|€|£|¥|฿|₩|₹)?\d+\.?\d*|\b[a-zA-Z_][a-zA-Z0-9_]*\b|[+\-*/^%=()]"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return }
        
        let nsText = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))
        
        for match in matches {
            let matchRange = NSRange(location: offset + match.range.location, length: match.range.length)
            let matchedText = nsText.substring(with: match.range)
            let lowercased = matchedText.lowercased()
            
            let currencySymbols: Set<Character> = ["$", "€", "£", "¥", "฿", "₩", "₹"]
            
            if let first = matchedText.first, currencySymbols.contains(first) {
                attributed.addAttribute(.foregroundColor, value: currencyColor, range: matchRange)
            } else if let _ = Double(matchedText) {
                attributed.addAttribute(.foregroundColor, value: numberColor, range: matchRange)
            } else if keywords.contains(lowercased) {
                attributed.addAttribute(.foregroundColor, value: keywordColor, range: matchRange)
            } else if units.contains(lowercased) {
                attributed.addAttribute(.foregroundColor, value: unitColor, range: matchRange)
            } else if "+-*/^%=()".contains(matchedText) {
                attributed.addAttribute(.foregroundColor, value: operatorColor, range: matchRange)
            }
        }
    }
}
