# Fear & Greed Score App

## 📊 개요

Fear & Greed Score App은 CNN의 Fear & Greed Index를 참고하여 개발된 정교한 시장 심리 분석 애플리케이션입니다. **13개의 다양한 지표**를 활용하여 시장의 공포/탐욕 상태를 실시간으로 분석하고 시각화합니다.

## 🎯 주요 기능

### 📈 13개 정교한 지표
1. **VIX 점수** (20%) - 시장 변동성 지수
2. **모멘텀 점수** (15%) - S&P500 125일 이동평균 대비 성과
3. **안전자산 점수** (12%) - 주식 vs 채권 상대 성과
4. **Put/Call 비율** (10%) - 옵션 시장 투자자 심리
5. **정크본드 스프레드** (8%) - 위험 자산 선호도
6. **시장 폭** (8%) - S&P500 52주 고점/저점 대비 위치
7. **거래량** (5%) - 현재 거래량 vs 평균 거래량
8. **변동성 점수** (8%) - S&P500 20일 변동성
9. **상관관계 점수** (5%) - 주식, 금, 채권 간 상관관계
10. **감정 점수** (4%) - VIX와 Put/Call 비율 기반 시장 심리
11. **기술적 점수** (3%) - RSI, MACD 등 기술적 지표
12. **경제 점수** (1%) - 10년 국채 금리 기반 경제 상황
13. **글로벌 점수** (1%) - 미국, 유럽, 아시아 시장 상대 성과

### 🎨 사용자 인터페이스
- **실시간 업데이트**: 매일 오전 7시 자동 업데이트
- **상세 분석 뷰**: 13개 지표의 개별 점수와 설명
- **투자 권장사항**: 점수별 맞춤형 투자 조언
- **리스크 레벨**: 5단계 리스크 평가
- **시각적 개선**: 원형 차트, 진행률 바, 카드 형태 UI
- **위젯 지원**: iOS 위젯으로 빠른 확인

### 📱 지원 플랫폼
- **주식 시장**: S&P500 기반 Fear & Greed Index
- **암호화폐**: Crypto Fear & Greed Index

## 🚀 설치 및 실행

### 필수 요구사항
- iOS 15.0+
- Xcode 15.0+
- Swift 5.9+

### 설치 방법
1. 저장소 클론
```bash
git clone https://github.com/yourusername/FearGreedApp.git
cd FearGreedApp
```

2. Xcode에서 프로젝트 열기
```bash
open "Feer & Greed Score.xcodeproj"
```

3. 빌드 및 실행
- Xcode에서 `Cmd + R`로 시뮬레이터 실행
- 또는 실제 기기에 배포

### Python 스크립트 실행 (daily.json 업데이트)
```bash
# 의존성 설치
pip install -r requirements.txt

# daily.json 업데이트
python update_daily.py
```

## 📊 데이터 구조

### daily.json 예시
```json
{
  "asOf": "2025-08-08",
  "metrics": {
    "vix": 15.72,
    "currentSP": 6388.23,
    "ma125": 5885.97,
    "bond10Y": 4.0,
    "putCall": 0.95,
    "junkSpread": 2.95,
    "spHigh": 6389.77,
    "spLow": 4982.77,
    "usdDxy": 103,
    "volatility": 0.12,
    "correlation": 0.35,
    "sentiment": 0.65,
    "technical": 0.72,
    "economic": 0.75,
    "global": 0.68
  },
  "scores": {
    "vixScore": 84,
    "momentumScore": 93,
    "safeHavenScore": 81,
    "putCallScore": 50,
    "junkScore": 84,
    "breadthScore": 100,
    "volumeScore": 100,
    "volatilityScore": 73,
    "correlationScore": 65,
    "sentimentScore": 65,
    "technicalScore": 72,
    "economicScore": 75,
    "globalScore": 68,
    "finalScore": 79
  }
}
```

## 🔧 기술 스택

### Frontend
- **SwiftUI**: 모던 iOS UI 프레임워크
- **Core Motion**: 기기 모션 감지
- **WidgetKit**: iOS 위젯 지원

### Backend
- **Yahoo Finance API**: 실시간 시장 데이터
- **CBOE API**: Put/Call 비율 데이터
- **FRED API**: 경제 지표 데이터

### Data Processing
- **Python**: 데이터 수집 및 처리
- **Pandas**: 데이터 분석
- **NumPy**: 수치 계산

## 📈 점수 해석

### Fear & Greed 레벨
- **0-25**: 극도의 공포 (Extreme Fear)
- **25-45**: 공포 (Fear)
- **45-55**: 중립 (Neutral)
- **55-75**: 탐욕 (Greed)
- **75-100**: 극도의 탐욕 (Extreme Greed)

### 리스크 레벨
- **매우 낮음**: 반등 가능성이 높음
- **낮음**: 점진적인 매수 기회
- **보통**: 균형잡힌 접근 필요
- **높음**: 주의가 필요
- **매우 높음**: 매우 신중한 접근 필요

## 🤝 기여하기

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 라이선스

이 프로젝트는 MIT 라이선스 하에 배포됩니다. 자세한 내용은 `LICENSE` 파일을 참조하세요.

## 📞 연락처

프로젝트 링크: [https://github.com/yourusername/FearGreedApp](https://github.com/yourusername/FearGreedApp)

## 🙏 감사의 말

- CNN Fear & Greed Index 참고
- Yahoo Finance API 제공
- SwiftUI 커뮤니티 지원
