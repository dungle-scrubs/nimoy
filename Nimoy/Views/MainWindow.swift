import AppKit
import SwiftUI

/// Pure SwiftUI content - window is managed by AppDelegate
struct MainWindowContent: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var themeManager = ThemeManager.shared

    var body: some View {
        ZStack(alignment: .top) {
            // Background extends to edges
            themeManager.currentTheme.backgroundSwiftUI
                .ignoresSafeArea()

            PageCarousel()

            // Titlebar buttons
            HStack {
                // Drawer toggle (right of traffic lights)
                DrawerToggleButton()
                    .padding(.leading, 78) // Clear traffic lights

                Spacer()

                // Right-side toolbar buttons
                ContentToolbarButtons(appState: appState)
                    .padding(.trailing, 12)
            }
            .padding(.top, 2)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .ignoresSafeArea()

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
                    if appState.currentPageIndex < appState.pages.count {
                        appState.pages[appState.currentPageIndex].content = generatedContent
                    }
                }
                .id(appState.generateId)
            }
        }
        .frame(minWidth: 500, minHeight: 300)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }
}

/// Keep for backwards compatibility if needed
struct MainWindow: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        MainWindowContent()
            .environmentObject(appState)
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

struct DrawerToggleButton: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var isHovered = false

    var body: some View {
        Image(systemName: "sidebar.left")
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(themeManager.currentTheme.textSwiftUI.opacity(isHovered ? 0.9 : 0.5))
            .frame(width: 28, height: 28)
            .contentShape(Rectangle())
            .onTapGesture {
                // TODO: Toggle drawer
            }
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

struct ContentToolbarButtons: View {
    @ObservedObject var appState: AppState
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var hoveredButton: String?

    var body: some View {
        HStack(spacing: 8) {
            toolbarButton(icon: "plus", id: "add") {
                appState.createNewPage()
            }
            toolbarButton(icon: "magnifyingglass", id: "search") {
                appState.showSearch = true
            }
            toolbarButton(icon: "square.and.arrow.up", id: "export") {
                appState.exportCurrentPage()
            }
        }
    }

    private func toolbarButton(icon: String, id: String, action: @escaping () -> Void) -> some View {
        Image(systemName: icon)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(themeManager.currentTheme.textSwiftUI.opacity(hoveredButton == id ? 0.9 : 0.5))
            .frame(width: 28, height: 28)
            .contentShape(Rectangle())
            .onTapGesture(perform: action)
            .onHover { isHovered in
                hoveredButton = isHovered ? id : nil
            }
    }
}
