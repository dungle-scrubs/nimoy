import AppKit
import SwiftUI

/// Defines all colors used in the app
struct Theme: Codable, Equatable {
    let name: String
    let colors: ThemeColors
    let syntax: SyntaxColors
    
    struct ThemeColors: Codable, Equatable {
        let background: String
        let text: String
        let cursor: String
        let selection: String
        let result: String
        let secondaryText: String
        let border: String
        let overlayBackground: String
        let buttonHover: String
    }
    
    struct SyntaxColors: Codable, Equatable {
        let comment: String
        let number: String
        let unit: String
        let keyword: String
        let variable: String
        let `operator`: String
        let currency: String
    }
}

// MARK: - NSColor / Color Extensions

extension Theme {
    var backgroundColor: NSColor { NSColor(hex: colors.background) }
    var textColor: NSColor { NSColor(hex: colors.text) }
    var cursorColor: NSColor { NSColor(hex: colors.cursor) }
    var selectionColor: NSColor { NSColor(hex: colors.selection) }
    var resultColor: NSColor { NSColor(hex: colors.result) }
    var secondaryTextColor: NSColor { NSColor(hex: colors.secondaryText) }
    var borderColor: NSColor { NSColor(hex: colors.border) }
    var overlayBackgroundColor: NSColor { NSColor(hex: colors.overlayBackground) }
    var buttonHoverColor: NSColor { NSColor(hex: colors.buttonHover) }
    
    var commentColor: NSColor { NSColor(hex: syntax.comment) }
    var numberColor: NSColor { NSColor(hex: syntax.number) }
    var unitColor: NSColor { NSColor(hex: syntax.unit) }
    var keywordColor: NSColor { NSColor(hex: syntax.keyword) }
    var variableColor: NSColor { NSColor(hex: syntax.variable) }
    var operatorColor: NSColor { NSColor(hex: syntax.operator) }
    var currencyColor: NSColor { NSColor(hex: syntax.currency) }
    
    // SwiftUI Colors
    var backgroundSwiftUI: Color { Color(backgroundColor) }
    var textSwiftUI: Color { Color(textColor) }
    var cursorSwiftUI: Color { Color(cursorColor) }
    var selectionSwiftUI: Color { Color(selectionColor) }
    var resultSwiftUI: Color { Color(resultColor) }
    var secondaryTextSwiftUI: Color { Color(secondaryTextColor) }
    var borderSwiftUI: Color { Color(borderColor) }
    var overlayBackgroundSwiftUI: Color { Color(overlayBackgroundColor) }
    var buttonHoverSwiftUI: Color { Color(buttonHoverColor) }
}

// MARK: - Hex Color Parsing

extension NSColor {
    convenience init(hex: String) {
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hexString.hasPrefix("#") {
            hexString.removeFirst()
        }
        
        var rgb: UInt64 = 0
        Scanner(string: hexString).scanHexInt64(&rgb)
        
        let r, g, b, a: CGFloat
        switch hexString.count {
        case 6: // RGB
            r = CGFloat((rgb >> 16) & 0xFF) / 255.0
            g = CGFloat((rgb >> 8) & 0xFF) / 255.0
            b = CGFloat(rgb & 0xFF) / 255.0
            a = 1.0
        case 8: // RGBA
            r = CGFloat((rgb >> 24) & 0xFF) / 255.0
            g = CGFloat((rgb >> 16) & 0xFF) / 255.0
            b = CGFloat((rgb >> 8) & 0xFF) / 255.0
            a = CGFloat(rgb & 0xFF) / 255.0
        default:
            r = 0; g = 0; b = 0; a = 1
        }
        
        self.init(calibratedRed: r, green: g, blue: b, alpha: a)
    }
    
    var hexString: String {
        guard let color = usingColorSpace(.sRGB) else { return "#000000" }
        let r = Int(color.redComponent * 255)
        let g = Int(color.greenComponent * 255)
        let b = Int(color.blueComponent * 255)
        return String(format: "#%02x%02x%02x", r, g, b)
    }
}
