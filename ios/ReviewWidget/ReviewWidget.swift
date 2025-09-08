import WidgetKit
import SwiftUI

@main
struct ReviewWidget: Widget {
    let kind: String = "ReviewWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ReviewWidgetProvider()) { entry in
            ReviewWidgetView(entry: entry)
        }
        .configurationDisplayName("WaniKani Review")
        .description("Displays a random review word.")
    }
}
