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

import Foundation

@MainActor
class ContextAndNuancesViewModel {
  enum State {
    case loading
    case success(String)
    case error(String)
  }

  var state: State = .loading
  var onStateChange: ((State) -> Void)?

  private let japaneseText: String
  private let meaning: String
  private let subjectType: String
  private var hasStartedFetch = false

  init(japaneseText: String, meaning: String, subjectType: String) {
    self.japaneseText = japaneseText
    self.meaning = meaning
    self.subjectType = subjectType
  }

  func fetchResponse() async {
    guard !hasStartedFetch else { return }
    hasStartedFetch = true

    state = .loading
    onStateChange?(state)

    let geminiAPIKey = Settings.geminiAPIKey
    if geminiAPIKey.isEmpty {
      state = .error("Additional context not available at this time (API key missing)")
      onStateChange?(state)
      return
    }

    let generalInstructions = """
    You are a helpful and knowledgeable Japanese language tutor.

    Your task is to provide a brief, 2 to 3 sentence explanation about the context, nuances, and usage of a specific Japanese Kanji or Vocabulary word. Explain if the word is formal, casual, or obscure, if it has archaic or special meanings, or in what specific context it is most naturally used. Limit your response to just 2 or 3 short sentences. Do not use markdown styling like bolding or lists, just return plain text.
    """

    let exampleUserInput = """
    Word Type: Vocabulary
    Japanese: 一階 (いっかい)
    Meaning: First floor
    """

    let exampleAIResponse = """
    While "一階" directly translates to "first floor," in Japan it specifically refers to the ground floor of a building. It's a very common, everyday word used in both formal and informal contexts when navigating spaces or describing building layouts.
    """

    let userInput = """
    Word Type: \(subjectType)
    Japanese: \(japaneseText)
    Meaning: \(meaning)
    """

    let requestBody = GenerateContentRequest(contents: [
      .init(role: "user", parts: [
        .init(text: generalInstructions),
        .init(text: exampleUserInput),
      ]),
      .init(role: "model", parts: [.init(text: exampleAIResponse)]),
      .init(role: "user", parts: [.init(text: userInput)]),
    ])

    do {
      let fullResponseText = try await GeminiAPI.generateContent(requestBody: requestBody,
                                                                 apiKey: geminiAPIKey)
      state = .success(fullResponseText.trimmingCharacters(in: .whitespacesAndNewlines))
    } catch {
      state = .error("Additional context not available at this time")
    }
    onStateChange?(state)
  }
}
