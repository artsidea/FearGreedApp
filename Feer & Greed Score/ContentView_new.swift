//
//  ContentView.swift
//  Feer & Greed Score
//
//  Created by hyujang on 5/11/25.
//

import SwiftUI
import CoreMotion
import UIKit

struct ShadowText: UIViewRepresentable {
    let text: String
    let size: CGFloat
    let weight: UIFont.Weight
    
    func makeUIView(context: Context) -> UIView {
        let label = UILabel()
        label.textAlignment = .center
        label.numberOfLines = 1
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.5
        label.text = text
        label.font = UIFont.systemFont(ofSize: size, weight: weight)
        label.textColor = .black
        return label
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let label = uiView as? UILabel {
            label.text = text
            label.font = UIFont.systemFont(ofSize: size, weight: weight)
            label.textColor = .black
        }
    }
}

enum MarketType: String, CaseIterable {
    case stock = "Stock"
    case crypto = "Crypto"
}

struct CryptoFearGreed: Decodable {
    struct Data: Decodable {
        let value: String
        let value_classification: String
    }
    let data: [Data]
}

struct ContentView: View {
    @State private var score: Int = VIXFetcher.shared.getLastScore()
    @State private var vixValue: Double = 0
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var lastRefresh: Date? = VIXFetcher.shared.getLastUpdateTime()
    @State private var now: Date = Date()
    @State private var originalScore: Int? = nil
    @State private var phase: CGFloat = 0
    @State private var time: CGFloat = 0
    @State private var scoreRect: CGRect = .zero
    @ObservedObject private var motion = MotionManager.shared
    @State private var selectedMarket: MarketType = .stock
    @State private var cryptoMood: String = ""
    @State private var isTransitioning = false
    @State private var previousMarket: MarketType = .stock
    @State private var currentMarket: MarketType = .stock
    @State private var currentScore: Int = 0
    @State private var currentCryptoMood: String = ""
    @State private var dragOffset: CGFloat = 0
    @State private var lastCryptoUpdate: Date? = nil
    @State private var showingDetailedAnalysis = false
    @State private var marketSentiment: MarketSentimentScore?
    
