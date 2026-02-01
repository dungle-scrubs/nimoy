import Foundation

class CryptoPriceCache {
    static let shared = CryptoPriceCache()
    
    private var prices: [String: Double] = [:]
    private var fetchingTokens: Set<String> = []
    
    // All supported tokens (top 50 by market cap)
    private let cryptoIds: [String: String] = [
        // Top 10
        "btc": "bitcoin", "eth": "ethereum", "usdt": "tether", "bnb": "binancecoin",
        "xrp": "ripple", "usdc": "usd-coin", "sol": "solana", "trx": "tron",
        "doge": "dogecoin", "ada": "cardano",
        // 11-20
        "bch": "bitcoin-cash", "xmr": "monero", "leo": "leo-token", "link": "chainlink",
        "xlm": "stellar", "ltc": "litecoin", "dai": "dai", "avax": "avalanche-2",
        "sui": "sui", "shib": "shiba-inu",
        // 21-30
        "hbar": "hedera-hashgraph", "ton": "the-open-network", "cro": "crypto-com-chain",
        "dot": "polkadot", "uni": "uniswap", "mnt": "mantle", "bgb": "bitget-token",
        "aave": "aave", "okb": "okb", "tao": "bittensor",
        // 31-40
        "pepe": "pepe", "near": "near", "atom": "cosmos", "etc": "ethereum-classic",
        "matic": "matic-network", "apt": "aptos", "op": "optimism", "arb": "arbitrum",
        "vet": "vechain", "fil": "filecoin",
        // 41-50
        "algo": "algorand", "ftm": "fantom", "inj": "injective-protocol", "sei": "sei-network",
        "imx": "immutable-x", "grt": "the-graph", "sand": "the-sandbox", "mana": "decentraland",
        "axs": "axie-infinity", "ape": "apecoin"
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
    
    private init() {}
    
    // MARK: - Public API
    
    func isCrypto(_ symbol: String) -> Bool {
        cryptoIds[symbol.lowercased()] != nil
    }
    
    func getSymbol(_ crypto: String) -> String {
        symbols[crypto.lowercased()] ?? crypto.uppercased()
    }
    
    /// Returns true if we're currently fetching this token
    func isFetching(_ crypto: String) -> Bool {
        fetchingTokens.contains(crypto.lowercased())
    }
    
    /// Get price, returns nil if not cached (triggers fetch)
    func getPriceInUSD(_ crypto: String) -> Double? {
        let key = crypto.lowercased()
        
        // Return cached price if available
        if let price = prices[key] {
            return price
        }
        
        // Not cached - trigger fetch if not already fetching
        if !fetchingTokens.contains(key) {
            fetchToken(key)
        }
        
        return nil
    }
    
    func convertToUSD(amount: Double, crypto: String) -> Double? {
        guard let price = getPriceInUSD(crypto) else { return nil }
        return amount * price
    }
    
    func convertFromUSD(usdAmount: Double, crypto: String) -> Double? {
        guard let price = getPriceInUSD(crypto), price > 0 else { return nil }
        return usdAmount / price
    }
    
    // MARK: - Private
    
    private func fetchToken(_ token: String) {
        guard let coinId = cryptoIds[token] else { return }
        
        fetchingTokens.insert(token)
        
        let urlString = "https://api.coingecko.com/api/v3/simple/price?ids=\(coinId)&vs_currencies=usd"
        guard let url = URL(string: urlString) else { 
            fetchingTokens.remove(token)
            return 
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            defer {
                DispatchQueue.main.async {
                    self?.fetchingTokens.remove(token)
                }
            }
            
            guard let self = self, let data = data, error == nil else { return }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: [String: Double]],
                   let priceData = json[coinId],
                   let usdPrice = priceData["usd"] {
                    DispatchQueue.main.async {
                        self.prices[token] = usdPrice
                        // Post notification so UI can refresh
                        NotificationCenter.default.post(name: .cryptoPriceUpdated, object: token)
                    }
                }
            } catch {
                print("Failed to parse crypto price for \(token): \(error)")
            }
        }.resume()
    }
}

extension Notification.Name {
    static let cryptoPriceUpdated = Notification.Name("cryptoPriceUpdated")
}
