//
//  FearGreedApp.swift
//  FearAndGreedScore
//
//  Created by hyujang on 5/11/25.
//

import SwiftUI
import UIKit
import WidgetKit
import BackgroundTasks

class AppDelegate: NSObject, UIApplicationDelegate {
    private let backgroundTaskIdentifier = "com.hyujang.feargreed.refresh"
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Info.plist에 아래 키를 추가하면 런타임에 설정됩니다.
        // - CNNRapidAPIHost (String)
        // - CNNRapidAPIKey (String)
        // - CNNRapidAPIURL (String)
        var configured = false
        if let host = Bundle.main.object(forInfoDictionaryKey: "CNNRapidAPIHost") as? String,
           let key = Bundle.main.object(forInfoDictionaryKey: "CNNRapidAPIKey") as? String,
           let url = Bundle.main.object(forInfoDictionaryKey: "CNNRapidAPIURL") as? String,
           !host.isEmpty, !key.isEmpty, !url.isEmpty {
            CNNFearGreedFetcher.shared.configure(host: host, key: key, urlString: url)
            configured = true
            print("[CNN] Configured from Info.plist")
        } else {
            // 대체: 스킴 환경변수에서 읽기 (Xcode > Scheme > Edit Scheme > Arguments)
            let env = ProcessInfo.processInfo.environment
            if let host = env["CNNRapidAPIHost"], let key = env["CNNRapidAPIKey"], let url = env["CNNRapidAPIURL"],
               !host.isEmpty, !key.isEmpty, !url.isEmpty {
                CNNFearGreedFetcher.shared.configure(host: host, key: key, urlString: url)
                configured = true
                print("[CNN] Configured from Environment Variables")
            }
        }
        if !configured { print("[CNN] Configuration missing. Using fallback daily.json.") }

        // 호출 최소 간격/히스토리 보관일 기본값 설정 (필요 시 조정)
        CNNFearGreedFetcher.shared.minRefreshInterval = 60 * 15 // 15분으로 단축
        CNNFearGreedFetcher.shared.maxHistoryDays = 60
        
        // 백그라운드 작업 등록
        BGTaskScheduler.shared.register(forTaskWithIdentifier: backgroundTaskIdentifier, using: nil) { task in
            self.handleAppRefresh(task: task as! BGAppRefreshTask)
        }
        
        return true
    }
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return .portrait
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        scheduleAppRefresh()
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        // 포어그라운드로 돌아올 때 위젯 즉시 새로고침
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    private func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: backgroundTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15분 후
        
        try? BGTaskScheduler.shared.submit(request)
    }
    
    private func handleAppRefresh(task: BGAppRefreshTask) {
        scheduleAppRefresh() // 다음 백그라운드 작업 예약
        
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        // 백그라운드에서 데이터 업데이트 및 위젯 새로고침
        Task {
            do {
                // CNN 데이터 가져오기
                if let marketScore = try? await CNNFearGreedFetcher.shared.fetchMarketScore() {
                    let userDefaults = UserDefaults(suiteName: "group.com.hyujang.feargreed")
                    userDefaults?.set(marketScore.finalScore, forKey: "lastStockScore")
                    
                    // 위젯 새로고침
                    WidgetCenter.shared.reloadAllTimelines()
                    print("📱 백그라운드에서 위젯 업데이트 완료: \(marketScore.finalScore)")
                }
                
                task.setTaskCompleted(success: true)
            } catch {
                print("❌ 백그라운드 업데이트 실패: \(error)")
                task.setTaskCompleted(success: false)
            }
        }
    }
}

@main
struct FearGreedApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
