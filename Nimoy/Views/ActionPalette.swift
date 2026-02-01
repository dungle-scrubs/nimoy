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
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var searchText: String = ""
    @State private var selectedIndex: Int = 0
    @State private var eventMonitor: Any?
    
    var actions: [AppAction] {
        var result: [AppAction] = [
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
        
        // Add theme options
        for themeId in themeManager.themeIds {
            let themeName = themeManager.availableThemes[themeId]?.name ?? themeId
            let isCurrent = themeId == themeManager.currentThemeId
            let displayName = isCurrent ? "Theme: \(themeName) ✓" : "Theme: \(themeName)"
            result.append(AppAction(name: displayName, shortcut: nil, icon: "paintpalette") {
                themeManager.setTheme(themeId)
                appState.showActions = false
            })
        }
        
        return result
    }
    
    var filteredActions: [AppAction] {
        if searchText.isEmpty {
            return actions
        }
        return actions.filter { $0.name.lowercased().contains(searchText.lowercased()) }
    }
    
    var body: some View {
        let theme = themeManager.currentTheme
        
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
                        .foregroundColor(theme.secondaryTextSwiftUI)
                    TextField("Search actions...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16))
                        .foregroundColor(theme.textSwiftUI)
                }
                .padding(12)
                .background(theme.selectionSwiftUI)
                
                Divider()
                    .background(theme.borderSwiftUI)
                
                // Actions list
                VStack(spacing: 0) {
                    ForEach(Array(filteredActions.enumerated()), id: \.element.id) { index, action in
                        ActionRow(action: action, isSelected: index == selectedIndex, theme: theme)
                            .onTapGesture {
                                action.action()
                            }
                    }
                }
            }
            .frame(width: 400)
            .background(theme.overlayBackgroundSwiftUI)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.5), radius: 20)
            .onAppear {
                selectedIndex = 0
                setupEventMonitor()
            }
            .onDisappear {
                removeEventMonitor()
            }
        }
    }
    
    private func setupEventMonitor() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [self] event in
            switch event.keyCode {
            case 53: // Escape
                DispatchQueue.main.async {
                    appState.showActions = false
                }
                return nil
            case 125: // Down arrow
                DispatchQueue.main.async {
                    if filteredActions.isEmpty { return }
                    if selectedIndex >= filteredActions.count - 1 {
                        selectedIndex = 0  // Wrap to top
                    } else {
                        selectedIndex += 1
                    }
                }
                return nil
            case 126: // Up arrow
                DispatchQueue.main.async {
                    if filteredActions.isEmpty { return }
                    if selectedIndex <= 0 {
                        selectedIndex = filteredActions.count - 1  // Wrap to bottom
                    } else {
                        selectedIndex -= 1
                    }
                }
                return nil
            case 36: // Return
                DispatchQueue.main.async {
                    if selectedIndex < filteredActions.count {
                        filteredActions[selectedIndex].action()
                    }
                }
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

struct ActionRow: View {
    let action: AppAction
    let isSelected: Bool
    let theme: Theme
    
    var body: some View {
        HStack {
            Image(systemName: action.icon)
                .frame(width: 24)
                .foregroundColor(theme.textSwiftUI.opacity(0.8))
            
            Text(action.name)
                .foregroundColor(theme.textSwiftUI)
            
            Spacer()
            
            if let shortcut = action.shortcut {
                Text(shortcut)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(theme.secondaryTextSwiftUI)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(isSelected ? theme.selectionSwiftUI : Color.clear)
    }
}


