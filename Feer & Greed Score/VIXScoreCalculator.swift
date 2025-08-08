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
        
        // CNN 원래 계산식과 일치하도록 수정
        return score
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
    
    // MARK: - 확장된 분석 기능
    
    static func detailedAnalysis(for score: Int) -> DetailedAnalysis {
        return DetailedAnalysis(score: score)
    }
    
    static func getIndicatorDescription(for indicator: String) -> String {
        switch indicator {
        case "vixScore":
            return "VIX 지수는 시장의 변동성과 투자자들의 공포/탐욕을 측정하는 지표입니다. 낮은 VIX는 탐욕, 높은 VIX는 공포를 나타냅니다."
        case "momentumScore":
            return "모멘텀 점수는 S&P500의 125일 이동평균 대비 현재 가격의 상대적 성과를 측정합니다. 상승 모멘텀은 탐욕을 나타냅니다."
        case "safeHavenScore":
            return "안전자산 점수는 주식과 채권의 상대적 성과를 비교합니다. 주식이 채권보다 잘 나올 때 탐욕을 나타냅니다."
        case "putCallScore":
            return "Put/Call 비율은 옵션 시장의 투자자 심리를 반영합니다. 낮은 비율은 탐욕, 높은 비율은 공포를 나타냅니다."
        case "junkScore":
            return "정크본드 스프레드는 위험 자산에 대한 투자자들의 선호도를 측정합니다. 낮은 스프레드는 탐욕을 나타냅니다."
        case "breadthScore":
            return "시장 폭 점수는 S&P500의 52주 고점/저점 대비 현재 위치를 측정합니다. 고점에 가까울수록 탐욕을 나타냅니다."
        case "volumeScore":
            return "거래량 점수는 현재 거래량과 평균 거래량의 비율을 측정합니다. 낮은 거래량은 탐욕을 나타냅니다."
        case "volatilityScore":
            return "변동성 점수는 S&P500의 20일 변동성을 측정합니다. 낮은 변동성은 탐욕, 높은 변동성은 공포를 나타냅니다."
        case "correlationScore":
            return "상관관계 점수는 주식, 금, 채권 간의 상관관계를 측정합니다. 낮은 상관관계는 탐욕을 나타냅니다."
        case "sentimentScore":
            return "감정 점수는 VIX와 Put/Call 비율을 기반으로 한 시장 심리를 측정합니다."
        case "technicalScore":
            return "기술적 점수는 RSI와 MACD 등의 기술적 지표를 기반으로 계산됩니다."
        case "economicScore":
            return "경제 점수는 10년 국채 금리를 기반으로 한 경제 상황을 측정합니다."
        case "globalScore":
            return "글로벌 점수는 미국, 유럽, 아시아 시장의 상대적 성과를 측정합니다."
        default:
            return "알 수 없는 지표입니다."
        }
    }
}

// MARK: - 상세 분석 구조체
struct DetailedAnalysis {
    let score: Int
    let mood: String
    let description: String
    let recommendations: [String]
    let riskLevel: RiskLevel
    
    init(score: Int) {
        self.score = score
        self.mood = VIXScoreCalculator.mood(for: score)
        self.description = DetailedAnalysis.getDescription(for: score)
        self.recommendations = DetailedAnalysis.getRecommendations(for: score)
        self.riskLevel = DetailedAnalysis.getRiskLevel(for: score)
    }
    
    private static func getDescription(for score: Int) -> String {
        switch score {
        case 0..<20:
            return "시장이 극도의 공포 상태에 있습니다. 투자자들이 대규모로 자산을 매도하고 있으며, 변동성이 매우 높습니다. 이는 종종 반등의 기회가 될 수 있습니다."
        case 20..<45:
            return "시장이 공포 상태에 있습니다. 투자자들이 위험을 회피하고 있으며, 안전자산으로 자금이 이동하고 있습니다."
        case 45..<55:
            return "시장이 중립 상태에 있습니다. 투자자들이 극단적인 감정 없이 시장을 바라보고 있으며, 균형잡힌 접근이 필요합니다."
        case 55..<75:
            return "시장이 탐욕 상태에 있습니다. 투자자들이 위험을 감수하려는 경향이 있으며, 자산 가격이 상승하고 있습니다."
        default:
            return "시장이 극도의 탐욕 상태에 있습니다. 투자자들이 과도하게 낙관적이며, 자산 가격이 과열될 가능성이 있습니다."
        }
    }
    
    private static func getRecommendations(for score: Int) -> [String] {
        switch score {
        case 0..<20:
            return [
                "장기 투자 관점에서 매수 기회를 고려해보세요",
                "분산 투자를 통해 위험을 관리하세요",
                "현금 보유 비율을 높여 유연성을 확보하세요",
                "품질 좋은 기업들의 주식을 우선적으로 고려하세요"
            ]
        case 20..<45:
            return [
                "점진적인 매수 전략을 고려해보세요",
                "안전자산과 위험자산의 균형을 맞추세요",
                "정기적인 리밸런싱을 통해 포트폴리오를 관리하세요",
                "장기적인 관점에서 투자 결정을 내리세요"
            ]
        case 45..<55:
            return [
                "현재 포트폴리오를 유지하면서 관망하세요",
                "정기적인 리밸런싱을 통해 목표 자산 배분을 유지하세요",
                "새로운 투자 기회를 신중하게 평가하세요",
                "리스크 관리에 주의를 기울이세요"
            ]
        case 55..<75:
            return [
                "과도한 낙관에 주의하세요",
                "리스크 관리에 더욱 신중하세요",
                "고평가된 자산의 비중을 줄이는 것을 고려하세요",
                "현금 보유 비율을 점진적으로 높이세요"
            ]
        default:
            return [
                "극도의 탐욕 상태이므로 매우 신중한 접근이 필요합니다",
                "고평가된 자산의 비중을 줄이는 것을 강력히 권장합니다",
                "현금 보유 비율을 높여 유연성을 확보하세요",
                "단기적인 투자보다는 장기적인 관점을 유지하세요"
            ]
        }
    }
    
    private static func getRiskLevel(for score: Int) -> RiskLevel {
        switch score {
        case 0..<20: return .veryLow
        case 20..<45: return .low
        case 45..<55: return .medium
        case 55..<75: return .high
        default: return .veryHigh
        }
    }
}

// MARK: - 리스크 레벨 열거형
enum RiskLevel: String, CaseIterable {
    case veryLow = "매우 낮음"
    case low = "낮음"
    case medium = "보통"
    case high = "높음"
    case veryHigh = "매우 높음"
    
    var color: String {
        switch self {
        case .veryLow: return "green"
        case .low: return "lightGreen"
        case .medium: return "yellow"
        case .high: return "orange"
        case .veryHigh: return "red"
        }
    }
    
    var description: String {
        switch self {
        case .veryLow:
            return "매우 낮은 리스크. 시장이 극도의 공포 상태로, 반등 가능성이 높습니다."
        case .low:
            return "낮은 리스크. 시장이 공포 상태로, 점진적인 매수 기회가 있습니다."
        case .medium:
            return "보통 리스크. 시장이 중립 상태로, 균형잡힌 접근이 필요합니다."
        case .high:
            return "높은 리스크. 시장이 탐욕 상태로, 주의가 필요합니다."
        case .veryHigh:
            return "매우 높은 리스크. 시장이 극도의 탐욕 상태로, 매우 신중한 접근이 필요합니다."
        }
    }
}


