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
import UIKit

struct AITutorView: View {
  @State private var didCopyResponse = false
  @StateObject private var viewModel: AITutorViewModel
  @Environment(\.dismiss) private var dismiss
  let sentence: String

  // Existing initializer remains for production use
  init(sentence: String) {
    _viewModel = StateObject(wrappedValue: AITutorViewModel(sentence: sentence))
    self.sentence = sentence
  }

  // New: injectable initializer for previews/tests
  init(sentence: String, viewModel: AITutorViewModel) {
    _viewModel = StateObject(wrappedValue: viewModel)
    self.sentence = sentence
  }

  var body: some View {
//      let vocabPurple = Color(UIColor { trait in
//          if trait.userInterfaceStyle == .dark {
//              // Dark: 0x6100AA
//              return UIColor(
//                  red: 97.0/255.0,
//                  green: 0.0/255.0,
//                  blue: 170.0/255.0,
//                  alpha: 1.0
//              )
//          } else {
//              // Light: 0xAA00FF
//              return UIColor(
//                  red: 170.0/255.0,
//                  green: 0.0/255.0,
//                  blue: 255.0/255.0,
//                  alpha: 1.0
//              )
//          }
//      })

    let purple = Color(UIColor(red: 97.0 / 255.0,
                               green: 0.0 / 255.0,
                               blue: 170.0 / 255.0,
                               alpha: 1.0))

    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          // MARK: Context Sentence card

          VStack(alignment: .leading, spacing: 8) {
            Text("Context Sentence:")
              .font(.headline)
              .fontWeight(.medium)
            // .foregroundColor(purple)

            Text(sentence)
              .font(.title2)
              .fontWeight(.semibold)
          }
          .padding()
          // Content layer: use standard materials (not Liquid Glass) per HIG
          // for readability and hierarchy.
          .background(.ultraThickMaterial)
          .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
          .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
          .padding(.horizontal)

          // MARK: AI Response card

          if viewModel.isLoading {
            ProgressView()
              .padding()
              .frame(maxWidth: .infinity)

          } else if let response = viewModel.responseText {
            VStack(alignment: .leading, spacing: 12) {
              Text("AI Tutor's Analysis:")
                .font(.headline)
                .fontWeight(.medium)
              // .foregroundColor(.gray)

              Text(convertToAttributedString(response))
                .font(.body)

              Divider()
                .padding(.top, 4)

              HStack {
                Spacer()
                Button {
                  // Remove markdown
                  if let attributed = try? AttributedString(markdown: response,
                                                            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
                    UIPasteboard.general.string = String(attributed.characters)
                  } else {
                    UIPasteboard.general.string = response
                  }
                  didCopyResponse = true
                } label: {
                  Label("Copy", systemImage: "doc.on.doc")
                    .font(.callout)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(.regularMaterial)
                    .foregroundColor(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
              }
            }
            .padding()
            .background(.ultraThickMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            .padding(.horizontal)
          }
        }
        .padding(.vertical)
      }
      .background(Color(purple))

      // MARK: Navigation / Toolbar

      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          // Symbol-forward item; monochrome + white ink on glass.
          Button {
            dismiss()
          } label: {
            Image(systemName: "chevron.down")
              .symbolRenderingMode(.monochrome)
          }
          .buttonStyle(.plain)
          .tint(.white) // ensure white ink
          .contentShape(Rectangle()) // good hit-testing
        }

        ToolbarItem(placement: .principal) {
          Text("AI Tutor")
            .font(.headline)
            .foregroundStyle(.white)
        }
      }
      .toolbarBackground(.visible, for: .navigationBar)
      .toolbarColorScheme(.dark, for: .navigationBar) // white ink across items
    }

    // MARK: Tasks & Alerts (unchanged)

    .task {
      #if DEBUG
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
          return
        }
      #endif
      await viewModel.fetchResponse()
    }
    .alert("Missing API Key", isPresented: $viewModel.isShowingAPIKeyAlert) {
      Button("OK", role: .cancel) {}
    } message: {
      Text("Please enter a Gemini API Key on Settings.")
    }
    .alert("Copied!", isPresented: $didCopyResponse) {
      Button("OK", role: .cancel) {}
    } message: {
      Text("The analysis has been copied to your clipboard.")
    }
  }

  let customBackgroundColor = UIColor { traitCollection in
    if traitCollection.userInterfaceStyle == .dark {
      return UIColor(red: 28 / 255, green: 28 / 255, blue: 30 / 255, alpha: 1) // #1C1C1E
    } else {
      return .white
    }
  }

  // Helper function to convert a Markdown string to AttributedString
  private func convertToAttributedString(_ markdownString: String) -> AttributedString {
    do {
      return try AttributedString(markdown: markdownString,
                                  options: AttributedString
                                    .MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace))
    } catch {
      print("Error parsing Markdown: \(error.localizedDescription)")
      return AttributedString(markdownString)
    }
  }
}

@MainActor
class AITutorViewModel: ObservableObject {
  @Published var responseText: String?
  @Published var isLoading = false
  @Published var isShowingAPIKeyAlert = false
  private let sentence: String

