## Fear & Greed Score CNN 스타일 계산 적용 PRD

### 목적
- CNN의 Fear & Greed Index와 유사한 계산 방식을 적용하여 더 정확하고 일관된 시장 심리 지표를 제공
- 앱이 외부 원본 API를 직접 호출하지 않고, 중앙에서 하루 1회 수집·가공한 결과(JSON)만 조회하도록 전환해 레이트 리밋과 불안정을 해소한다.

### 범위(Scope)
- 데이터 수집 파이프라인: GitHub Actions + Pages로 `docs/daily.json` 생성/배포
- 앱(`.stock`)의 데이터 소스: 중앙 JSON(`https://artsidea.github.io/FearGreedApp/daily.json`)
- 시장 전환 UX 안정화: 네트워크 성공 여부와 무관하게 전환 상태 유지
- 위젯은 현 시점 참고 항목(선택 사항)

### 아키텍처 개요
- 수집: GitHub Actions에서 매일 07:00 KST(= 22:00 UTC) 실행
- 가공: 7개 지표를 CNN 스타일 가중치로 환산 후 가중 평균해 최종 점수 생성
- 배포: `docs/daily.json`을 Pages로 정적 호스팅(캐시 600초)
- 소비: iOS 앱은 중앙 JSON만 1회 호출하여 화면 표시 및 로컬 캐시(UserDefaults)

### CNN 스타일 지표 및 가중치
1. **VIX (25% 가중치)**: 시장 공포의 주요 지표
   - 범위: 10-45, 낮을수록 탐욕
   - 계산: `(45 - capped_vix) / 35 * 100`

2. **S&P500 Momentum (20% 가중치)**: 125일 이동평균 대비 성과
   - 범위: -10% ~ +10%, 높을수록 탐욕
   - 계산: `((momentum + 0.1) / 0.2) * 100`

3. **Safe Haven Demand (15% 가중치)**: 주식 vs 채권 상대 성과 (3개월)
   - 범위: -20% ~ +20%, 주식 우위일수록 탐욕
   - 계산: `((relative_performance + 0.2) / 0.4) * 100`

4. **Put/Call Ratio (15% 가중치)**: 시장 심리
   - 범위: 0.7-1.2, 낮을수록 탐욕
   - 계산: `((1.2 - ratio) / 0.5) * 100`

5. **Junk Bond Demand (10% 가중치)**: 고수익 채권 스프레드
   - 범위: 2-8%, 낮을수록 탐욕
   - 계산: `((8 - spread) / 6) * 100`

6. **Market Breadth (10% 가중치)**: 52주 고저 대비 현재 위치
   - 범위: 0-100%, 높을수록 탐욕
   - 계산: `((current - low) / (high - low)) * 100`

7. **Market Volume (5% 가중치)**: 평균 대비 거래량
   - 범위: 0.5-2.0x, 낮을수록 탐욕
   - 계산: `(1 - ((volume_ratio - 0.5) / 1.5)) * 100`

### 데이터 소스(수집 스크립트)
- VIX: Yahoo Finance `^VIX` (1년 데이터)
- S&P500 6개월: Yahoo Finance `^GSPC` (125일 이동평균 및 현재가)
- Safe Haven: Yahoo Finance `^GSPC` vs `TLT` (3개월 상대 성과)
- Put/Call Ratio: Yahoo Finance `^CPC` (fallback: `^CPCE`)
- 정크본드 스프레드: FRED CSV `BAMLH0A0HYM2`
- S&P500 1년: Yahoo Finance `^GSPC` (52주 high/low)
- Market Volume: Yahoo Finance `^GSPC` (1개월 평균 대비)

### 점수 계산(CNN 스타일)
- **최종 점수**: 가중 평균 = `(vixScore * 0.25) + (momentumScore * 0.20) + (safeHavenScore * 0.15) + (putCallScore * 0.15) + (junkScore * 0.10) + (breadthScore * 0.10) + (volumeScore * 0.05)`

