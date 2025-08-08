#!/usr/bin/env python3
"""
Daily Fear & Greed Index 업데이트 스크립트
13개 지표를 포함한 정교한 분석 시스템
"""

import json
import requests
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import yfinance as yf

def fetch_vix():
    """VIX 지수 가져오기"""
    try:
        vix = yf.download('^VIX', period='1d', progress=False)
        return vix['Close'].iloc[-1] if not vix.empty else 20.0
    except:
        return 20.0

def fetch_sp500():
    """S&P500 데이터 가져오기"""
    try:
        sp500 = yf.download('^GSPC', period='6mo', progress=False)
        return sp500
    except:
        return pd.DataFrame()

def fetch_bond10y():
    """10년 국채 금리 가져오기"""
    try:
        bond = yf.download('^TNX', period='1mo', progress=False)
        return bond['Close'].iloc[-1] if not bond.empty else 4.0
    except:
        return 4.0

def fetch_put_call_ratio():
    """Put/Call 비율 (CBOE) - 실제로는 CBOE API 필요"""
    # 실제 구현에서는 CBOE API를 사용해야 함
    return 0.95

def fetch_junk_bond_spread():
    """정크본드 스프레드 (FRED API 필요)"""
    # 실제 구현에서는 FRED API를 사용해야 함
    return 3.5

def calculate_momentum_score(prices):
    """모멘텀 점수 계산"""
    if len(prices) < 125:
        return 50
    
    current = prices.iloc[-1]
    ma125 = prices.tail(125).mean()
    momentum = (current - ma125) / ma125
    
    # CNN-style: momentum -0.1 to +0.1 range
    momentum_capped = np.clip(momentum, -0.1, 0.1)
    score = int(((momentum_capped + 0.1) / 0.2) * 100)
    return max(0, min(100, score))

def calculate_vix_score(vix):
    """VIX 점수 계산"""
    capped = np.clip(vix, 10, 45)
    normalized = (45 - capped) / (45 - 10)
    return int(normalized * 100)

def calculate_volatility_score(prices):
    """변동성 점수 계산"""
    if len(prices) < 20:
        return 50
    
    returns = prices.pct_change().dropna()
    volatility = returns.std() * np.sqrt(252)
    
    # CNN-style: 10%-40% range, lower = more greed
    volatility_capped = np.clip(volatility, 0.1, 0.4)
    score = int((1 - ((volatility_capped - 0.1) / 0.3)) * 100)
    return max(0, min(100, score))

def calculate_correlation_score():
    """상관관계 점수 계산"""
    try:
        # S&P500, Gold, Bonds 데이터 가져오기
        sp500 = yf.download('^GSPC', period='1mo', progress=False)
        gold = yf.download('GC=F', period='1mo', progress=False)
        bonds = yf.download('^TNX', period='1mo', progress=False)
        
        if sp500.empty or gold.empty or bonds.empty:
            return 50
        
        # 수익률 계산
        sp_returns = sp500['Close'].pct_change().dropna()
        gold_returns = gold['Close'].pct_change().dropna()
        bond_returns = bonds['Close'].pct_change().dropna()
        
        # 상관관계 계산
        min_len = min(len(sp_returns), len(gold_returns), len(bond_returns))
        if min_len < 10:
            return 50
        
        sp_corr_gold = sp_returns.tail(min_len).corr(gold_returns.tail(min_len))
        sp_corr_bonds = sp_returns.tail(min_len).corr(bond_returns.tail(min_len))
        
        avg_correlation = (sp_corr_gold + sp_corr_bonds) / 2
        score = int((1 - avg_correlation) * 100)
        return max(0, min(100, score))
    except:
        return 50

def calculate_sentiment_score(vix, put_call):
    """감정 점수 계산"""
    vix_component = max(0, min(100, int((45 - vix) / 35 * 100)))
    put_call_component = max(0, min(100, int((1.2 - put_call) / 0.5 * 100)))
    return (vix_component + put_call_component) // 2

