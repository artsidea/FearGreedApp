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

struct ContentView: View {
    @State private var score: Int = 66
    @State private var vixValue: Double = 0
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var lastRefresh: Date? = nil
    @State private var now: Date = Date()
    @State private var originalScore: Int? = nil
    @State private var phase: CGFloat = 0
    @State private var time: CGFloat = 0
    @State private var scoreRect: CGRect = .zero
    @ObservedObject private var motion = MotionManager.shared
    
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
            let width = geo.size.width
            let height = geo.size.height
            ZStack(alignment: .bottom) {
                Color.black.opacity(0.1).ignoresSafeArea().zIndex(0)
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
                LiquidView(score: score, color: scoreColor)
                    .zIndex(2)
                // 중앙 점수
                ShadowText(
                    text: "\(score)",
                    size: min(width, height) * 0.44,
                    weight: .ultraLight
                )
                .position(x: width/2 + CGFloat(motion.gravity.x) * 40, y: height/2)
                .zIndex(2)
                // 하단 안내 (카운트다운 + 업데이트 시각)
                VStack {
                    Spacer()
                    Text("NEXT UPDATE IN: \(timeLeftString) (\(nextVIXUpdate.formatted(date: .omitted, time: .shortened)))")
                        .font(.caption)
                        .foregroundColor(.black)
                        .padding(.bottom, height * 0.04)
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
            }
            .onTapGesture {
                if let original = originalScore {
                    score = original
                }
            }
            .onAppear {
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
    
    private func fetchData() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let vix = try await VIXFetcher.shared.fetchVIX()
                await MainActor.run {
                    self.vixValue = vix
                    self.score = VIXScoreCalculator.vixToScore(vix: vix)
                    self.originalScore = VIXScoreCalculator.vixToScore(vix: vix)
                    self.isLoading = false
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