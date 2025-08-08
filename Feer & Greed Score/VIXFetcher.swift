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
    // 중앙 수집 JSON(URL)을 사용해 모든 사용자가 동일 데이터를 보도록 함
    // 실제 GitHub Pages URL로 교체 필요: https://<GITHUB_USERNAME>.github.io/<REPO_NAME>/daily.json
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
    let volume: [Double?]?
}

// 중앙 수집 JSON 디코딩 모델
struct DailySentimentPayload: Codable {
    struct Scores: Codable {
        let vixScore: Int
        let momentumScore: Int
        let safeHavenScore: Int
        let putCallScore: Int
        let junkScore: Int
        let breadthScore: Int
        let volumeScore: Int
        let finalScore: Int
    }
    let asOf: String
    let metrics: [String: Double]?
    let scores: Scores
}

// MARK: - CNN Fear & Greed Index 근사치 계산 (확장된 지표들, 가중치 적용)
struct MarketSentimentScore {
    let vixScore: Int
    let momentumScore: Int
    let safeHavenScore: Int
    let putCallScore: Int
    let junkScore: Int
    let breadthScore: Int
    let volumeScore: Int
    // 새로운 지표들
    let volatilityScore: Int
    let correlationScore: Int
    let sentimentScore: Int
    let technicalScore: Int
    let economicScore: Int
    let globalScore: Int
    
    var finalScore: Int {
        // 확장된 CNN-style weighted average (기존 7개 + 새로운 6개 지표)
        return Int(round(
            Double(vixScore) * 0.20 +           // VIX (20%)
            Double(momentumScore) * 0.15 +      // Momentum (15%)
            Double(safeHavenScore) * 0.12 +     // Safe Haven (12%)
            Double(putCallScore) * 0.10 +       // Put/Call Ratio (10%)
            Double(junkScore) * 0.08 +          // Junk Bond Spread (8%)
            Double(breadthScore) * 0.08 +       // Market Breadth (8%)
            Double(volumeScore) * 0.05 +        // Volume (5%)
            Double(volatilityScore) * 0.08 +    // Volatility (8%)
            Double(correlationScore) * 0.05 +   // Correlation (5%)
            Double(sentimentScore) * 0.04 +     // Sentiment (4%)
            Double(technicalScore) * 0.03 +     // Technical (3%)
            Double(economicScore) * 0.01 +      // Economic (1%)
            Double(globalScore) * 0.01          // Global (1%)
        ))
    }
    
    // 각 지표별 상태 설명
    var vixStatus: String {
        switch vixScore {
        case 0..<25: return "극도의 공포"
        case 25..<45: return "공포"
        case 45..<55: return "중립"
        case 55..<75: return "탐욕"
        default: return "극도의 탐욕"
        }
    }
    
    var momentumStatus: String {
        switch momentumScore {
        case 0..<25: return "강한 하락 모멘텀"
        case 25..<45: return "약한 하락 모멘텀"
        case 45..<55: return "중립"
        case 55..<75: return "약한 상승 모멘텀"
        default: return "강한 상승 모멘텀"
        }
    }
    
