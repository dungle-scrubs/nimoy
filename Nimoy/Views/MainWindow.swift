import AppKit
import SwiftUI

/// Pure SwiftUI content - window is managed by AppDelegate
struct MainWindowContent: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var themeManager = ThemeManager.shared

    private let sidebarWidth: CGFloat = 220
    private let floatingThreshold: CGFloat = 600

    var body: some View {
        GeometryReader { geometry in
            let isFloating = geometry.size.width < floatingThreshold

            ZStack(alignment: .topLeading) {
                // Background
                themeManager.currentTheme.backgroundSwiftUI
                    .ignoresSafeArea()

                // Main content (PageCarousel only)
                // Only push content when sidebar is open AND not floating
                PageCarousel()
                    .frame(maxWidth: .infinity)
                    .padding(.leading, (appState.showSidebar && !isFloating) ? sidebarWidth : 0)
                    .padding(.top, 38)
                    .animation(.easeInOut(duration: 0.25), value: appState.showSidebar)
                    .animation(.easeInOut(duration: 0.25), value: isFloating)

                // LEFT side: plus button + drawer button + full-width divider
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Spacer()
                        if appState.showSidebar {
                            SidebarPlusButton()
                                .environmentObject(appState)
                                .transition(.move(edge: .leading).combined(with: .opacity))
                        }
                        DrawerToggleButton()
                            .environmentObject(appState)
                    }
                    .padding(.trailing, 12)

                    if appState.showSidebar {
                        Divider()
                            .padding(.trailing, 12)
                            .transition(.opacity)
                    }
                }
                .frame(width: appState.showSidebar ? sidebarWidth : 78 + 40, height: 36, alignment: .top)
                .padding(.top, 2)
                .animation(.easeInOut(duration: 0.25), value: appState.showSidebar)
                .zIndex(1)

                // RIGHT side: toolbar buttons
                HStack {
                    Spacer()
                    ContentToolbarButtons(appState: appState)
                        .padding(.trailing, 12)
                }
                .frame(maxHeight: 40, alignment: .top)
                .padding(.top, 4)
                .zIndex(1)

                // Overlays
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

                // Floating sidebar overlay (dim background when floating)
                if appState.showSidebar, isFloating {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                appState.showSidebar = false
                            }
                        }
                }

                // Sidebar - LAST in ZStack to be on top for hit testing
                if appState.showSidebar {
                    Sidebar(isFloating: isFloating)
                        .environmentObject(appState)
                        .frame(width: sidebarWidth)
                        .padding(.top, 38)
                        .background(themeManager.currentTheme.backgroundSwiftUI)
                        .shadow(color: isFloating ? .black.opacity(0.2) : .clear, radius: 10, x: 5, y: 0)
                        .transition(.move(edge: .leading))
                }
            }
        }
        .frame(minWidth: 480, minHeight: 300)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }
}

struct MainWindow: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        MainWindowContent()
            .environmentObject(appState)
    }
}

struct SidebarPlusButton: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var isHovered = false

    var body: some View {
        Button {
            appState.createNewPage()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(themeManager.currentTheme.textSwiftUI.opacity(isHovered ? 0.9 : 0.5))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

struct DrawerToggleButton: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var isHovered = false

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                appState.showSidebar.toggle()
            }
        } label: {
            Image(systemName: "sidebar.left")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(themeManager.currentTheme.textSwiftUI.opacity(isHovered ? 0.9 : 0.5))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
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
