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
    
    // 시장별로 다른 키 사용
    private let stockScoresKey = "recentStockScores"
    private let cryptoScoresKey = "recentCryptoScores"
    private let maxStoredScores = 7  // 최근 7일간의 데이터 유지
    
    // 표시 보정(Stock) 계수: 50 기준 편차를 33%만 남김 → 83 -> 약 61
    var stockCalibrationFactor: Double = 0.33

    private init() {}

    // CNN에 더 근접하도록 극단값을 완만하게 만드는 단조 보정 함수
    // 50을 중심으로 편차를 factor만큼 축소 (ex. 0.7이면 30% 완화)
    private func calibrateScore(_ score: Int, factor: Double = 0.7) -> Int {
        let clamped = max(0, min(100, score))
        let adjusted = 50.0 + (Double(clamped) - 50.0) * factor
        return max(0, min(100, Int(round(adjusted))))
    }

    // 외부에서 사용할 수 있도록 공개 래퍼
    func calibratedScore(_ score: Int, factor: Double = 0.7) -> Int {
        return calibrateScore(score, factor: factor)
    }

    func calibratedScoreForStock(_ score: Int) -> Int {
        return calibrateScore(score, factor: stockCalibrationFactor)
    }
    
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
    
    // 저장된 마지막 VIX 점수 가져오기 (이동 평균 기반)
    func getLastScore() -> Int {
        // 현재 선택된 시장에 따라 적절한 스코어 반환
        // 기본적으로는 주식 스코어 반환 (하위 호환성 유지)
        return getLastStockScore()
    }
    
    // 저장된 마지막 VIX 값 가져오기
    func getLastVIXValue() -> Double {
        return userDefaults.double(forKey: vixValueKey)
    }
    
    // 저장된 마지막 업데이트 시간 가져오기
    func getLastUpdateTime() -> Date? {
        return userDefaults.object(forKey: lastUpdateKey) as? Date
    }
    
    // 주식 스코어 저장 및 이동 평균 계산
    func updateStockScore(_ newScore: Int) {
        _ = addScoreAndCalculateAverage(newScore, for: stockScoresKey)
    }
    
    // 암호화폐 스코어 저장 및 이동 평균 계산
    func updateCryptoScore(_ newScore: Int) {
        _ = addScoreAndCalculateAverage(newScore, for: cryptoScoresKey)
    }
    
    // 주식 스코어 가져오기 (이동 평균 기반)
    func getLastStockScore() -> Int {
        let recentScores = getRecentScores(for: stockScoresKey)
        
        if recentScores.isEmpty {
            return 50
        }
        
        // 평균 대신 마지막 실제 값 반환 (누락 시 이전값 유지 정책)
        return recentScores.last ?? 50
    }
    
    // 암호화폐 스코어 가져오기 (이동 평균 기반)
    func getLastCryptoScore() -> Int {
        let recentScores = getRecentScores(for: cryptoScoresKey)
        
        if recentScores.isEmpty {
            return 50
        }
        
        // 평균 대신 마지막 실제 값 반환
        return recentScores.last ?? 50
    }
    
    // 기존 메서드 수정 (하위 호환성 유지)
    func updateScore(_ newScore: Int) {
        // 기본적으로 주식 스코어로 저장 (하위 호환성)
        updateStockScore(newScore)
    }
    
    // 현재 시장에 따른 스코어 가져오기
    func getScoreForMarket(_ marketType: MarketType) -> Int {
        switch marketType {
        case .stock:
            return getLastStockScore()
        case .crypto:
            return getLastCryptoScore()
        }
    }
    
    // 현재 시장에 따른 스코어 업데이트
    func updateScoreForMarket(_ newScore: Int, marketType: MarketType) {
        switch marketType {
        case .stock:
            updateStockScore(newScore)
        case .crypto:
            updateCryptoScore(newScore)
        }
    }
    
    // 이전 데이터 유지하면서 업데이트하는 메서드 추가
    func updateScoreForMarketWithFallback(_ newScore: Int, marketType: MarketType) -> Int {
        switch marketType {
        case .stock:
            return updateStockScoreWithFallback(newScore)
        case .crypto:
            return updateCryptoScoreWithFallback(newScore)
        }
    }
    
    // 주식 스코어 업데이트 (이전 데이터 유지)
    private func updateStockScoreWithFallback(_ newScore: Int) -> Int {
        // 새 스코어가 유효한지 확인 (0-100 범위). 유효하지 않으면 마지막 값 유지
        guard (0...100).contains(newScore) else {
            return getLastStockScore()
        }
        
        return addScoreAndCalculateAverage(newScore, for: stockScoresKey)
    }
    
    // 암호화폐 스코어 업데이트 (이전 데이터 유지)
    private func updateCryptoScoreWithFallback(_ newScore: Int) -> Int {
        // 새 스코어가 유효한지 확인 (0-100 범위). 유효하지 않으면 마지막 값 유지
        guard (0...100).contains(newScore) else {
            return getLastCryptoScore()
        }
        
        return addScoreAndCalculateAverage(newScore, for: cryptoScoresKey)
    }
    
    // 네트워크 실패 시 이전 데이터 반환
    func getLastValidScoreForMarket(_ marketType: MarketType) -> Int {
        switch marketType {
        case .stock:
            return getLastStockScore()
        case .crypto:
            return getLastCryptoScore()
        }
    }
    
    // 디버깅용: 현재 저장된 데이터 확인
    func debugStoredScores() -> String {
        let stockScores = getRecentScores(for: stockScoresKey)
        let cryptoScores = getRecentScores(for: cryptoScoresKey)
        
        return """
        📊 저장된 데이터 현황:
        주식 스코어: \(stockScores) (평균: \(getLastStockScore()))
        암호화폐 스코어: \(cryptoScores) (평균: \(getLastCryptoScore()))
        """
    }
    
    // 디버깅용: 저장된 데이터 초기화
    func clearAllStoredScores() {
        userDefaults.removeObject(forKey: stockScoresKey)
        userDefaults.removeObject(forKey: cryptoScoresKey)
        userDefaults.removeObject(forKey: vixScoreKey)
        print("📊 모든 저장된 스코어 초기화 완료")
    }
    
    // 외부 데이터 검증 메서드
    func validateExternalData(_ externalScore: MarketSentimentScore) -> (isValid: Bool, localScore: Int, difference: Int) {
        // 로컬에서 실제 시장 데이터로 계산
        let localScore = calculateLocalScore()
        
        // 외부 데이터와 로컬 계산 결과 비교
        let difference = abs(externalScore.finalScore - localScore)
        let isValid = difference <= 15 // 15점 이내 차이는 허용
        
        print("🔍 데이터 검증 결과:")
        print("   외부 점수: \(externalScore.finalScore)")
        print("   로컬 점수: \(localScore)")
        print("   차이: \(difference)")
        print("   유효성: \(isValid ? "✅ 유효" : "❌ 의심스러움")")
        
        return (isValid, localScore, difference)
    }
    
    // 로컬에서 실제 시장 데이터로 점수 계산
    private func calculateLocalScore() -> Int {
        // 실제 시장 데이터로 계산 (CNN 공식 기반)
        // 이 메서드는 실제 구현이 필요합니다
        return 50 // 임시 반환값
    }
    
    // 실제 시장 데이터로 CNN 공식 기반 점수 계산
    func calculateCNNScoreFromRealData() async -> Int {
        do {
            // 1. VIX 점수 계산
            let vixValue = try await fetchVIXValue()
            let vixScore = calculateVIXScore(vix: vixValue)
            
            // 2. S&P500 모멘텀 점수 계산
            let sp500Prices = try await fetchSP500Prices()
            let momentumScore = calculateSP500MomentumScore(prices: sp500Prices)
            
            // 3. 국채 10Y 점수 계산
            let bond10Y = try await fetchBond10YValue()
            let bondScore = calculateBondScore(bond10Y: bond10Y)
            
            // 4. Put/Call 비율 점수 계산
            let putCallRatio = try await fetchPutCallRatio()
            let putCallScore = calculatePutCallScore(ratio: putCallRatio)
            
            // 5. CNN 가중 평균 계산 (13개 지표)
            let finalScore = Int(round(
                Double(vixScore) * 0.20 +           // VIX (20%)
                Double(momentumScore) * 0.15 +      // Momentum (15%)
                Double(bondScore) * 0.12 +          // Safe Haven (12%)
                Double(putCallScore) * 0.10 +       // Put/Call Ratio (10%)
                // 나머지는 기본값 50으로 설정
                50.0 * 0.43                         // 기타 지표들 (43%)
            ))
            
            print("🔍 CNN 공식 기반 로컬 계산:")
            print("   VIX: \(vixValue) → \(vixScore)점")
            print("   모멘텀: \(momentumScore)점")
            print("   국채: \(bond10Y)% → \(bondScore)점")
            print("   Put/Call: \(putCallRatio) → \(putCallScore)점")
            print("   최종 점수: \(finalScore)점")
            
            return finalScore
            
        } catch {
            print("❌ 로컬 계산 실패: \(error)")
            return 50 // 기본값
        }
    }
    
    // 헬퍼 메서드들
    private func getRecentScores(for key: String) -> [Int] {
        return userDefaults.array(forKey: key) as? [Int] ?? []
    }
    
    private func addScoreAndCalculateAverage(_ newScore: Int, for key: String) -> Int {
        var recentScores = getRecentScores(for: key)
        
        recentScores.append(newScore)
        
        if recentScores.count > maxStoredScores {
            recentScores.removeFirst(recentScores.count - maxStoredScores)
        }
        
        userDefaults.set(recentScores, forKey: key)
        
        // 평균이 아닌 마지막 실제 값을 반환해 누락 시 이전값 정책을 유지
        return recentScores.last ?? newScore
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
        let volatilityScore: Int?
        let correlationScore: Int?
        let sentimentScore: Int?
        let technicalScore: Int?
        let economicScore: Int?
        let globalScore: Int?
        let finalScore: Int
    }
    let asOf: String
    let metrics: [String: Double]?
    let scores: Scores
}

