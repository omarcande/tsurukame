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

import SwiftUI
import WidgetKit

struct ReviewWidgetProvider: TimelineProvider {
  public typealias Entry = ReviewEntry

  func placeholder(in _: Context) -> ReviewEntry {
    ReviewEntry(date: Date(), reviewItem: nil)
  }

  func getSnapshot(in _: Context, completion: @escaping (ReviewEntry) -> Void) {
    let entry = ReviewEntry(date: Date(), reviewItem: readReviewItem())
    completion(entry)
  }

  func getTimeline(in _: Context, completion: @escaping (Timeline<Entry>) -> Void) {
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
