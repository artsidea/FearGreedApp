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
    private let stockScoreKey = "lastStockScore"  // 앱과 동일한 키 사용
    private let cryptoScoreKey = "lastCryptoScore" // 암호화폐는 별개
    
    func placeholder(in context: Context) -> FearGreedEntry {
        let stockScore = userDefaults?.integer(forKey: stockScoreKey) ?? 0
        return FearGreedEntry(date: Date(), score: stockScore > 0 ? stockScore : 50)
    }

    func getSnapshot(in context: Context, completion: @escaping (FearGreedEntry) -> Void) {
        let stockScore = userDefaults?.integer(forKey: stockScoreKey) ?? 0
        let entry = FearGreedEntry(date: Date(), score: stockScore > 0 ? stockScore : 50)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FearGreedEntry>) -> Void) {
        // 앱에서 저장한 주식 스코어를 직접 사용 (동기화)
        let stockScore = userDefaults?.integer(forKey: stockScoreKey) ?? 0
        let score = stockScore > 0 ? stockScore : 50
        
        print("Widget: Using app's stock score: \(score)")
        
        let currentDate = Date()
        let calendar = Calendar.current
        
        // 여러 시간대의 엔트리를 생성하여 더 자주 업데이트
        var entries: [FearGreedEntry] = []
        
        // 현재 시간부터 시작하여 15분마다 업데이트
        for minuteOffset in stride(from: 0, to: 240, by: 15) { // 4시간 동안 15분마다
            if let entryDate = calendar.date(byAdding: .minute, value: minuteOffset, to: currentDate) {
                let entry = FearGreedEntry(date: entryDate, score: score)
                entries.append(entry)
            }
        }
        
        // 다음 주요 업데이트는 15분 후
        let nextUpdate = calendar.date(byAdding: .minute, value: 15, to: currentDate) ?? Date()
        
        // atEnd 정책으로 변경하여 시스템이 더 자주 새로고침하도록 유도
        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
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
