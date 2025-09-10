import WidgetKit
import SwiftUI

struct ReviewWidgetProvider: TimelineProvider {
    public typealias Entry = ReviewEntry

    func placeholder(in context: Context) -> ReviewEntry {
        ReviewEntry(date: Date(), reviewItem: nil)
    }

    func getSnapshot(in context:Context, completion: @escaping (ReviewEntry) -> ()) {
        let entry = ReviewEntry(date: Date(), reviewItem: readReviewItem())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        var entries: [ReviewEntry] = []
        let currentDate = Date()
        let entry = ReviewEntry(date: currentDate, reviewItem: readReviewItem())
        entries.append(entry)

        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }

    private func readReviewItem() -> SharedReviewItem? {
        let sharedDefaults = UserDefaults(suiteName: "group.app.hanaso.tsurukame")!
        if let data = sharedDefaults.data(forKey: "sharedReviewItem") {
            return try? JSONDecoder().decode(SharedReviewItem.self, from: data)
        }
        return nil
    }
}

struct ReviewEntry: TimelineEntry {
    public let date: Date
    public let reviewItem: SharedReviewItem?
}
