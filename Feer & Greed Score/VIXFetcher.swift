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
    
    private init() {}
    
    func fetchVIX() async throws -> Double {
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
