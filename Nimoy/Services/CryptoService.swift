import Foundation

class CryptoPriceCache {
    static let shared = CryptoPriceCache()
    
    private var prices: [String: Double] = [:]
    private var lastFetch: Date?
    private var isFetching = false
    private var refreshTimer: Timer?
    
    private let cryptoIds: [String: String] = [
        "btc": "bitcoin",
        "eth": "ethereum", 
        "sol": "solana",
        "doge": "dogecoin",
        "xrp": "ripple",
        "ada": "cardano",
        "dot": "polkadot",
        "matic": "matic-network",
        "link": "chainlink",
        "uni": "uniswap",
        "avax": "avalanche-2",
        "atom": "cosmos",
        "ltc": "litecoin",
        "etc": "ethereum-classic",
        "xlm": "stellar",
        "algo": "algorand",
        "near": "near",
        "ftm": "fantom",
        "bnb": "binancecoin",
        "usdt": "tether",
        "usdc": "usd-coin"
    ]
    
    private let symbols: [String: String] = [
        "btc": "₿",
        "eth": "Ξ",
        "sol": "SOL",
        "doge": "DOGE",
        "xrp": "XRP",
        "ada": "ADA",
        "dot": "DOT",
        "matic": "MATIC",
        "link": "LINK",
        "uni": "UNI",
        "avax": "AVAX",
        "atom": "ATOM",
        "ltc": "LTC",
        "etc": "ETC",
        "xlm": "XLM",
        "algo": "ALGO",
        "near": "NEAR",
        "ftm": "FTM",
        "bnb": "BNB",
        "usdt": "USDT",
        "usdc": "USDC"
    ]
    
    // Fallback prices (approximate) when API is unavailable
    private let fallbackPrices: [String: Double] = [
        "btc": 97000,
        "eth": 3300,
        "sol": 200,
        "doge": 0.35,
        "xrp": 2.5,
        "ada": 1.0,
        "dot": 7.0,
        "matic": 0.5,
        "link": 23,
        "uni": 14,
        "avax": 35,
        "atom": 7,
        "ltc": 120,
        "etc": 28,
        "xlm": 0.4,
        "algo": 0.4,
        "near": 5,
        "ftm": 0.7,
        "bnb": 680,
        "usdt": 1.0,
        "usdc": 1.0
    ]
    
    private var usingFallback = false
    
    private init() {
        // Start with fallback prices
        prices = fallbackPrices
        // Then try to load real prices async
        refreshPricesAsync()
        // Refresh every 60 seconds
        startRefreshTimer()
    }
    
    private func startRefreshTimer() {
        DispatchQueue.main.async { [weak self] in
            // Refresh every 5 minutes to stay well under rate limit (~30/min)
            self?.refreshTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
                self?.refreshPricesAsync()
            }
        }
    }
    
    func isCrypto(_ symbol: String) -> Bool {
        cryptoIds[symbol.lowercased()] != nil
    }
    
    func getSymbol(_ crypto: String) -> String {
        symbols[crypto.lowercased()] ?? crypto.uppercased()
    }
    
    func isLoading() -> Bool {
        return isFetching && prices.isEmpty
    }
    
    func hasPrices() -> Bool {
        return !prices.isEmpty
    }
    
    func getPriceInUSD(_ crypto: String) -> Double? {
        return prices[crypto.lowercased()]
    }
    
    func convertToUSD(amount: Double, crypto: String) -> Double? {
        guard let price = getPriceInUSD(crypto) else { return nil }
        return amount * price
    }
    
    func convertFromUSD(usdAmount: Double, crypto: String) -> Double? {
        guard let price = getPriceInUSD(crypto), price > 0 else { return nil }
        return usdAmount / price
    }
    
    private func refreshPricesAsync() {
        guard !isFetching else { return }
        
        let ids = cryptoIds.values.joined(separator: ",")
        let urlString = "https://api.coingecko.com/api/v3/simple/price?ids=\(ids)&vs_currencies=usd"
        
        guard let url = URL(string: urlString) else { return }
        
        isFetching = true
        
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            defer { self?.isFetching = false }
            
            guard let self = self, let data = data, error == nil else { return }
            self.parsePrices(data: data)
        }.resume()
    }
    
    private func parsePrices(data: Data) {
        do {
            // Check for rate limit error response
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let status = json["status"] as? [String: Any],
               let errorCode = status["error_code"] as? Int {
                print("CoinGecko API error \(errorCode): \(status["error_message"] ?? "Unknown")")
                // Keep using fallback/cached prices
                DispatchQueue.main.async {
                    self.usingFallback = true
                }
                return
            }
            
            // Parse successful response
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: [String: Double]] {
                var newPrices: [String: Double] = [:]
                for (symbol, coinId) in cryptoIds {
                    if let priceData = json[coinId], let usdPrice = priceData["usd"] {
                        newPrices[symbol] = usdPrice
                    }
                }
                // Only update if we got valid prices
                if !newPrices.isEmpty {
                    DispatchQueue.main.async {
                        self.prices = newPrices
                        self.lastFetch = Date()
                        self.usingFallback = false
                    }
                }
            }
        } catch {
            print("Failed to parse crypto prices: \(error)")
        }
    }
}
