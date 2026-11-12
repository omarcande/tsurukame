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

import SwiftUI
import UIKit

extension Color {
  static let charcoalGray = Color("CharcoalGray")
  static let vocabPurple = Color("VocabPurple")
  static let vocabPurpleInverted = Color("VocabPurpleInverted")
}

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
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          // MARK: Context Sentence card

//          VStack(alignment: .leading, spacing: 8) {
//            Text("Context Sentence:")
//              .font(.headline)
//              .fontWeight(.medium)
//
//            Text(sentence)
//              .font(.title2)
//              .fontWeight(.semibold)
//          }
//          .padding()
//          .background(.ultraThickMaterial)
//          .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
//          .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
//          .padding(.horizontal)

          VStack(alignment: .leading, spacing: 8) {
//              Text("Context Sentence:")
//                .font(.headline)
//                .fontWeight(.medium)

            Text(sentence)
              .font(.title2)
              .fontWeight(.semibold)
              .foregroundColor(.white)
              .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
          }
          .padding()
          // .background(.ultraThinMaterial)
          // .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
          .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
          .padding(.horizontal)

          // MARK: AI Response card

          if viewModel.isLoading {
            ProgressView()
              .padding()
              .frame(maxWidth: .infinity)
              .tint(.white)

          } else if let response = viewModel.responseText {
            VStack(alignment: .leading, spacing: 12) {
              Text("AI Tutor's Analysis:")
                .font(.headline)
                .fontWeight(.medium)
                .foregroundColor(Color.vocabPurpleInverted)

              MarkdownContentView(markdown: response)
                .textSelection(.enabled)

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
      .background(Color.charcoalGray)

      // MARK: Navigation / Toolbar

      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button {
            dismiss()
          } label: {
            Image(systemName: "chevron.down")
              .symbolRenderingMode(.monochrome)
          }
          .buttonStyle(.plain)
          .tint(.white)
        }

//        ToolbarItem(placement: .principal) {
//          Text("AI Tutor")
//            .font(.headline)
//            .foregroundStyle(.white)
//        }

        ToolbarItem(placement: .navigationBarTrailing) {
          Button {
            Task { await viewModel.fetchResponse() }
          } label: {
            Image(systemName: "arrow.clockwise")
              .symbolRenderingMode(.monochrome)
          }
          .buttonStyle(.plain)
          .tint(.white)
          .disabled(viewModel.isLoading)
        }
      }
      .toolbarBackground(.visible, for: .navigationBar)
      .toolbarColorScheme(.dark, for: .navigationBar)
    }

    // MARK: Tasks & Alerts

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
}

// MARK: - Native SwiftUI Markdown Renderer

private struct MarkdownContentView: View {
  let markdown: String

  fileprivate enum Block {
    case heading(level: Int, text: String)
    case bulletItem(level: Int, text: String)
    case numberedItem(level: Int, number: String, text: String)
    case blockquote(text: String)
    case codeBlock(code: String)
    case divider
    case paragraph(text: String)

    var isListItem: Bool {
      switch self {
      case .bulletItem, .numberedItem:
        return true
      default:
        return false
      }
    }
  }

  var body: some View {
    let blocks = Self.parseBlocks(from: markdown)
    VStack(alignment: .leading, spacing: 6) {
      ForEach(Array(blocks.enumerated()), id: \.offset) { index, block in
        blockView(for: block)
          .padding(.top, topPadding(for: block, at: index, in: blocks))
      }
    }
  }

  private func topPadding(for block: Block, at index: Int, in blocks: [Block]) -> CGFloat {
    guard index > 0 else { return 0 }
    switch block {
    case .heading:
      return 8
    case .bulletItem, .numberedItem:
      return blocks[index - 1].isListItem ? 0 : 4
    case .paragraph, .blockquote, .codeBlock, .divider:
      return 4
    }
  }

  @ViewBuilder
  private func blockView(for block: Block) -> some View {
    switch block {
    case let .heading(level, text):
      Text(Self.inlineAttributedString(text))
        .font(headingFont(for: level))
        .foregroundColor(Color.vocabPurpleInverted)
        .fixedSize(horizontal: false, vertical: true)

    case let .bulletItem(level, text):
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Text(bulletSymbol(for: level))
          .font(.body.weight(.semibold))
          .foregroundColor(Color.vocabPurpleInverted)
        Text(Self.inlineAttributedString(text))
          .font(.body)
          .fixedSize(horizontal: false, vertical: true)
      }
      .padding(.leading, CGFloat(level) * 18)

    case let .numberedItem(level, number, text):
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Text(number)
          .font(.body.weight(.semibold))
          .foregroundColor(Color.vocabPurpleInverted)
        Text(Self.inlineAttributedString(text))
          .font(.body)
          .fixedSize(horizontal: false, vertical: true)
      }
      .padding(.leading, CGFloat(level) * 18)

