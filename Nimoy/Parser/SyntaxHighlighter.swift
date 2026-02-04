import AppKit

class SyntaxHighlighter {
    static let keywords = Set([
        "to",
        "in",
        "as",
        "of",
        "plus",
        "minus",
        "times",
        "divided",
        "by",
        "and",
        "sum",
        "total",
        "average",
        "avg",
        "count",
        "half",
        "quarter",
        "third",
        "double",
        "triple",
    ])

    static let units = Set([
        "km",
        "m",
        "cm",
        "mm",
        "mi",
        "mile",
        "miles",
        "ft",
        "feet",
        "foot",
        "inch",
        "inches",
        "yd",
        "yard",
        "yards",
        "kg",
        "g",
        "mg",
        "lb",
        "lbs",
        "pound",
        "pounds",
        "oz",
        "ounce",
        "ounces",
        "ton",
        "tons",
        "s",
        "sec",
        "secs",
        "second",
        "seconds",
        "min",
        "mins",
        "minute",
        "minutes",
        "hr",
        "hrs",
        "hour",
        "hours",
        "day",
        "days",
        "week",
        "weeks",
        "month",
        "months",
        "year",
        "years",
        "b",
        "kb",
        "mb",
        "gb",
        "tb",
        "byte",
        "bytes",
        "kilobyte",
        "megabyte",
        "gigabyte",
        "terabyte",
        "l",
        "ml",
        "liter",
        "liters",
        "litre",
        "litres",
        "gal",
        "gallon",
        "gallons",
        "cup",
        "cups",
        "pt",
        "pint",
        "pints",
        "usd",
        "eur",
        "gbp",
        "jpy",
        "chf",
        "thb",
        "cny",
        "krw",
        "inr",
        "euro",
        "euros",
        "dollar",
        "dollars",
        "yen",
        "baht",
        "franc",
        "francs",
        "celsius",
        "fahrenheit",
        "kelvin",
        // Crypto - Top 50 by market cap
        "btc",
        "eth",
        "usdt",
        "bnb",
        "xrp",
        "usdc",
        "sol",
        "trx",
        "doge",
        "ada",
        "bch",
        "xmr",
        "leo",
        "link",
        "xlm",
        "ltc",
        "dai",
        "avax",
        "sui",
        "shib",
        "hbar",
        "ton",
        "cro",
        "dot",
        "uni",
        "mnt",
        "bgb",
        "aave",
        "okb",
        "tao",
        "pepe",
        "near",
        "atom",
        "etc",
        "matic",
        "apt",
        "op",
        "arb",
        "vet",
        "fil",
        "algo",
        "ftm",
        "inj",
        "sei",
        "imx",
        "grt",
        "sand",
        "mana",
        "axs",
        "ape",
        // Full names
        "bitcoin",
        "ethereum",
        "tether",
        "solana",
        "dogecoin",
        "ripple",
        "cardano",
        "polkadot",
        "chainlink",
        "uniswap",
        "avalanche",
        "cosmos",
        "litecoin",
        "stellar",
        "algorand",
        "fantom",
        "monero",
        "tron",
        "filecoin",
        "aptos",
        "arbitrum",
        "optimism",
    ])

