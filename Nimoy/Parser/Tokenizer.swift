import Foundation

enum Token: Equatable {
    case number(Double)
    case identifier(String)
    case plus
    case minus
    case multiply
    case divide
    case power
    case percent
    case leftParen
    case rightParen
    case equals
    case to  // for unit conversion: "5 km to miles"
    case of  // for "half of", "10% of"
    case off // for "10% off $100"
    case asA // for "$5 as a % of $10"
    case currency(String, Double) // $, €, £ with value
    case function(String) // sqrt, sin, cos, tan, log
    case eof
}

class Tokenizer {
    private let input: String
    private var index: String.Index
    
    init(_ input: String) {
        self.input = input
        self.index = input.startIndex
    }
    
    private var currentChar: Character? {
        guard index < input.endIndex else { return nil }
        return input[index]
    }
    
    private func advance() {
        if index < input.endIndex {
            index = input.index(after: index)
        }
    }
    
    private func skipWhitespace() {
        while let char = currentChar, char.isWhitespace {
            advance()
        }
    }
    
    private func readNumber() -> Double? {
        var numStr = ""
        var hasDecimal = false
        
        while let char = currentChar {
            if char.isNumber {
                numStr.append(char)
                advance()
            } else if char == "." && !hasDecimal {
                hasDecimal = true
                numStr.append(char)
                advance()
            } else if char == "," {
                // Allow comma as thousands separator
                advance()
            } else {
                break
            }
        }
        
        return Double(numStr)
    }
    
    private func readIdentifier() -> String {
        var str = ""
        while let char = currentChar, (char.isLetter || char.isNumber || char == "_") {
            str.append(char)
            advance()
        }
        return str
    }
    
    func tokenize() -> [Token] {
        var tokens: [Token] = []
        
        while index < input.endIndex {
            skipWhitespace()
            guard let char = currentChar else { break }
            
            // Currency symbols
            if char == "$" || char == "€" || char == "£" {
                let symbol = String(char)
                advance()
                skipWhitespace()
                if let value = readNumber() {
                    tokens.append(.currency(symbol, value))
                } else {
                    tokens.append(.identifier(symbol))
                }
                continue
            }
            
            // Numbers
            if char.isNumber {
                if let num = readNumber() {
                    tokens.append(.number(num))
                }
                continue
            }
            
            // Identifiers and keywords
            if char.isLetter {
                let ident = readIdentifier().lowercased()
                switch ident {
                case "to", "in":
                    tokens.append(.to)
                case "of":
                    tokens.append(.of)
                case "off":
                    tokens.append(.off)
                case "as":
                    // Check for "as a" pattern - will be followed by "a"
                    tokens.append(.asA)
                case "plus", "and":
                    tokens.append(.plus)
                case "minus", "subtract":
                    tokens.append(.minus)
                case "times", "multiplied":
                    tokens.append(.multiply)
                case "divided", "over":
                    tokens.append(.divide)
                case "squared":
                    tokens.append(.power)
                    tokens.append(.number(2))
                case "cubed":
                    tokens.append(.power)
                    tokens.append(.number(3))
                case "half":
                    tokens.append(.number(0.5))
                    tokens.append(.multiply)
                case "third":
                    tokens.append(.number(1.0/3.0))
                    tokens.append(.multiply)
                case "quarter":
                    tokens.append(.number(0.25))
                    tokens.append(.multiply)
                case "double":
                    tokens.append(.number(2))
                    tokens.append(.multiply)
                case "triple":
                    tokens.append(.number(3))
                    tokens.append(.multiply)
                // Math functions
                case "sqrt", "sin", "cos", "tan", "log", "ln", "abs", "floor", "ceil", "round":
                    tokens.append(.function(ident))
                case "square":
                    // Check if next word is "root"
                    skipWhitespace()
                    if currentChar?.lowercased() == "r" {
                        let next = readIdentifier().lowercased()
                        if next == "root" {
                            tokens.append(.function("sqrt"))
                        } else {
                            tokens.append(.identifier("square"))
                            tokens.append(.identifier(next))
                        }
                    } else {
                        tokens.append(.identifier("square"))
                    }
                default:
                    tokens.append(.identifier(ident))
                }
                continue
            }
            
            // Operators
            switch char {
            case "+":
                tokens.append(.plus)
                advance()
            case "-":
                tokens.append(.minus)
                advance()
            case "*", "×":
                tokens.append(.multiply)
                advance()
            case "/":
                tokens.append(.divide)
                advance()
            case "^":
                tokens.append(.power)
                advance()
            case "%":
                tokens.append(.percent)
                advance()
            case "(":
                tokens.append(.leftParen)
                advance()
            case ")":
                tokens.append(.rightParen)
                advance()
            case "=":
                tokens.append(.equals)
                advance()
            case "°":
                // Degree symbol - mark previous number as degrees
                tokens.append(.identifier("deg"))
                advance()
            default:
                advance() // Skip unknown characters
            }
        }
        
        tokens.append(.eof)
        return tokens
    }
}
