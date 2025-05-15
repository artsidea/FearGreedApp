//
//  VIXFetcher.swift
//  Feer & Greed Score
//
//  Created by hyujang on 5/11/25.
//

import Foundation

struct VIXFetcher {
    static let shared = VIXFetcher()
    private let baseURL = "https://query1.finance.yahoo.com/v8/finance/chart/%5EVIX"
    private let userDefaults = UserDefaults(suiteName: "group.com.hyujang.feargreed") ?? UserDefaults.standard
    private let lastUpdateKey = "lastVIXUpdate"
    private let vixValueKey = "lastVIXValue"
    private let vixScoreKey = "lastVIXScore"
    
    private init() {}
    
    func fetchVIX() async throws -> Double {
        // 마지막 업데이트 시간 확인
        if let lastUpdate = userDefaults.object(forKey: lastUpdateKey) as? Date {
            let calendar = Calendar.current
            if calendar.isDateInToday(lastUpdate) {
                // 오늘 이미 업데이트된 경우 저장된 값 반환
                return userDefaults.double(forKey: vixValueKey)
            }
        }
        
        // API에서 새로운 데이터 가져오기
        let vix = try await fetchFromAPI()
        
        // 새로운 데이터 저장
        userDefaults.set(Date(), forKey: lastUpdateKey)
        userDefaults.set(vix, forKey: vixValueKey)
        userDefaults.set(VIXScoreCalculator.vixToScore(vix: vix), forKey: vixScoreKey)
        
        return vix
    }
    
    private func fetchFromAPI() async throws -> Double {
#if DEBUG
        // 디버깅용: 로컬 JSON 파일 우선 사용
        if let url = Bundle.main.url(forResource: "vix_sample", withExtension: "json"),
           let data = try? Data(contentsOf: url) {
            let decoder = JSONDecoder()
            let response = try decoder.decode(YahooFinanceResponse.self, from: data)
            guard let quote = response.chart.result.first,
                  let indicators = quote.indicators,
                  let quotes = indicators.quote.first,
                  let lastPrice = quotes.close.last,
                  let vix = lastPrice else {
                throw URLError(.cannotParseResponse)
            }
            return vix
        }
#endif
        let urlString = "\(baseURL)?interval=1d&range=1d"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        // 디버깅을 위한 응답 출력
        if let httpResponse = response as? HTTPURLResponse {
            print("HTTP Status Code: \(httpResponse.statusCode)")
        }
        
        if let jsonString = String(data: data, encoding: .utf8) {
            print("API Response: \(jsonString)")
        }
        
        let decoder = JSONDecoder()
        do {
            let response = try decoder.decode(YahooFinanceResponse.self, from: data)
            guard let quote = response.chart.result.first,
                  let indicators = quote.indicators,
                  let quotes = indicators.quote.first,
                  let lastPrice = quotes.close.last,
                  let vix = lastPrice else {
                throw URLError(.cannotParseResponse)
            }
            return vix
        } catch {
            print("Decoding error: \(error)")
            throw error
        }
    }
    
    // 저장된 마지막 VIX 점수 가져오기
    func getLastScore() -> Int {
        return userDefaults.integer(forKey: vixScoreKey)
    }
    
    // 저장된 마지막 VIX 값 가져오기
    func getLastVIXValue() -> Double {
        return userDefaults.double(forKey: vixValueKey)
    }
    
    // 저장된 마지막 업데이트 시간 가져오기
    func getLastUpdateTime() -> Date? {
        return userDefaults.object(forKey: lastUpdateKey) as? Date
    }
}

// Yahoo Finance API 응답 모델
struct YahooFinanceResponse: Codable {
    let chart: ChartResponse
}

struct ChartResponse: Codable {
    let result: [ChartResult]
}

struct ChartResult: Codable {
    let indicators: Indicators?
}

struct Indicators: Codable {
    let quote: [Quote]
}

struct Quote: Codable {
    let close: [Double?]
}

// MARK: - CNN Fear & Greed Index 근사치 계산
struct MarketSentimentScore {
    let sp500MomentumScore: Int
    let vixScore: Int
    let bondScore: Int
    var finalScore: Int {
        (sp500MomentumScore + vixScore + bondScore) / 3
    }
}

extension VIXFetcher {
    // S&P500 125일치 종가 fetch
    func fetchSP500Prices() async throws -> [Double] {
        let urlString = "https://query1.finance.yahoo.com/v8/finance/chart/^GSPC?range=6mo&interval=1d"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(YahooFinanceResponse.self, from: data)
        guard let quote = response.chart.result.first?.indicators?.quote.first else { throw URLError(.cannotParseResponse) }
        let closes = quote.close.compactMap { $0 }
        return closes.suffix(125)
    }
    // VIX 최신값 fetch (기존 fetchVIX 활용)
    func fetchVIXValue() async throws -> Double {
        return try await fetchVIX()
    }
    // 10Y 국채 최신값 fetch
    func fetchBond10YValue() async throws -> Double {
        let urlString = "https://query1.finance.yahoo.com/v8/finance/chart/^TNX?range=1mo&interval=1d"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(YahooFinanceResponse.self, from: data)
        guard let quote = response.chart.result.first?.indicators?.quote.first else { throw URLError(.cannotParseResponse) }
        let closes = quote.close.compactMap { $0 }
        return closes.last ?? 4.0
    }
    // S&P500 모멘텀 점수 계산
    func calculateSP500MomentumScore(prices: [Double]) -> Int {
        guard let latest = prices.last, prices.count >= 125 else { return 50 }
        let ma125 = prices.reduce(0, +) / Double(prices.count)
        let momentum = (latest - ma125) / ma125
        let score = min(max((momentum * 5 + 0.5) * 100, 0), 100)
        return Int(score)
    }
    // VIX 점수 (공포/탐욕)
    func calculateVIXScore(vix: Double) -> Int {
        let capped = min(max(vix, 10), 45)
        let normalized = (45 - capped) / (45 - 10)
        let score = Int(normalized * 100)
        return Int(sqrt(Double(score) * 100))
    }
    // 국채 금리 점수 (안전자산 선호)
    func calculateBondScore(bond10Y: Double) -> Int {
        let capped = min(max(bond10Y, 1), 5)
        let normalized = (capped - 1) / (5 - 1)
        let score = Int(normalized * 100)
        return score
    }
    // 통합 점수 fetch 및 계산
    func fetchAndCalculateMarketSentiment() async throws -> MarketSentimentScore {
        async let sp500Prices = fetchSP500Prices()
        async let vixValue = fetchVIXValue()
        async let bond10Y = fetchBond10YValue()
        let (prices, vix, bond) = try await (sp500Prices, vixValue, bond10Y)
        let sp500Score = calculateSP500MomentumScore(prices: prices)
        let vixScore = calculateVIXScore(vix: vix)
        let bondScore = calculateBondScore(bond10Y: bond)
        return MarketSentimentScore(sp500MomentumScore: sp500Score, vixScore: vixScore, bondScore: bondScore)
    }
}
