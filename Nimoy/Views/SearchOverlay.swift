import SwiftUI
import AppKit

struct SearchOverlay: View {
    @EnvironmentObject var appState: AppState
    @State private var searchText = ""
    @State private var selectedIndex = 0
    
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
                    
                    SearchTextField(
                        text: $searchText,
                        onSubmit: { selectCurrentPage() },
                        onEscape: { close() },
                        onArrowUp: { moveSelection(by: -1) },
                        onArrowDown: { moveSelection(by: 1) }
                    )
                    .frame(height: 24)
                    
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
                            
                            if filteredPages.isEmpty && !searchText.isEmpty {
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
                    }
                    .frame(maxHeight: 300)
                    .onChange(of: selectedIndex) { _, newIndex in
                        withAnimation {
                            proxy.scrollTo(newIndex, anchor: .center)
                        }
                    }
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
        }
    }
    
    private func moveSelection(by delta: Int) {
        let newIndex = selectedIndex + delta
        if newIndex >= 0 && newIndex < filteredPages.count {
            selectedIndex = newIndex
        }
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
}

struct SearchTextField: NSViewRepresentable {
    @Binding var text: String
    var onSubmit: () -> Void
    var onEscape: () -> Void
    var onArrowUp: () -> Void
    var onArrowDown: () -> Void
    
    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.delegate = context.coordinator
        textField.placeholderString = "Search pages..."
        textField.font = .systemFont(ofSize: 18)
        textField.isBordered = false
        textField.backgroundColor = .clear
        textField.focusRingType = .none
        textField.stringValue = ""
        
        return textField
    }
    
    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        
        // Always try to focus when view updates
        DispatchQueue.main.async {
            if nsView.window?.firstResponder != nsView.currentEditor() {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: SearchTextField
        
        init(_ parent: SearchTextField) {
            self.parent = parent
        }
        
        func controlTextDidChange(_ obj: Notification) {
            if let textField = obj.object as? NSTextField {
                parent.text = textField.stringValue
            }
        }
        
        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onSubmit()
                return true
            }
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                parent.onEscape()
                return true
            }
            if commandSelector == #selector(NSResponder.moveUp(_:)) {
                parent.onArrowUp()
                return true
            }
            if commandSelector == #selector(NSResponder.moveDown(_:)) {
                parent.onArrowDown()
                return true
            }
            return false
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