    // VIX 공식 업데이트 시각 (매일 오전 7시, 한국 시간)
    private var nextVIXUpdate: Date {
        let calendar = Calendar.current
        let now = self.now
        var next = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: now) ?? now
        if now >= next {
            next = calendar.date(byAdding: .day, value: 1, to: next) ?? next
        }
        return next
    }
    
    // 다음 업데이트 시각을 문자열로 변환
    private var nextVIXUpdateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "a h:mm"
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: nextVIXUpdate)
    }
    private var timeLeftString: String {
        let interval = Int(nextVIXUpdate.timeIntervalSince(now))
        let hours = interval / 3600
        let minutes = (interval % 3600) / 60
        let seconds = interval % 60
        return String(format: "%02dhr %02dmin %02dsec", hours, minutes, seconds)
    }
    
    var body: some View {
        GeometryReader { geo in
            let _ = geo.size.width
            let height = geo.size.height
            ZStack {
                // 배경
                Color.black.opacity(0.1).ignoresSafeArea()
                
                // 구간별 표시 (왼쪽)
                let sectionLabels = ["Extreme Greed", "Greed", "Neutral", "Fear", "Extreme Fear"]
                let sectionRanges = [100, 75, 55, 45, 20, 0]
                let labelHeights: [CGFloat] = (0..<sectionLabels.count).map { i in
                    height * (CGFloat(sectionRanges[i] - sectionRanges[i+1]) / 100)
                }
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(0..<sectionLabels.count, id: \.self) { i in
                        VStack(alignment: .leading, spacing: 0) {
                            Rectangle()
                                .fill(Color.black.opacity(0.4))
                                .frame(width: 10, height: 1, alignment: .leading)
                                .alignmentGuide(.leading) { d in d[.leading] }
                                .padding(.leading, 16)
                            Text(sectionLabels[i])
                                .font(.caption)
                                .foregroundColor(.black)
                                .frame(height: labelHeights[i], alignment: .top)
                                .padding(.leading, 1)
                        }
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
                .zIndex(10)
                .allowsHitTesting(false)
                
                // 파티클 효과
                LiquidView(score: currentScore, color: currentMarket == .stock ? scoreColor : cryptoColor, marketType: currentMarket, scoreOffsetX: 0)
                    .zIndex(2)
                
                // 하단 안내 (카운트다운 + 업데이트 시각)
                VStack {
                    Spacer()
                    
                    // 상세 분석 버튼 (주식 시장일 때만 표시)
                    if currentMarket == .stock {
                        Button(action: {
                            showingDetailedAnalysis = true
                        }) {
                            HStack {
                                Image(systemName: "chart.bar.fill")
                                Text("상세 분석")
                            }
                            .font(.caption)
                            .foregroundColor(.black)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.8))
                            .cornerRadius(15)
                            .shadow(radius: 2)
                        }
                        .padding(.bottom, 8)
                    }
                    
                    // 화살표 버튼(중앙, 하단 텍스트 위)
                    Button(action: {
                        if !isTransitioning {
                            let next: MarketType = (selectedMarket == .stock) ? .crypto : .stock
                            selectedMarket = next
                        }
                    }) {
                        Image(systemName: selectedMarket == .stock ? "chevron.right.circle.fill" : "chevron.left.circle.fill")
                            .resizable()
                            .frame(width: 40, height: 40)
                            .foregroundColor(Color(.sRGB, white: 0.12, opacity: 0.85))
                            .shadow(radius: 4)
                            .padding(.bottom, 8)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    // 안내 텍스트
                    if currentMarket == .crypto {
                        Text("CRYPTO FEAR & GREED: \(currentScore) (\(currentCryptoMood))")
                            .font(.caption)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity, alignment: .center)
                        if let last = lastCryptoUpdate {
                            Text("LAST UPDATED: \(last.formatted(date: .abbreviated, time: .standard))")
                                .font(.caption2)
                                .foregroundColor(.black.opacity(0.7))
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.bottom, height * 0.04)
                        } else {
                            Text("")
                                .padding(.bottom, height * 0.04)
                        }
                    } else {
                        Text("STOCK FEAR & GREED: \(currentScore)")
                            .font(.caption)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity, alignment: .center)
                        Text("NEXT UPDATE IN: \(timeLeftString) (\(nextVIXUpdate.formatted(date: .omitted, time: .shortened)))")
                            .font(.caption)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.bottom, height * 0.04)
                    }
                }
                .zIndex(20)
                
                if let error = errorMessage {
                    VStack {
                        Spacer()
                        Text(error)
                            .foregroundColor(.black)
                            .padding()
                        Spacer()
                    }
                }
                
                // 검은색 전환 오버레이
                Color.black
                    .ignoresSafeArea()
                    .opacity(isTransitioning ? 1 : 0)
                    .zIndex(100)
            }
            .sheet(isPresented: $showingDetailedAnalysis) {
                DetailedAnalysisView(marketSentiment: marketSentiment)
            }
            .onAppear {
                currentScore = VIXFetcher.shared.getLastScore()
                fetchData()
                Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                    self.now = Date()
                }
                Timer.scheduledTimer(withTimeInterval: 1/60, repeats: true) { _ in
                    withAnimation(.linear(duration: 1/60)) {
                        time += 1/60
                        phase = sin(time) * .pi
                    }
                }
            }
            .onChange(of: selectedMarket) { oldValue, newValue in
                guard newValue != previousMarket else { return }
                previousMarket = newValue
                // 전환 시작 (검은색으로 fade out)
                withAnimation(.easeOut(duration: 0.2)) {
                    isTransitioning = true
                }
                // 검은색이 완전히 화면을 덮은 후에 데이터를 가져오고 컨텐츠를 업데이트
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    Task {
                        // 전환 타겟을 먼저 반영하여, 네트워크 실패 시에도 화면 전환 상태 유지
                        await MainActor.run {
                            currentMarket = newValue
                            if newValue == .stock { currentCryptoMood = "" }
                        }
                        do {
                            if newValue == .stock {
                                let sentiment = try await VIXFetcher.shared.fetchAndCalculateMarketSentiment()
                                await MainActor.run {
                                    currentScore = sentiment.finalScore
                                    let userDefaults = UserDefaults(suiteName: "group.com.hyujang.feargreed")
                                    userDefaults?.set(sentiment.finalScore, forKey: "lastVIXScore")
                                    isLoading = false
                                    lastCryptoUpdate = nil
                                }
                            } else {
                                let url = URL(string: "https://api.alternative.me/fng/")!
                                let (data, _) = try await URLSession.shared.data(from: url)
                                let decoded = try JSONDecoder().decode(CryptoFearGreed.self, from: data)
                                let value = Int(decoded.data.first?.value ?? "50") ?? 50
                                let mood = decoded.data.first?.value_classification ?? ""
                                await MainActor.run {
                                    currentScore = value
                                    currentCryptoMood = mood
                                    isLoading = false
                                    lastCryptoUpdate = Date()
                                }
                            }
                            // 데이터 업데이트 후 검은색 오버레이 제거
                            await MainActor.run {
                                withAnimation(.easeIn(duration: 0.2)) {
                                    isTransitioning = false
                                }
                            }
                        } catch {
                            await MainActor.run {
                                errorMessage = "데이터를 가져오는데 실패했습니다: \(error.localizedDescription)"
                                isLoading = false
                                isTransitioning = false
                            }
                        }
                    }
                }
            }
        }
    }
    
    private var scoreColor: Color {
        switch score {
        case 0..<20: return .red
        case 20..<45: return .orange
        case 45..<55: return .yellow
        case 55..<75: return .green
        default: return .blue
        }
    }
    
    private var cryptoColor: Color {
        switch score {
        case 0..<20: return .purple // Extreme Fear
        case 20..<45: return Color(red: 110/255, green: 60/255, blue: 200/255) // Fear (보라+파랑 느낌)
        case 45..<55: return .blue // Neutral
        case 55..<75: return .cyan // Greed
        default: return .mint // Extreme Greed
        }
    }
    
    private func fetchData() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                if selectedMarket == .stock {
                    let sentiment = try await VIXFetcher.shared.fetchAndCalculateMarketSentiment()
                    await MainActor.run {
                        self.score = sentiment.finalScore
                        self.marketSentiment = sentiment
                        let userDefaults = UserDefaults(suiteName: "group.com.hyujang.feargreed")
                        userDefaults?.set(sentiment.finalScore, forKey: "lastVIXScore")
                        self.isLoading = false
                        self.cryptoMood = ""
                    }
                } else {
                    // 코인 공포/탐욕 지수 fetch
                    let url = URL(string: "https://api.alternative.me/fng/")!
                    let (data, _) = try await URLSession.shared.data(from: url)
                    let decoded = try JSONDecoder().decode(CryptoFearGreed.self, from: data)
                    let value = Int(decoded.data.first?.value ?? "50") ?? 50
                    let mood = decoded.data.first?.value_classification ?? ""
                await MainActor.run {
                        self.score = value
                        self.cryptoMood = mood
                    self.isLoading = false
                    self.lastCryptoUpdate = Date()
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "데이터를 가져오는데 실패했습니다: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
}

#Preview {
    ContentView()
}

