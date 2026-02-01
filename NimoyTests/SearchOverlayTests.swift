import XCTest
@testable import Nimoy

@MainActor
final class SearchOverlayTests: XCTestCase {
    
    var appState: AppState!
    
    override func setUp() async throws {
        appState = AppState()
    }
    
    func testSearchCanBeOpenedMultipleTimes() {
        // First open
        XCTAssertFalse(appState.showSearch)
        let firstId = appState.searchId
        
        appState.showSearch = true
        XCTAssertTrue(appState.showSearch)
        let secondId = appState.searchId
        XCTAssertNotEqual(firstId, secondId, "searchId should change when opening")
        
        // Close
        appState.showSearch = false
        XCTAssertFalse(appState.showSearch)
        
        // Second open
        appState.showSearch = true
        XCTAssertTrue(appState.showSearch)
        let thirdId = appState.searchId
        XCTAssertNotEqual(secondId, thirdId, "searchId should change on each open")
        
        // Close
        appState.showSearch = false
        
        // Third open
        appState.showSearch = true
        XCTAssertTrue(appState.showSearch)
        let fourthId = appState.searchId
        XCTAssertNotEqual(thirdId, fourthId, "searchId should change on each open")
    }
    
    func testSearchIdOnlyChangesWhenOpening() {
        appState.showSearch = true
        let openId = appState.searchId
        
        // Closing should NOT change the ID
        appState.showSearch = false
        XCTAssertEqual(appState.searchId, openId, "searchId should NOT change when closing")
    }
    
    func testActionsCanBeOpenedMultipleTimes() {
        let firstId = appState.actionsId
        
        appState.showActions = true
        let secondId = appState.actionsId
        XCTAssertNotEqual(firstId, secondId)
        
        appState.showActions = false
        appState.showActions = true
        let thirdId = appState.actionsId
        XCTAssertNotEqual(secondId, thirdId)
        
        appState.showActions = false
        appState.showActions = true
        let fourthId = appState.actionsId
        XCTAssertNotEqual(thirdId, fourthId)
    }
}
