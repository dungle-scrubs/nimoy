import Foundation

enum BuiltInThemes {
    static let all: [String: Theme] = [
        "dark": dark,
        "light": light,
        "solarized-dark": solarizedDark,
        "solarized-light": solarizedLight,
        "monokai": monokai,
        "nord": nord,
        "catppuccin-latte": catppuccinLatte,
        "catppuccin-frappe": catppuccinFrappe,
        "catppuccin-macchiato": catppuccinMacchiato,
        "catppuccin-mocha": catppuccinMocha
    ]
    
    static let `default` = dark
    
    // MARK: - Dark Theme (current default)
    
    static let dark = Theme(
        name: "Dark",
        colors: Theme.ThemeColors(
            background: "#262629",
            text: "#f2f2f2",
            cursor: "#ffffff",
            selection: "#3a3a3c",
            result: "#99e699",
            secondaryText: "#808080",
            border: "#3a3a3c",
            overlayBackground: "#262629",
            buttonHover: "#ffffff1a"
        ),
        syntax: Theme.SyntaxColors(
            comment: "#808080",
            number: "#e6cc66",
            unit: "#66cccc",
            keyword: "#99b3e6",
            variable: "#f2f2f2",
            operator: "#b3b3b3",
            currency: "#99e699"
        )
    )
    
    // MARK: - Light Theme
    
    static let light = Theme(
        name: "Light",
        colors: Theme.ThemeColors(
            background: "#f5f5f5",
            text: "#1a1a1a",
            cursor: "#000000",
            selection: "#b4d5fe",
            result: "#2e7d32",
            secondaryText: "#666666",
            border: "#d0d0d0",
            overlayBackground: "#ffffff",
            buttonHover: "#00000020"
        ),
        syntax: Theme.SyntaxColors(
            comment: "#6a6a6a",
            number: "#c75000",
            unit: "#0277bd",
            keyword: "#7b1fa2",
            variable: "#1a1a1a",
            operator: "#333333",
            currency: "#2e7d32"
        )
    )
    
    // MARK: - Solarized Dark
    
    static let solarizedDark = Theme(
        name: "Solarized Dark",
        colors: Theme.ThemeColors(
            background: "#002b36",
            text: "#839496",
            cursor: "#93a1a1",
            selection: "#073642",
            result: "#859900",
            secondaryText: "#586e75",
            border: "#073642",
            overlayBackground: "#073642",
            buttonHover: "#ffffff1a"
        ),
        syntax: Theme.SyntaxColors(
            comment: "#586e75",
            number: "#d33682",
            unit: "#2aa198",
            keyword: "#268bd2",
            variable: "#839496",
            operator: "#93a1a1",
            currency: "#859900"
        )
    )
    
    // MARK: - Solarized Light
    
    static let solarizedLight = Theme(
        name: "Solarized Light",
        colors: Theme.ThemeColors(
            background: "#fdf6e3",
            text: "#657b83",
            cursor: "#586e75",
            selection: "#eee8d5",
            result: "#859900",
            secondaryText: "#93a1a1",
            border: "#eee8d5",
            overlayBackground: "#eee8d5",
            buttonHover: "#0000001a"
        ),
        syntax: Theme.SyntaxColors(
            comment: "#93a1a1",
            number: "#d33682",
            unit: "#2aa198",
            keyword: "#268bd2",
            variable: "#657b83",
            operator: "#586e75",
            currency: "#859900"
        )
    )
    
    // MARK: - Monokai
    
    static let monokai = Theme(
        name: "Monokai",
        colors: Theme.ThemeColors(
            background: "#272822",
            text: "#f8f8f2",
            cursor: "#f8f8f0",
            selection: "#49483e",
            result: "#a6e22e",
            secondaryText: "#75715e",
            border: "#3e3d32",
            overlayBackground: "#3e3d32",
            buttonHover: "#ffffff1a"
        ),
        syntax: Theme.SyntaxColors(
            comment: "#75715e",
            number: "#ae81ff",
            unit: "#66d9ef",
            keyword: "#f92672",
            variable: "#f8f8f2",
            operator: "#f8f8f2",
            currency: "#a6e22e"
        )
    )
    
