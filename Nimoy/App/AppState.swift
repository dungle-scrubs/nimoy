import SwiftUI
import Combine

@MainActor
class AppState: ObservableObject {
    @Published var pages: [Page] = []
    @Published var currentPageIndex: Int = 0
    @Published var showSearch: Bool = false { didSet { if showSearch { searchId = UUID() } } }
    @Published var showActions: Bool = false { didSet { if showActions { actionsId = UUID() } } }
    @Published var showGenerate: Bool = false { didSet { if showGenerate { generateId = UUID() } } }
    @Published var searchId = UUID()
    @Published var actionsId = UUID()
    @Published var generateId = UUID()
    
    private let storageURL: URL
    
    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        storageURL = appSupport.appendingPathComponent("Nimoy", isDirectory: true)
        
        try? FileManager.default.createDirectory(at: storageURL, withIntermediateDirectories: true)
        
        loadPages()
        
        if pages.isEmpty {
            createNewPage()
        }
    }
    
    var currentPage: Page? {
        guard currentPageIndex >= 0 && currentPageIndex < pages.count else { return nil }
        return pages[currentPageIndex]
    }
    
    func createNewPage() {
        let page = Page.newWithRandomName()
        pages.append(page)
        currentPageIndex = pages.count - 1
        savePage(page)
    }
    
    func deletePage(at index: Int) {
        guard index >= 0 && index < pages.count else { return }
        let page = pages[index]
        pages.remove(at: index)
        
        let fileURL = storageURL.appendingPathComponent("\(page.id.uuidString).json")
        try? FileManager.default.removeItem(at: fileURL)
        
        if currentPageIndex >= pages.count {
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
        guard index >= 0 && index < pages.count else { return }
        currentPageIndex = index
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
    
    func copyCurrentPageToClipboard() {
        guard let page = currentPage else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(page.content, forType: .string)
    }
    
    // MARK: - Persistence
    
    private func loadPages() {
        guard let files = try? FileManager.default.contentsOfDirectory(at: storageURL, includingPropertiesForKeys: nil) else {
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
