//
//  VIXScoreCalculator.swift
//  Feer & Greed Score
//
//  Created by hyujang on 5/11/25.
//

import Foundation

struct VIXScoreCalculator {
    static func vixToScore(vix: Double) -> Int {
        let capped = min(max(vix, 10), 45)
        let normalized = (45 - capped) / (45 - 10) // 0~1
        let score = Int(normalized * 100)
        
        return Int(sqrt(Double(score) * 100))
    }

    static func mood(for score: Int) -> String {
        switch score {
        case 0..<20: return "Extreme Fear"
        case 20..<45: return "Fear"
        case 45..<55: return "Neutral"
        case 55..<75: return "Greed"
        default: return "Extreme Greed"
        }
    }
}


