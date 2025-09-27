//
//  FearGreedWidgetBundle.swift
//  FearGreedWidget
//
//  Created by hyujang on 5/13/25.
//

import WidgetKit
import SwiftUI

@main
struct FearGreedWidgetBundle: WidgetBundle {
    var body: some Widget {
        FearGreedWidget()
    }
}

struct FearGreedWidget: Widget {
    let kind: String = "FearGreedWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            FearGreedWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Fear & Greed Score")
        .description("Today's market mood based on VIX or Crypto")
        .supportedFamilies([.systemSmall])
    }
}