    static func highlight(_ text: String, font: NSFont, lineHeight: CGFloat, theme: Theme) -> NSAttributedString {
        let attributed = NSMutableAttributedString(string: text)
        let fullRange = NSRange(location: 0, length: text.utf16.count)

        // Paragraph style for line height and wrap indent
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.minimumLineHeight = lineHeight
        paragraphStyle.maximumLineHeight = lineHeight
        paragraphStyle.headIndent = 20 // Indent wrapped lines

        // Default attributes
        attributed.addAttribute(.font, value: font, range: fullRange)
        attributed.addAttribute(.foregroundColor, value: theme.variableColor, range: fullRange)
        attributed.addAttribute(.paragraphStyle, value: paragraphStyle, range: fullRange)

        // First pass: handle block comments /* */
        highlightBlockComments(in: attributed, theme: theme)

        // Second pass: line by line
        let lines = text.components(separatedBy: "\n")
        var currentLocation = 0
        var inBlockComment = false

        for line in lines {
            let lineRange = NSRange(location: currentLocation, length: line.utf16.count)
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)

            // Check if we're in a block comment
            if inBlockComment {
                attributed.addAttribute(.foregroundColor, value: theme.commentColor, range: lineRange)
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
                        let commentNSRange = NSRange(
                            location: currentLocation + commentStart,
                            length: commentEnd - commentStart
                        )
                        attributed.addAttribute(.foregroundColor, value: theme.commentColor, range: commentNSRange)

                        // Highlight before comment
                        if commentStart > 0 {
                            let beforeComment = String(line[..<startRange.lowerBound])
                            highlightExpression(
                                beforeComment,
                                in: attributed,
                                startingAt: currentLocation,
                                font: font,
                                theme: theme
                            )
                        }
                        // Highlight after comment
                        let afterComment = String(line[endRange.upperBound...])
                        if !afterComment.isEmpty {
                            let afterStart = currentLocation + commentEnd
                            highlightExpression(
                                afterComment,
                                in: attributed,
                                startingAt: afterStart,
                                font: font,
                                theme: theme
                            )
                        }
                    }
                } else {
                    // Block comment starts, highlight from /* to end of line
                    if let startRange = line.range(of: "/*") {
                        let commentStart = line.distance(from: line.startIndex, to: startRange.lowerBound)
                        let commentNSRange = NSRange(
                            location: currentLocation + commentStart,
                            length: line.utf16.count - commentStart
                        )
                        attributed.addAttribute(.foregroundColor, value: theme.commentColor, range: commentNSRange)

                        // Highlight before comment
                        if commentStart > 0 {
                            let beforeComment = String(line[..<startRange.lowerBound])
                            highlightExpression(
                                beforeComment,
                                in: attributed,
                                startingAt: currentLocation,
                                font: font,
                                theme: theme
                            )
                        }
                    }
                    inBlockComment = true
                }
                currentLocation += line.utf16.count + 1
                continue
            }

            // Check for markdown headings (treat as comments)
            if trimmedLine.hasPrefix("#") {
                attributed.addAttribute(.foregroundColor, value: theme.commentColor, range: lineRange)
            }
            // Check for // comments
            else if let commentRange = line.range(of: "//") {
                let commentStart = line.distance(from: line.startIndex, to: commentRange.lowerBound)
                let commentNSRange = NSRange(
                    location: currentLocation + commentStart,
                    length: line.utf16.count - commentStart
                )
                attributed.addAttribute(.foregroundColor, value: theme.commentColor, range: commentNSRange)

                if commentStart > 0 {
                    let beforeComment = String(line[..<commentRange.lowerBound])
                    highlightExpression(
                        beforeComment,
                        in: attributed,
                        startingAt: currentLocation,
                        font: font,
                        theme: theme
                    )
                }
            } else {
                highlightExpression(line, in: attributed, startingAt: currentLocation, font: font, theme: theme)
            }

            currentLocation += line.utf16.count + 1
        }

        return attributed
    }

    private static func highlightBlockComments(in attributed: NSMutableAttributedString, theme: Theme) {
        let text = attributed.string
        var searchStart = text.startIndex

        while let startRange = text.range(of: "/*", range: searchStart ..< text.endIndex) {
            if let endRange = text.range(of: "*/", range: startRange.upperBound ..< text.endIndex) {
                let nsRange = NSRange(startRange.lowerBound ..< endRange.upperBound, in: text)
                attributed.addAttribute(.foregroundColor, value: theme.commentColor, range: nsRange)
                searchStart = endRange.upperBound
            } else {
                // No closing */, highlight to end
                let nsRange = NSRange(startRange.lowerBound ..< text.endIndex, in: text)
                attributed.addAttribute(.foregroundColor, value: theme.commentColor, range: nsRange)
                break
            }
        }
    }

    private static func highlightExpression(
        _ text: String,
        in attributed: NSMutableAttributedString,
        startingAt offset: Int,
        font: NSFont,
        theme: Theme
    ) {
        // Pattern to match: currency+number, number+unit (like 5000THB), number (with optional thousands separators),
        // word, operator
        // Numbers can have commas or underscores as thousands separators: 1,000 or 1_000
        let pattern = #"(\$|€|£|¥|฿|₩|₹)[\d,_]+\.?\d*|[\d,_]+\.?\d*[a-zA-Z]+|[\d,_]+\.?\d*|\b[a-zA-Z_][a-zA-Z0-9_]*\b|[+\-*/^%=()]"#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return }

        let nsText = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))

        for match in matches {
            let matchRange = NSRange(location: offset + match.range.location, length: match.range.length)
            let matchedText = nsText.substring(with: match.range)
            let lowercased = matchedText.lowercased()

            let currencySymbols: Set<Character> = ["$", "€", "£", "¥", "฿", "₩", "₹"]

            if let first = matchedText.first, currencySymbols.contains(first) {
                // Currency symbol + number (e.g., $100)
                attributed.addAttribute(.foregroundColor, value: theme.currencyColor, range: matchRange)
            } else if matchedText.first?.isNumber == true, matchedText.contains(where: \.isLetter) {
                // Number followed by unit (e.g., 5000THB) - split and highlight separately
                if let splitIndex = matchedText.firstIndex(where: { $0.isLetter }) {
                    let numberPart = String(matchedText[..<splitIndex])
                    let unitPart = String(matchedText[splitIndex...])

                    let numberRange = NSRange(location: offset + match.range.location, length: numberPart.utf16.count)
                    let unitRange = NSRange(
                        location: offset + match.range.location + numberPart.utf16.count,
                        length: unitPart.utf16.count
                    )

                    attributed.addAttribute(.foregroundColor, value: theme.numberColor, range: numberRange)
                    if units.contains(unitPart.lowercased()) {
                        attributed.addAttribute(.foregroundColor, value: theme.unitColor, range: unitRange)
                    }
                }
            } else if isNumber(matchedText) {
                attributed.addAttribute(.foregroundColor, value: theme.numberColor, range: matchRange)
            } else if keywords.contains(lowercased) {
                attributed.addAttribute(.foregroundColor, value: theme.keywordColor, range: matchRange)
            } else if units.contains(lowercased) {
                attributed.addAttribute(.foregroundColor, value: theme.unitColor, range: matchRange)
            } else if "+-*/^%=()".contains(matchedText) {
                attributed.addAttribute(.foregroundColor, value: theme.operatorColor, range: matchRange)
            }
        }
    }

    /// Check if a string represents a number (with optional thousands separators)
    private static func isNumber(_ text: String) -> Bool {
        // Remove thousands separators (commas and underscores)
        let cleaned = text.replacingOccurrences(of: ",", with: "").replacingOccurrences(of: "_", with: "")
        return Double(cleaned) != nil
    }
}
