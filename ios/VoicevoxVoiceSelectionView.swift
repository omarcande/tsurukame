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

import AVFoundation
import SwiftUI

struct VoicevoxVoiceSelectionView: View {
  @AppStorage("SelectedVoicevoxStyle") private var selectedStyleRawValue: Int = VoicevoxStyle
    .zundamonTsundere.rawValue
  @State private var playingStyleID: Int? = nil
  @StateObject private var viewModel = VoicevoxVoiceSelectionViewModel()

  private let voicevox = VoicevoxClient()

  var body: some View {
    TabView {
      // Recommended tab
      List(VoicevoxStyle.allCases, id: \.self) { style in
        HStack {
          VStack(alignment: .leading) {
            Text(style.displayName)
            if style.rawValue == selectedStyleRawValue {
              Text("Selected")
                .font(.caption)
                .foregroundColor(.gray)
            }
          }
          Spacer()
          Button(action: {
            if playingStyleID == style.rawValue {
              voicevox.stopPlayback()
              playingStyleID = nil
            } else {
              playingStyleID = style.rawValue
              voicevox.speak(text: "この声が好きですか。", voiceStyle: style) { _ in
                playingStyleID = nil
              }
            }
          }) {
            Image(systemName: playingStyleID == style.rawValue ? "stop.fill" : "play.fill")
              .foregroundColor(.accentColor)
          }
          .buttonStyle(BorderlessButtonStyle())
        }
        .contentShape(Rectangle())
        .onTapGesture {
          selectedStyleRawValue = style.rawValue
        }
      }
      .tabItem {
        Text("Recommended")
      }

      // All tab
      List(viewModel.allStyles, id: \.id) { style in
        HStack {
          VStack(alignment: .leading) {
            Text(style.displayName)
            if style.id == selectedStyleRawValue {
              Text("Selected")
                .font(.caption)
                .foregroundColor(.gray)
            }
          }
          Spacer()
          Button(action: {
            if playingStyleID == style.id {
              voicevox.stopPlayback()
              playingStyleID = nil
            } else {
              playingStyleID = style.id
              voicevox.speak(text: "この声が好きですか。", voiceStyleId: style.id) { _ in
                playingStyleID = nil
              }
            }
          }) {
            Image(systemName: playingStyleID == style.id ? "stop.fill" : "play.fill")
              .foregroundColor(.accentColor)
          }
          .buttonStyle(BorderlessButtonStyle())
        }
        .contentShape(Rectangle())
        .onTapGesture {
          selectedStyleRawValue = style.id
        }
      }
      .tabItem {
        Text("All")
      }
    }
    .navigationTitle("Select Voice")
    .onAppear {
      viewModel.fetchSpeakers()
    }
  }
}

struct VoicevoxStyleModel: Codable, Identifiable {
  let name: String
  let id: Int

  var voicevoxStyle: VoicevoxStyle? {
    VoicevoxStyle(rawValue: id)
  }
}

struct VoicevoxSpeaker: Codable {
  let name: String
  let styles: [VoicevoxStyleModel]
}

struct VoicevoxRawStyle {
  let id: Int
  let displayName: String
}

class VoicevoxVoiceSelectionViewModel: ObservableObject {
  @Published var allStyles: [VoicevoxRawStyle] = []

  func fetchSpeakers() {
    guard let url = URL(string: "http://pop-os.local:50021/speakers") else { return }

    let task = URLSession.shared.dataTask(with: url) { data, _, error in
      guard let data = data, error == nil else { return }

      do {
        let decoded = try JSONDecoder().decode([VoicevoxSpeaker].self, from: data)
        var collectedStyles: [VoicevoxRawStyle] = []
        for speaker in decoded {
          for style in speaker.styles {
            let rawStyle = VoicevoxRawStyle(id: style.id,
                                            displayName: "\(speaker.name) - \(style.name)")
            collectedStyles.append(rawStyle)
          }
        }
        DispatchQueue.main.async {
          self.allStyles = collectedStyles
        }
      } catch {
        print("Failed to decode speakers:", error)
      }
    }
    task.resume()
  }
}
