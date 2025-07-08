//
//  FearGreedWidgetLiveActivity.swift
//  FearGreedWidget
//
//  Created by hyujang on 5/13/25.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct FearGreedWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct FearGreedWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FearGreedWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension FearGreedWidgetAttributes {
    fileprivate static var preview: FearGreedWidgetAttributes {
        FearGreedWidgetAttributes(name: "World")
    }
}

extension FearGreedWidgetAttributes.ContentState {
    fileprivate static var smiley: FearGreedWidgetAttributes.ContentState {
        FearGreedWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: FearGreedWidgetAttributes.ContentState {
         FearGreedWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: FearGreedWidgetAttributes.preview) {
   FearGreedWidgetLiveActivity()
} contentStates: {
    FearGreedWidgetAttributes.ContentState.smiley
    FearGreedWidgetAttributes.ContentState.starEyes
}
