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
  func ttsAudioManagerDidBeginTTSRetrieve()
  func ttsAudioManagerDidFinishTTSRetrieve()
  func ttsAudioManagerDidStartPlaying()
  func ttsAudioManagerDidPausePlaying()
  func ttsAudioManagerDidFinishPlaying()
}

class TTSAudioManager: NSObject {
  private let baseURLString = "https://tts-api.netlify.app/?"
  private let langURLString = "&lang=ja"
  private let textURLString = "&text="

  private var avPlayer: AVPlayer?
  private var observedPlayer: AVPlayer? // ✅ Added this line
  private var timeObserverToken: Any?
  private var isStartingPlayback = false // Optional debounce flag

  var delegate: TTSAudioManagerDelegate?

  var isPlaying: Bool {
    avPlayer?.timeControlStatus == .playing
  }

  func stop() {
    guard let avPlayer = avPlayer else { return }

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
    guard !isStartingPlayback else { return }
    isStartingPlayback = true

    // Stop existing playback
    if avPlayer?.timeControlStatus == .playing {
      avPlayer?.pause()
      avPlayer?.seek(to: .zero)
    }

    // Remove observers before replacing the player
    removePlayerObservers()

    var docsURL = AudioFileWriter.baseURL
    let fileName = data.URL.absoluteString
    docsURL.appendPathComponent(fileName)

    configureAudioSession()

    let asset = AVURLAsset(url: docsURL)
    let playerItem = AVPlayerItem(asset: asset)

    let newPlayer = AVPlayer(playerItem: playerItem)
    avPlayer = newPlayer

    addPlayerObservers()
    newPlayer.play()

    // Reset debounce flag after short delay
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
      self.isStartingPlayback = false
    }
  }

  func configureAudioSession() {
    let audioSession = AVAudioSession.sharedInstance()
    do {
      // Set the audio session category and mode.
      try audioSession.setCategory(.playback, options: .duckOthers)
    } catch {
      print("Failed to set the audio session configuration")
    }
  }

  deinit {
    removePlayerObservers()
  }

  private func addPlayerObservers() {
    guard let avPlayer = avPlayer else { return }

    NotificationCenter.default.addObserver(self,
                                           selector: #selector(playerDidFinishPlaying),
                                           name: .AVPlayerItemDidPlayToEndTime,
                                           object: avPlayer.currentItem)

    timeObserverToken = avPlayer.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5,
                                                                             preferredTimescale: CMTimeScale(NSEC_PER_SEC)),
                                                         queue: .main) { [weak self] _ in
      guard let self = self else { return }
      switch avPlayer.timeControlStatus {
      case .playing:
        self.delegate?.ttsAudioManagerDidStartPlaying()
      case .paused:
        self.delegate?.ttsAudioManagerDidPausePlaying()
      default:
        break
      }
    }

    observedPlayer = avPlayer
  }

  private func removePlayerObservers() {
    if let player = observedPlayer, let token = timeObserverToken {
      player.removeTimeObserver(token)
      timeObserverToken = nil
      observedPlayer = nil
    }

    NotificationCenter.default.removeObserver(self)
  }

  @objc private func playerDidFinishPlaying() {
    delegate?.ttsAudioManagerDidFinishPlaying()
  }

  private func makeRequest(url: URL, method: String) -> URLRequest {
    var req = URLRequest(url: url)
    req.httpMethod = method
    return req
  }
}
