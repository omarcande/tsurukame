//
//  VoicevoxClient.swift
//  Tsurukame
//
//  Created by Omar Candelaria on 4/30/25.
//  Copyright © 2025 David Sansome. All rights reserved.
//

import Foundation
import AVFoundation

class VoicevoxClient {
  let baseURL = URL(string: "http://pop-os.local:50021")! 
  var audioPlayer: AVAudioPlayer?

  func speak(text: String, speakerID: Int = 1) {
    // 1. Create /audio_query request
    var queryURL = baseURL.appendingPathComponent("audio_query")
    queryURL = URL(string: "\(queryURL)?text=\(text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&speaker=\(speakerID)")!

    var queryRequest = URLRequest(url: queryURL)
    queryRequest.httpMethod = "POST"
    queryRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

    // 2. Call /audio_query
    URLSession.shared.dataTask(with: queryRequest) { data, _, error in
      guard let data = data, error == nil else {
        print("Audio query failed:", error ?? "Unknown error")
        return
      }

      // 3. Create /synthesis request
      var synthURL = self.baseURL.appendingPathComponent("synthesis")
      synthURL = URL(string: "\(synthURL)?speaker=\(speakerID)")!

      var synthRequest = URLRequest(url: synthURL)
      synthRequest.httpMethod = "POST"
      synthRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
      synthRequest.httpBody = data  // reuse audio_query JSON

      // 4. Call /synthesis
      URLSession.shared.dataTask(with: synthRequest) { audioData, _, error in
        guard let audioData = audioData, error == nil else {
          print("Synthesis failed:", error ?? "Unknown error")
          return
        }

        // 5. Save to temporary file
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("voicevox_output.wav")
        do {
          try audioData.write(to: tempURL)

          // 6. Play with AVAudioPlayer
          DispatchQueue.main.async {
            do {
              self.audioPlayer = try AVAudioPlayer(contentsOf: tempURL)
              self.audioPlayer?.prepareToPlay()
              self.audioPlayer?.play()
              print("🎧 Playing: \(text)")
            } catch {
              print("Audio playback error:", error)
            }
          }
        } catch {
          print("Failed to save audio file:", error)
        }
      }.resume()
    }.resume()
  }
}
