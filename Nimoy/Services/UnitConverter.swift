import Foundation

enum UnitCategory: String, CaseIterable {
    case length
    case mass
    case time
    case temperature
    case data
    case currency
    case area
    case volume
}

enum SymbolPosition {
    case before  // $100
    case after   // 100€
}

struct Unit: Equatable {
    let name: String
    let symbol: String
    let category: UnitCategory
    let toBase: Double
    let fromBase: Double
    let symbolPosition: SymbolPosition
    
    init(name: String, symbol: String, category: UnitCategory, factor: Double, symbolPosition: SymbolPosition = .after) {
        self.name = name
        self.symbol = symbol
        self.category = category
        self.toBase = factor
        self.fromBase = 1.0 / factor
        self.symbolPosition = symbolPosition
    }
    
    func format(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = category == .currency ? 2 : 0
        
        let formatted = formatter.string(from: NSNumber(value: value)) ?? String(value)
        
        switch symbolPosition {
        case .before:
            return "\(symbol)\(formatted)"
        case .after:
            return "\(formatted) \(symbol)"
        }
    }
}

class UnitConverter {
    static let shared = UnitConverter()
    
    private var units: [String: Unit] = [:]
    private var aliases: [String: String] = [:]
    
    private init() {
        registerUnits()
    }
    
