// Copyright 2026 Omar Candelaria
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

import SwiftUI
import WidgetKit

struct ReviewWidgetProvider: TimelineProvider {
  public typealias Entry = ReviewEntry

  // The placeholder is for the widget gallery. It should be clear, not blurred.
  func placeholder(in _: Context) -> ReviewEntry {
    // Create a sample item to show in the gallery
    let sampleItem = SharedReviewItem(id: 1, japanese: "日本語", reading: "にほんご",
                                      meaning: "Japanese language", type: "Vocabulary")
    return ReviewEntry(date: Date(), reviewItem: sampleItem, isBlurred: false)
  }

  // The snapshot is for a single, quick preview. It should also be clear.
  func getSnapshot(in _: Context, completion: @escaping (ReviewEntry) -> Void) {
    let entry = ReviewEntry(date: Date(), reviewItem: readReviewItems().randomElement(),
                            isBlurred: false)
    completion(entry)
  }

  // The timeline is where the animation sequence is created.
  func getTimeline(in _: Context, completion: @escaping (Timeline<Entry>) -> Void) {
    let currentDate = Date()
    let reviewItem = readReviewItems().randomElement()

    // 1. First entry is NOW and is BLURRED.
    let blurredEntry = ReviewEntry(date: currentDate, reviewItem: reviewItem, isBlurred: true)

    // 2. Second entry is 10 seconds LATER and is NOT blurred.
    let revealDate = Calendar.current.date(byAdding: .second, value: 10, to: currentDate)!
    let revealedEntry = ReviewEntry(date: revealDate, reviewItem: reviewItem, isBlurred: false)

    let entries = [blurredEntry, revealedEntry]
    let timeline = Timeline(entries: entries, policy: .atEnd)
    completion(timeline)
  }

  private func readReviewItems() -> [SharedReviewItem] {
    let sharedDefaults = UserDefaults(suiteName: "group.app.yomou.tsurukame")!
    if let data = sharedDefaults.data(forKey: "sharedReviewItems") {
      return (try? JSONDecoder().decode([SharedReviewItem].self, from: data)) ?? []
    }
    return []
  }
}

struct ReviewEntry: TimelineEntry {
  public let date: Date
  public let reviewItem: SharedReviewItem?
  public let isBlurred: Bool
}
