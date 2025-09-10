import Foundation
import WaniKaniAPI
import Reachability
import WidgetKit

class ReviewWidgetDataUpdater {
    static let shared = ReviewWidgetDataUpdater()

    private let localCachingClient: LocalCachingClient

    private init() {
        let sharedDefaults = UserDefaults(suiteName: "group.app.hanaso.tsurukame")!
        let apiToken = sharedDefaults.string(forKey: "userApiToken") ?? ""
        let client = WaniKaniAPIClient(apiToken: apiToken)
        let reachability = try! Reachability()
        self.localCachingClient = LocalCachingClient(client: client, reachability: reachability)
    }

    func updateReviewItem() {
        let assignments = localCachingClient.getAllAssignments().filter { $0.isReviewStage }

        if let assignment = assignments.randomElement(),
           let subject = localCachingClient.getSubject(id: assignment.subjectID),
           let reading = subject.primaryReading?.reading,
           let meaning = subject.primaryMeaning?.meaning {
            let sharedReviewItem = SharedReviewItem(japanese: subject.japanese, reading: reading, meaning: meaning)
            save(sharedReviewItem)
        }
    }

    private func save(_ item: SharedReviewItem) {
        let sharedDefaults = UserDefaults(suiteName: "group.app.hanaso.tsurukame")!
        if let encoded = try? JSONEncoder().encode(item) {
            sharedDefaults.set(encoded, forKey: "sharedReviewItem")
            WidgetCenter.shared.reloadTimelines(ofKind: "ReviewWidget")
        }
    }
}

private extension TKMSubject {
    var primaryReading: TKMReading? {
        readings.first(where: { $0.isPrimary })
    }

    var primaryMeaning: TKMMeaning? {
        meanings.first(where: { $0.type == .primary })
    }
}
