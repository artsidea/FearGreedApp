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
                                let sentiment = try await VIXFetcher.shared.fetchFromGithubDaily()
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
                    let sentiment = try await VIXFetcher.shared.fetchFromGithubDaily()
                    await MainActor.run {
                        self.score = sentiment.finalScore
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