    // MARK: - Nord
    
    static let nord = Theme(
        name: "Nord",
        colors: Theme.ThemeColors(
            background: "#2e3440",
            text: "#d8dee9",
            cursor: "#d8dee9",
            selection: "#434c5e",
            result: "#a3be8c",
            secondaryText: "#4c566a",
            border: "#3b4252",
            overlayBackground: "#3b4252",
            buttonHover: "#ffffff1a"
        ),
        syntax: Theme.SyntaxColors(
            comment: "#616e88",
            number: "#b48ead",
            unit: "#88c0d0",
            keyword: "#81a1c1",
            variable: "#d8dee9",
            operator: "#eceff4",
            currency: "#a3be8c"
        )
    )
    
    // MARK: - Catppuccin Latte (Light)
    
    static let catppuccinLatte = Theme(
        name: "Catppuccin Latte",
        colors: Theme.ThemeColors(
            background: "#eff1f5",
            text: "#4c4f69",
            cursor: "#dc8a78",
            selection: "#ccd0da",
            result: "#40a02b",
            secondaryText: "#8c8fa1",
            border: "#ccd0da",
            overlayBackground: "#e6e9ef",
            buttonHover: "#4c4f691a"
        ),
        syntax: Theme.SyntaxColors(
            comment: "#8c8fa1",
            number: "#fe640b",
            unit: "#04a5e5",
            keyword: "#8839ef",
            variable: "#4c4f69",
            operator: "#5c5f77",
            currency: "#40a02b"
        )
    )
    
    // MARK: - Catppuccin Frappé
    
    static let catppuccinFrappe = Theme(
        name: "Catppuccin Frappé",
        colors: Theme.ThemeColors(
            background: "#303446",
            text: "#c6d0f5",
            cursor: "#f2d5cf",
            selection: "#414559",
            result: "#a6d189",
            secondaryText: "#737994",
            border: "#414559",
            overlayBackground: "#292c3c",
            buttonHover: "#c6d0f51a"
        ),
        syntax: Theme.SyntaxColors(
            comment: "#737994",
            number: "#ef9f76",
            unit: "#99d1db",
            keyword: "#ca9ee6",
            variable: "#c6d0f5",
            operator: "#b5bfe2",
            currency: "#a6d189"
        )
    )
    
    // MARK: - Catppuccin Macchiato
    
    static let catppuccinMacchiato = Theme(
        name: "Catppuccin Macchiato",
        colors: Theme.ThemeColors(
            background: "#24273a",
            text: "#cad3f5",
            cursor: "#f4dbd6",
            selection: "#363a4f",
            result: "#a6da95",
            secondaryText: "#6e738d",
            border: "#363a4f",
            overlayBackground: "#1e2030",
            buttonHover: "#cad3f51a"
        ),
        syntax: Theme.SyntaxColors(
            comment: "#6e738d",
            number: "#f5a97f",
            unit: "#91d7e3",
            keyword: "#c6a0f6",
            variable: "#cad3f5",
            operator: "#b8c0e0",
            currency: "#a6da95"
        )
    )
    
    // MARK: - Catppuccin Mocha (Darkest)
    
    static let catppuccinMocha = Theme(
        name: "Catppuccin Mocha",
        colors: Theme.ThemeColors(
            background: "#1e1e2e",
            text: "#cdd6f4",
            cursor: "#f5e0dc",
            selection: "#313244",
            result: "#a6e3a1",
            secondaryText: "#6c7086",
            border: "#313244",
            overlayBackground: "#181825",
            buttonHover: "#cdd6f41a"
        ),
        syntax: Theme.SyntaxColors(
            comment: "#6c7086",
            number: "#fab387",
            unit: "#89dceb",
            keyword: "#cba6f7",
            variable: "#cdd6f4",
            operator: "#bac2de",
            currency: "#a6e3a1"
        )
    )
}
