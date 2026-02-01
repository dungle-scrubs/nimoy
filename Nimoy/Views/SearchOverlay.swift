import SwiftUI
import AppKit

struct SearchOverlay: View {
    @EnvironmentObject var appState: AppState
    @State private var searchText = ""
    @State private var selectedIndex = 0
    @FocusState private var isSearchFocused: Bool
    @State private var eventMonitor: Any?
    
    private var filteredPages: [Page] {
        appState.searchPages(query: searchText)
    }
    
    var body: some View {
        ZStack {
            // Backdrop
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    close()
                }
            
            // Search panel
            VStack(spacing: 0) {
                // Search field
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 18))
                    
                    TextField("Search pages...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 18))
                        .focused($isSearchFocused)
                        .onSubmit { selectCurrentPage() }
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                
                Divider()
                
                // Results list
                if !filteredPages.isEmpty {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(Array(filteredPages.enumerated()), id: \.element.id) { index, page in
                                    SearchResultRow(
                                        page: page,
                                        searchQuery: searchText,
                                        isSelected: index == selectedIndex
                                    )
                                    .id(index)
                                    .onTapGesture {
                                        navigateToPage(page)
                                    }
                                }
                            }
                        }
                        .frame(maxHeight: min(CGFloat(filteredPages.count) * 52, 300))
                        .onChange(of: selectedIndex) { _, newIndex in
                            withAnimation {
                                proxy.scrollTo(newIndex, anchor: .center)
                            }
                        }
                    }
                } else if !searchText.isEmpty {
                    VStack(spacing: 8) {
                        Text("No pages found")
                            .foregroundColor(.secondary)
                        
                        Button("Create \"\(searchText)\"") {
                            createNewPage(titled: searchText)
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.vertical, 24)
                }
            }
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
            .frame(width: 500)
            .offset(y: -50)
        }
        .onAppear {
            searchText = ""
            selectedIndex = 0
            isSearchFocused = true
            setupEventMonitor()
        }
        .onDisappear {
            removeEventMonitor()
        }
    }
    
    private func moveSelection(by delta: Int) {
        guard !filteredPages.isEmpty else { return }
        var newIndex = selectedIndex + delta
        if newIndex < 0 {
            newIndex = filteredPages.count - 1  // Wrap to bottom
        } else if newIndex >= filteredPages.count {
            newIndex = 0  // Wrap to top
        }
        selectedIndex = newIndex
    }
    
    private func selectCurrentPage() {
        guard selectedIndex >= 0 && selectedIndex < filteredPages.count else { return }
        navigateToPage(filteredPages[selectedIndex])
    }
    
    private func navigateToPage(_ page: Page) {
        if let index = appState.pages.firstIndex(where: { $0.id == page.id }) {
            appState.navigateToPage(at: index)
        }
        close()
    }
    
    private func createNewPage(titled title: String) {
        let page = Page(title: title, content: "")
        appState.pages.append(page)
        appState.currentPageIndex = appState.pages.count - 1
        close()
    }
    
    private func close() {
        appState.showSearch = false
    }
    
    private func setupEventMonitor() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            switch event.keyCode {
            case 53: // Escape
                DispatchQueue.main.async { close() }
                return nil
            case 125: // Down arrow
                DispatchQueue.main.async { moveSelection(by: 1) }
                return nil
            case 126: // Up arrow
                DispatchQueue.main.async { moveSelection(by: -1) }
                return nil
            default:
                return event
            }
        }
    }
    
    private func removeEventMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}

struct SearchResultRow: View {
    let page: Page
    let searchQuery: String
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.text")
                .foregroundColor(.secondary)
                .font(.system(size: 16))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(page.title.isEmpty ? "Untitled" : page.title)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
                
                if let preview = contentPreview {
                    Text(preview)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            Text(formatDate(page.modifiedAt))
                .font(.caption)
                .foregroundColor(Color(nsColor: .tertiaryLabelColor))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .contentShape(Rectangle())
    }
    
    private var contentPreview: String? {
        guard !searchQuery.isEmpty else { return nil }
        
        let lines = page.content.components(separatedBy: .newlines)
        if let matchingLine = lines.first(where: { $0.localizedCaseInsensitiveContains(searchQuery) }) {
            return matchingLine.trimmingCharacters(in: .whitespaces)
        }
        
        return lines.first { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
