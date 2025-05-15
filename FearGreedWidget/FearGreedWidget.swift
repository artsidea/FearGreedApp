//
//  FearGreedWidget.swift
//  FearGreedWidget
//
//  Created by hyujang on 5/13/25.
//

import WidgetKit
import SwiftUI

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
    
    func placeholder(in context: Context) -> FearGreedEntry {
        FearGreedEntry(date: Date(), score: userDefaults?.integer(forKey: vixScoreKey) ?? 57)
    }

    func getSnapshot(in context: Context, completion: @escaping (FearGreedEntry) -> Void) {
        let entry = FearGreedEntry(date: Date(), score: userDefaults?.integer(forKey: vixScoreKey) ?? 57)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FearGreedEntry>) -> Void) {
        let score = userDefaults?.integer(forKey: vixScoreKey) ?? 57
        print("Widget loaded score: \(score)")
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

// MARK: - Widget View
struct FearGreedWidgetEntryView : View {
    var entry: FearGreedEntry

    var body: some View {
        ZStack {
            Color.black
            VStack(spacing: 8) {
                Text("Fear & Greed")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                
                Text("\(entry.score)")
                    .font(.system(size: 52, weight: .bold))
                    .foregroundColor(.white)
                
                Text(mood(for: entry.score))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(scoreColor(for: entry.score))
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
}

struct MarketSentimentScore {
    let sp500MomentumScore: Int
    let vixScore: Int
    let bondScore: Int

    var finalScore: Int {
        return (sp500MomentumScore + vixScore + bondScore) / 3
    }
}
