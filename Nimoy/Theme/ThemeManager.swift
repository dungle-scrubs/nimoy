import Foundation
import Combine

/// Manages theme loading and persistence using UserDefaults
@MainActor
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    private static let themeKey = "selectedTheme"
    
    @Published private(set) var currentTheme: Theme = BuiltInThemes.default
    @Published private(set) var currentThemeId: String = "dark"
    
    let availableThemes: [String: Theme] = BuiltInThemes.all
    
    private init() {
        loadTheme()
    }
    
    // MARK: - Public API
    
    /// Set theme by ID
    func setTheme(_ themeId: String) {
        guard let theme = availableThemes[themeId] else { return }
        currentThemeId = themeId
        currentTheme = theme
        UserDefaults.standard.set(themeId, forKey: Self.themeKey)
    }
    
    /// Get list of available theme IDs sorted alphabetically
    var themeIds: [String] {
        Array(availableThemes.keys).sorted()
    }
    
    // MARK: - Private
    
    private func loadTheme() {
        let savedThemeId = UserDefaults.standard.string(forKey: Self.themeKey) ?? "dark"
        
        if let theme = availableThemes[savedThemeId] {
            currentThemeId = savedThemeId
            currentTheme = theme
        } else {
            currentThemeId = "dark"
            currentTheme = BuiltInThemes.default
        }
    }
}
