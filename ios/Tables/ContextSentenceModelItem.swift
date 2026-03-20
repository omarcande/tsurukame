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

import Accelerate
import AVFoundation
import Foundation
import SwiftUI
import WaniKaniAPI

private let kBlurKernelSize: CGFloat = 19
private let kBlurAlpha: CGFloat = 0.75
private let kRevealDuration: TimeInterval = 0.2
private let kRightMarginTextView: CGFloat = 54.0

enum RightButtonImageStyle: String {
  case downloading = "icloud.and.arrow.down"
  case stop = "stop.fill"
  case moreInfo = "info.bubble.fill"
  case play = "speaker.wave.2.bubble.fill"
  case ai = "sparkles"

  var image: UIImage? {
    UIImage(systemName: rawValue)
  }
}

enum RightButtonActionState {
  case menuAvailable
  case playingAudio
  case downloading
}

class ContextSentenceModelItem: AttributedModelItem {
  let japaneseText: NSAttributedString
  let englishText: NSAttributedString
  var blurred = Settings.blurContextSentences
  let speechSynthesizer = AVSpeechSynthesizer()
  let voicevox = VoicevoxClient()
  let ttsAudioManager = TTSAudioManager()

  init(_ sentence: TKMVocabulary.Sentence,
       highlightSubject: TKMSubject,
       defaultAttributes: [NSAttributedString.Key: Any],
       fontSize: CGFloat) {
    func attr(_ text: String) -> NSAttributedString {
      NSAttributedString(string: text, attributes: defaultAttributes)
    }

    // Build the attributed string normally.
    var text = NSMutableAttributedString()
    let japanese = highlightOccurrences(of: highlightSubject, in: attr(sentence.japanese)) ??
      attr(sentence.japanese)
    text.append(japanese)
    text.append(attr("\n"))
    text.append(attr(sentence.english))
    text = text.replaceFontSize(fontSize)

    // Now build the two parts individually so we can render them separately.  For the English text
    // we render the Japanese text on top in a transparent color so the English text is positioned
    // properly.
    let english = NSMutableAttributedString()
    english.append(NSAttributedString(string: sentence.japanese,
                                      attributes: [.foregroundColor: UIColor.clear]))
    english.append(attr("\n"))
    english.append(attr(sentence.english))
    englishText = english.replaceFontSize(fontSize)

    japaneseText = NSMutableAttributedString(attributedString: japanese).replaceFontSize(fontSize)

    super.init(text: text)
  }

  func initReader() {
    rightButtonImage = RightButtonImageStyle.moreInfo.image
  }

  func presentAITutor(with sentence: String) {
    guard let topVC = UIApplication.shared.windows.first(where: { $0.isKeyWindow })?
      .rootViewController else {
      return
    }
    let hostingController =
      UIHostingController(rootView: NavigationView { AITutorView(sentence: sentence) })
    hostingController.modalPresentationStyle = .fullScreen
    topVC.present(hostingController, animated: true, completion: nil)
  }

  func stopAudio() {
    if speechSynthesizer.isSpeaking {
      speechSynthesizer.stopSpeaking(at: .immediate)
    }

    if ttsAudioManager.isPlaying {
      ttsAudioManager.stop()
    }

    if voicevox.isPlaying() {
      voicevox.stopPlayback()
    }
  }

  private func fallbackToAVSpeechSynthesizer() {
    if speechSynthesizer.isSpeaking {
      speechSynthesizer.stopSpeaking(at: .immediate)
    } else {
      let utterance = AVSpeechUtterance(string: japaneseText.string)
      utterance.voice = AVSpeechSynthesisVoice(language: "ja-JP")
      speechSynthesizer.speak(utterance)
    }
  }

  private func readSentenceWithGoogleTTS() {
    if ttsAudioManager.isPlaying {
      ttsAudioManager.stop()
    }

    Task {
      do {
        guard let voiceData = try await ttsAudioManager
          .retrieveAudio(for: japaneseText.string)
        else {
          print("Error: Voice audio not available")
          fallbackToAVSpeechSynthesizer()
          return
        }
        ttsAudioManager.playAudio(from: voiceData)
      } catch {
        print("Error: \(error)")
        fallbackToAVSpeechSynthesizer()
      }
    }
  }

  func readContextSentence() {
    if voicevox.isPlaying() {
      voicevox.stopPlayback()
    } else {
      let selectedID = UserDefaults.standard.integer(forKey: "SelectedVoicevoxStyle")

      if !voicevox.speak(text: japaneseText.string,
                         voiceStyleId: selectedID,
                         completion: { error in
                           if error != nil {
                             self.readSentenceWithGoogleTTS()
                           }
                         }) {
        readSentenceWithGoogleTTS()
      }
    }
  }

  override var cellFactory: TableModelCellFactory {
    .fromDefaultConstructor(cellClass: ContextSentenceModelCell.self)
  }
}

private class ContextSentenceModelCell: AttributedModelCell {
  @TypedModelItem var contextSentenceItem: ContextSentenceModelItem

  var blurredOverlay: UIView!