  // MARK: - Prompt Components

  // General instructions for the AI tutor's persona and output format
  let generalInstructions = """
  You are a Japanese language tutor.

  When you receive a sentence written in Japanese, you will translate the sentence to English and provide a detailed analysis of the grammar of the sentence. You will divide your response in 4 sections: Hiragana & Romanji | Translation | Breakdown and Explanation | Overall Meaning and Nuances
  """

  // Example user input for the few-shot example
  let exampleUserInput = """
  このリストには、あなたの氏名も入ってます。
  """

  // Example AI response for the few-shot example
  let exampleAIResponse = """

    **Hiragana:** このリストには、あなたのしめいもはいってます。
    **Romanji:** Kono risuto ni wa, anata no shimei mo haittemasu.

  **Translation:**

  - "Your full name is also included on this list."
  - "Your name is also on this list."

  **Breakdown and Explanation:**

  - **この (kono):** “This.” It directly modifies the noun that follows it.
  - **リスト (risuto):** “List.” This is a loanword from English, written in Katakana.
  - **に (ni):** A particle indicating location or inclusion. Here, it means “on” or “in” the list.
  - **は (wa):** The topic particle. It marks 「このリストに」 (on this list) as the topic of the sentence. It can convey a subtle nuance of contrast or emphasis, like “As for this list…”
  - **あなたの (anata no):** “Your.”
      - **あなた (anata)::** “You.”
      - **の (no):** The possessive particle, equivalent to “‘s” or “of.”
  - **氏名 (しめい - shimei):** “Full name.” This term is formal and is commonly used on official documents or forms.
  - **も (mo):** A particle meaning “also” or “too.” Here, it implies that in addition to other names, *your* name is included.
  - **入ってます (haitte masu):** This is the polite form of **入っている (haitte iru)**, which means “is in,” “is included,” or “is contained.”
      - **入る (hairu):** The plain form of the verb “to enter” or “to be included.”
      * **〜ている (te iru):** This form indicates a state of being or a continuous action. In this case, it’s a **resulting state** (the name has entered the list, and is now in it).
      * **〜てます (temasu):** A slightly more casual contraction of 〜ています (te imasu). It’s commonly used in spoken Japanese.

  **Overall Meaning:**

  The sentence informs the listener that their full name is indeed present on the list being referred to. The **も** particle suggests that perhaps other names are on the list as well, or that their name’s inclusion is noteworthy. The use of **氏名** makes it clear that it’s their complete official name.
  """

  init(sentence: String) {
    self.sentence = sentence
  }

  func fetchResponse() async {
    isLoading = true
    responseText = nil // Clear any previous response text

    do {
      try await fetchFromGemini(sentence: sentence) // Call the non-streaming function
    } catch {
      responseText = "❌ Error: \(error.localizedDescription)"
      print("Gemini API Error: \(error)") // Print the full error for debugging
    }
    isLoading = false
  }

  // Renamed from fetchFromGeminiStreamed to reflect non-streaming
  private func fetchFromGemini(sentence: String) async throws {
    let geminiAPIKey = Settings.geminiAPIKey
    if geminiAPIKey.isEmpty {
      isShowingAPIKeyAlert = true
      return
    }

    // Changed endpoint from :streamGenerateContent to :generateContent
    guard let url =
      URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=\(geminiAPIKey)")
    else {
      throw URLError(.badURL)
    }

    // --- Build request using typed Encodable structs to avoid type-checker blowups ---
    let requestBody = GenerateContentRequest(contents: [
      .init(role: "user", parts: [.init(text: generalInstructions)]),
      .init(role: "user", parts: [.init(text: exampleUserInput)]),
      .init(role: "model", parts: [.init(text: exampleAIResponse)]),
      .init(role: "user", parts: [.init(text: sentence)]),
    ],
    generationConfig: .init(temperature: 0.7))

    let jsonData = try JSONEncoder().encode(requestBody)

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = jsonData

    // --- Core change: Use data(for:) for a single response ---
    let (data, response) = try await URLSession.shared.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
      throw URLError(.badServerResponse,
                     userInfo: [NSLocalizedDescriptionKey: "Invalid HTTP Response"])
    }

    guard httpResponse.statusCode == 200 else {
      if let errorString = String(data: data, encoding: .utf8) {
        print("Server Error Response Body: \(errorString)")
      }
      throw URLError(.badServerResponse, userInfo: [
        NSLocalizedDescriptionKey: "Server responded with status code \(httpResponse.statusCode)",
      ])
    }

    // --- Decode the entire JSON response at once ---
    do {
      let decodedResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
      // Extract the text from the first candidate's content parts
      if let fullResponseText = decodedResponse.candidates.first?.content.parts.first?.text {
        responseText = fullResponseText // Set the entire response at once
      } else {
        responseText = "No text content found in response."
      }
    } catch {
      print("Error decoding full response JSON: \(error.localizedDescription)")
      print("Received Data: \(String(data: data, encoding: .utf8) ?? "N/A")")
      throw error // Re-throw the decoding error
    }
  }
}

// MARK: - Encodable Structs for Request (fixes preview type-checking)