    private func registerUnits() {
        // Length (base: meter)
        register(Unit(name: "meter", symbol: "m", category: .length, factor: 1.0), aliases: ["meters", "metre", "metres"])
        register(Unit(name: "kilometer", symbol: "km", category: .length, factor: 1000.0), aliases: ["kilometers", "kilometre", "kilometres"])
        register(Unit(name: "centimeter", symbol: "cm", category: .length, factor: 0.01), aliases: ["centimeters", "centimetre", "centimetres"])
        register(Unit(name: "millimeter", symbol: "mm", category: .length, factor: 0.001), aliases: ["millimeters", "millimetre", "millimetres"])
        register(Unit(name: "mile", symbol: "mi", category: .length, factor: 1609.344), aliases: ["miles"])
        register(Unit(name: "yard", symbol: "yd", category: .length, factor: 0.9144), aliases: ["yards"])
        register(Unit(name: "foot", symbol: "ft", category: .length, factor: 0.3048), aliases: ["feet"])
        register(Unit(name: "inch", symbol: "in", category: .length, factor: 0.0254), aliases: ["inches"])
        
        // Mass (base: kilogram)
        register(Unit(name: "kilogram", symbol: "kg", category: .mass, factor: 1.0), aliases: ["kilograms", "kilo", "kilos"])
        register(Unit(name: "gram", symbol: "g", category: .mass, factor: 0.001), aliases: ["grams"])
        register(Unit(name: "milligram", symbol: "mg", category: .mass, factor: 0.000001), aliases: ["milligrams"])
        register(Unit(name: "pound", symbol: "lb", category: .mass, factor: 0.453592), aliases: ["pounds", "lbs"])
        register(Unit(name: "ounce", symbol: "oz", category: .mass, factor: 0.0283495), aliases: ["ounces"])
        register(Unit(name: "ton", symbol: "t", category: .mass, factor: 1000.0), aliases: ["tons", "tonne", "tonnes"])
        
        // Time (base: second)
        register(Unit(name: "second", symbol: "s", category: .time, factor: 1.0), aliases: ["seconds", "sec", "secs"])
        register(Unit(name: "minute", symbol: "min", category: .time, factor: 60.0), aliases: ["minutes", "mins"])
        register(Unit(name: "hour", symbol: "hr", category: .time, factor: 3600.0), aliases: ["hours", "hrs"])
        register(Unit(name: "day", symbol: "day", category: .time, factor: 86400.0), aliases: ["days"])
        register(Unit(name: "week", symbol: "wk", category: .time, factor: 604800.0), aliases: ["weeks", "wks"])
        register(Unit(name: "month", symbol: "mo", category: .time, factor: 2629746.0), aliases: ["months"])
        register(Unit(name: "year", symbol: "yr", category: .time, factor: 31556952.0), aliases: ["years", "yrs"])
        
        // Data (base: byte)
        register(Unit(name: "byte", symbol: "B", category: .data, factor: 1.0), aliases: ["bytes"])
        register(Unit(name: "kilobyte", symbol: "KB", category: .data, factor: 1024.0), aliases: ["kilobytes", "kb"])
        register(Unit(name: "megabyte", symbol: "MB", category: .data, factor: 1048576.0), aliases: ["megabytes", "mb"])
        register(Unit(name: "gigabyte", symbol: "GB", category: .data, factor: 1073741824.0), aliases: ["gigabytes", "gb"])
        register(Unit(name: "terabyte", symbol: "TB", category: .data, factor: 1099511627776.0), aliases: ["terabytes", "tb"])
        
        // Currency (base: USD) - symbol position matters!
        // Symbol BEFORE number
        register(Unit(name: "usd", symbol: "$", category: .currency, factor: 1.0, symbolPosition: .before), aliases: ["dollar", "dollars"])
        register(Unit(name: "gbp", symbol: "£", category: .currency, factor: 1.27, symbolPosition: .before), aliases: ["sterling"])
        register(Unit(name: "jpy", symbol: "¥", category: .currency, factor: 0.0067, symbolPosition: .before), aliases: ["yen"])
        register(Unit(name: "cny", symbol: "CN¥", category: .currency, factor: 0.14, symbolPosition: .before), aliases: ["yuan", "rmb"])
        register(Unit(name: "krw", symbol: "₩", category: .currency, factor: 0.00075, symbolPosition: .before), aliases: ["won"])
        register(Unit(name: "inr", symbol: "₹", category: .currency, factor: 0.012, symbolPosition: .before), aliases: ["rupee", "rupees"])
        
        // Symbol AFTER number  
        register(Unit(name: "eur", symbol: "€", category: .currency, factor: 1.08, symbolPosition: .after), aliases: ["euro", "euros"])
        register(Unit(name: "thb", symbol: "THB", category: .currency, factor: 0.029, symbolPosition: .after), aliases: ["baht"])
        register(Unit(name: "chf", symbol: "CHF", category: .currency, factor: 1.13, symbolPosition: .after), aliases: ["franc", "francs"])
        register(Unit(name: "sek", symbol: "kr", category: .currency, factor: 0.096, symbolPosition: .after), aliases: ["krona", "kronor"])
        register(Unit(name: "nok", symbol: "kr", category: .currency, factor: 0.094, symbolPosition: .after), aliases: [])
        register(Unit(name: "dkk", symbol: "kr", category: .currency, factor: 0.15, symbolPosition: .after), aliases: [])
        register(Unit(name: "pln", symbol: "zł", category: .currency, factor: 0.25, symbolPosition: .after), aliases: ["zloty"])
        register(Unit(name: "czk", symbol: "Kč", category: .currency, factor: 0.044, symbolPosition: .after), aliases: ["koruna"])
        register(Unit(name: "rub", symbol: "₽", category: .currency, factor: 0.011, symbolPosition: .after), aliases: ["ruble", "rubles"])
        register(Unit(name: "brl", symbol: "R$", category: .currency, factor: 0.20, symbolPosition: .before), aliases: ["real", "reais"])
        register(Unit(name: "aud", symbol: "A$", category: .currency, factor: 0.66, symbolPosition: .before), aliases: [])
        register(Unit(name: "cad", symbol: "C$", category: .currency, factor: 0.74, symbolPosition: .before), aliases: [])
        register(Unit(name: "sgd", symbol: "S$", category: .currency, factor: 0.75, symbolPosition: .before), aliases: [])
        register(Unit(name: "hkd", symbol: "HK$", category: .currency, factor: 0.13, symbolPosition: .before), aliases: [])
        register(Unit(name: "mxn", symbol: "MX$", category: .currency, factor: 0.058, symbolPosition: .before), aliases: ["peso", "pesos"])
        
        // Area (base: square meter)
        register(Unit(name: "sqm", symbol: "m²", category: .area, factor: 1.0), aliases: ["sqmeter", "sqmeters", "squaremeter", "squaremeters"])
        register(Unit(name: "sqkm", symbol: "km²", category: .area, factor: 1000000.0), aliases: ["sqkilometer", "sqkilometers"])
        register(Unit(name: "sqft", symbol: "ft²", category: .area, factor: 0.092903), aliases: ["sqfoot", "sqfeet", "squarefoot", "squarefeet"])
        register(Unit(name: "acre", symbol: "ac", category: .area, factor: 4046.86), aliases: ["acres"])
        register(Unit(name: "hectare", symbol: "ha", category: .area, factor: 10000.0), aliases: ["hectares"])
        
        // Volume (base: liter)
        register(Unit(name: "liter", symbol: "L", category: .volume, factor: 1.0), aliases: ["liters", "litre", "litres", "l"])
        register(Unit(name: "milliliter", symbol: "mL", category: .volume, factor: 0.001), aliases: ["milliliters", "ml"])
        register(Unit(name: "gallon", symbol: "gal", category: .volume, factor: 3.78541), aliases: ["gallons"])
        register(Unit(name: "quart", symbol: "qt", category: .volume, factor: 0.946353), aliases: ["quarts"])
        register(Unit(name: "pint", symbol: "pt", category: .volume, factor: 0.473176), aliases: ["pints"])
        register(Unit(name: "cup", symbol: "cup", category: .volume, factor: 0.236588), aliases: ["cups"])
        register(Unit(name: "floz", symbol: "fl oz", category: .volume, factor: 0.0295735), aliases: ["fluidounce", "fluidounces"])
    }
    