def calculate_technical_score(prices):
    """기술적 점수 계산 (RSI + MACD)"""
    if len(prices) < 26:
        return 50
    
    # RSI 계산
    delta = prices.diff()
    gain = (delta.where(delta > 0, 0)).rolling(window=14).mean()
    loss = (-delta.where(delta < 0, 0)).rolling(window=14).mean()
    rs = gain / loss
    rsi = 100 - (100 / (1 + rs))
    rsi_value = rsi.iloc[-1]
    
    # MACD 계산
    ema12 = prices.ewm(span=12).mean()
    ema26 = prices.ewm(span=26).mean()
    macd = ema12 - ema26
    macd_value = macd.iloc[-1]
    
    # 점수 계산
    rsi_score = 100 if rsi_value > 70 else 0 if rsi_value < 30 else int((rsi_value - 30) / 40 * 100)
    macd_score = 100 if macd_value > 0 else 0
    
    return (rsi_score + macd_score) // 2

def calculate_economic_score(bond10y):
    """경제 점수 계산"""
    score = int(np.clip((bond10y - 1) / 4 * 100, 0, 100))
    return score

def calculate_global_score():
    """글로벌 점수 계산"""
    try:
        # 미국, 유럽, 아시아 시장 데이터
        us = yf.download('^GSPC', period='1mo', progress=False)
        eu = yf.download('^STOXX50E', period='1mo', progress=False)
        asia = yf.download('^N225', period='1mo', progress=False)
        
        if us.empty or eu.empty or asia.empty:
            return 50
        
        us_return = (us['Close'].iloc[-1] - us['Close'].iloc[0]) / us['Close'].iloc[0]
        eu_return = (eu['Close'].iloc[-1] - eu['Close'].iloc[0]) / eu['Close'].iloc[0]
        asia_return = (asia['Close'].iloc[-1] - asia['Close'].iloc[0]) / asia['Close'].iloc[0]
        
        avg_global_return = (us_return + eu_return + asia_return) / 3
        score = int(((avg_global_return + 0.1) / 0.2) * 100)
        return max(0, min(100, score))
    except:
        return 50

def calculate_safe_haven_score():
    """안전자산 점수 계산"""
    try:
        sp3m = yf.download('^GSPC', period='3mo', progress=False)
        tlt3m = yf.download('TLT', period='3mo', progress=False)
        
        if sp3m.empty or tlt3m.empty:
            return 50
        
        sp_return = (sp3m['Close'].iloc[-1] - sp3m['Close'].iloc[0]) / sp3m['Close'].iloc[0]
        tlt_return = (tlt3m['Close'].iloc[-1] - tlt3m['Close'].iloc[0]) / tlt3m['Close'].iloc[0]
        
        relative_performance = sp_return - tlt_return
        performance_capped = np.clip(relative_performance, -0.2, 0.2)
        score = int(((performance_capped + 0.2) / 0.4) * 100)
        return max(0, min(100, score))
    except:
        return 50

def calculate_volume_score():
    """거래량 점수 계산"""
    try:
        sp500 = yf.download('^GSPC', period='1mo', progress=False)
        if sp500.empty:
            return 50
        
        current_volume = sp500['Volume'].iloc[-1]
        avg_volume = sp500['Volume'].mean()
        volume_ratio = current_volume / avg_volume
        
        volume_capped = np.clip(volume_ratio, 0.5, 2.0)
        score = int((1 - ((volume_capped - 0.5) / 1.5)) * 100)
        return max(0, min(100, score))
    except:
        return 50

def calculate_breadth_score(current, high, low):
    """시장 폭 점수 계산"""
    if high <= low:
        return 50
    
    normalized = (current - low) / (high - low)
    return int(normalized * 100)

def calculate_put_call_score(ratio):
    """Put/Call 점수 계산"""
    capped = np.clip(ratio, 0.7, 1.2)
    normalized = (1.2 - capped) / (1.2 - 0.7)
    return int(normalized * 100)

