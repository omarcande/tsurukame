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
  case randomVoice = -1
  case metanNormal = 2
  case zundamonTsundere = 7
  case tsumugi = 8
  case hau = 10
  case himari = 14
  case ritsuQueen = 65
  case takemitsuNormal = 11
  case kensakiNormal = 21
  case ryuseiPassion = 81
  case ryuseiGentle = 84
  case soraSexy = 17
  case mochikoSexy = 66
  case culSad = 25
  case no7Read = 31
  case nurseRoboNormal = 47
  case zonkoNormal = 90

  var displayName: String {
    switch self {
    case .randomVoice: return "ランダム"
    case .metanNormal: return "四国めたん - ノーマル"
    case .zundamonTsundere: return "ずんだもん - ツンツン"
    case .tsumugi: return "春日部つむぎ - ノーマル"
    case .hau: return "雨晴はう - ノーマル"
    case .himari: return "冥鳴ひまり - ノーマル"
    case .ritsuQueen: return "波音リツ - クイーン"
    case .takemitsuNormal: return "玄野武宏 - ノーマル"
    case .kensakiNormal: return "剣崎雌雄 - ノーマル"
    case .ryuseiPassion: return "青山龍星 - 熱血"
    case .ryuseiGentle: return "青山龍星 - しっとり"
    case .soraSexy: return "九州そら - セクシー"
    case .mochikoSexy: return "もち子さん - セクシー／あん子"
    case .culSad: return "WhiteCUL - かなしい"
    case .no7Read: return "No.7 - 読み聞かせ"
    case .nurseRoboNormal: return "ナースロボT - ノーマル"
    case .zonkoNormal: return "ぞん子 - ノーマル"
    }
  }

  static func from(id: Int) -> VoicevoxStyle? {
    allCases.first(where: { $0.rawValue == id })
  }

  static func random() -> VoicevoxStyle {
    var style: VoicevoxStyle?
    repeat {
      style = allCases.randomElement()!
    } while style == .randomVoice
    return style!
  }
}

protocol VoicevoxClientDelegate: AnyObject {
  func voicevoxClientDidStartFetching()
  func voicevoxClientDidStartPlaying()
  func voicevoxClientDidFinishPlaying()
  func voicevoxClientDidThrowError()
}

class VoicevoxClient: NSObject {
  let baseURL = URL(string: "http://pop-os.local:50021")!
  var audioPlayer: AVAudioPlayer?
  weak var delegate: VoicevoxClientDelegate?

  func speak(text: String, voiceStyle: VoicevoxStyle = VoicevoxStyle.random(),
             completion: @escaping (Error?) -> Void) {
    let id = voiceStyle == .randomVoice ? VoicevoxStyle.random().rawValue : voiceStyle.rawValue
    speak(text: text, voiceStyleId: id, completion: completion)
  }

  func speak(text: String, voiceStyleId: Int,
             completion: @escaping (Error?) -> Void) {
    delegate?.voicevoxClientDidStartFetching()

    if !isVoiceVoxAvailable() {
      completion(NSError(domain: "VoicevoxClient", code: -3,
                         userInfo: [NSLocalizedDescriptionKey: "No network connection"]))
      delegate?.voicevoxClientDidThrowError()
      return
    }

    let speakerID = voiceStyleId
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
              print("With Voice: \(speakerID)")
              self.delegate?.voicevoxClientDidStartPlaying()
              completion(nil)
            } catch {
              print("Audio playback error:", error)
              self.delegate?.voicevoxClientDidThrowError()
              completion(error)
            }
          }
        } catch {
          print("Failed to save audio file:", error)
          self.delegate?.voicevoxClientDidThrowError()
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

  func isVoiceVoxAvailable() -> Bool {
    // Check if baseURL is reachable before proceeding
    var request = URLRequest(url: baseURL)
    request.httpMethod = "HEAD"

    let semaphore = DispatchSemaphore(value: 0)
    var isReachable = false

    URLSession.shared.dataTask(with: request) { _, response, _ in
      if let httpResponse = response as? HTTPURLResponse {
        isReachable = (200 ... 405).contains(httpResponse.statusCode)
      }
      semaphore.signal()
    }.resume()

    _ = semaphore.wait(timeout: .now() + 2.0) // wait up to 2 seconds

    return isReachable
  }
}

extension VoicevoxClient: AVAudioPlayerDelegate {
  func audioPlayerDidFinishPlaying(_: AVAudioPlayer, successfully _: Bool) {
    delegate?.voicevoxClientDidFinishPlaying()
  }
}
