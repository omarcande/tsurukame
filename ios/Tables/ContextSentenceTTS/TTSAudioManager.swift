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

protocol TTSAudioManagerDelegate: AnyObject {
  func ttsAudioManagerDidBeginTTSRetrieve() // start download
  func ttsAudioManagerDidFinishTTSRetrieve() // download finished
  func ttsAudioManagerDidStartPlaying() // playing audio
  func ttsAudioManagerDidPausePlaying() // paused audio
  func ttsAudioManagerDidFinishPlaying() // stop audio
}

class TTSAudioManager: NSObject {
  private let baseURLString: String = "https://tts-api.netlify.app/?"
  private let langURLString: String = "&lang=ja"
  private let textURLString: String = "&text="

  private var avPlayer: AVPlayer?

  var delegate: TTSAudioManagerDelegate?

  var isPlaying: Bool {
    guard let avPlayer = avPlayer else {
      return false
    }

    return avPlayer.timeControlStatus != .playing
  }

  func stop() {
    guard let avPlayer = avPlayer else {
      return
    }

    if avPlayer.timeControlStatus == .playing {
      avPlayer.pause()
    }

    avPlayer.seek(to: CMTime(seconds: 0, preferredTimescale: 1))
  }

  func retrieveAudio(for text: String) async throws -> TranslatedVoiceData? {
    Task { @MainActor in
      delegate?.ttsAudioManagerDidBeginTTSRetrieve()
    }

    guard let encodedText = text.urlEncoded() else {
      print("Error: text could not be URL encoded")
      throw URLError(.unsupportedURL)
    }
    let urlString = baseURLString + langURLString + textURLString + encodedText

    print("URL: \(urlString)")

    guard let finalURL = URL(string: urlString) else {
      print("Error: URL is invalid")
      throw URLError(.badURL)
    }

    let request = makeRequest(url: finalURL, method: "GET")

    let (data, resp) = try await URLSession.shared.data(for: request)

    Task { @MainActor in
      delegate?.ttsAudioManagerDidFinishTTSRetrieve()
    }

    if let httpResponse = resp as? HTTPURLResponse, httpResponse.statusCode != 200 {
      print("Error: server responded with error code \(httpResponse.statusCode)")
      throw URLError(.badServerResponse)
    }

    guard let voiceData = AudioFileWriter.shared.saveAudio(data: data) else {
      print("Error: voice data could not be saved to file")
      throw URLError(.cannotWriteToFile)
    }

    return voiceData
  }

  func playAudio(from data: TranslatedVoiceData) {
    if let avPlayer = avPlayer {
      guard avPlayer.timeControlStatus != .playing else {
        avPlayer.pause()
        avPlayer.seek(to: CMTime(seconds: 0, preferredTimescale: 1))
        return
      }

      avPlayer.removeObserver(self, forKeyPath: KeyPathDefaults.timeControlStatus.rawValue)
    }

    var finalURL: URL!

    var docsURL = AudioFileWriter.baseURL
    let fileName = data.URL.absoluteString
    docsURL.appendPathComponent(fileName)

    finalURL = docsURL

    let asset = AVURLAsset(url: finalURL)
    let playerItem = AVPlayerItem(asset: asset)

    avPlayer = AVPlayer(playerItem: playerItem)
    avPlayer?.addObserver(self, forKeyPath: "timeControlStatus", options: [.old, .new],
                          context: nil)
    avPlayer?.play()
  }

  deinit {
    if let avPlayer = avPlayer {
      avPlayer.removeObserver(self, forKeyPath: KeyPathDefaults.timeControlStatus.rawValue)
    }
  }
}

private extension TTSAudioManager {
  func prepareAudioSession() {
    do {
      try AVAudioSession.sharedInstance().setCategory(.playback)
    } catch {
      print("Error configuring AVAudioSession: \(error.localizedDescription)")
    }
  }

  func makeRequest(url: URL, method: String) -> URLRequest {
    var req = URLRequest(url: url)
    req.httpMethod = method
    return req
  }
}

extension TTSAudioManager {
  override func observeValue(forKeyPath keyPath: String?, of object: Any?,
                             change _: [NSKeyValueChangeKey: Any]?,
                             context _: UnsafeMutableRawPointer?) {
    guard let avPlayer = avPlayer, object as? AnyObject === avPlayer else {
      return
    }

    if keyPath == KeyPathDefaults.timeControlStatus.rawValue {
      switch avPlayer.timeControlStatus {
      case .playing:
        print("AVPlayer: playing")
        delegate?.ttsAudioManagerDidStartPlaying()
      case .paused:
        print("AVPlayer: paused")
        delegate?.ttsAudioManagerDidPausePlaying()
        delegate?.ttsAudioManagerDidFinishPlaying()
      case .waitingToPlayAtSpecifiedRate:
        print("AVPlayer: waiting to play")
      @unknown default:
        print("AVPlayer: unknown future state")
      }
    }
  }
}
