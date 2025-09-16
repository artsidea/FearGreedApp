//
//  ContentView.swift
//  FearAndGreedScore
//
//  Created by hyujang on 5/11/25.
//

import SwiftUI
import CoreMotion
import UIKit
import WidgetKit

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
    @State private var autoRefreshTimer: Timer?
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
    @State private var debugText: String = ""
    @State private var showDebug: Bool = false // 디버그 로그 표시 (true로 변경하면 우측 상단에 로그 표시)
    @State private var todayDelta: Int? = nil
    @State private var screenBrightness: Double = 1.0
    @State private var isScreenDimmed: Bool = false
    @State private var lastInteractionTime: Date = Date()
    @State private var isFirstLaunch = true  // 첫 실행 여부 추적
    @State private var hasInitializedBubbles = false  // 버블 초기화 여부
    
    private let dimTimeout: TimeInterval = 120 // 2분 후 화면 어둡게
    private let screenOffTimeout: TimeInterval = 180 // 3분 후 화면 완전히 끄기
    
    // 시간 차이를 "(X minutes ago)" 형식으로 변환하는 함수
    private func timeAgoString(from date: Date) -> String {
        let now = Date()
        let interval = now.timeIntervalSince(date)
        let minutes = Int(interval / 60)
        
        if minutes < 1 {
            return "(just now)"
        } else if minutes == 1 {
            return "(1 minute ago)"
        } else if minutes < 60 {
            return "(\(minutes) minutes ago)"
        } else {
            let hours = minutes / 60
            if hours == 1 {
                return "(1 hour ago)"
            } else if hours < 24 {
                return "(\(hours) hours ago)"
            } else {
                let days = hours / 24
                if days == 1 {
                    return "(1 day ago)"
                } else {
                    return "(\(days) days ago)"
                }
            }
        }
    }
    
    // CNN Fear & Greed Index 다음 업데이트 시각
    private var nextVIXUpdate: Date {
        let calendar = Calendar.current
        let now = self.now
        
        // 뉴욕 시간대 (EST/EDT)
        guard let nyTimeZone = TimeZone(identifier: "America/New_York") else {
            // 시간대 설정 실패 시 1시간 후로 설정
            return calendar.date(byAdding: .hour, value: 1, to: now) ?? now
        }
        
        // 현재 시간을 뉴욕 시간으로 변환
        var nyCalendar = calendar
        nyCalendar.timeZone = nyTimeZone
        
        let nyComponents = nyCalendar.dateComponents([.year, .month, .day, .hour, .minute, .weekday], from: now)
        let currentHour = nyComponents.hour ?? 0
        let weekday = nyComponents.weekday ?? 1 // 1=일요일, 2=월요일, ..., 7=토요일
        
        // 주말 확인 (일요일=1, 토요일=7)
        if weekday == 1 || weekday == 7 {
            // 주말이면 다음 월요일 9:30 AM
            let nextMonday = calendar.date(bySetting: .weekday, value: 2, of: now) ?? now
            var mondayComponents = nyCalendar.dateComponents([.year, .month, .day], from: nextMonday)
            mondayComponents.hour = 9
            mondayComponents.minute = 30
            mondayComponents.timeZone = nyTimeZone
            return nyCalendar.date(from: mondayComponents) ?? now
        }
        
        // 평일 처리
        if currentHour < 9 || (currentHour == 9 && (nyComponents.minute ?? 0) < 30) {
            // 시장 오픈 전이면 오늘 9:30 AM
            var todayComponents = nyComponents
            todayComponents.hour = 9
            todayComponents.minute = 30
            todayComponents.timeZone = nyTimeZone
            return nyCalendar.date(from: todayComponents) ?? now
        } else if currentHour >= 16 {
            // 시장 마감 후면 다음 거래일 9:30 AM
            let nextDay = calendar.date(byAdding: .day, value: 1, to: now) ?? now
            let nextDayComponents = nyCalendar.dateComponents([.year, .month, .day, .weekday], from: nextDay)
            
            // 다음날이 주말이면 월요일로
            if nextDayComponents.weekday == 1 || nextDayComponents.weekday == 7 {
                let nextMonday = calendar.date(bySetting: .weekday, value: 2, of: nextDay) ?? nextDay
                var mondayComponents = nyCalendar.dateComponents([.year, .month, .day], from: nextMonday)
                mondayComponents.hour = 9
                mondayComponents.minute = 30
                mondayComponents.timeZone = nyTimeZone
                return nyCalendar.date(from: mondayComponents) ?? now
            } else {
                var nextDayFinal = nyCalendar.dateComponents([.year, .month, .day], from: nextDay)
                nextDayFinal.hour = 9
                nextDayFinal.minute = 30
                nextDayFinal.timeZone = nyTimeZone
                return nyCalendar.date(from: nextDayFinal) ?? now
            }
        } else {
            // 시장 거래 중이면 15분 후 (CNN은 실시간 업데이트)
            return calendar.date(byAdding: .minute, value: 15, to: now) ?? now
        }
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
        
        if hours > 0 {
            return String(format: "%dh %02dm", hours, minutes)
        } else {
            return String(format: "%dm", minutes)
        }
    }
    
    var body: some View {
        GeometryReader { geo in
            let _ = geo.size.width
            let height = geo.size.height
            ZStack {
                // 배경
                Color.black.opacity(0.1).ignoresSafeArea()
                
                // 화면 어둡게 하는 오버레이
                if isScreenDimmed {
                    Color.black
                        .opacity(1.0 - screenBrightness)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                        .animation(.easeInOut(duration: 2.0), value: screenBrightness)
                }
                
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
                
                // 중앙 스코어 아래 변동 텍스트
                GeometryReader { innerGeo in
                    let minDim = min(innerGeo.size.width, innerGeo.size.height)
                    
                    Group {
                        if let delta = todayDelta {
                            let arrow: String = {
                                if delta > 0 { return "▲" }
                                else if delta < 0 { return "▼" }
                                else { return "＝" }
                            }()
                            
                            let pointText: String = {
                                if delta > 0 { return "\(abs(delta)) point" }
                                else if delta < 0 { return "\(abs(delta)) point" }
                                else { return "Same" }
                            }()
                            
                            // 마지막 변경 시간 가져오기
                            let timeText: String = {
                                if let lastChangeTime = VIXFetcher.shared.getLastChangeTime(for: selectedMarket) {
                                    return timeAgoString(from: lastChangeTime)
                                } else {
                                    return "(unknown)"
                                }
                            }()
                            
                            Text("\(arrow) \(pointText) \(timeText)")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(.black.opacity(0.7))
                                        .stroke(.gray.opacity(0.3), lineWidth: 0.5)
                                )
                                .position(x: innerGeo.size.width/2,
                                          y: innerGeo.size.height/2 + minDim * 0.15)
                        } else {
                            // 변동 데이터가 없을 때
                            Text("＝ Same as Yesterday")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(.black.opacity(0.7))
                                        .stroke(.gray.opacity(0.3), lineWidth: 0.5)
                                )
                                .position(x: innerGeo.size.width/2,
                                          y: innerGeo.size.height/2 + minDim * 0.15)
                        }
                    }
                }
                .allowsHitTesting(false)
                .zIndex(3)
                
                // 디버그 로그 오버레이 (상단 우측)
                if showDebug {
                    VStack(spacing: 6) {
                        Text(debugText)
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(6)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(.top, 12)
                    .padding(.trailing, 12)
                    .zIndex(300)
                    .allowsHitTesting(false)
                }
                
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
                        Text("STOCK FEAR & GREED: \(currentScore) (\(moodText(for: currentScore)))")
                            .font(.caption)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity, alignment: .center)
                        Text("NEXT UPDATE IN: \(timeLeftString)")
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
        .onTapGesture {
            // 터치 시 화면 밝기 복원 및 상호작용 시간 업데이트
            resetScreenBrightness()
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    resetScreenBrightness()
                }
        )
        .onAppear {
            // 현재 선택된 시장에 맞는 스코어 로드
            currentScore = VIXFetcher.shared.getScoreForMarket(selectedMarket)
            todayDelta = VIXFetcher.shared.getTodayTotalDelta(for: selectedMarket)
            
            // 첫 실행 이후로 설정
            if isFirstLaunch {
                isFirstLaunch = false
                hasInitializedBubbles = true
            }
            
            // 화면 꺼짐 타이머 시작
            startScreenDimTimer()
                
                // 디버깅 정보 출력
                print("🔍 디버깅 정보:")
                print(VIXFetcher.shared.debugStoredScores())
                print("[CNN] Config: \(CNNFearGreedFetcher.shared.debugConfigSummary())")
                print("[CNN] LastDiag: \(CNNFearGreedFetcher.shared.debugLastDiagnosticsSummary())")
                
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
                
                // 자동 새로고침 타이머 시작 (15분마다)
                startAutoRefreshTimer()
            }
            .onDisappear {
                // 타이머 정리
                stopAutoRefreshTimer()
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
                    // RapidAPI CNN 점수 우선 (보정 없이 그대로 사용)
                    if let cnnScore = try? await CNNFearGreedFetcher.shared.fetchCNNScore(forceRefresh: false) {
                        await MainActor.run {
                            let newScore = VIXFetcher.shared.updateScoreForMarketWithFallback(cnnScore, marketType: .stock)
                            currentScore = newScore
                            score = newScore
                            let userDefaults = UserDefaults(suiteName: "group.com.hyujang.feargreed")
                            userDefaults?.set(currentScore, forKey: "lastStockScore")
                            WidgetCenter.shared.reloadAllTimelines()
                            isLoading = false
                            lastCryptoUpdate = nil
                            let changesCount = VIXFetcher.shared.getDailyChanges(for: currentMarket).count
                            debugText = "CNN via RapidAPI (cache-ok): \(cnnScore)\n\(changesCount) updates today"
                            todayDelta = VIXFetcher.shared.getTodayTotalDelta(for: currentMarket)
                        }
                    } else if let cachedCNN = CNNFearGreedFetcher.shared.getCachedScore() {
                        await MainActor.run {
                            let newScore = VIXFetcher.shared.updateScoreForMarketWithFallback(cachedCNN, marketType: .stock)
                            currentScore = newScore
                            score = newScore
                            let userDefaults = UserDefaults(suiteName: "group.com.hyujang.feargreed")
                            userDefaults?.set(currentScore, forKey: "lastStockScore")
                            WidgetCenter.shared.reloadAllTimelines()
                            isLoading = false
                            lastCryptoUpdate = nil
                            let changesCount = VIXFetcher.shared.getDailyChanges(for: currentMarket).count
                            debugText = "CNN Cached only: \(cachedCNN)\n\(changesCount) updates today"
                            todayDelta = VIXFetcher.shared.getTodayTotalDelta(for: currentMarket)
                        }
                    } else {
                        if let local = try? await VIXFetcher.shared.fetchAndCalculateMarketSentiment() {
                            await MainActor.run {
                                let newScore = VIXFetcher.shared.updateScoreForMarketWithFallback(local.finalScore, marketType: .stock)
                                currentScore = newScore
                                score = newScore
                                
                                let userDefaults = UserDefaults(suiteName: "group.com.hyujang.feargreed")
                                userDefaults?.set(currentScore, forKey: "lastStockScore")
                                WidgetCenter.shared.reloadAllTimelines()
                                isLoading = false
                                lastCryptoUpdate = nil
                                let changesCount = VIXFetcher.shared.getDailyChanges(for: currentMarket).count
                                debugText = "Local compute: \(local.finalScore)\n\(changesCount) updates today"
                                todayDelta = VIXFetcher.shared.getTodayTotalDelta(for: currentMarket)
                            }
                        } else {
                            let sentiment = try await VIXFetcher.shared.fetchFromGithubDaily()
                            await MainActor.run {
                                // 폴백 시에도 보정 없이 원 점수 사용
                                let newScore = VIXFetcher.shared.updateScoreForMarketWithFallback(sentiment.finalScore, marketType: .stock)
                                currentScore = newScore
                                score = newScore
                                
                                let userDefaults = UserDefaults(suiteName: "group.com.hyujang.feargreed")
                                userDefaults?.set(currentScore, forKey: "lastStockScore")
                                WidgetCenter.shared.reloadAllTimelines()
                                isLoading = false
                                lastCryptoUpdate = nil
                                let summary = CNNFearGreedFetcher.shared.debugConfigSummary()
                                let diag = CNNFearGreedFetcher.shared.debugLastDiagnosticsSummary()
                                let changesCount = VIXFetcher.shared.getDailyChanges(for: currentMarket).count
                                debugText = "Fallback daily.json: final=\(sentiment.finalScore) -> calibrated=\(newScore)\n\(changesCount) updates today\nDiag: \(diag)\nCfg: \(summary)"
                                todayDelta = VIXFetcher.shared.getTodayTotalDelta(for: currentMarket)
                            }
                        }
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
                        let changesCount = VIXFetcher.shared.getDailyChanges(for: currentMarket).count
                        debugText = "Crypto via alternative.me FNG: \(value) (\(mood))\n\(changesCount) updates today"
                        todayDelta = VIXFetcher.shared.getTodayTotalDelta(for: currentMarket)
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
    
    // 점수에 따른 상태 텍스트 반환
    private func moodText(for score: Int) -> String {
        switch score {
        case 0..<25: return "Extreme Fear"
        case 25..<45: return "Fear"
        case 45..<55: return "Neutral"
        case 55..<75: return "Greed"
        default: return "Extreme Greed"
        }
    }
    
    private func fetchData() {
        // 로딩 시작 전에 현재 스코어를 백업
        let previousScore = self.score
        
        isLoading = true
        errorMessage = nil
        debugText = "Loading..."
        
        Task {
            do {
                if selectedMarket == .stock {
                    // 1) RapidAPI CNN 점수 캐시 우선 사용 (보정 없이 그대로 저장)
                    var fetchedCNN: Int? = try? await CNNFearGreedFetcher.shared.fetchCNNScore(forceRefresh: false)
                    if fetchedCNN == nil && CNNFearGreedFetcher.shared.getCachedScore() == nil {
                        // 최초 실행 등 캐시가 아예 없으면 1회 강제 갱신 시도
                        fetchedCNN = try? await CNNFearGreedFetcher.shared.fetchCNNScore(forceRefresh: true)
                    }
                    if let cnnScore = fetchedCNN ?? CNNFearGreedFetcher.shared.getCachedScore() {
                        await MainActor.run {
                            let newScore = VIXFetcher.shared.updateScoreForMarketWithFallback(cnnScore, marketType: .stock)
                            self.score = newScore
                            self.currentScore = newScore
                            let userDefaults = UserDefaults(suiteName: "group.com.hyujang.feargreed")
                            userDefaults?.set(self.score, forKey: "lastStockScore")
                            WidgetCenter.shared.reloadAllTimelines()
                            self.isLoading = false
                            self.cryptoMood = ""
                            let changesCount = VIXFetcher.shared.getDailyChanges(for: self.selectedMarket).count
                            self.debugText = "CNN via RapidAPI (fresh/cache): \(cnnScore)\n\(changesCount) updates today"
                            self.todayDelta = VIXFetcher.shared.getTodayTotalDelta(for: self.selectedMarket)
                        }
                    } else if let cachedCNN = CNNFearGreedFetcher.shared.getCachedScore() {
                        await MainActor.run {
                            let newScore = VIXFetcher.shared.updateScoreForMarketWithFallback(cachedCNN, marketType: .stock)
                            self.score = newScore
                            self.currentScore = newScore
                            let userDefaults = UserDefaults(suiteName: "group.com.hyujang.feargreed")
                            userDefaults?.set(self.score, forKey: "lastStockScore")
                            WidgetCenter.shared.reloadAllTimelines()
                            self.isLoading = false
                            self.cryptoMood = ""
                            let changesCount = VIXFetcher.shared.getDailyChanges(for: self.selectedMarket).count
                            self.debugText = "CNN Cached only: \(cachedCNN)\n\(changesCount) updates today"
                            self.todayDelta = VIXFetcher.shared.getTodayTotalDelta(for: self.selectedMarket)
                        }
                    } else {
                        // 2) 로컬 계산 시도 → 실패 시 중앙 JSON 폴백
                        if let local = try? await VIXFetcher.shared.fetchAndCalculateMarketSentiment() {
                            await MainActor.run {
                                let newScore = VIXFetcher.shared.updateScoreForMarketWithFallback(local.finalScore, marketType: .stock)
                                self.score = newScore
                                self.currentScore = newScore
                                let userDefaults = UserDefaults(suiteName: "group.com.hyujang.feargreed")
                                userDefaults?.set(self.score, forKey: "lastStockScore")
                                WidgetCenter.shared.reloadAllTimelines()
                                self.isLoading = false
                                self.cryptoMood = ""
                                let changesCount = VIXFetcher.shared.getDailyChanges(for: self.selectedMarket).count
                                self.debugText = "Local compute: \(local.finalScore)\n\(changesCount) updates today"
                                self.todayDelta = VIXFetcher.shared.getTodayTotalDelta(for: self.selectedMarket)
                            }
                        } else {
                            let sentiment = try await VIXFetcher.shared.fetchFromGithubDaily()
                            await MainActor.run {
                                let newScore = VIXFetcher.shared.updateScoreForMarketWithFallback(sentiment.finalScore, marketType: .stock)
                                self.score = newScore
                                self.currentScore = newScore
                                let userDefaults = UserDefaults(suiteName: "group.com.hyujang.feargreed")
                                userDefaults?.set(self.score, forKey: "lastStockScore")
                                WidgetCenter.shared.reloadAllTimelines()
                                self.isLoading = false
                                self.cryptoMood = ""
                                let summary = CNNFearGreedFetcher.shared.debugConfigSummary()
                                let diag = CNNFearGreedFetcher.shared.debugLastDiagnosticsSummary()
                                let changesCount = VIXFetcher.shared.getDailyChanges(for: self.selectedMarket).count
                                self.debugText = "Fallback daily.json: final=\(sentiment.finalScore) -> calibrated=\(newScore)\n\(changesCount) updates today\nDiag: \(diag)\nCfg: \(summary)"
                                self.todayDelta = VIXFetcher.shared.getTodayTotalDelta(for: self.selectedMarket)
                            }
                        }
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
                        let changesCount = VIXFetcher.shared.getDailyChanges(for: self.selectedMarket).count
                        self.debugText = "Crypto via alternative.me FNG: \(value) (\(mood))\n\(changesCount) updates today"
                        self.todayDelta = VIXFetcher.shared.getTodayTotalDelta(for: self.selectedMarket)
                    }
                }
            } catch {
                await MainActor.run {
                    // 에러 발생 시 이전 데이터 유지
                    self.score = previousScore
                    self.currentScore = VIXFetcher.shared.getLastValidScoreForMarket(self.selectedMarket)
                    let changesCount = VIXFetcher.shared.getDailyChanges(for: self.selectedMarket).count
                    self.errorMessage = "데이터를 가져오는데 실패했습니다: \(error.localizedDescription)\n\(changesCount) updates today"
                    self.isLoading = false
                    self.todayDelta = VIXFetcher.shared.getTodayTotalDelta(for: self.selectedMarket)
                    
                    // 에러 메시지를 잠시만 표시
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        self.errorMessage = nil
                    }
                }
            }
        }
    }
    
    // MARK: - 화면 밝기 관리 함수들
    
    private func resetScreenBrightness() {
        lastInteractionTime = Date()
        if isScreenDimmed {
            withAnimation(.easeInOut(duration: 0.5)) {
                screenBrightness = 1.0
                isScreenDimmed = false
            }
        }
    }
    
    private func startScreenDimTimer() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            let timeSinceLastInteraction = Date().timeIntervalSince(lastInteractionTime)
            
            if timeSinceLastInteraction >= screenOffTimeout {
                // 3분 후 화면 완전히 끄기
                if !isScreenDimmed || screenBrightness > 0.05 {
                    withAnimation(.easeInOut(duration: 3.0)) {
                        screenBrightness = 0.05
                        isScreenDimmed = true
                    }
                }
            } else if timeSinceLastInteraction >= dimTimeout {
                // 2분 후 화면 어둡게 하기
                if !isScreenDimmed || screenBrightness > 0.3 {
                    withAnimation(.easeInOut(duration: 2.0)) {
                        screenBrightness = 0.3
                        isScreenDimmed = true
                    }
                }
            }
        }
    }
    
    private func startAutoRefreshTimer() {
        // 기존 타이머가 있으면 정리
        autoRefreshTimer?.invalidate()
        
        // 15분마다 자동 새로고침
        autoRefreshTimer = Timer.scheduledTimer(withTimeInterval: 15 * 60, repeats: true) { _ in
            print("🔄 자동 새로고침 시작...")
            fetchData()
        }
    }
    
    private func stopAutoRefreshTimer() {
        autoRefreshTimer?.invalidate()
        autoRefreshTimer = nil
    }
}

#Preview {
    ContentView()
} 