  override var canBecomeFirstResponder: Bool { true }

  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)

    blurredOverlay = UIView()
    contentView.addSubview(blurredOverlay)
  }

  override func update() {
    super.update()

    updateRightButtonActionMenu()

    blurredOverlay.alpha = contextSentenceItem.blurred ? 1 : 0

    if contextSentenceItem.speechSynthesizer.delegate !== self {
      contextSentenceItem.speechSynthesizer.delegate = self
    }

    if contextSentenceItem.voicevox.delegate !== self {
      contextSentenceItem.voicevox.delegate = self
    }

    if contextSentenceItem.ttsAudioManager.delegate !== self {
      contextSentenceItem.ttsAudioManager.delegate = self
    }
  }

  override func layoutSubviews() {
    super.layoutSubviews()

    // since we're adding a context button to the right side of the cell, we need to adjust the
    // textView size to give the button space
    textView.frame.size.width = contentView.bounds.size.width - kRightMarginTextView

    let rect = contentView.bounds
    let size = rect.size

    // Render just the english text into an image.
    let englishCtx = CGContext.screenBitmap(size: size, screen: window!.screen)
    englishCtx.with {
      // Fill the image with a solid color so you can't see the underlying textView through it.
      TKMStyle.Color.cellBackground.setFill()
      UIRectFill(rect)
      englishCtx.setAlpha(kBlurAlpha)
      // draw the full attributed string as displayed by the text view with Japanese as clear text
      let mut = NSMutableAttributedString(attributedString: textView.attributedText)
      mut.addAttribute(NSAttributedString.Key.foregroundColor, value: UIColor.clear,
                       range: NSRange(location: 0,
                                      length: contextSentenceItem.japaneseText.length))
      mut.draw(in: textView.frame)
    }

    // Blur the english text.
    // The kernel size must be odd.
    var kernelSize = UInt32(UIFontMetrics.default.scaledValue(for: kBlurKernelSize))
    if kernelSize.isMultiple(of: 2) {
      kernelSize += 1
    }

    let blurredCtx = CGContext.screenBitmap(size: size, screen: window!.screen)
    englishCtx.blur(to: blurredCtx, kernelSize: kernelSize)

    // Render the Japanese text on top of the result.
    blurredCtx.with {
      contextSentenceItem.japaneseText.draw(with: textView.frame, options: .usesLineFragmentOrigin,
                                            context: nil)
    }

    // Position the overlay and set its contents to the image we just rendered.
    blurredOverlay.frame = rect
    blurredOverlay.layer.contents = blurredCtx.makeImage()!
  }

  override func didSelect() {
    contextSentenceItem.blurred = false
    UIView.animate(withDuration: kRevealDuration) {
      self.blurredOverlay.alpha = 0
    }
  }

  @objc func stopAudio() {
    contextSentenceItem.stopAudio()
    updateRightButtonActionMenu()
  }

  func updateRightButtonState(to state: RightButtonActionState) {
    switch state {
    case .menuAvailable:
      updateRightButtonActionMenu()
    case .playingAudio:
      updateRightButtonActionStop()
    case .downloading:
      updateRightButtonImage(to: .downloading)
      rightButton?.isEnabled = false
    }
  }

  private func updateRightButtonActionMenu() {
    let customMenu = UIMenu(title: "", options: [.displayInline], children: [
      UIAction(title: "Play Sentence Audio",
               image: RightButtonImageStyle.play.image) { [unowned self] _ in
        let item = contextSentenceItem
        item.readContextSentence()
      },
      UIAction(title: "Show AI Tutor",
               image: RightButtonImageStyle.ai.image) { [unowned self] _ in
        let item = self.contextSentenceItem
        let text = item.japaneseText.string
        item.presentAITutor(with: text)
      },
    ])

    // replace original button action
    rightButton?.removeTarget(self, action: nil,
                              for: .touchUpInside)

    // configure
    rightButton?.menu = customMenu
    rightButton?.showsMenuAsPrimaryAction = true
    rightButton?.setTitle(nil, for: .normal)
    updateRightButtonImage(to: .moreInfo)
  }

  private func updateRightButtonActionStop() {
    updateRightButtonImage(to: .stop)
    rightButton?.showsMenuAsPrimaryAction = false
    rightButton?.addTarget(self, action: #selector(stopAudio), for: .touchUpInside)
  }

  private func updateRightButtonImage(to style: RightButtonImageStyle) {
    rightButton?.setImage(style.image, for: .normal)
  }
}

extension ContextSentenceModelCell: TTSAudioManagerDelegate, AVSpeechSynthesizerDelegate,
  VoicevoxClientDelegate {
  func ttsAudioManagerDidBeginTTSRetrieve() {
    updateRightButtonState(to: .downloading)
  }

  func ttsAudioManagerDidFinishTTSRetrieve() {
    // noop
  }

  func ttsAudioManagerDidStartPlaying() {
    rightButton?.isEnabled = true
    updateRightButtonState(to: .playingAudio)
  }

  func ttsAudioManagerDidPausePlaying() {
    // noop
  }

  func ttsAudioManagerDidFinishPlaying() {
    updateRightButtonState(to: .menuAvailable)
  }

  func speechSynthesizer(_: AVSpeechSynthesizer, didStart _: AVSpeechUtterance) {
    updateRightButtonState(to: .playingAudio)
  }

  func speechSynthesizer(_: AVSpeechSynthesizer, didFinish _: AVSpeechUtterance) {
    updateRightButtonState(to: .menuAvailable)
  }

  func speechSynthesizer(_: AVSpeechSynthesizer, didCancel _: AVSpeechUtterance) {
    updateRightButtonState(to: .menuAvailable)
  }

  func voicevoxClientDidStartFetching() {
    rightButton?.isEnabled = false
  }

  func voicevoxClientDidStartPlaying() {
    rightButton?.isEnabled = true
    updateRightButtonState(to: .playingAudio)
  }

  func voicevoxClientDidFinishPlaying() {
    rightButton?.isEnabled = true
    updateRightButtonState(to: .menuAvailable)
  }

  func voicevoxClientDidThrowError() {
    rightButton?.isEnabled = true
    updateRightButtonState(to: .menuAvailable)
  }
}
