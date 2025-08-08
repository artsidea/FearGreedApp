//
//  FearGreedWidget.swift
//  FearGreedWidget
//
//  Created by hyujang on 5/13/25.
//

import WidgetKit
import SwiftUI
import Foundation

// MARK: - Entry
struct FearGreedEntry: TimelineEntry {
    let date: Date
    let score: Int
}

// MARK: - Provider
struct Provider: TimelineProvider {
    private let userDefaults = UserDefaults(suiteName: "group.com.hyujang.feargreed")
    private let lastUpdateKey = "lastVIXUpdate"
    private let vixScoreKey = "lastVIXScore"
    private let centralDailyURL = URL(string: "https://artsidea.github.io/FearGreedApp/daily.json")!

    struct DailyPayload: Decodable {
        struct Scores: Decodable { 
            let finalScore: Int 
        }
        let scores: Scores
    }
    
    func placeholder(in context: Context) -> FearGreedEntry {
        let cachedScore = userDefaults?.integer(forKey: vixScoreKey) ?? 0
        return FearGreedEntry(date: Date(), score: cachedScore > 0 ? cachedScore : 50)
    }

    func getSnapshot(in context: Context, completion: @escaping (FearGreedEntry) -> Void) {
        let cachedScore = userDefaults?.integer(forKey: vixScoreKey) ?? 0
        let entry = FearGreedEntry(date: Date(), score: cachedScore > 0 ? cachedScore : 50)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FearGreedEntry>) -> Void) {
        Task {
            var score = 50 // 기본값을 50으로 설정
            var fetchedScore: Int?
            
            // 실제 데이터를 가져오기 시도
            do {
                fetchedScore = try await fetchCentralScore()
                if let fetched = fetchedScore {
                    score = fetched
                    // 위젯에서도 최신 점수를 앱 그룹에 업데이트하여 일관성 유지
                    userDefaults?.set(score, forKey: vixScoreKey)
                    userDefaults?.set(Date(), forKey: lastUpdateKey)
                    print("Widget: Fetched score \(score) from central JSON")
                } else {
                    // 캐시된 데이터가 있으면 사용
                    let cachedScore = userDefaults?.integer(forKey: vixScoreKey) ?? 0
                    if cachedScore > 0 {
                        score = cachedScore
                        print("Widget: Using cached score \(score)")
                    } else {
                        print("Widget: No data available, using default score \(score)")
                    }
                }
            } catch {
                // 에러 발생 시 캐시된 데이터 사용
                let cachedScore = userDefaults?.integer(forKey: vixScoreKey) ?? 0
                if cachedScore > 0 {
                    score = cachedScore
                    print("Widget: Error fetching data, using cached score \(score)")
                } else {
                    print("Widget: Error fetching data and no cache, using default score \(score)")
                }
            }

            let entry = FearGreedEntry(date: Date(), score: score)

            // 다음 업데이트 시간 계산 (매일 오전 7시)
            let calendar = Calendar.current
            var nextUpdate = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: Date()) ?? Date()
            if Date() >= nextUpdate {
                nextUpdate = calendar.date(byAdding: .day, value: 1, to: nextUpdate) ?? nextUpdate
            }

            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }

    private func fetchCentralScore() async throws -> Int {
        let (data, response) = try await URLSession.shared.data(from: centralDailyURL)
        
        // HTTP 응답 상태 확인
        if let httpResponse = response as? HTTPURLResponse {
            guard httpResponse.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
        }
        
        let payload = try JSONDecoder().decode(DailyPayload.self, from: data)
        return payload.scores.finalScore
    }
}

// MARK: - Widget View
struct FearGreedWidgetEntryView : View {
    var entry: FearGreedEntry

    var body: some View {
        ZStack {
            Color.black
            VStack(spacing: 8) {
                Text("Stock market")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                
                // 점수(Score)는 흰색, ultraLight, 64pt
                Text("\(entry.score)")
                    .font(.system(size: 64, weight: .light))
                    .foregroundColor(.white)
                
                // Mood 텍스트: 12pt, 구간별 색상
                Text(mood(for: entry.score))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(moodColor(for: entry.score))
            }
            .padding()
        }
        .containerBackground(for: .widget) {
            Color.black
        }
    }

    func scoreColor(for score: Int) -> Color {
        switch score {
        case 0..<20: return .red
        case 20..<45: return .orange
        case 45..<55: return .gray
        case 55..<75: return .green
        default: return .blue
        }
    }

    func mood(for score: Int) -> String {
        switch score {
        case 0..<20: return "Extreme Fear"
        case 20..<45: return "Fear"
        case 45..<55: return "Neutral"
        case 55..<75: return "Greed"
        default: return "Extreme Greed"
        }
    }

    // Mood별 색상 지정 함수 추가
    func moodColor(for score: Int) -> Color {
        switch score {
        case 0...24: return .red // Extreme Fear
        case 25...49: return .orange // Fear
        case 50...59: return .green // Neutral
        case 60...74: return .blue // Greed
        case 75...100: return .purple // Extreme Greed
        default: return .white
        }
    }
}
