//
//  PortfolioWidgetLiveActivity.swift
//  PortfolioWidget
//
//  Created by Aymeric Grassart on 2/9/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct PortfolioWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct PortfolioWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PortfolioWidgetAttributes.self) { context in
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

extension PortfolioWidgetAttributes {
    fileprivate static var preview: PortfolioWidgetAttributes {
        PortfolioWidgetAttributes(name: "World")
    }
}

extension PortfolioWidgetAttributes.ContentState {
    fileprivate static var smiley: PortfolioWidgetAttributes.ContentState {
        PortfolioWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: PortfolioWidgetAttributes.ContentState {
         PortfolioWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: PortfolioWidgetAttributes.preview) {
   PortfolioWidgetLiveActivity()
} contentStates: {
    PortfolioWidgetAttributes.ContentState.smiley
    PortfolioWidgetAttributes.ContentState.starEyes
}