    case let .blockquote(text):
      HStack(alignment: .top, spacing: 10) {
        RoundedRectangle(cornerRadius: 1.5)
          .fill(Color.vocabPurpleInverted)
          .frame(width: 3)
        Text(Self.inlineAttributedString(text))
          .font(.body)
          .foregroundColor(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      .padding(.vertical, 2)

    case let .codeBlock(code):
      ScrollView(.horizontal, showsIndicators: false) {
        Text(code)
          .font(.system(.callout, design: .monospaced))
          .padding(10)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Color(.tertiarySystemFill))
      .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

    case .divider:
      Divider()
        .padding(.vertical, 4)

    case let .paragraph(text):
      Text(Self.inlineAttributedString(text))
        .font(.body)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  private func headingFont(for level: Int) -> SwiftUI.Font {
    switch level {
    case 1:
      return .title3.weight(.bold)
    case 2:
      return .headline.weight(.bold)
    default:
      return .subheadline.weight(.semibold)
    }
  }

  private func bulletSymbol(for level: Int) -> String {
    switch level {
    case 0:
      return "•"
    case 1:
      return "◦"
    default:
      return "▪"
    }
  }

  private static func inlineAttributedString(_ markdownString: String) -> AttributedString {
    do {
      return try AttributedString(markdown: markdownString,
                                  options: AttributedString
                                    .MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace))
    } catch {
      return AttributedString(markdownString)
    }
  }

  private static func parseBlocks(from markdown: String) -> [Block] {
    let lines = markdown.replacingOccurrences(of: "\r\n", with: "\n")
      .components(separatedBy: "\n")

    var blocks: [Block] = []
    var paragraphLines: [String] = []
    var codeBlockLines: [String] = []
    var isInCodeBlock = false

    func flushParagraph() {
      guard !paragraphLines.isEmpty else { return }
      blocks.append(.paragraph(text: paragraphLines.joined(separator: "\n")))
      paragraphLines.removeAll()
    }

    for rawLine in lines {
      let trimmed = rawLine.trimmingCharacters(in: .whitespaces)

      if trimmed.hasPrefix("```") {
        flushParagraph()
        if isInCodeBlock {
          blocks.append(.codeBlock(code: codeBlockLines.joined(separator: "\n")))
          codeBlockLines.removeAll()
          isInCodeBlock = false
        } else {
          isInCodeBlock = true
        }
        continue
      }

      if isInCodeBlock {
        codeBlockLines.append(rawLine)
        continue
      }

      if trimmed.isEmpty {
        flushParagraph()
        continue
      }

      // Horizontal rule (---, ***, ___)
      if isHorizontalRule(trimmed) {
        flushParagraph()
        blocks.append(.divider)
        continue
      }

      // ATX Heading (#, ##, ###, ...)
      if let (level, headingText) = parseATXHeading(trimmed) {
        flushParagraph()
        blocks.append(.heading(level: level, text: headingText))
        continue
      }

      // Standalone bold section heading (e.g., "**Translation:**" or "**Breakdown and
      // Explanation:**")
      if let boldHeadingText = parseStandaloneBoldHeading(trimmed) {
        flushParagraph()
        blocks.append(.heading(level: 3, text: boldHeadingText))
        continue
      }

      let leadingSpaces = rawLine.prefix(while: { $0 == " " || $0 == "\t" })
        .reduce(0) { $0 + ($1 == "\t" ? 4 : 1) }
      let indentLevel = (leadingSpaces + 2) / 4

      // Bullet list item (-, *, +)
      if let itemText = parseBulletItem(trimmed) {
        flushParagraph()
        blocks.append(.bulletItem(level: indentLevel, text: itemText))
        continue
      }

      // Numbered list item (1., 2), etc.)
      if let (number, itemText) = parseNumberedItem(trimmed) {
        flushParagraph()
        blocks.append(.numberedItem(level: indentLevel, number: number, text: itemText))
        continue
      }

      // Blockquote (> ...)
      if trimmed.hasPrefix(">") {
        flushParagraph()
        let quoteText = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
        blocks.append(.blockquote(text: quoteText))
        continue
      }

      paragraphLines.append(trimmed)
    }

    if isInCodeBlock, !codeBlockLines.isEmpty {
      blocks.append(.codeBlock(code: codeBlockLines.joined(separator: "\n")))
    }
    flushParagraph()

    return blocks
  }

  private static func isHorizontalRule(_ trimmed: String) -> Bool {
    guard trimmed.count >= 3 else { return false }
    let chars = Set(trimmed.filter { !$0.isWhitespace })
    guard chars.count == 1, let char = chars.first else { return false }
    return (char == "-" || char == "*" || char == "_") &&
      trimmed.filter { $0 == char }.count >= 3
  }

  private static func parseATXHeading(_ trimmed: String) -> (Int, String)? {
    let hashes = trimmed.prefix(while: { $0 == "#" })
    guard !hashes.isEmpty, hashes.count <= 6 else { return nil }
    let remainder = trimmed.dropFirst(hashes.count)
    guard remainder.first == " " else { return nil }
    let text = remainder.trimmingCharacters(in: .whitespaces)
    guard !text.isEmpty else { return nil }
    return (hashes.count, text)
  }

  private static func parseStandaloneBoldHeading(_ trimmed: String) -> String? {
    guard trimmed.hasPrefix("**") else { return nil }
    var remainder = String(trimmed.dropFirst(2))
    let hasTrailingColonOutside: Bool
    if remainder.hasSuffix("**:") {
      remainder = String(remainder.dropLast(3))
      hasTrailingColonOutside = true
    } else if remainder.hasSuffix("**") {
      remainder = String(remainder.dropLast(2))
      hasTrailingColonOutside = false
    } else {
      return nil
    }
    guard !remainder.isEmpty, remainder.count <= 60, !remainder.contains("**") else {
      return nil
    }
    return hasTrailingColonOutside ? "\(remainder):" : remainder
  }

  private static func parseBulletItem(_ trimmed: String) -> String? {
    for prefix in ["- ", "* ", "+ ", "• "] {
      if trimmed.hasPrefix(prefix) {
        return String(trimmed.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
      }
    }
    return nil
  }

  private static func parseNumberedItem(_ trimmed: String) -> (String, String)? {
    let digits = trimmed.prefix(while: \.isNumber)
    guard !digits.isEmpty else { return nil }
    let afterDigits = trimmed.dropFirst(digits.count)
    guard let delimiter = afterDigits.first, delimiter == "." || delimiter == ")" else {
      return nil
    }
    let afterDelimiter = afterDigits.dropFirst()
    guard afterDelimiter.first == " " else { return nil }
    let text = afterDelimiter.trimmingCharacters(in: .whitespaces)
    return ("\(digits)\(delimiter)", text)
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

  private func fetchFromGemini(sentence: String) async throws {
    let geminiAPIKey = Settings.geminiAPIKey
    if geminiAPIKey.isEmpty {
      isShowingAPIKeyAlert = true
      return
    }

    // Combine generalInstructions and exampleUserInput into the first "user" turn
    // so roles strictly alternate: user -> model -> user.
    let requestBody = GenerateContentRequest(contents: [
      .init(role: "user", parts: [
        .init(text: generalInstructions),
        .init(text: exampleUserInput),
      ]),
      .init(role: "model", parts: [.init(text: exampleAIResponse)]),
      .init(role: "user", parts: [.init(text: sentence)]),
    ])

    responseText = try await GeminiAPI.generateContent(requestBody: requestBody,
                                                       apiKey: geminiAPIKey)
  }
}

// MARK: - Shared Gemini API Client

@MainActor
enum GeminiAPI {
  private static let endpoint =
    "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent"

  static func generateContent(requestBody: GenerateContentRequest,
                              apiKey: String) async throws -> String {
    guard let url = URL(string: endpoint) else {
      throw URLError(.badURL)
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.timeoutInterval = 30
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
    request.httpBody = try JSONEncoder().encode(requestBody)

    let (data, response) = try await URLSession.shared.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
      throw URLError(.badServerResponse,
                     userInfo: [NSLocalizedDescriptionKey: "Invalid HTTP Response"])
    }

    guard httpResponse.statusCode == 200 else {
      let apiMessage = (try? JSONDecoder().decode(GeminiErrorResponse.self, from: data))?
        .error?.message
      if let errorString = String(data: data, encoding: .utf8) {
        print("Gemini HTTP \(httpResponse.statusCode): \(errorString)")
      }
      throw URLError(.badServerResponse, userInfo: [
        NSLocalizedDescriptionKey: apiMessage ??
          "Server responded with status code \(httpResponse.statusCode)",
      ])
    }

    let decodedResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
    guard let text = decodedResponse.extractedText, !text.isEmpty else {
      throw URLError(.cannotParseResponse, userInfo: [
        NSLocalizedDescriptionKey: "No text content found in response.",
      ])
    }

    return text
  }
}

// MARK: - Encodable Structs for Request

struct GenerateContentRequest: Encodable {
  var contents: [Content]

  struct Content: Encodable {
    var role: String
    var parts: [Part]

    struct Part: Encodable {
      var text: String
    }
  }
}

// MARK: - Decodable Struct for Non-Streaming Gemini Response

struct GeminiResponse: Decodable {
  let candidates: [Candidate]?

  struct Candidate: Decodable {
    let content: Content?
    let finishReason: String?

    struct Content: Decodable {
      let parts: [Part]?

      struct Part: Decodable {
        let text: String?
        let thought: Bool?
      }
    }
  }

  /// Extracts non-thinking text parts from the first candidate.
  var extractedText: String? {
    guard let parts = candidates?.first?.content?.parts else { return nil }
    let nonThoughtTexts = parts
      .filter { $0.thought != true }
      .compactMap(\.text)
    if !nonThoughtTexts.isEmpty {
      return nonThoughtTexts.joined()
    }
    return parts.compactMap(\.text).last
  }
}

struct GeminiErrorResponse: Decodable {
  struct ErrorDetail: Decodable {
    let code: Int?
    let message: String?
    let status: String?
  }

  let error: ErrorDetail?
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