/// Strongly-typed request body for the Gemini `:generateContent` endpoint.
/// Using `Encodable` eliminates large `[String: Any]` literals that cause
/// type-checker performance issues in SwiftUI previews.
struct GenerateContentRequest: Encodable {
  var contents: [Content]
  var generationConfig: GenerationConfig?

  struct Content: Encodable {
    var role: String
    var parts: [Part]

    struct Part: Encodable {
      var text: String
    }
  }

  struct GenerationConfig: Encodable {
    var temperature: Double?
  }
}

// MARK: - Decodable Struct for Non-Streaming Gemini Response

// This struct is now named GeminiResponse to represent the full, single response object.
// Its structure is identical to what the streaming chunks would eventually aggregate into.
struct GeminiResponse: Decodable {
  let candidates: [Candidate]
  // You might also find 'usageMetadata' or 'promptFeedback' at the top level
  // in non-streaming responses, you can add them here if you need to parse them.
  // let usageMetadata: UsageMetadata?
  // let promptFeedback: PromptFeedback?

  struct Candidate: Decodable {
    let content: Content
    // In non-streaming, you might also find 'finishReason' or 'safetyRatings' here
    // let finishReason: String?
    // let safetyRatings: [SafetyRating]?

    struct Content: Decodable {
      let parts: [Part]

      struct Part: Decodable {
        let text: String
      }
    }
  }
  // Example of how you'd add other top-level structs if needed:
  // struct UsageMetadata: Decodable {
  //     let promptTokenCount: Int
  //     let candidatesTokenCount: Int
  //     let totalTokenCount: Int
  // }
  // struct PromptFeedback: Decodable {
  //     let blockReason: String?
  //     let safetyRatings: [SafetyRating]?
  // }
  // struct SafetyRating: Decodable {
  //     let category: String
  //     let probability: String
  // }
}

// MARK: - Preview Support

@MainActor
final class MockAITutorViewModel: AITutorViewModel {
  init(sentence: String,
       responseText: String? = nil,
       isLoading: Bool = false,
       showApiKeyAlert: Bool = false) {
    super.init(sentence: sentence)
    self.responseText = responseText
    self.isLoading = isLoading
    isShowingAPIKeyAlert = showApiKeyAlert
  }

  override func fetchResponse() async {
    // no-op in previews
  }
}

struct AITutorView_Previews: PreviewProvider {
  static var sampleSentence: String {
    "昨日、駅で友達に会って、一緒に晩ごはんを食べました。"
  }

  static var sampleResponse: String {
    """
    **Hiragana:** きのう、えきでともだちにあって、いっしょにばんごはんをたべました。
    **Romanji:** Kinō, eki de tomodachi ni atte, issho ni bangohan o tabemashita.

    **Translation:**
    - “Yesterday, I met a friend at the station and we had dinner together.”

    **Breakdown and Explanation:**
    - **昨日 (きのう / kinō):** yesterday.
    - **駅 (えき / eki):** station.
    - **で (de):** location particle (at/in).
    - **友達 (ともだち / tomodachi):** friend.
    - **に (ni):** indirect object marker.
    - **会う (あう / au) → 会って (あって / atte):** te-form of “to meet.”
    - **一緒に (いっしょに / issho ni):** together.
    - **晩ごはん (ばんごはん / bangohan):** dinner.
    - **食べる (たべる / taberu) → 食べました (たべました / tabemashita):** polite past “ate.”

    **Overall Meaning and Nuances:**
    The sentence conveys a simple past sequence: met a friend at the station, then had dinner together. The te-form links actions naturally.
    """
  }

  static var previews: some View {
    Group {
      // 1) Loaded – Light
      NavigationStack {
        AITutorView(sentence: sampleSentence,
                    viewModel: MockAITutorViewModel(sentence: sampleSentence,
                                                    responseText: sampleResponse,
                                                    isLoading: false))
      }
      .previewDisplayName("Loaded – Light")
      .environment(\.colorScheme, .light)

      // 1b) Loaded – Dark
      NavigationStack {
        AITutorView(sentence: sampleSentence,
                    viewModel: MockAITutorViewModel(sentence: sampleSentence,
                                                    responseText: sampleResponse,
                                                    isLoading: false))
      }
      .previewDisplayName("Loaded – Dark")
      .environment(\.colorScheme, .dark)

      // 2) Loading
      NavigationStack {
        AITutorView(sentence: sampleSentence,
                    viewModel: MockAITutorViewModel(sentence: sampleSentence,
                                                    responseText: nil,
                                                    isLoading: true))
      }
      .previewDisplayName("Loading")
      .environment(\.colorScheme, .light)

      // 3) Missing API Key (shows the state; alerts don’t present in previews)
      NavigationStack {
        AITutorView(sentence: sampleSentence,
                    viewModel: MockAITutorViewModel(sentence: sampleSentence,
                                                    responseText: nil,
                                                    isLoading: false,
                                                    showApiKeyAlert: true))
      }
      .previewDisplayName("Missing API Key")
      .environment(\.colorScheme, .light)
    }
  }
}
