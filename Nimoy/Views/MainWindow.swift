import AppKit
import SwiftUI

struct MainWindow: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var themeManager = ThemeManager.shared

    var body: some View {
        ZStack {
            // Background that extends under titlebar
            themeManager.currentTheme.backgroundSwiftUI
                .ignoresSafeArea()

            PageCarousel()

            if appState.showSearch {
                SearchOverlay()
                    .id(appState.searchId)
            }

            if appState.showActions {
                ActionPalette()
                    .id(appState.actionsId)
            }

            if appState.showGenerate {
                GenerateOverlay(isPresented: $appState.showGenerate) { generatedContent in
                    // Insert generated content into current page
                    if appState.currentPageIndex < appState.pages.count {
                        appState.pages[appState.currentPageIndex].content = generatedContent
                    }
                }
                .id(appState.generateId)
            }
        }
        .frame(minWidth: 500, minHeight: 300)
        .toolbar(id: "main") {
            ToolbarItem(id: "spacer", placement: .automatic) {
                Spacer()
            }
            ToolbarItem(id: "add", placement: .automatic) {
                Button(action: { appState.createNewPage() }) {
                    Image(systemName: "plus")
                }
            }
            ToolbarItem(id: "search", placement: .automatic) {
                Button(action: { appState.showSearch = true }) {
                    Image(systemName: "magnifyingglass")
                }
            }
            ToolbarItem(id: "export", placement: .automatic) {
                Button(action: { appState.exportCurrentPage() }) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .toolbarRole(.editor)
        .background(WindowAccessor(appState: appState, theme: themeManager.currentTheme))
    }
}

struct WindowAccessor: NSViewRepresentable {
    let appState: AppState
    let theme: Theme

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }

            // Configure window for transparent titlebar
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.styleMask.insert(.fullSizeContentView)
            window.isMovableByWindowBackground = true
            window.titlebarSeparatorStyle = .none

            // Set window appearance based on theme brightness
            window.appearance = windowAppearance(for: theme)

            // Set window background color
            window.backgroundColor = theme.backgroundColor

            // Ensure traffic light buttons are visible
            window.standardWindowButton(.closeButton)?.isHidden = false
            window.standardWindowButton(.miniaturizeButton)?.isHidden = false
            window.standardWindowButton(.zoomButton)?.isHidden = false
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // Update window background and appearance when theme changes
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            window.appearance = windowAppearance(for: theme)
            window.backgroundColor = theme.backgroundColor
        }
    }

    private func windowAppearance(for theme: Theme) -> NSAppearance? {
        // Determine if theme is light or dark based on background luminance
        let bgColor = theme.backgroundColor
        guard let rgb = bgColor.usingColorSpace(.sRGB) else {
            return NSAppearance(named: .darkAqua)
        }

        // Calculate relative luminance
        let luminance = 0.299 * rgb.redComponent + 0.587 * rgb.greenComponent + 0.114 * rgb.blueComponent

        // If luminance > 0.5, it's a light theme
        return NSAppearance(named: luminance > 0.5 ? .aqua : .darkAqua)
    }
}

struct TitlebarButtonsToolbar: View {
    @ObservedObject var appState: AppState
    @ObservedObject private var themeManager = ThemeManager.shared

    var body: some View {
        HStack(spacing: 8) {
            Button(action: { appState.createNewPage() }) {
                Image(systemName: "plus")
            }
            Button(action: { appState.showSearch = true }) {
                Image(systemName: "magnifyingglass")
            }
            Button(action: { appState.exportCurrentPage() }) {
                Image(systemName: "square.and.arrow.up")
            }
        }
    }
}

struct TitlebarButtonsView: View {
    @ObservedObject var appState: AppState
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var hovered: String? = nil

    var body: some View {
        HStack(spacing: 8) {
            TitlebarButton(icon: "plus", isHovered: hovered == "new", theme: themeManager.currentTheme) {
                appState.createNewPage()
            }
            .onHover { hovered = $0 ? "new" : nil }

            TitlebarButton(icon: "magnifyingglass", isHovered: hovered == "search", theme: themeManager.currentTheme) {
                appState.showSearch = true
            }
            .onHover { hovered = $0 ? "search" : nil }

            TitlebarButton(
                icon: "square.and.arrow.up",
                isHovered: hovered == "export",
                theme: themeManager.currentTheme
            ) {
                appState.exportCurrentPage()
            }
            .onHover { hovered = $0 ? "export" : nil }
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(themeManager.currentTheme.backgroundSwiftUI)
    }
}

struct TitlebarButton: View {
    let icon: String
    let isHovered: Bool
    let theme: Theme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(theme.textSwiftUI.opacity(isHovered ? 0.9 : 0.6))
        }
        .buttonStyle(.plain)
        .frame(width: 24, height: 24)
        .background(theme.buttonHoverSwiftUI.opacity(isHovered ? 1 : 0))
        .cornerRadius(5)
    }
}
