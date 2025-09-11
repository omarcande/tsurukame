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

struct ReviewWidgetView: View {
  var entry: ReviewWidgetProvider.Entry
  @Environment(\.colorScheme) var colorScheme

  private func AdaptiveColor(light: Color, dark _: Color) -> Color {
    @Environment(\.colorScheme) var colorScheme
//    if self.colorScheme == .dark {
//      return dark
//    }
    return light
  }

  private func AdaptiveColorHex(light: Int32, dark: Int32) -> Color {
    AdaptiveColor(light: UIColorFromHex(light), dark: UIColorFromHex(dark))
  }

  private func UIColorFromHex(_ hexColor: Int32) -> Color {
    let red = CGFloat((hexColor & 0xFF0000) >> 16) / 255
    let green = CGFloat((hexColor & 0x00FF00) >> 8) / 255
    let blue = CGFloat(hexColor & 0x0000FF) / 255
    return Color(red: red, green: green, blue: blue)
  }

  var body: some View {
    let radicalColor1 = AdaptiveColorHex(light: 0x00AAFF, dark: 0x006090)
    let radicalColor2 = AdaptiveColorHex(light: 0x0093DD, dark: 0x005080)
    let kanjiColor1 = AdaptiveColorHex(light: 0xFF00AA, dark: 0x940060)
    let kanjiColor2 = AdaptiveColorHex(light: 0xDD0093, dark: 0x800050)
    let vocabularyColor1 = AdaptiveColorHex(light: 0xAA00FF, dark: 0x6100AA)
    let vocabularyColor2 = AdaptiveColorHex(light: 0x9300DD, dark: 0x530080)

    let radicalGradient = [radicalColor1, radicalColor2]
    let kanjiGradient = [kanjiColor1, kanjiColor2]
    let vocabularyGradient = [vocabularyColor1, vocabularyColor2]

      let darkGradient = [Color(red: 60 / 255, green: 60 / 255, blue: 75 / 255), Color(red: 28 / 255, green: 28 / 255, blue: 30 / 255)]

    let gradient = switch entry.reviewItem?.type {
    case "Radical":
      radicalGradient
    case "Kanji":
      kanjiGradient
    case "Vocabulary":
      vocabularyGradient
    default:
      vocabularyGradient
    }

    let textColor = self.colorScheme == .dark ? gradient[0] : Color.white

    VStack(alignment: .leading, spacing: 2) {
      if let item = entry.reviewItem {
        Text(item.japanese)
          .font(.largeTitle)
          .foregroundColor(textColor)

        Group {
          Text(item.reading)
            .font(.title2)
            .foregroundColor(textColor.opacity(0.8))

          Text(item.meaning)
            .font(.body)
            .foregroundColor(textColor)
            .lineLimit(2)
            .multilineTextAlignment(.leading)
        }.blur(radius: entry.isBlurred ? 4 : 0)
      } else {
        Text("No review available.")
          .foregroundColor(textColor)
      }
    }
    // .padding()
    .containerBackground(for: .widget) {
      LinearGradient(gradient: Gradient(colors: self
                       .colorScheme == .dark ? darkGradient : gradient),
      startPoint: .top,
                     endPoint: .bottomTrailing)
    }
  }
}

struct ReviewWidgetView_Previews: PreviewProvider {
  static var previews: some View {
    let reviewItem: SharedReviewItem = .init(id: 123, japanese: "今", reading: "いま",
                                             meaning: "now this has a longer meaning",
                                             type: "Vocabulary")

    let entry: ReviewWidgetProvider.Entry = .init(date: Date(), reviewItem: reviewItem,
                                                  isBlurred: false)
    ReviewWidgetView(entry: entry).previewContext(WidgetPreviewContext(family: .systemSmall))
  }
}
