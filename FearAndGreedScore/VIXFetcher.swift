//
//  VIXFetcher.swift
//  FearAndGreedScore
//
//  Created by hyujang on 5/11/25.
//

import Foundation

struct VIXFetcher {
    static let shared = VIXFetcher()
    private let baseURL = "https://query1.finance.yahoo.com/v8/finance/chart/%5EVIX"
    // 중앙 수집 JSON(URL) - GitHub Pages (artsidea/FearGreedApp)
    private let centralDailyURLString = "https://artsidea.github.io/FearGreedApp/daily.json"
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

// 중앙 수집 JSON 디코딩 모델
struct DailySentimentPayload: Codable {
    struct Scores: Codable {
        let sp500MomentumScore: Int
        let vixScore: Int
        let bondScore: Int
        let putCallScore: Int
        let junkScore: Int
        let highLowScore: Int
        let finalScore: Int
    }
    let asOf: String
    let scores: Scores
}

// MARK: - CNN Fear & Greed Index 근사치 계산 (6개 지표)
struct MarketSentimentScore {
    let sp500MomentumScore: Int
    let vixScore: Int
    let bondScore: Int
    let putCallScore: Int
    let junkScore: Int
    let highLowScore: Int
    var finalScore: Int {
        (sp500MomentumScore + vixScore + bondScore + putCallScore + junkScore + highLowScore) / 6
    }
}

extension VIXFetcher {
    // 중앙 JSON에서 점수 가져오기 (GitHub Pages)
    func fetchFromGithubDaily() async throws -> MarketSentimentScore {
        guard let url = URL(string: centralDailyURLString), !centralDailyURLString.contains("<GITHUB_USERNAME>") else {
            throw URLError(.badURL)
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        let payload = try JSONDecoder().decode(DailySentimentPayload.self, from: data)

        // 일부 값은 기존 로컬 캐시에 저장 (위젯 공유 등)
        userDefaults.set(Date(), forKey: lastUpdateKey)
        userDefaults.set(payload.scores.finalScore, forKey: vixScoreKey)

        return MarketSentimentScore(
            sp500MomentumScore: payload.scores.sp500MomentumScore,
            vixScore: payload.scores.vixScore,
            bondScore: payload.scores.bondScore,
            putCallScore: payload.scores.putCallScore,
            junkScore: payload.scores.junkScore,
            highLowScore: payload.scores.highLowScore
        )
    }

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
    // (1) Put/Call Ratio Fetcher (CBOE, 실제 데이터)
    func fetchPutCallRatio() async throws -> Double {
        let urlString = "https://cdn.cboe.com/api/global/delayed_quotes/put_call_ratios/all.csv"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let csv = String(data: data, encoding: .utf8) else { throw URLError(.cannotParseResponse) }
        if let line = csv.components(separatedBy: "\n").first(where: { $0.contains("TOTAL") }),
           let valueString = line.components(separatedBy: ",").last,
           let value = Double(valueString) {
            return value
        }
        throw URLError(.cannotParseResponse)
    }
    func calculatePutCallScore(ratio: Double) -> Int {
        let capped = min(max(ratio, 0.7), 1.2)
        let normalized = (1.2 - capped) / (1.2 - 0.7)
        return Int(normalized * 100)
    }

    // (2) 정크본드 스프레드 Fetcher (FRED, 실제 데이터)
    func fetchJunkBondSpread() async throws -> Double {
        let urlString = "https://fred.stlouisfed.org/graph/fredgraph.csv?id=BAMLH0A0HYM2"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let csv = String(data: data, encoding: .utf8) else { throw URLError(.cannotParseResponse) }
        let lines = csv.components(separatedBy: "\n").reversed()
        for line in lines {
            let comps = line.components(separatedBy: ",")
            if comps.count == 2, let value = Double(comps[1]) {
                return value
            }
        }
        throw URLError(.cannotParseResponse)
    }
    func calculateJunkBondScore(spread: Double) -> Int {
        let capped = min(max(spread, 2), 8)
        let normalized = (8 - capped) / (8 - 2)
        return Int(normalized * 100)
    }

    // (3) S&P500 52주 high/low fetch (대체, 예시)
    func fetchSP500HighLow() async throws -> (Double, Double) {
        let urlString = "https://query1.finance.yahoo.com/v8/finance/chart/^GSPC?range=1y&interval=1d"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(YahooFinanceResponse.self, from: data)
        guard let quote = response.chart.result.first?.indicators?.quote.first else { throw URLError(.cannotParseResponse) }
        let closes = quote.close.compactMap { $0 }
        guard let high = closes.max(), let low = closes.min() else { throw URLError(.cannotParseResponse) }
        return (high, low)
    }
    func calculateHighLowScore(current: Double, high: Double, low: Double) -> Int {
        guard high > low else { return 50 }
        let normalized = (current - low) / (high - low)
        return Int(normalized * 100)
    }

    // (NEW) 통합 점수 fetch 및 계산 (6개 지표, 오류에 강인하게)
    func fetchAndCalculateMarketSentiment() async throws -> MarketSentimentScore {
        let sp500Prices = (try? await fetchSP500Prices()) ?? Array(repeating: 0.0, count: 125)
        let vix = (try? await fetchVIXValue()) ?? 20.0
        let bond10Y = (try? await fetchBond10YValue()) ?? 4.0
        let putCall = (try? await fetchPutCallRatio()) ?? 0.95
        let junkSpread = (try? await fetchJunkBondSpread()) ?? 3.5
        let (spHigh, spLow) = (try? await fetchSP500HighLow()) ?? (4800.0, 3600.0)

        let sp500MomentumScore = calculateSP500MomentumScore(prices: sp500Prices)
        let vixScore = calculateVIXScore(vix: vix)
        let bondScore = calculateBondScore(bond10Y: bond10Y)
        let putCallScore = calculatePutCallScore(ratio: putCall)
        let junkScore = calculateJunkBondScore(spread: junkSpread)
        let highLowScore = calculateHighLowScore(current: sp500Prices.last ?? 0, high: spHigh, low: spLow)

        return MarketSentimentScore(
            sp500MomentumScore: sp500MomentumScore,
            vixScore: vixScore,
            bondScore: bondScore,
            putCallScore: putCallScore,
            junkScore: junkScore,
            highLowScore: highLowScore
        )
    }
}
