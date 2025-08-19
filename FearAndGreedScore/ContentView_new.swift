//
//  ContentView.swift
//  FearAndGreedScore
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
                
                // 구간별 표시 (왼쪽) — 안전영역 기준 퍼센트 고정 배치
                let safeTop = geo.safeAreaInsets.top
                let safeBottom = geo.safeAreaInsets.bottom
                let safeHeight = height - safeTop - safeBottom

                ZStack(alignment: .topLeading) {
                    let marks: [(String, CGFloat)] = [
                        ("Extreme Fear", 0.15),
                        ("Fear",         0.30),
                        ("Neutral",      0.45),
                        ("Greed",        0.65),
                        ("Extreme Greed",0.85)
                    ]
                    ForEach(0..<marks.count, id: \.self) { i in
                        let (label, pctFromTop) = marks[i]
                        // 아래에서 위로 0%→100%가 되도록 반전
                        let y = safeTop + safeHeight * (1 - pctFromTop)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            // 좌측 정렬 선
                            Rectangle()
                                .fill(Color.black.opacity(0.4))
                                .frame(width: 10, height: 1)
                            // 선 아래에 텍스트 좌측 정렬
                            Text(label)
                                .font(.caption)
                                .foregroundColor(.black)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 16)
                        .offset(x: 0, y: y)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
                        ZStack(alignment: .leading) {
                            let toggleWidth: CGFloat = 72
                            let toggleHeight: CGFloat = 44
                            let knobSize: CGFloat = 40
                            // Track
                            RoundedRectangle(cornerRadius: toggleHeight/2)
                                .fill(Color.black.opacity(0.08))
                                .frame(width: toggleWidth, height: toggleHeight)
                                // Outline for contrast
                                .overlay(
                                    RoundedRectangle(cornerRadius: toggleHeight/2)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                                // Inner shade (top highlight -> bottom shadow)
                                .overlay(
                                    RoundedRectangle(cornerRadius: toggleHeight/2)
                                        .fill(
                                            LinearGradient(
                                                colors: [Color.black.opacity(0.18), Color.clear],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                        .mask(
                                            RoundedRectangle(cornerRadius: toggleHeight/2)
                                                .inset(by: 1)
                                        )
                                )
                                // Inner side shade (left to right)
                                .overlay(
                                    RoundedRectangle(cornerRadius: toggleHeight/2)
                                        .fill(
                                            LinearGradient(
                                                colors: [Color.black.opacity(0.06), Color.clear, Color.black.opacity(0.06)],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .mask(
                                            RoundedRectangle(cornerRadius: toggleHeight/2)
                                                .inset(by: 1)
                                        )
                                )
                            // Faint inactive symbols (no circle) on opposite side
                            HStack {
                                if selectedMarket == .crypto {
                                    Image(systemName: "dollarsign.circle.fill")
                                        .resizable()
                                        .frame(width: knobSize, height: knobSize)
                                        .foregroundColor(Color(.sRGB, white: 0.12, opacity: 0.85))
                                        .opacity(0.0)
                                } else {
                                    Color.clear.frame(width: knobSize, height: knobSize)
                                }
                                Spacer()
                                if selectedMarket == .stock {
                                    Image(systemName: "bitcoinsign.circle.fill")
                                        .resizable()
                                        .frame(width: knobSize, height: knobSize)
                                        .foregroundColor(Color(.sRGB, white: 0.12, opacity: 0.85))
                                        .opacity(0.0)
                                } else {
                                    Color.clear.frame(width: knobSize, height: knobSize)
                                }
                            }
                            .frame(width: toggleWidth, height: toggleHeight)
                            .allowsHitTesting(false)
                            // Knob (active icon with circle)
                            ZStack {
                                Circle()
                                    .fill(Color(.sRGB, white: 0.12, opacity: 0.85))
                                    .overlay(
                                        Circle().stroke(Color.white.opacity(0.2), lineWidth: 1)
                                    )
                                Text(selectedMarket == .stock ? "$" : "₿")
                                    .font(.system(size: knobSize * 0.55, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            .frame(width: knobSize, height: knobSize)
                            .shadow(radius: 4)
                                .offset(x: selectedMarket == .stock ? 2 : (toggleWidth - knobSize - 2))
                                .animation(.easeInOut(duration: 0.2), value: selectedMarket)
                        }
                        .frame(width: 66, height: 44)
                        .zIndex(200)
                    }
                    .buttonStyle(.plain)
                    .position(x: geo.size.width / 2, y: height - geo.safeAreaInsets.bottom - 48)
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
                                .padding(.bottom, height * 0.012)
                        } else {
                            Text("")
                                .padding(.bottom, height * 0.012)
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
                            .padding(.bottom, height * 0.012)
                    }
                }
                .zIndex(200)
                
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
                // 현재 선택된 시장에 맞는 스코어 로드
                currentScore = VIXFetcher.shared.getScoreForMarket(selectedMarket)
                
                // 디버깅 정보 출력
                print("🔍 디버깅 정보:")
                print(VIXFetcher.shared.debugStoredScores())
                
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
                        // 최종 점수에 동일 보정 적용
                        let calibrated = VIXFetcher.shared.calibratedScoreForStock(sentiment.finalScore)
                        let newScore = VIXFetcher.shared.updateScoreForMarketWithFallback(calibrated, marketType: .stock)
                        currentScore = newScore
                        score = newScore
                        
                        let userDefaults = UserDefaults(suiteName: "group.com.hyujang.feargreed")
                        userDefaults?.set(currentScore, forKey: "lastStockScore")
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
                        // Crypto는 보정 없이 원점수 사용
                        let newScore = VIXFetcher.shared.updateScoreForMarketWithFallback(value, marketType: .crypto)
                        currentScore = newScore
                        score = newScore
                        
                        let userDefaults = UserDefaults(suiteName: "group.com.hyujang.feargreed")
                        userDefaults?.set(currentScore, forKey: "lastCryptoScore")
                        
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
                                // 에러 발생 시 이전 데이터 유지
                                currentScore = VIXFetcher.shared.getLastValidScoreForMarket(newValue)
                                errorMessage = "데이터를 가져오는데 실패했습니다: \(error.localizedDescription)"
                                isLoading = false
                                isTransitioning = false
                                
                                // 에러 메시지를 잠시만 표시
                                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                    self.errorMessage = nil
                                }
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
        // 로딩 시작 전에 현재 스코어를 백업
        let previousScore = self.score
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                if selectedMarket == .stock {
                    let sentiment = try await VIXFetcher.shared.fetchFromGithubDaily()
                    await MainActor.run {
                        // 최종 점수에 보정 적용(50 기준 편차 30% 축소)
                        let calibrated = VIXFetcher.shared.calibratedScoreForStock(sentiment.finalScore)
                        let newScore = VIXFetcher.shared.updateScoreForMarketWithFallback(calibrated, marketType: .stock)
                        self.score = newScore
                        self.currentScore = newScore
                        
                        let userDefaults = UserDefaults(suiteName: "group.com.hyujang.feargreed")
                        userDefaults?.set(self.score, forKey: "lastStockScore")
                        
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
                        // Crypto는 외부 API 점수를 직접 사용 (보정 없음)
                        let newScore = VIXFetcher.shared.updateScoreForMarketWithFallback(value, marketType: .crypto)
                        self.score = newScore
                        self.currentScore = newScore
                        
                        // UserDefaults에 암호화폐 스코어 저장
                        let userDefaults = UserDefaults(suiteName: "group.com.hyujang.feargreed")
                        userDefaults?.set(self.score, forKey: "lastCryptoScore")
                        
                        self.cryptoMood = mood
                        self.isLoading = false
                        self.lastCryptoUpdate = Date()
                    }
                }
            } catch {
                await MainActor.run {
                    // 에러 발생 시 이전 데이터 유지
                    self.score = previousScore
                    self.currentScore = VIXFetcher.shared.getLastValidScoreForMarket(self.selectedMarket)
                    self.errorMessage = "데이터를 가져오는데 실패했습니다: \(error.localizedDescription)"
                    self.isLoading = false
                    
                    // 에러 메시지를 잠시만 표시
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        self.errorMessage = nil
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
} 