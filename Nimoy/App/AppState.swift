import Combine
import SwiftUI

@MainActor
class AppState: ObservableObject {
    @Published var pages: [Page] = []
    @Published var currentPageIndex: Int = 0 {
        didSet { saveLastPage() }
    }

    @Published var showSearch: Bool = false {
        didSet { if showSearch { searchId = UUID() } }
    }

    @Published var showActions: Bool = false {
        didSet { if showActions { actionsId = UUID() } }
    }

    @Published var showGenerate: Bool = false {
        didSet { if showGenerate { generateId = UUID() } }
    }

    @Published var showSidebar: Bool = false

    @Published var searchId = UUID()
    @Published var actionsId = UUID()
    @Published var generateId = UUID()

    private let storageURL: URL

    private let lastPageKey = "lastOpenedPageId"

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        storageURL = appSupport.appendingPathComponent("Nimoy", isDirectory: true)

        try? FileManager.default.createDirectory(at: storageURL, withIntermediateDirectories: true)

        loadPages()

        if pages.isEmpty {
            createNewPage()
        }

        // Restore last opened page
        if let lastPageId = UserDefaults.standard.string(forKey: lastPageKey),
           let uuid = UUID(uuidString: lastPageId),
           let index = pages.firstIndex(where: { $0.id == uuid })
        {
            currentPageIndex = index
        }
    }

    var currentPage: Page? {
        guard currentPageIndex >= 0, currentPageIndex < pages.count else { return nil }
        return pages[currentPageIndex]
    }

    func createNewPage() {
        createPage(Page.newWithRandomName())
    }

    func createNewPage(titled title: String, content: String = "") {
        createPage(Page(title: title, content: content))
    }

    private func createPage(_ page: Page) {
        pages.append(page)
        currentPageIndex = pages.count - 1
        savePage(page)
    }

    func deletePage(at index: Int) {
        guard index >= 0, index < pages.count else { return }
        let page = pages[index]
        pages.remove(at: index)

        let fileURL = storageURL.appendingPathComponent("\(page.id.uuidString).json")
        try? FileManager.default.removeItem(at: fileURL)

        if index < currentPageIndex {
            currentPageIndex -= 1
        } else if currentPageIndex >= pages.count {
            currentPageIndex = max(0, pages.count - 1)
        }

        if pages.isEmpty {
            createNewPage()
        }
    }

    func updatePage(_ page: Page) {
        if let index = pages.firstIndex(where: { $0.id == page.id }) {
            pages[index] = page
            savePage(page)
        }
    }

    func navigateToPage(at index: Int) {
        guard index >= 0, index < pages.count else { return }
        currentPageIndex = index
        saveLastPage()
    }

    private func saveLastPage() {
        if let page = currentPage {
            UserDefaults.standard.set(page.id.uuidString, forKey: lastPageKey)
        }
    }

    func nextPage() {
        if currentPageIndex < pages.count - 1 {
            currentPageIndex += 1
        }
    }

    func previousPage() {
        if currentPageIndex > 0 {
            currentPageIndex -= 1
        }
    }

    func searchPages(query: String) -> [Page] {
        guard !query.isEmpty else { return pages }
        let q = query.lowercased().trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return pages }

        return pages.filter { page in
            let title = page.title.lowercased()
            let content = page.content.lowercased()
            return title.contains(q) || content.contains(q)
        }
    }

    func exportCurrentPage() {
        guard let page = currentPage else { return }

        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.plainText]
        savePanel.nameFieldStringValue = "\(page.title).txt"
        savePanel.title = "Export Page"

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                try? page.content.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }

    func exportToExcel() {
        guard let page = currentPage else { return }

        // Evaluate the content to get results
        let evaluator = Evaluator()
        let lines = page.content.components(separatedBy: "\n")
        let results = lines.enumerated().map { index, line in
            LineResult(lineNumber: index + 1, input: line, result: evaluator.evaluate(line))
        }

        // Generate Excel file
        guard let tempURL = ExcelExporter.export(content: page.content, results: results) else {
            return
        }

        // Show save panel
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.init(filenameExtension: "xlsx")!]
        savePanel.nameFieldStringValue = "\(page.title).xlsx"
        savePanel.title = "Export to Excel"

        savePanel.begin { response in
            if response == .OK, let destURL = savePanel.url {
                try? FileManager.default.removeItem(at: destURL)
                try? FileManager.default.moveItem(at: tempURL, to: destURL)
            } else {
                // Clean up temp file
                try? FileManager.default.removeItem(at: tempURL)
            }
        }
    }

    func copyCurrentPageToClipboard() {
        guard let page = currentPage else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(page.content, forType: .string)
    }

    // MARK: - Persistence

    private func loadPages() {
        guard let files = try? FileManager.default.contentsOfDirectory(at: storageURL, includingPropertiesForKeys: nil)
        else {
            return
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        pages = files
            .filter { $0.pathExtension == "json" }
            .compactMap { url -> Page? in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? decoder.decode(Page.self, from: data)
            }
            .sorted { $0.modifiedAt > $1.modifiedAt }
    }

    private func savePage(_ page: Page) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted

        guard let data = try? encoder.encode(page) else { return }

        let fileURL = storageURL.appendingPathComponent("\(page.id.uuidString).json")
        try? data.write(to: fileURL)
    }
}
