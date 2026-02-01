import XCTest
@testable import Nimoy

final class EvaluatorTests: XCTestCase {
    
    var evaluator: Evaluator!
    
    override func setUp() {
        super.setUp()
        evaluator = Evaluator()
    }
    
    override func tearDown() {
        evaluator = nil
        super.tearDown()
    }
    
    // MARK: - Basic Math
    
    func testSimpleAddition() {
        let result = evaluator.evaluate("18 + 23")
        XCTAssertEqual(result, .number(41, nil))
    }
    
    func testSimpleSubtraction() {
        let result = evaluator.evaluate("50 - 8")
        XCTAssertEqual(result, .number(42, nil))
    }
    
    func testSimpleMultiplication() {
        let result = evaluator.evaluate("6 * 7")
        XCTAssertEqual(result, .number(42, nil))
    }
    
    func testSimpleDivision() {
        let result = evaluator.evaluate("84 / 2")
        XCTAssertEqual(result, .number(42, nil))
    }
    
    // MARK: - Natural Language Operators
    
    func testPlusKeyword() {
        let result = evaluator.evaluate("18 plus 23")
        XCTAssertEqual(result, .number(41, nil))
    }
    
    func testMinusKeyword() {
        let result = evaluator.evaluate("50 minus 8")
        XCTAssertEqual(result, .number(42, nil))
    }
    
    func testTimesKeyword() {
        let result = evaluator.evaluate("6 times 7")
        XCTAssertEqual(result, .number(42, nil))
    }
    
    func testDividedByKeyword() {
        let result = evaluator.evaluate("84 divided by 2")
        XCTAssertEqual(result, .number(42, nil))
    }
    
    func testXAsMultiply() {
        let result = evaluator.evaluate("6 x 7")
        XCTAssertEqual(result, .number(42, nil))
    }
    
    // MARK: - Natural Language Stripping
    
    func testStripUnknownWords() {
        let result = evaluator.evaluate("18 apples + 23")
        XCTAssertEqual(result, .number(41, nil))
    }
    
    func testStripMultipleUnknownWords() {
        let result = evaluator.evaluate("18 apples plus 49 pears")
        XCTAssertEqual(result, .number(67, nil))
    }
    
    func testStripForPhrase() {
        let result = evaluator.evaluate("100 + 50 for groceries")
        XCTAssertEqual(result, .number(150, nil))
    }
    
    func testStripOnPhrase() {
        let result = evaluator.evaluate("200 on rent + 100")
        XCTAssertEqual(result, .number(300, nil))
    }
    
    // MARK: - Variables
    
    func testVariableAssignment() {
        let result = evaluator.evaluate("x = 42")
        XCTAssertEqual(result, .number(42, nil))
    }
    
    func testVariableReference() {
        _ = evaluator.evaluate("x = 42")
        let result = evaluator.evaluate("x")
        XCTAssertEqual(result, .number(42, nil))
    }
    
    func testVariableInExpression() {
        _ = evaluator.evaluate("x = 10")
        let result = evaluator.evaluate("x + 5")
        XCTAssertEqual(result, .number(15, nil))
    }
    
    // MARK: - Sum
    
    func testSum() {
        _ = evaluator.evaluate("a = 10")
        _ = evaluator.evaluate("b = 20")
        _ = evaluator.evaluate("c = 30")
        let result = evaluator.evaluate("sum")
        XCTAssertEqual(result, .number(60, nil))
    }
    
    func testSumWithVariableReferences() {
        _ = evaluator.evaluate("a = 10")
        _ = evaluator.evaluate("b = 20")
        _ = evaluator.evaluate("") // Section break
        _ = evaluator.evaluate("a") // Reference a
        _ = evaluator.evaluate("b") // Reference b
        let result = evaluator.evaluate("sum")
        XCTAssertEqual(result, .number(30, nil))
    }
    
    func testSumAnonymousExpressions() {
        _ = evaluator.evaluate("18 + 23")  // 41
        _ = evaluator.evaluate("18 + 49")  // 67
        let result = evaluator.evaluate("sum")
        XCTAssertEqual(result, .number(108, nil))
    }
    
    func testSumMixedExpressionsAndVariables() {
        _ = evaluator.evaluate("x = 10")
        _ = evaluator.evaluate("20 + 5")  // 25
        let result = evaluator.evaluate("sum")
        XCTAssertEqual(result, .number(35, nil))
    }
    
    // MARK: - Comments
    
    func testLineComment() {
        let result = evaluator.evaluate("// this is a comment")
        XCTAssertNil(result)
    }
    
    func testHashComment() {
        let result = evaluator.evaluate("# this is a heading")
        XCTAssertNil(result)
    }
    
    func testInlineComment() {
        let result = evaluator.evaluate("42 // the answer")
        XCTAssertEqual(result, .number(42, nil))
    }
    
    // MARK: - Empty Lines
    
    func testEmptyLine() {
        let result = evaluator.evaluate("")
        XCTAssertNil(result)
    }
    
    func testWhitespaceOnlyLine() {
        let result = evaluator.evaluate("   ")
        XCTAssertNil(result)
    }
}