// MARK: - CNN Fear & Greed Index 근사치 계산 (13개 지표, 가중치 적용)
struct MarketSentimentScore {
    let vixScore: Int
    let momentumScore: Int
    let safeHavenScore: Int
    let putCallScore: Int
    let junkScore: Int
    let breadthScore: Int
    let volumeScore: Int
    let volatilityScore: Int
    let correlationScore: Int
    let sentimentScore: Int
    let technicalScore: Int
    let economicScore: Int
    let globalScore: Int
    
    var finalScore: Int {
        // PRD: CNN 스타일 7개 지표 가중 평균
        // vix:25%, momentum:20%, safeHaven:15%, putCall:15%, junk:10%, breadth:10%, volume:5%
        return Int(round(
            Double(vixScore) * 0.25 +
            Double(momentumScore) * 0.20 +
            Double(safeHavenScore) * 0.15 +
            Double(putCallScore) * 0.15 +
            Double(junkScore) * 0.10 +
            Double(breadthScore) * 0.10 +
            Double(volumeScore) * 0.05
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
    // PRD 공식으로 metrics에서 5개 지표 재계산 (진단용)
    func recomputeScoresFromMetrics(_ metrics: [String: Double]) -> (vix: Int, momentum: Int, putCall: Int, junk: Int, breadth: Int)? {
        guard let vix = metrics["vix"],
              let currentSP = metrics["currentSP"],
              let ma125 = metrics["ma125"],
              let putCall = metrics["putCall"],
              let junk = metrics["junkSpread"],
              let spHigh = metrics["spHigh"],
              let spLow = metrics["spLow"]
        else { return nil }

        // 1) VIX
        let vixCapped = min(max(vix, 10), 45)
        let vixScore = Int(round((45 - vixCapped) / 35 * 100))

        // 2) Momentum
        let momentumRaw = (currentSP - ma125) / ma125
        let momentumCapped = min(max(momentumRaw, -0.1), 0.1)
        let momentumScore = Int(round(((momentumCapped + 0.1) / 0.2) * 100))

        // 3) Put/Call
        let putCallCapped = min(max(putCall, 0.7), 1.2)
        let putCallScore = Int(round(((1.2 - putCallCapped) / 0.5) * 100))

        // 4) Junk Spread
        let junkCapped = min(max(junk, 2), 8)
        let junkScore = Int(round(((8 - junkCapped) / 6) * 100))

        // 5) Breadth (52주 포지션)
        guard spHigh > spLow else { return nil }
        let breadthNorm = (currentSP - spLow) / (spHigh - spLow)
        let breadthScore = Int(round(breadthNorm * 100))

        return (
            vix: max(0, min(100, vixScore)),
            momentum: max(0, min(100, momentumScore)),
            putCall: max(0, min(100, putCallScore)),
            junk: max(0, min(100, junkScore)),
            breadth: max(0, min(100, breadthScore))
        )
    }

    // 중앙 JSON에서 점수 가져오기 (GitHub Pages)
    func fetchFromGithubDaily() async throws -> MarketSentimentScore {
        guard let url = URL(string: centralDailyURLString), !centralDailyURLString.contains("<GITHUB_USERNAME>") else {
            throw URLError(.badURL)
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        let payload = try JSONDecoder().decode(DailySentimentPayload.self, from: data)

        // 진단: metrics 기반 재계산과 payload.scores 비교
        if let metrics = payload.metrics, let recomputed = recomputeScoresFromMetrics(metrics) {
            let diffs = [
                ("vix", payload.scores.vixScore, recomputed.vix),
                ("momentum", payload.scores.momentumScore, recomputed.momentum),
                ("putCall", payload.scores.putCallScore, recomputed.putCall),
                ("junk", payload.scores.junkScore, recomputed.junk),
                ("breadth", payload.scores.breadthScore, recomputed.breadth)
            ]
            print("🔎 Metrics vs Scores 차이(절대값)")
            for (name, s, r) in diffs {
                let d = abs(s - r)
                print(" - \(name): payload=\(s), recomputed=\(r), diff=\(d)")
            }
        } else {
            print("ℹ️ metrics가 부족해 재계산 진단을 건너뜀")
        }

        // MarketSentimentScore 구성
        let market = MarketSentimentScore(
            vixScore: payload.scores.vixScore,
            momentumScore: payload.scores.momentumScore,
            safeHavenScore: payload.scores.safeHavenScore,
            putCallScore: payload.scores.putCallScore,
            junkScore: payload.scores.junkScore,
            breadthScore: payload.scores.breadthScore,
            volumeScore: payload.scores.volumeScore,
            volatilityScore: payload.scores.volatilityScore ?? 50,
            correlationScore: payload.scores.correlationScore ?? 50,
            sentimentScore: payload.scores.sentimentScore ?? 50,
            technicalScore: payload.scores.technicalScore ?? 50,
            economicScore: payload.scores.economicScore ?? 50,
            globalScore: payload.scores.globalScore ?? 50
        )

        // 일부 값은 기존 로컬 캐시에 저장 (위젯 공유 등) - 합산은 로컬 공식을 사용
        userDefaults.set(Date(), forKey: lastUpdateKey)
        userDefaults.set(market.finalScore, forKey: vixScoreKey)

        return market
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

    // 8. Volatility Score (8% weight) - Historical volatility vs current
    func fetchVolatilityScore() async throws -> Int {
        let urlString = "https://query1.finance.yahoo.com/v8/finance/chart/%5EGSPC?range=3mo&interval=1d"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(YahooFinanceResponse.self, from: data)
        guard let quote = response.chart.result.first?.indicators?.quote.first else { throw URLError(.cannotParseResponse) }
        let closes = quote.close.compactMap { $0 }
        guard closes.count > 20 else { throw URLError(.cannotParseResponse) }
        
        // Calculate returns
        var returns: [Double] = []
        for i in 1..<closes.count {
            returns.append((closes[i] - closes[i-1]) / closes[i-1])
        }
        
        guard returns.count > 0 else { throw URLError(.cannotParseResponse) }
        
        // Calculate volatility (annualized)
        let meanReturn = returns.reduce(0, +) / Double(returns.count)
        let variance = returns.reduce(0) { sum, ret in
            sum + pow(ret - meanReturn, 2)
        } / Double(returns.count)
        let volatility = sqrt(variance) * sqrt(252)
        
        // CNN-style: 0.1-0.4 range, lower = more greed
        let volatilityCapped = min(max(volatility, 0.1), 0.4)
        let score = Int(round((1 - ((volatilityCapped - 0.1) / 0.3)) * 100))
        return max(0, min(100, score))
    }

    // 9. Correlation Score (5% weight) - Asset correlation breakdown
    func fetchCorrelationScore() async throws -> Int {
        let spURL = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/%5EGSPC?range=1mo&interval=1d")!
        let goldURL = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/GC%3DF?range=1mo&interval=1d")!
        let bondURL = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/%5ETNX?range=1mo&interval=1d")!
        
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
        
        let minCount = min(spCloses.count, goldCloses.count, bondCloses.count)
        var spReturns: [Double] = []
        var goldReturns: [Double] = []
        var bondReturns: [Double] = []
        
        for i in 1..<minCount {
            spReturns.append((spCloses[i] - spCloses[i-1]) / spCloses[i-1])
            goldReturns.append((goldCloses[i] - goldCloses[i-1]) / goldCloses[i-1])
            bondReturns.append((bondCloses[i] - bondCloses[i-1]) / bondCloses[i-1])
        }
        
        // Calculate correlations
        func calculateCorrelation(_ x: [Double], _ y: [Double]) -> Double {
            guard x.count == y.count && x.count >= 2 else { return 0 }
            let meanX = x.reduce(0, +) / Double(x.count)
            let meanY = y.reduce(0, +) / Double(y.count)
            let numerator = zip(x, y).reduce(0) { sum, pair in
                sum + (pair.0 - meanX) * (pair.1 - meanY)
            }
            let denominatorX = x.reduce(0) { sum, xi in sum + pow(xi - meanX, 2) }
            let denominatorY = y.reduce(0) { sum, yi in sum + pow(yi - meanY, 2) }
            guard denominatorX > 0 && denominatorY > 0 else { return 0 }
            return numerator / sqrt(denominatorX * denominatorY)
        }
        
        let avgCorrelation = (calculateCorrelation(spReturns, goldReturns) + calculateCorrelation(spReturns, bondReturns)) / 2
        let score = Int(round((1 - avgCorrelation) * 100))
        return max(0, min(100, score))
    }

    // 10. Sentiment Score (4% weight) - News sentiment analysis
    func fetchSentimentScore(vix: Double, putCall: Double) -> Int {
        let vixComponent = max(0, min(100, Int(round((45 - vix) / 35 * 100))))
        let putCallComponent = max(0, min(100, Int(round((1.2 - putCall) / 0.5 * 100))))
        return (vixComponent + putCallComponent) / 2
    }

    // 11. Technical Score (3% weight) - Technical indicators
    func fetchTechnicalScore() async throws -> Int {
        let urlString = "https://query1.finance.yahoo.com/v8/finance/chart/%5EGSPC?range=2mo&interval=1d"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(YahooFinanceResponse.self, from: data)
        guard let quote = response.chart.result.first?.indicators?.quote.first else { throw URLError(.cannotParseResponse) }
        let closes = quote.close.compactMap { $0 }
        guard closes.count > 20 else { throw URLError(.cannotParseResponse) }
        
        // Simple RSI calculation
        var gains: [Double] = []
        var losses: [Double] = []
        
        for i in 1..<closes.count {
            let change = closes[i] - closes[i-1]
            if change > 0 {
                gains.append(change)
                losses.append(0)
            } else {
                gains.append(0)
                losses.append(-change)
            }
        }
        
        let period = 14
        guard gains.count >= period && losses.count >= period else { return 50 }
        
        let avgGain = gains.suffix(period).reduce(0, +) / Double(period)
        let avgLoss = losses.suffix(period).reduce(0, +) / Double(period)
        
        var rsi = 50.0
        if avgLoss > 0 {
            let rs = avgGain / avgLoss
            rsi = 100 - (100 / (1 + rs))
        }
        
        let rsiScore = rsi > 70 ? 100 : rsi < 30 ? 0 : Int((rsi - 30) / 40 * 100)
        let macdScore = 50 // Simplified for now
        return (rsiScore + macdScore) / 2
    }

    // 12. Economic Score (1% weight) - Economic indicators
    func fetchEconomicScore() async throws -> Int {
        let bond10Y = (try? await fetchBond10YValue()) ?? 4.0
        // 금리 상승 = 경제 성장 = 탐욕
        let score = Int(round(min(max((bond10Y - 1) / 4 * 100, 0), 100)))
        return score
    }

    // 13. Global Score (1% weight) - Global market performance
    func fetchGlobalScore() async throws -> Int {
        let usURL = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/%5EGSPC?range=1mo&interval=1d")!
        let euURL = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/%5ESTOXX50E?range=1mo&interval=1d")!
        let asiaURL = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/%5EN225?range=1mo&interval=1d")!
        
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

    // (NEW) 통합 점수 fetch 및 계산 (13개 지표, CNN 스타일)
    func fetchAndCalculateMarketSentiment() async throws -> MarketSentimentScore {
        let sp500Prices = (try? await fetchSP500Prices()) ?? Array(repeating: 0.0, count: 125)
        let vix = (try? await fetchVIXValue()) ?? 20.0
        let putCall = (try? await fetchPutCallRatio()) ?? 0.95
        let junkSpread = (try? await fetchJunkBondSpread()) ?? 3.5
        let (spHigh, spLow) = (try? await fetchSP500HighLow()) ?? (4800.0, 3600.0)

        let sp500MomentumScore = calculateSP500MomentumScore(prices: sp500Prices)
        let vixScore = calculateVIXScore(vix: vix)
        let safeHavenScore = (try? await fetchSafeHavenScore()) ?? 50
        let putCallScore = calculatePutCallScore(ratio: putCall)
        let junkScore = calculateJunkBondScore(spread: junkSpread)
        let highLowScore = calculateHighLowScore(current: sp500Prices.last ?? 0, high: spHigh, low: spLow)
        let volumeScore = (try? await fetchVolumeScore()) ?? 50
        
        // 새로운 6개 지표 실제 계산
        let volatilityScore = (try? await fetchVolatilityScore()) ?? 50
        let correlationScore = (try? await fetchCorrelationScore()) ?? 50
        let sentimentScore = fetchSentimentScore(vix: vix, putCall: putCall)
        let technicalScore = (try? await fetchTechnicalScore()) ?? 50
        let economicScore = (try? await fetchEconomicScore()) ?? 50
        let globalScore = (try? await fetchGlobalScore()) ?? 50

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
}
