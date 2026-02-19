@testable import Nimoy
import XCTest

/// Debug tests - only uncomment when debugging
final class DebugTest: XCTestCase {}

@MainActor
final class AppStateBehaviorTests: XCTestCase {
    private var appState: AppState!

    override func setUp() async throws {
        appState = AppState()
    }

    override func tearDown() async throws {
        appState = nil
    }

    func testDeletePageBeforeCurrentKeepsSameSelectedPage() {
        let first = Page(title: "first", content: "")
        let second = Page(title: "second", content: "")
        let third = Page(title: "third", content: "")

        appState.pages = [first, second, third]
        appState.currentPageIndex = 1

        let selectedIdBeforeDelete = appState.currentPage?.id

        appState.deletePage(at: 0)

        XCTAssertEqual(appState.currentPageIndex, 0)
        XCTAssertEqual(appState.currentPage?.id, selectedIdBeforeDelete)
    }

    func testCreateNewPageTitledPersistsAndSelectsPage() {
        let title = "search-created-\(UUID().uuidString)"
        appState.createNewPage(titled: title)

        guard let createdPage = appState.currentPage else {
            XCTFail("Expected a newly created page")
            return
        }

        XCTAssertEqual(createdPage.title, title)

        let reloadedState = AppState()
        XCTAssertTrue(reloadedState.pages.contains { $0.id == createdPage.id && $0.title == title })

        if let index = reloadedState.pages.firstIndex(where: { $0.id == createdPage.id }) {
            reloadedState.deletePage(at: index)
        }
    }
}
