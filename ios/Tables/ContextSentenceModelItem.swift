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

import Accelerate
import AVFoundation
import Foundation
import SwiftUI
import WaniKaniAPI

private let kBlurKernelSize: CGFloat = 19
private let kBlurAlpha: CGFloat = 0.75
private let kRevealDuration: TimeInterval = 0.2

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
    rightButtonImage = Asset.baselineVolumeUpBlack24pt.image
    rightButtonCallback = { [unowned self] (_: AttributedModelCell) in
      self.readContextSentence()
    }
    rightButtonLongPressCallback = { [unowned self] (_: AttributedModelCell) in
      self.presentAITutor(with: japaneseText.string)
    }
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

  private func fallbackToAVSpeechSynthesizer() {
    if speechSynthesizer.isSpeaking {
      speechSynthesizer.stopSpeaking(at: .immediate)
    } else {
      let utterance = AVSpeechUtterance(string: japaneseText.string)
      utterance.voice = AVSpeechSynthesisVoice(language: "ja-JP")
      speechSynthesizer.speak(utterance)
    }
  }

  @objc private func readSentenceWithGoogleTTS() {
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

  @objc private func readContextSentence() {
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

  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)

    blurredOverlay = UIView()
    contentView.addSubview(blurredOverlay)
  }

  override func update() {
    super.update()

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
}

extension ContextSentenceModelCell: TTSAudioManagerDelegate, AVSpeechSynthesizerDelegate,
  VoicevoxClientDelegate {
  func ttsAudioManagerDidBeginTTSRetrieve() {
    rightButton?.setImage(Asset.baselineCloudDownloadBlack24pt.image, for: .normal)
  }

  func ttsAudioManagerDidFinishTTSRetrieve() {
    // noop
  }

  func ttsAudioManagerDidStartPlaying() {
    rightButton?.setImage(Asset.baselineStopBlack24pt.image, for: .normal)
  }

  func ttsAudioManagerDidPausePlaying() {
    // noop
  }

  func ttsAudioManagerDidFinishPlaying() {
    rightButton?.setImage(Asset.baselineVolumeUpBlack24pt.image, for: .normal)
  }

  func speechSynthesizer(_: AVSpeechSynthesizer, didStart _: AVSpeechUtterance) {
    rightButton?.setImage(Asset.baselineStopBlack24pt.image, for: .normal)
  }

  func speechSynthesizer(_: AVSpeechSynthesizer, didFinish _: AVSpeechUtterance) {
    rightButton?.setImage(Asset.baselineVolumeUpBlack24pt.image, for: .normal)
  }

  func speechSynthesizer(_: AVSpeechSynthesizer, didCancel _: AVSpeechUtterance) {
    rightButton?.setImage(Asset.baselineVolumeUpBlack24pt.image, for: .normal)
  }

  func voicevoxClientDidStartFetching() {
    rightButton?.isEnabled = false
  }

  func voicevoxClientDidStartPlaying() {
    rightButton?.isEnabled = true
    rightButton?.setImage(Asset.baselineStopBlack24pt.image, for: .normal)
  }

  func voicevoxClientDidFinishPlaying() {
    rightButton?.isEnabled = true
    rightButton?.setImage(Asset.baselineVolumeUpBlack24pt.image, for: .normal)
  }

  func voicevoxClientDidThrowError() {
    rightButton?.isEnabled = true
    rightButton?.setImage(Asset.baselineVolumeUpBlack24pt.image, for: .normal)
  }
}