    private func register(_ unit: Unit, aliases: [String] = []) {
        units[unit.name.lowercased()] = unit
        units[unit.symbol.lowercased()] = unit
        
        for alias in aliases {
            self.aliases[alias.lowercased()] = unit.name.lowercased()
        }
    }
    
    func isUnit(_ name: String) -> Bool {
        let lower = name.lowercased()
        return units[lower] != nil || aliases[lower] != nil
    }
    
    func unit(named name: String) -> Unit? {
        let lower = name.lowercased()
        if let unit = units[lower] {
            return unit
        }
        if let canonical = aliases[lower], let unit = units[canonical] {
            return unit
        }
        return nil
    }
    
    func currencyUnit(for symbol: String) -> Unit? {
        switch symbol {
        case "$": return unit(named: "usd")
        case "€": return unit(named: "eur")
        case "£": return unit(named: "gbp")
        case "¥": return unit(named: "jpy")
        case "฿": return unit(named: "thb")
        case "₩": return unit(named: "krw")
        case "₹": return unit(named: "inr")
        case "₽": return unit(named: "rub")
        default: return nil
        }
    }
    
    func convert(_ value: Double, from source: Unit, to target: Unit) -> Double {
        guard source.category == target.category else {
            return .nan
        }
        
        if source.category == .temperature {
            return convertTemperature(value, from: source, to: target)
        }
        
        // Use real-time rates for currency if available
        if source.category == .currency {
            if let converted = CurrencyRateCache.shared.convert(value, from: source.name, to: target.name) {
                return converted
            }
            // Fall back to static rates if API not loaded yet
        }
        
        let baseValue = value * source.toBase
        return baseValue * target.fromBase
    }
    
    private func convertTemperature(_ value: Double, from source: Unit, to target: Unit) -> Double {
        var kelvin: Double
        switch source.name.lowercased() {
        case "celsius", "c":
            kelvin = value + 273.15
        case "fahrenheit", "f":
            kelvin = (value - 32) * 5/9 + 273.15
        case "kelvin", "k":
            kelvin = value
        default:
            return .nan
        }
        
        switch target.name.lowercased() {
        case "celsius", "c":
            return kelvin - 273.15
        case "fahrenheit", "f":
            return (kelvin - 273.15) * 9/5 + 32
        case "kelvin", "k":
            return kelvin
        default:
            return .nan
        }
    }
}