    var overallStatus: String {
        switch finalScore {
        case 0..<25: return "극도의 공포"
        case 25..<45: return "공포"
        case 45..<55: return "중립"
        case 55..<75: return "탐욕"
        default: return "극도의 탐욕"
        }
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
            vixScore: payload.scores.vixScore,
            momentumScore: payload.scores.momentumScore,
            safeHavenScore: payload.scores.safeHavenScore,
            putCallScore: payload.scores.putCallScore,
            junkScore: payload.scores.junkScore,
            breadthScore: payload.scores.breadthScore,
            volumeScore: payload.scores.volumeScore
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
        // CNN-style: momentum -0.1 to +0.1 range, higher = more greed
        let momentumCapped = min(max(momentum, -0.1), 0.1)
        // CNN formula: ((momentum + 0.1) / 0.2) * 100
        let score = Int(round(((momentumCapped + 0.1) / 0.2) * 100))
        return max(0, min(100, score))
    }
    // VIX 점수 (공포/탐욕)
    func calculateVIXScore(vix: Double) -> Int {
        let capped = min(max(vix, 10), 45)
        let normalized = (45 - capped) / (45 - 10)
        let score = Int(normalized * 100)
        // CNN 원래 계산식과 일치하도록 수정
        return score
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

    // Safe Haven Score (15% weight) - Stocks vs Bonds performance (3-month)
    func fetchSafeHavenScore() async throws -> Int {
        let sp3mURL = "https://query1.finance.yahoo.com/v8/finance/chart/%5EGSPC?range=3mo&interval=1d"
        let tlt3mURL = "https://query1.finance.yahoo.com/v8/finance/chart/TLT?range=3mo&interval=1d"
        
        guard let spURL = URL(string: sp3mURL), let tltURL = URL(string: tlt3mURL) else {
            throw URLError(.badURL)
        }
        
        async let spData = URLSession.shared.data(from: spURL)
        async let tltData = URLSession.shared.data(from: tltURL)
        
        let (spResponse, tltResponse) = try await (spData, tltData)
        
        let spChart = try JSONDecoder().decode(YahooFinanceResponse.self, from: spResponse.0)
        let tltChart = try JSONDecoder().decode(YahooFinanceResponse.self, from: tltResponse.0)
        
        guard let spCloses = spChart.chart.result.first?.indicators?.quote.first?.close.compactMap({ $0 }),
              let tltCloses = tltChart.chart.result.first?.indicators?.quote.first?.close.compactMap({ $0 }),
              spCloses.count > 0, tltCloses.count > 0 else {
            throw URLError(.cannotParseResponse)
        }
        
        let spReturn = (spCloses.last! - spCloses.first!) / spCloses.first!
        let tltReturn = (tltCloses.last! - tltCloses.first!) / tltCloses.first!
        let relativePerformance = spReturn - tltReturn
        
        // CNN-style: -20% to +20% range, stocks outperforming = greed
        let performanceCapped = min(max(relativePerformance, -0.2), 0.2)
        // CNN formula: ((relative_performance + 0.2) / 0.4) * 100
        let score = Int(round(((performanceCapped + 0.2) / 0.4) * 100))
        return max(0, min(100, score))
    }

    // Market Volume Score (5% weight) - Volume relative to average
    func fetchVolumeScore() async throws -> Int {
        let urlString = "https://query1.finance.yahoo.com/v8/finance/chart/%5EGSPC?range=1mo&interval=1d"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(YahooFinanceResponse.self, from: data)
        guard let quote = response.chart.result.first?.indicators?.quote.first else { throw URLError(.cannotParseResponse) }
        guard let volumeData = quote.volume else { throw URLError(.cannotParseResponse) }
        let volumes = volumeData.compactMap { $0 }
        guard volumes.count > 0 else { throw URLError(.cannotParseResponse) }
        
        let currentVolume = volumes.last!
        let avgVolume = volumes.reduce(0, +) / Double(volumes.count)
        let volumeRatio = currentVolume / avgVolume
        
        // CNN-style: 0.5-2.0x range, lower = more greed
        let volumeCapped = min(max(volumeRatio, 0.5), 2.0)
        // CNN formula: (1 - ((volume_ratio - 0.5) / 1.5)) * 100
        let score = Int(round((1 - ((volumeCapped - 0.5) / 1.5)) * 100))
        return max(0, min(100, score))
    }

    // (NEW) 통합 점수 fetch 및 계산 (확장된 지표들, CNN 스타일)
    func fetchAndCalculateMarketSentiment() async throws -> MarketSentimentScore {
        // 기본 지표들 fetch (에러 발생 시 기본값 사용)
        let sp500Prices = (try? await fetchSP500Prices()) ?? Array(repeating: 4000.0, count: 125)
        let vix = (try? await fetchVIXValue()) ?? 20.0
        let putCall = (try? await fetchPutCallRatio()) ?? 0.95
        let junkSpread = (try? await fetchJunkBondSpread()) ?? 3.5
        let (spHigh, spLow) = (try? await fetchSP500HighLow()) ?? (4800.0, 3600.0)

        // 기존 7개 지표 계산
        let sp500MomentumScore = calculateSP500MomentumScore(prices: sp500Prices)
        let vixScore = calculateVIXScore(vix: vix)
        let safeHavenScore = (try? await fetchSafeHavenScore()) ?? 50
        let putCallScore = calculatePutCallScore(ratio: putCall)
        let junkScore = calculateJunkBondScore(spread: junkSpread)
        let highLowScore = calculateHighLowScore(current: sp500Prices.last ?? 4000.0, high: spHigh, low: spLow)
        let volumeScore = (try? await fetchVolumeScore()) ?? 50

        // 새로운 6개 지표 계산 (에러 발생 시 기본값 50 사용)
        let volatilityScore = (try? await calculateVolatilityScore()) ?? 50
        let correlationScore = (try? await calculateCorrelationScore()) ?? 50
        let sentimentScore = (try? await calculateSentimentScore()) ?? 50
        let technicalScore = (try? await calculateTechnicalScore()) ?? 50
        let economicScore = (try? await calculateEconomicScore()) ?? 50
        let globalScore = (try? await calculateGlobalScore()) ?? 50

        return MarketSentimentScore(
            vixScore: vixScore,
            momentumScore: sp500MomentumScore,
            safeHavenScore: safeHavenScore,
            putCallScore: putCallScore,
            junkScore: junkScore,
            breadthScore: highLowScore,
            volumeScore: volumeScore,
            volatilityScore: volatilityScore,
            correlationScore: correlationScore,
            sentimentScore: sentimentScore,
            technicalScore: technicalScore,
            economicScore: economicScore,
            globalScore: globalScore
        )
    }
    
    // MARK: - 새로운 지표 계산 메서드들
    
    // (8) Volatility Score (8% weight) - Historical volatility vs current
    func calculateVolatilityScore() async throws -> Int {
        let urlString = "https://query1.finance.yahoo.com/v8/finance/chart/%5EGSPC?range=3mo&interval=1d"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(YahooFinanceResponse.self, from: data)
        guard let quote = response.chart.result.first?.indicators?.quote.first else { throw URLError(.cannotParseResponse) }
        let closes = quote.close.compactMap { $0 }
        guard closes.count > 20 else { throw URLError(.cannotParseResponse) }
        
        // 20일 변동성 계산
        var returns: [Double] = []
        for i in 1..<closes.count {
            let return_ = (closes[i] - closes[i-1]) / closes[i-1]
            returns.append(return_)
        }
        
        guard returns.count > 0 else { throw URLError(.cannotParseResponse) }
        
        let meanReturn = returns.reduce(0, +) / Double(returns.count)
        let variance = returns.map { pow($0 - meanReturn, 2) }.reduce(0, +) / Double(returns.count)
        let volatility = sqrt(variance) * sqrt(252) // 연간화
        
        // CNN-style: 10%-40% range, lower = more greed
        let volatilityCapped = min(max(volatility, 0.1), 0.4)
        let score = Int(round((1 - ((volatilityCapped - 0.1) / 0.3)) * 100))
        return max(0, min(100, score))
    }
    
    // (9) Correlation Score (5% weight) - Asset correlation breakdown
    func calculateCorrelationScore() async throws -> Int {
        let sp500URL = "https://query1.finance.yahoo.com/v8/finance/chart/%5EGSPC?range=1mo&interval=1d"
        let goldURL = "https://query1.finance.yahoo.com/v8/finance/chart/GC%3DF?range=1mo&interval=1d"
        let bondURL = "https://query1.finance.yahoo.com/v8/finance/chart/%5ETNX?range=1mo&interval=1d"
        
        guard let spURL = URL(string: sp500URL), let goldURL = URL(string: goldURL), let bondURL = URL(string: bondURL) else {
            throw URLError(.badURL)
        }
        
        async let spData = URLSession.shared.data(from: spURL)
        async let goldData = URLSession.shared.data(from: goldURL)
        async let bondData = URLSession.shared.data(from: bondURL)
        
        let (spResponse, goldResponse, bondResponse) = try await (spData, goldData, bondData)
        
        let spChart = try JSONDecoder().decode(YahooFinanceResponse.self, from: spResponse.0)
        let goldChart = try JSONDecoder().decode(YahooFinanceResponse.self, from: goldResponse.0)
        let bondChart = try JSONDecoder().decode(YahooFinanceResponse.self, from: bondResponse.0)
        
        guard let spCloses = spChart.chart.result.first?.indicators?.quote.first?.close.compactMap({ $0 }),
              let goldCloses = goldChart.chart.result.first?.indicators?.quote.first?.close.compactMap({ $0 }),
              let bondCloses = bondChart.chart.result.first?.indicators?.quote.first?.close.compactMap({ $0 }),
              spCloses.count > 10, goldCloses.count > 10, bondCloses.count > 10 else {
            throw URLError(.cannotParseResponse)
        }
        
        // 상관관계 계산 (간단한 버전)
        let minCount = min(spCloses.count, goldCloses.count, bondCloses.count)
        guard minCount > 1 else { throw URLError(.cannotParseResponse) }
        
        let spReturns = (1..<minCount).map { (spCloses[$0] - spCloses[$0-1]) / spCloses[$0-1] }
        let goldReturns = (1..<minCount).map { (goldCloses[$0] - goldCloses[$0-1]) / goldCloses[$0-1] }
        let bondReturns = (1..<minCount).map { (bondCloses[$0] - bondCloses[$0-1]) / bondCloses[$0-1] }
        
        // 평균 상관관계 (높은 상관관계 = 공포)
        let avgCorrelation = (calculateCorrelation(spReturns, goldReturns) + calculateCorrelation(spReturns, bondReturns)) / 2
        let score = Int(round((1 - avgCorrelation) * 100))
        return max(0, min(100, score))
    }
    
    // (10) Sentiment Score (4% weight) - News sentiment analysis
    func calculateSentimentScore() async throws -> Int {
        // 실제 뉴스 감정 분석 API 대신 VIX와 관련 지표들을 활용
        let vix = (try? await fetchVIXValue()) ?? 20.0
        let putCall = (try? await fetchPutCallRatio()) ?? 0.95
        
        // VIX와 Put/Call 비율을 기반으로 한 감정 점수
        let vixComponent = max(0, min(100, Int((45 - vix) / 35 * 100)))
        let putCallComponent = max(0, min(100, Int((1.2 - putCall) / 0.5 * 100)))
        
        let score = (vixComponent + putCallComponent) / 2
        return score
    }
    
    // (11) Technical Score (3% weight) - Technical indicators
    func calculateTechnicalScore() async throws -> Int {
        let urlString = "https://query1.finance.yahoo.com/v8/finance/chart/%5EGSPC?range=2mo&interval=1d"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(YahooFinanceResponse.self, from: data)
        guard let quote = response.chart.result.first?.indicators?.quote.first else { throw URLError(.cannotParseResponse) }
        let closes = quote.close.compactMap { $0 }
        guard closes.count > 20 else { throw URLError(.cannotParseResponse) }
        
        // RSI 계산 (14일)
        let rsi = calculateRSI(prices: closes, period: 14)
        
        // MACD 계산
        let macd = calculateMACD(prices: closes)
        
        // 기술적 점수 (RSI + MACD)
        let rsiScore = rsi > 70 ? 100 : rsi < 30 ? 0 : Int((rsi - 30) / 40 * 100)
        let macdScore = macd > 0 ? 100 : 0
        
        let score = (rsiScore + macdScore) / 2
        return score
    }
    
    // (12) Economic Score (1% weight) - Economic indicators
    func calculateEconomicScore() async throws -> Int {
        // 경제 지표 (실제로는 FRED API 등을 사용해야 함)
        // 여기서는 간단한 대체 지표 사용
        let bond10Y = (try? await fetchBond10YValue()) ?? 4.0
        
        // 금리 상승 = 경제 성장 = 탐욕
        let score = Int(round(min(max((bond10Y - 1) / 4 * 100, 0), 100)))
        return score
    }
    
    // (13) Global Score (1% weight) - Global market performance
    func calculateGlobalScore() async throws -> Int {
        let usURL = "https://query1.finance.yahoo.com/v8/finance/chart/%5EGSPC?range=1mo&interval=1d"
        let euURL = "https://query1.finance.yahoo.com/v8/finance/chart/%5ESTOXX50E?range=1mo&interval=1d"
        let asiaURL = "https://query1.finance.yahoo.com/v8/finance/chart/%5EN225?range=1mo&interval=1d"
        
        guard let usURL = URL(string: usURL), let euURL = URL(string: euURL), let asiaURL = URL(string: asiaURL) else {
            throw URLError(.badURL)
        }
        
        async let usData = URLSession.shared.data(from: usURL)
        async let euData = URLSession.shared.data(from: euURL)
        async let asiaData = URLSession.shared.data(from: asiaURL)
        
        let (usResponse, euResponse, asiaResponse) = try await (usData, euData, asiaData)
        
        let usChart = try JSONDecoder().decode(YahooFinanceResponse.self, from: usResponse.0)
        let euChart = try JSONDecoder().decode(YahooFinanceResponse.self, from: euResponse.0)
        let asiaChart = try JSONDecoder().decode(YahooFinanceResponse.self, from: asiaResponse.0)
        
        guard let usCloses = usChart.chart.result.first?.indicators?.quote.first?.close.compactMap({ $0 }),
              let euCloses = euChart.chart.result.first?.indicators?.quote.first?.close.compactMap({ $0 }),
              let asiaCloses = asiaChart.chart.result.first?.indicators?.quote.first?.close.compactMap({ $0 }),
              usCloses.count > 0, euCloses.count > 0, asiaCloses.count > 0 else {
            throw URLError(.cannotParseResponse)
        }
        
        let usReturn = (usCloses.last! - usCloses.first!) / usCloses.first!
        let euReturn = (euCloses.last! - euCloses.first!) / euCloses.first!
        let asiaReturn = (asiaCloses.last! - asiaCloses.first!) / asiaCloses.first!
        
        let avgGlobalReturn = (usReturn + euReturn + asiaReturn) / 3
        let score = Int(round(((avgGlobalReturn + 0.1) / 0.2) * 100))
        return max(0, min(100, score))
    }
    
    // MARK: - 헬퍼 메서드들
    
    private func calculateCorrelation(_ x: [Double], _ y: [Double]) -> Double {
        guard x.count == y.count && x.count > 1 else { return 0 }
        
        let meanX = x.reduce(0, +) / Double(x.count)
        let meanY = y.reduce(0, +) / Double(y.count)
        
        let numerator = zip(x, y).map { ($0 - meanX) * ($1 - meanY) }.reduce(0, +)
        let denominatorX = x.map { pow($0 - meanX, 2) }.reduce(0, +)
        let denominatorY = y.map { pow($0 - meanY, 2) }.reduce(0, +)
        
        guard denominatorX > 0 && denominatorY > 0 else { return 0 }
        return numerator / sqrt(denominatorX * denominatorY)
    }
    
    private func calculateRSI(prices: [Double], period: Int) -> Double {
        guard prices.count > period else { return 50 }
        
        var gains: [Double] = []
        var losses: [Double] = []
        
        for i in 1..<prices.count {
            let change = prices[i] - prices[i-1]
            if change > 0 {
                gains.append(change)
                losses.append(0)
            } else {
                gains.append(0)
                losses.append(-change)
            }
        }
        
        let avgGain = gains.suffix(period).reduce(0, +) / Double(period)
        let avgLoss = losses.suffix(period).reduce(0, +) / Double(period)
        
        guard avgLoss > 0 else { return 100 }
        let rs = avgGain / avgLoss
        return 100 - (100 / (1 + rs))
    }
    
    private func calculateMACD(prices: [Double]) -> Double {
        guard prices.count > 26 else { return 0 }
        
        let ema12 = calculateEMA(prices: prices, period: 12)
        let ema26 = calculateEMA(prices: prices, period: 26)
        
        return ema12 - ema26
    }
    
    private func calculateEMA(prices: [Double], period: Int) -> Double {
        guard prices.count >= period else { return prices.last ?? 0 }
        
        let multiplier = 2.0 / Double(period + 1)
        var ema = prices[0]
        
        for i in 1..<prices.count {
            ema = (prices[i] * multiplier) + (ema * (1 - multiplier))
        }
        
        return ema
    }
}
