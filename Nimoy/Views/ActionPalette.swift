import SwiftUI
import AppKit

struct AppAction: Identifiable {
    let id = UUID()
    let name: String
    let shortcut: String?
    let icon: String
    let action: () -> Void
}

struct ActionPalette: View {
    @EnvironmentObject var appState: AppState
    @State private var searchText: String = ""
    @State private var selectedIndex: Int = 0
    
    var actions: [AppAction] {
        [
            AppAction(name: "New Page", shortcut: "⌘N", icon: "plus") {
                appState.createNewPage()
                appState.showActions = false
            },
            AppAction(name: "Search Pages", shortcut: "⌘O", icon: "magnifyingglass") {
                appState.showActions = false
                appState.showSearch = true
            },
            AppAction(name: "Export to File", shortcut: "⌘E", icon: "square.and.arrow.up") {
                appState.showActions = false
                appState.exportCurrentPage()
            },
            AppAction(name: "Copy to Clipboard", shortcut: "⌘⇧C", icon: "doc.on.doc") {
                appState.copyCurrentPageToClipboard()
                appState.showActions = false
            },
            AppAction(name: "Delete Page", shortcut: nil, icon: "trash") {
                appState.deletePage(at: appState.currentPageIndex)
                appState.showActions = false
            },
        ]
    }
    
    var filteredActions: [AppAction] {
        if searchText.isEmpty {
            return actions
        }
        return actions.filter { $0.name.lowercased().contains(searchText.lowercased()) }
    }
    
    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    appState.showActions = false
                }
            
            // Action palette
            VStack(spacing: 0) {
                // Search field
                HStack {
                    Image(systemName: "command")
                        .foregroundColor(.gray)
                    TextField("Search actions...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                }
                .padding(12)
                .background(Color(white: 0.2))
                
                Divider()
                    .background(Color.gray.opacity(0.3))
                
                // Actions list
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(filteredActions.enumerated()), id: \.element.id) { index, action in
                            ActionRow(action: action, isSelected: index == selectedIndex)
                                .onTapGesture {
                                    action.action()
                                }
                        }
                    }
                }
                .frame(maxHeight: 300)
            }
            .frame(width: 400)
            .background(Color(white: 0.15))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.5), radius: 20)
            .onAppear {
                selectedIndex = 0
            }
            .background(
                KeyEventHandler { event in
                    handleKeyEvent(event)
                }
            )
        }
    }
    
    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        switch event.keyCode {
        case 53: // Escape
            appState.showActions = false
            return true
        case 125: // Down arrow
            if selectedIndex < filteredActions.count - 1 {
                selectedIndex += 1
            }
            return true
        case 126: // Up arrow
            if selectedIndex > 0 {
                selectedIndex -= 1
            }
            return true
        case 36: // Return
            if selectedIndex < filteredActions.count {
                filteredActions[selectedIndex].action()
            }
            return true
        default:
            return false
        }
    }
}

struct ActionRow: View {
    let action: AppAction
    let isSelected: Bool
    
    var body: some View {
        HStack {
            Image(systemName: action.icon)
                .frame(width: 24)
                .foregroundColor(.white.opacity(0.8))
            
            Text(action.name)
                .foregroundColor(.white)
            
            Spacer()
            
            if let shortcut = action.shortcut {
                Text(shortcut)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(isSelected ? Color.white.opacity(0.1) : Color.clear)
    }
}

struct KeyEventHandler: NSViewRepresentable {
    let handler: (NSEvent) -> Bool
    
    func makeNSView(context: Context) -> KeyEventView {
        let view = KeyEventView()
        view.handler = handler
        return view
    }
    
    func updateNSView(_ nsView: KeyEventView, context: Context) {
        nsView.handler = handler
    }
}

class KeyEventView: NSView {
    var handler: ((NSEvent) -> Bool)?
    
    override var acceptsFirstResponder: Bool { true }
    
    override func keyDown(with event: NSEvent) {
        if handler?(event) != true {
            super.keyDown(with: event)
        }
    }
}