// MARK: - 상세 분석 뷰
struct DetailedAnalysisView: View {
    let marketSentiment: MarketSentimentScore?
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = false
    @State private var detailedSentiment: MarketSentimentScore?
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if let sentiment = detailedSentiment ?? marketSentiment {
                        // 전체 점수 카드
                        OverallScoreCard(sentiment: sentiment)
                        
                        // 개별 지표들
                        IndicatorsGrid(sentiment: sentiment)
                        
                        // 상세 분석
                        DetailedAnalysisCard(sentiment: sentiment)
                        
                        // 투자 권장사항
                        RecommendationsCard(sentiment: sentiment)
                    } else if isLoading {
                        ProgressView("분석 중...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let error = errorMessage {
                        VStack {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.largeTitle)
                                .foregroundColor(.red)
                            Text("오류 발생")
                                .font(.headline)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .padding()
            }
            .navigationTitle("상세 분석")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("닫기") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            if detailedSentiment == nil && marketSentiment == nil {
                loadDetailedAnalysis()
            }
        }
    }
    
    private func loadDetailedAnalysis() {
        isLoading = true
        Task {
            do {
                let sentiment = try await VIXFetcher.shared.fetchAndCalculateMarketSentiment()
                await MainActor.run {
                    self.detailedSentiment = sentiment
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}

// MARK: - 전체 점수 카드
struct OverallScoreCard: View {
    let sentiment: MarketSentimentScore
    
    var body: some View {
        VStack(spacing: 12) {
            Text("전체 시장 심리")
                .font(.headline)
                .foregroundColor(.primary)
            
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                    .frame(width: 120, height: 120)
                
                Circle()
                    .trim(from: 0, to: CGFloat(sentiment.finalScore) / 100)
                    .stroke(scoreColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 1), value: sentiment.finalScore)
                
                VStack {
                    Text("\(sentiment.finalScore)")
                        .font(.title)
                        .fontWeight(.bold)
                    Text(sentiment.overallStatus)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Text(sentiment.overallStatus)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(scoreColor)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private var scoreColor: Color {
        switch sentiment.finalScore {
        case 0..<25: return .red
        case 25..<45: return .orange
        case 45..<55: return .yellow
        case 55..<75: return .green
        default: return .blue
        }
    }
}

// MARK: - 지표 그리드
struct IndicatorsGrid: View {
    let sentiment: MarketSentimentScore
    
    private let indicators = [
        ("VIX", "vixScore", "chart.line.uptrend.xyaxis"),
        ("모멘텀", "momentumScore", "speedometer"),
        ("안전자산", "safeHavenScore", "shield.fill"),
        ("Put/Call", "putCallScore", "chart.bar.fill"),
        ("정크본드", "junkScore", "chart.line.downtrend.xyaxis"),
        ("시장폭", "breadthScore", "chart.pie.fill"),
        ("거래량", "volumeScore", "chart.bar.xaxis"),
        ("변동성", "volatilityScore", "waveform.path.ecg"),
        ("상관관계", "correlationScore", "link"),
        ("감정", "sentimentScore", "heart.fill"),
        ("기술적", "technicalScore", "chart.xyaxis.line"),
        ("경제", "economicScore", "building.2.fill"),
        ("글로벌", "globalScore", "globe")
    ]
    
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
            ForEach(indicators, id: \.0) { indicator in
                IndicatorCard(
                    title: indicator.0,
                    score: getScore(for: indicator.1),
                    icon: indicator.2,
                    description: VIXScoreCalculator.getIndicatorDescription(for: indicator.1)
                )
            }
        }
    }
    
    private func getScore(for indicator: String) -> Int {
        switch indicator {
        case "vixScore": return sentiment.vixScore
        case "momentumScore": return sentiment.momentumScore
        case "safeHavenScore": return sentiment.safeHavenScore
        case "putCallScore": return sentiment.putCallScore
        case "junkScore": return sentiment.junkScore
        case "breadthScore": return sentiment.breadthScore
        case "volumeScore": return sentiment.volumeScore
        case "volatilityScore": return sentiment.volatilityScore
        case "correlationScore": return sentiment.correlationScore
        case "sentimentScore": return sentiment.sentimentScore
        case "technicalScore": return sentiment.technicalScore
        case "economicScore": return sentiment.economicScore
        case "globalScore": return sentiment.globalScore
        default: return 50
        }
    }
}

// MARK: - 개별 지표 카드
struct IndicatorCard: View {
    let title: String
    let score: Int
    let icon: String
    let description: String
    @State private var showingDescription = false
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(scoreColor)
                Spacer()
                Text("\(score)")
                    .font(.headline)
                    .fontWeight(.bold)
            }
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            ProgressView(value: Double(score), total: 100)
                .progressViewStyle(LinearProgressViewStyle(tint: scoreColor))
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(radius: 1)
        .onTapGesture {
            showingDescription = true
        }
        .alert(title, isPresented: $showingDescription) {
            Button("확인") { }
        } message: {
            Text(description)
        }
    }
    
    private var scoreColor: Color {
        switch score {
        case 0..<25: return .red
        case 25..<45: return .orange
        case 45..<55: return .yellow
        case 55..<75: return .green
        default: return .blue
        }
    }
}

// MARK: - 상세 분석 카드
struct DetailedAnalysisCard: View {
    let sentiment: MarketSentimentScore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("상세 분석")
                .font(.headline)
                .foregroundColor(.primary)
            
            let analysis = VIXScoreCalculator.detailedAnalysis(for: sentiment.finalScore)
            
            Text(analysis.description)
                .font(.body)
                .foregroundColor(.secondary)
            
            HStack {
                Label("리스크 레벨", systemImage: "exclamationmark.triangle")
                Spacer()
                Text(analysis.riskLevel.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(riskColor)
                    .foregroundColor(.white)
                    .cornerRadius(4)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private var riskColor: Color {
        let analysis = VIXScoreCalculator.detailedAnalysis(for: sentiment.finalScore)
        switch analysis.riskLevel {
        case .veryLow: return .green
        case .low: return .blue
        case .medium: return .yellow
        case .high: return .orange
        case .veryHigh: return .red
        }
    }
}

// MARK: - 투자 권장사항 카드
struct RecommendationsCard: View {
    let sentiment: MarketSentimentScore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("투자 권장사항")
                .font(.headline)
                .foregroundColor(.primary)
            
            let analysis = VIXScoreCalculator.detailedAnalysis(for: sentiment.finalScore)
            
            ForEach(analysis.recommendations, id: \.self) { recommendation in
                HStack(alignment: .top) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    Text(recommendation)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
} 