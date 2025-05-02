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

import AVFoundation
import Foundation

enum VoicevoxStyle: Int, CaseIterable {
  case metanNormal = 2
  case metanWhisper = 36
  case zundamonTsundere = 7
  case tsumugi = 8
  case hau = 10
  case ritsuQueen = 65
  case takemitsuJoy = 39
  case kotaroNervous = 33
  case ryuseiPassion = 81
  case ryuseiGentle = 84
  case soraSexy = 17
  case mochikoCrying = 77
  case culSad = 25
  case no7Announce = 30
  case nurseRoboHorror = 49
  case hanamaruWhisper = 71
  case zonkoStream = 93

  var displayName: String {
    switch self {
    case .metanNormal: return "四国めたん - ノーマル"
    case .metanWhisper: return "四国めたん - ささやき"
    case .zundamonTsundere: return "ずんだもん - ツンツン"
    case .tsumugi: return "春日部つむぎ - ノーマル"
    case .hau: return "雨晴はう - ノーマル"
    case .ritsuQueen: return "波音リツ - クイーン"
    case .takemitsuJoy: return "玄野武宏 - 喜び"
    case .kotaroNervous: return "白上虎太郎 - びくびく"
    case .ryuseiPassion: return "青山龍星 - 熱血"
    case .ryuseiGentle: return "青山龍星 - しっとり"
    case .soraSexy: return "九州そら - セクシー"
    case .mochikoCrying: return "もち子さん - 泣き"
    case .culSad: return "WhiteCUL - かなしい"
    case .no7Announce: return "No.7 - アナウンス"
    case .nurseRoboHorror: return "ナースロボT - 恐怖"
    case .hanamaruWhisper: return "満別花丸 - ささやき"
    case .zonkoStream: return "ぞん子 - 実況風"
    }
  }

  static func from(id: Int) -> VoicevoxStyle? {
    allCases.first(where: { $0.rawValue == id })
  }

  static func random() -> VoicevoxStyle {
    allCases.randomElement()!
  }
}

protocol VoicevoxClientDelegate: AnyObject {
  func voicevoxClientDidStartFetching()
  func voicevoxClientDidStartPlaying()
  func voicevoxClientDidFinishPlaying()
}

class VoicevoxClient: NSObject {
  let baseURL = URL(string: "http://pop-os.local:50021")!
  var audioPlayer: AVAudioPlayer?
  weak var delegate: VoicevoxClientDelegate?

  func speak(text: String, voiceStyle: VoicevoxStyle = VoicevoxStyle.random(),
             completion: @escaping (Error?) -> Void) {
    delegate?.voicevoxClientDidStartFetching()
    let speakerID = voiceStyle.rawValue
    // 1. Create /audio_query request
    var queryURL = baseURL.appendingPathComponent("audio_query")
    queryURL =
      URL(string: "\(queryURL)?text=\(text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&speaker=\(speakerID)")!

    var queryRequest = URLRequest(url: queryURL)
    queryRequest.httpMethod = "POST"
    queryRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

    // 2. Call /audio_query
    URLSession.shared.dataTask(with: queryRequest) { data, _, error in
      guard let data = data, error == nil else {
        print("Audio query failed:", error ?? "Unknown error")
        completion(error ?? NSError(domain: "VoicevoxClient", code: -1, userInfo: nil))
        return
      }

      // 3. Create /synthesis request
      var synthURL = self.baseURL.appendingPathComponent("synthesis")
      synthURL = URL(string: "\(synthURL)?speaker=\(speakerID)")!

      var synthRequest = URLRequest(url: synthURL)
      synthRequest.httpMethod = "POST"
      synthRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
      synthRequest.httpBody = data // reuse audio_query JSON

      // 4. Call /synthesis
      URLSession.shared.dataTask(with: synthRequest) { audioData, _, error in
        guard let audioData = audioData, error == nil else {
          print("Synthesis failed:", error ?? "Unknown error")
          completion(error ?? NSError(domain: "VoicevoxClient", code: -2, userInfo: nil))
          return
        }

        // 5. Save to temporary file
        let tempURL = FileManager.default.temporaryDirectory
          .appendingPathComponent("voicevox_output.wav")
        do {
          try audioData.write(to: tempURL)

          // 6. Play with AVAudioPlayer
          DispatchQueue.main.async {
            do {
              self.audioPlayer = try AVAudioPlayer(contentsOf: tempURL)
              self.audioPlayer?.delegate = self
              self.audioPlayer?.prepareToPlay()
              self.audioPlayer?.play()
              print("🎧 Playing: \(text)")
              print("With Voice: \(voiceStyle.displayName)")
              self.delegate?.voicevoxClientDidStartPlaying()
              completion(nil)
            } catch {
              print("Audio playback error:", error)
              completion(error)
            }
          }
        } catch {
          print("Failed to save audio file:", error)
          completion(error)
        }
      }.resume()
    }.resume()
  }

  func stopPlayback() {
    if audioPlayer?.isPlaying == true {
      audioPlayer?.stop()
      delegate?.voicevoxClientDidFinishPlaying()
    }
  }

  func isPlaying() -> Bool {
    audioPlayer?.isPlaying ?? false
  }
}

extension VoicevoxClient: AVAudioPlayerDelegate {
  func audioPlayerDidFinishPlaying(_: AVAudioPlayer, successfully _: Bool) {
    delegate?.voicevoxClientDidFinishPlaying()
  }
}
