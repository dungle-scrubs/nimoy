import Foundation

indirect enum ASTNode: Equatable {
    case number(Double)
    case currency(String, Double)
    case variable(String)
    case binaryOp(ASTNode, BinaryOperator, ASTNode)
    case unaryMinus(ASTNode)
    case percentage(ASTNode)  // e.g., 15% as a standalone value
    case percentageOf(ASTNode, ASTNode)  // e.g., 15% of 200
    case assignment(String, ASTNode)
    case conversion(ASTNode, String)  // e.g., 5 km to miles
    case withUnit(ASTNode, String)  // e.g., 5 km
}

enum BinaryOperator: Equatable {
    case add, subtract, multiply, divide, power
    case percentageAdd     // 100 + 10% means 100 + (10% of 100)
    case percentageSubtract // 100 - 10% means 100 - (10% of 100)
}

class Parser {
    private var tokens: [Token]
    private var index: Int = 0
    
    init(_ tokens: [Token]) {
        self.tokens = tokens
    }
    
    private var currentToken: Token {
        guard index < tokens.count else { return .eof }
        return tokens[index]
    }
    
    private func advance() {
        index += 1
    }
    
    private func consume(_ expected: Token) -> Bool {
        if currentToken == expected {
            advance()
            return true
        }
        return false
    }
    
    func parse() -> ASTNode? {
        let result = parseAssignment()
        return result
    }
    
    // assignment = identifier "=" expression | expression
    private func parseAssignment() -> ASTNode? {
        let startIndex = index
        
        if case .identifier(let name) = currentToken {
            advance()
            if consume(.equals) {
                if let expr = parseExpression() {
                    return .assignment(name, expr)
                }
            }
        }
        
        // Reset and parse as expression
        index = startIndex
        return parseExpression()
    }
    
    // expression = term (("+"|"-") term)*
    private func parseExpression() -> ASTNode? {
        guard var left = parseTerm() else { return nil }
        
        while true {
            switch currentToken {
            case .plus:
                advance()
                // Check for percentage: 100 + 10%
                if let right = parsePercentageTerm() {
                    left = .binaryOp(left, .percentageAdd, right)
                } else if let right = parseTerm() {
                    left = .binaryOp(left, .add, right)
                } else {
                    return left
                }
                
            case .minus:
                advance()
                // Check for percentage: 100 - 10%
                if let right = parsePercentageTerm() {
                    left = .binaryOp(left, .percentageSubtract, right)
                } else if let right = parseTerm() {
                    left = .binaryOp(left, .subtract, right)
                } else {
                    return left
                }
                
            default:
                return left
            }
        }
    }
    
    // Check if next term is a percentage (for percentage add/subtract)
    private func parsePercentageTerm() -> ASTNode? {
        let startIndex = index
        
        guard let primary = parsePrimary() else {
            index = startIndex
            return nil
        }
        
        if consume(.percent) {
            return .percentage(primary)
        }
        
        // Not a percentage term, reset
        index = startIndex
        return nil
    }
    
    // term = power (("*"|"/") power)*
    private func parseTerm() -> ASTNode? {
        guard var left = parsePower() else { return nil }
        
        while true {
            switch currentToken {
            case .multiply:
                advance()
                guard let right = parsePower() else { return left }
                left = .binaryOp(left, .multiply, right)
                
            case .divide:
                advance()
                guard let right = parsePower() else { return left }
                left = .binaryOp(left, .divide, right)
                
            case .of:
                // Handle "X% of Y" or "half of Y"
                advance()
                guard let right = parsePower() else { return left }
                left = .binaryOp(left, .multiply, right)
                
            default:
                return left
            }
        }
    }
    
    // power = unary ("^" unary)*
    private func parsePower() -> ASTNode? {
        guard var left = parseUnary() else { return nil }
        
        while currentToken == .power {
            advance()
            guard let right = parseUnary() else { return left }
            left = .binaryOp(left, .power, right)
        }
        
        return left
    }
    
    // unary = "-" unary | postfix
    private func parseUnary() -> ASTNode? {
        if consume(.minus) {
            guard let operand = parseUnary() else { return nil }
            return .unaryMinus(operand)
        }
        return parsePostfix()
    }
    
    // postfix = primary ("%" | unit | "to" unit)?
    private func parsePostfix() -> ASTNode? {
        guard var node = parsePrimary() else { return nil }
        
        // Check for percentage
        if consume(.percent) {
            // Check for "X% of Y"
            if currentToken == .of {
                advance()
                if let target = parseExpression() {
                    return .percentageOf(node, target)
                }
            }
            node = .percentage(node)
        }
        
        // Check for unit
        if case .identifier(let unit) = currentToken {
            if UnitConverter.shared.isUnit(unit) {
                advance()
                node = .withUnit(node, unit)
                
                // Check for conversion: "5 km to miles"
                if consume(.to) {
                    if case .identifier(let targetUnit) = currentToken {
                        advance()
                        return .conversion(node, targetUnit)
                    }
                }
            }
        }
        
        return node
    }
    
    // primary = number | currency | identifier | "(" expression ")"
    private func parsePrimary() -> ASTNode? {
        switch currentToken {
        case .number(let value):
            advance()
            return .number(value)
            
        case .currency(let symbol, let value):
            advance()
            return .currency(symbol, value)
            
        case .identifier(let name):
            advance()
            return .variable(name)
            
        case .leftParen:
            advance()
            let expr = parseExpression()
            _ = consume(.rightParen)
            return expr
            
        default:
            return nil
        }
    }
}