def calculate_junk_score(spread):
    """정크본드 점수 계산"""
    capped = np.clip(spread, 2, 8)
    normalized = (8 - capped) / (8 - 2)
    return int(normalized * 100)

def main():
    """메인 함수"""
    print("Fear & Greed Index 업데이트 중...")
    
    # 데이터 가져오기
    vix = fetch_vix()
    sp500_data = fetch_sp500()
    bond10y = fetch_bond10y()
    put_call = fetch_put_call_ratio()
    junk_spread = fetch_junk_bond_spread()
    
    if sp500_data.empty:
        print("S&P500 데이터를 가져올 수 없습니다.")
        return
    
    current_sp = sp500_data['Close'].iloc[-1]
    ma125 = sp500_data['Close'].tail(125).mean()
    sp_high = sp500_data['High'].max()
    sp_low = sp500_data['Low'].min()
    
    # 점수 계산
    vix_score = calculate_vix_score(vix)
    momentum_score = calculate_momentum_score(sp500_data['Close'])
    safe_haven_score = calculate_safe_haven_score()
    put_call_score = calculate_put_call_score(put_call)
    junk_score = calculate_junk_score(junk_spread)
    breadth_score = calculate_breadth_score(current_sp, sp_high, sp_low)
    volume_score = calculate_volume_score()
    volatility_score = calculate_volatility_score(sp500_data['Close'])
    correlation_score = calculate_correlation_score()
    sentiment_score = calculate_sentiment_score(vix, put_call)
    technical_score = calculate_technical_score(sp500_data['Close'])
    economic_score = calculate_economic_score(bond10y)
    global_score = calculate_global_score()
    
    # 최종 점수 계산 (가중 평균)
    final_score = int(round(
        vix_score * 0.20 +
        momentum_score * 0.15 +
        safe_haven_score * 0.12 +
        put_call_score * 0.10 +
        junk_score * 0.08 +
        breadth_score * 0.08 +
        volume_score * 0.05 +
        volatility_score * 0.08 +
        correlation_score * 0.05 +
        sentiment_score * 0.04 +
        technical_score * 0.03 +
        economic_score * 0.01 +
        global_score * 0.01
    ))
    
    # JSON 데이터 생성
    daily_data = {
        "asOf": datetime.now().strftime("%Y-%m-%d"),
        "metrics": {
            "vix": vix,
            "currentSP": current_sp,
            "ma125": ma125,
            "bond10Y": bond10y,
            "putCall": put_call,
            "junkSpread": junk_spread,
            "spHigh": sp_high,
            "spLow": sp_low,
            "usdDxy": 103,  # 실제로는 USD DXY 데이터 필요
            "volatility": sp500_data['Close'].pct_change().std() * np.sqrt(252),
            "correlation": 0.35,  # 실제 계산 필요
            "sentiment": sentiment_score / 100,
            "technical": technical_score / 100,
            "economic": economic_score / 100,
            "global": global_score / 100
        },
        "scores": {
            "vixScore": vix_score,
            "momentumScore": momentum_score,
            "safeHavenScore": safe_haven_score,
            "putCallScore": put_call_score,
            "junkScore": junk_score,
            "breadthScore": breadth_score,
            "volumeScore": volume_score,
            "volatilityScore": volatility_score,
            "correlationScore": correlation_score,
            "sentimentScore": sentiment_score,
            "technicalScore": technical_score,
            "economicScore": economic_score,
            "globalScore": global_score,
            "finalScore": final_score
        }
    }
    
    # JSON 파일 저장
    with open('docs/daily.json', 'w', encoding='utf-8') as f:
        json.dump(daily_data, f, indent=2, ensure_ascii=False)
    
    print(f"업데이트 완료! 최종 점수: {final_score}")
    print(f"파일 저장됨: docs/daily.json")

if __name__ == "__main__":
    main()