### 중앙 JSON 스키마 (업데이트됨)
```json
{
  "asOf": "YYYY-MM-DD",
  "metrics": {
    "vix": number,
    "currentSP": number,
    "ma125": number,
    "putCall": number,
    "junkSpread": number,
    "spHigh": number,
    "spLow": number
  },
  "scores": {
    "vixScore": number,
    "momentumScore": number,
    "safeHavenScore": number,
    "putCallScore": number,
    "junkScore": number,
    "breadthScore": number,
    "volumeScore": number,
    "finalScore": number
  }
}
```

### 배포/운영
- Pages URL: `https://artsidea.github.io/FearGreedApp/daily.json`
- 캐시: 600초(약 10분) → 최신 반영 확인 시 `?t=<timestamp>` 쿼리로 강제 갱신 가능
- GitHub 설정
  - Settings → Pages: Branch = `main`, Folder = `/docs`
  - Settings → Actions → Workflow permissions: Read & write
- 워크플로우: `.github/workflows/daily.yml`
  - 스케줄: `0 22 * * *` (KST 07:00)
  - 수동 실행 지원(workflow_dispatch)

### 앱 동작(주요 변경)
- `VIXFetcher.fetchFromGithubDaily()` 추가: 중앙 JSON 파싱 → `MarketSentimentScore` 반환
- `.stock` 경로는 항상 중앙 JSON을 사용(`ContentView_new.swift`)
- 시장 전환시(`onChange`) 네트워크 호출 전 `currentMarket`를 먼저 반영하여 전환 실패에도 UI 일관성 유지
- 로컬 캐시: `UserDefaults(suiteName: "group.com.hyujang.feargreed")`

### CNN과의 차이점 및 개선사항
- **가중치 적용**: CNN과 동일한 가중치 체계 적용
- **Safe Haven 지표**: 10Y 금리 대신 주식 vs 채권 상대 성과 사용
- **Market Volume 추가**: CNN의 7번째 지표인 거래량 지표 추가
- **스케일링 개선**: 극단값에서 과대평가 방지를 위한 캡핑 적용
- **퍼센타일 정규화**: 향후 히스토리 퍼센타일 기반 계산으로 개선 가능

### 오류 처리
- 중앙 JSON 호출 실패 시: 에러 메시지 표시, 이전 표시값 유지
- Pages 404/캐시 지연 시: 재시도(백오프) 또는 강제 새로고침 쿼리 사용

### 비기능 요구사항(NFR)
- 신뢰성: 수집 실패 시 워크플로 재시도(수동), 이후 앱은 마지막 성공 본문 사용 가능
- 성능: 앱은 단일 JSON 한 번 호출 → 빠른 로딩, 위젯도 동일 전략 권장
- 보안/프라이버시: 공개 지표만 사용, 개인 데이터 없음

### 테스트 체크리스트
- Pages URL 200 확인 및 JSON 스키마 유효성
- 앱 실행 시 `.stock` 로딩/표시 정상, 에러 시 메시지 노출
- 시장 전환(주식↔크립토) UI 자연스러움
- 캐시 만료 후 재호출 동작(약 10분 후)
- CNN 점수와의 비교 검증 (±10점 이내)

### 롤백 전략
- 필요 시 `fetchFromGithubDaily()` 대신 기존 직접 API 호출 경로로 임시 전환

### 향후 과제
- 크립토 지수도 중앙 수집으로 통일(레이트 리밋/속도 안정)
- 히스토리 퍼센타일 기반 계산으로 정확도 향상
- 7일 EMA 스무딩 적용으로 변동성 감소
- 모니터링: 워크플로 실패 알림 설정

### 수용 기준(Acceptance Criteria)
- Pages URL이 200으로 응답하고 앱 `.stock`에서 중앙 점수를 표시한다.
- 워크플로가 07:00 KST 이후 정상적으로 `docs/daily.json`을 갱신한다.
- 시장 전환 시 네트워크 실패에도 화면 전환 상태가 유지된다.
- CNN 점수와 ±10점 이내의 유사한 결과를 보여준다.


