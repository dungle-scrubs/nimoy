import Foundation

class CurrencyRateCache {
    static let shared = CurrencyRateCache()
    
    // Rates as: how many USD is 1 unit of currency worth
    private var rates: [String: Double] = [:]
    private var lastFetch: Date?
    private var isFetching = false
    private var refreshTimer: Timer?
    
    private init() {
        // Load async at startup
        refreshRatesAsync()
        // Refresh every 60 seconds
        startRefreshTimer()
    }
    
    private func startRefreshTimer() {
        DispatchQueue.main.async { [weak self] in
            self?.refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
                self?.refreshRatesAsync()
            }
        }
    }
    
    func isLoading() -> Bool {
        return isFetching && rates.isEmpty
    }
    
    func hasRates() -> Bool {
        return !rates.isEmpty
    }
    
    func getRate(_ currency: String) -> Double? {
        let cur = currency.lowercased()
        if cur == "usd" { return 1.0 }
        return rates[cur]
    }
    
    func convert(_ amount: Double, from: String, to: String) -> Double? {
        let fromCur = from.lowercased()
        let toCur = to.lowercased()
        
        if fromCur == toCur { return amount }
        
        // Get rate: how many USD is 1 unit worth
        let fromRate: Double?
        let toRate: Double?
        
        if fromCur == "usd" {
            fromRate = 1.0
        } else {
            fromRate = rates[fromCur]
        }
        
        if toCur == "usd" {
            toRate = 1.0
        } else {
            toRate = rates[toCur]
        }
        
        guard let fromR = fromRate, let toR = toRate, toR > 0 else { 
            return nil 
        }
        
        // Convert: amount * (USD per 1 from) / (USD per 1 to)
        return amount * fromR / toR
    }
    
    private func refreshRatesAsync() {
        guard !isFetching else { return }
        
        // Using frankfurter.app - free, no API key, reliable
        let urlString = "https://api.frankfurter.app/latest?from=USD"
        guard let url = URL(string: urlString) else { return }
        
        isFetching = true
        
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            defer { self?.isFetching = false }
            
            guard let self = self, let data = data, error == nil else { 
                print("Currency API error: \(error?.localizedDescription ?? "unknown")")
                return 
            }
            self.parseRates(data: data)
        }.resume()
    }
    
    private func parseRates(data: Data) {
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let ratesDict = json["rates"] as? [String: Double] {
                var newRates: [String: Double] = [:]
                
                // API returns: how many X per 1 USD (e.g., THB: 34 means 1 USD = 34 THB)
                // We want: how many USD per 1 X (e.g., THB: 0.029 means 1 THB = 0.029 USD)
                for (currency, rate) in ratesDict {
                    if rate > 0 {
                        newRates[currency.lowercased()] = 1.0 / rate
                    }
                }
                
                DispatchQueue.main.async {
                    self.rates = newRates
                    self.lastFetch = Date()
                    print("Currency rates loaded: \(newRates.count) currencies")
                }
            }
        } catch {
            print("Failed to parse currency rates: \(error)")
        }
    }
}
