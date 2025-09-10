// Copyright 2025 David Sansome
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import Reachability
import WaniKaniAPI
import WidgetKit

class ReviewWidgetDataUpdater {
  static let shared = ReviewWidgetDataUpdater()

  private let localCachingClient: LocalCachingClient

  private init() {
    let sharedDefaults = UserDefaults(suiteName: "group.app.hanaso.tsurukame")!
    let apiToken = sharedDefaults.string(forKey: "userApiToken") ?? ""
    let client = WaniKaniAPIClient(apiToken: apiToken)
    let reachability = try! Reachability()
    localCachingClient = LocalCachingClient(client: client, reachability: reachability)
  }

  func updateReviewItem() {
    let assignments = localCachingClient.getAllAssignments().filter { $0.isReviewStage }

    if let assignment = assignments.randomElement(),
       let subject = localCachingClient.getSubject(id: assignment.subjectID),
       let reading = subject.primaryReading?.reading,
       let meaning = subject.primaryMeaning?.meaning {
      let sharedReviewItem = SharedReviewItem(id: subject.id, japanese: subject.japanese,
                                              reading: reading,
                                              meaning: meaning,
                                              type: subject.subjectType.description)
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
