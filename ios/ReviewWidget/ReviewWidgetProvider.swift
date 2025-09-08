import WidgetKit
import SwiftUI
import WaniKaniAPI
import Reachability

struct ReviewWidgetProvider: TimelineProvider {
    public typealias Entry = ReviewEntry

    func placeholder(in context: Context) -> ReviewEntry {
        ReviewEntry(date: Date(), subject: nil, assignment: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (ReviewEntry) -> ()) {
        let entry = ReviewEntry(date: Date(), subject: nil, assignment: nil)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let localCachingClient = self.localCachingClient()

        var entries: [ReviewEntry] = []
        let currentDate = Date()
        let assignments = localCachingClient.getAllAssignments().filter { $0.isReviewStage }

        if let assignment = assignments.randomElement(),
           let subject = localCachingClient.getSubject(id: assignment.subjectID) {
            let entry = ReviewEntry(date: currentDate, subject: subject, assignment: assignment)
            entries.append(entry)
        } else {
            let entry = ReviewEntry(date: currentDate, subject: nil, assignment: nil)
            entries.append(entry)
        }

        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }

    private func localCachingClient() -> LocalCachingClient {
        let sharedDefaults = UserDefaults(suiteName: "group.app.hanaso.tsurukame")!
        let apiToken = sharedDefaults.string(forKey: "userApiToken") ?? ""
        let client = WaniKaniAPIClient(apiToken: apiToken)
        let reachability = try! Reachability()

        let localCachingClient = LocalCachingClient(client: client, reachability: reachability)
        return localCachingClient
    }
}

struct ReviewEntry: TimelineEntry {
    public let date: Date
    public let subject: TKMSubject?
    public let assignment: TKMAssignment?
}
