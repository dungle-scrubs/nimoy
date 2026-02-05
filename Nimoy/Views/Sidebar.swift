import SwiftUI

struct Sidebar: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var hoveredPageId: UUID?

    var isFloating: Bool = false

    private var theme: Theme {
        themeManager.currentTheme
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Page list (header is now in titlebar)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(appState.pages) { page in
                        SidebarRow(
                            page: page,
                            isSelected: appState.currentPage?.id == page.id,
                            isHovered: hoveredPageId == page.id,
                            theme: theme
                        ) {
                            if let index = appState.pages.firstIndex(where: { $0.id == page.id }) {
                                appState.navigateToPage(at: index)
                                // Close sidebar on selection when floating
                                if isFloating {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        appState.showSidebar = false
                                    }
                                }
                            }
                        } onDelete: {
                            if let index = appState.pages.firstIndex(where: { $0.id == page.id }) {
                                appState.deletePage(at: index)
                            }
                        }
                        .onHover { isHovered in
                            hoveredPageId = isHovered ? page.id : nil
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
            }
        }
        .contentShape(Rectangle())
    }
}

struct SidebarRow: View {
    let page: Page
    let isSelected: Bool
    let isHovered: Bool
    let theme: Theme
    let onSelect: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(page.title)
                        .font(.system(size: 13))
                        .foregroundColor(theme.textSwiftUI)
                        .lineLimit(1)

                    Text(page.modifiedAt.relativeFormatted)
                        .font(.system(size: 10))
                        .foregroundColor(theme.textSwiftUI.opacity(0.4))
                }

                Spacer()

                if isHovered {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.red.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .help("Delete Page")
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(backgroundColor)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var backgroundColor: Color {
        if isSelected {
            return theme.selectionSwiftUI.opacity(0.6)
        } else if isHovered {
            return theme.textSwiftUI.opacity(0.05)
        }
        return .clear
    }
}

private extension Date {
    var relativeFormatted: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}
