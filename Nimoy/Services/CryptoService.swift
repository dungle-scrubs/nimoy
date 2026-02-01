import Foundation

class CryptoPriceCache {
    static let shared = CryptoPriceCache()
    
    private var prices: [String: Double] = [:]
    private var lastFetch: Date?
    private var isFetching = false
    private var refreshTimer: Timer?
    
    // Top 50 mainstream crypto tokens by market cap
    private let cryptoIds: [String: String] = [
        // Top 10
        "btc": "bitcoin",
        "eth": "ethereum",
        "usdt": "tether",
        "bnb": "binancecoin",
        "xrp": "ripple",
        "usdc": "usd-coin",
        "sol": "solana",
        "trx": "tron",
        "doge": "dogecoin",
        "ada": "cardano",
        // 11-20
        "bch": "bitcoin-cash",
        "xmr": "monero",
        "leo": "leo-token",
        "link": "chainlink",
        "xlm": "stellar",
        "ltc": "litecoin",
        "dai": "dai",
        "avax": "avalanche-2",
        "sui": "sui",
        "shib": "shiba-inu",
        // 21-30
        "hbar": "hedera-hashgraph",
        "ton": "the-open-network",
        "cro": "crypto-com-chain",
        "dot": "polkadot",
        "uni": "uniswap",
        "mnt": "mantle",
        "bgb": "bitget-token",
        "aave": "aave",
        "okb": "okb",
        "tao": "bittensor",
        // 31-40
        "pepe": "pepe",
        "near": "near",
        "atom": "cosmos",
        "etc": "ethereum-classic",
        "matic": "matic-network",
        "apt": "aptos",
        "op": "optimism",
        "arb": "arbitrum",
        "vet": "vechain",
        "fil": "filecoin",
        // 41-50
        "algo": "algorand",
        "ftm": "fantom",
        "inj": "injective-protocol",
        "sei": "sei-network",
        "imx": "immutable-x",
        "grt": "the-graph",
        "sand": "the-sandbox",
        "mana": "decentraland",
        "axs": "axie-infinity",
        "ape": "apecoin"
    ]
    
    private let symbols: [String: String] = [
        "btc": "₿", "eth": "Ξ", "usdt": "₮", "bnb": "BNB", "xrp": "XRP",
        "usdc": "USDC", "sol": "◎", "trx": "TRX", "doge": "Ð", "ada": "₳",
        "bch": "BCH", "xmr": "ɱ", "leo": "LEO", "link": "LINK", "xlm": "XLM",
        "ltc": "Ł", "dai": "DAI", "avax": "AVAX", "sui": "SUI", "shib": "SHIB",
        "hbar": "ℏ", "ton": "TON", "cro": "CRO", "dot": "DOT", "uni": "UNI",
        "mnt": "MNT", "bgb": "BGB", "aave": "AAVE", "okb": "OKB", "tao": "TAO",
        "pepe": "PEPE", "near": "NEAR", "atom": "ATOM", "etc": "ETC", "matic": "MATIC",
        "apt": "APT", "op": "OP", "arb": "ARB", "vet": "VET", "fil": "FIL",
        "algo": "ALGO", "ftm": "FTM", "inj": "INJ", "sei": "SEI", "imx": "IMX",
        "grt": "GRT", "sand": "SAND", "mana": "MANA", "axs": "AXS", "ape": "APE"
    ]
    
    // Fallback prices (approximate USD) when API is unavailable
    private let fallbackPrices: [String: Double] = [
        // Top 10
        "btc": 77000, "eth": 2300, "usdt": 1.0, "bnb": 750, "xrp": 1.6,
        "usdc": 1.0, "sol": 100, "trx": 0.28, "doge": 0.10, "ada": 0.29,
        // 11-20
        "bch": 520, "xmr": 420, "leo": 8.3, "link": 9.5, "xlm": 0.17,
        "ltc": 58, "dai": 1.0, "avax": 10, "sui": 1.1, "shib": 0.000007,
        // 21-30
        "hbar": 0.09, "ton": 1.3, "cro": 0.08, "dot": 1.5, "uni": 3.8,
        "mnt": 0.68, "bgb": 3.0, "aave": 123, "okb": 86, "tao": 190,
        // 31-40
        "pepe": 0.000004, "near": 1.2, "atom": 2.0, "etc": 9.5, "matic": 0.15,
        "apt": 4.0, "op": 0.7, "arb": 0.25, "vet": 0.02, "fil": 2.3,
        // 41-50
        "algo": 0.10, "ftm": 0.05, "inj": 8.0, "sei": 0.12, "imx": 0.4,
        "grt": 0.07, "sand": 0.22, "mana": 0.22, "axs": 2.8, "ape": 0.4
    ]
    
    private var usingFallback = false
    
    private init() {
        // Start with fallback prices
        prices = fallbackPrices
        // Then try to load real prices async
        refreshPricesAsync()
        // Refresh every 5 minutes to stay under rate limit (~30/min)
        startRefreshTimer()
    }
    
    private func startRefreshTimer() {
        DispatchQueue.main.async { [weak self] in
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
