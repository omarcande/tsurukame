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

import Foundation
import SwiftUI
import UIKit

class SettingsViewController: UITableViewController, TKMViewController {
  private var services: TKMServices!
  private var model: TableModel?
  private var versionIndexPath: IndexPath?
  private var notificationHandler: ((Bool) -> Void)?

  func setup(services: TKMServices) {
    self.services = services
  }

  // MARK: - TKMViewController

  var canSwipeToGoBack: Bool { true }

  // MARK: - UIViewController

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    navigationController?.isNavigationBarHidden = false
    rerender()
  }

  private func rerender() {
    let model = MutableTableModel(tableView: tableView, delegate: self)

    model.add(section: "General")
    model.add(BasicModelItem(style: .default,
                             title: "Appearance & Notifications",
                             accessoryType: .disclosureIndicator) { [unowned self] in
        self.perform(segue: StoryboardSegue.Settings.appSettings, sender: self)
      })
    model.add(BasicModelItem(style: .default,
                             title: "Lessons",
                             accessoryType: .disclosureIndicator) { [unowned self] in
        self.perform(segue: StoryboardSegue.Settings.lessonSettings, sender: self)
      })
    model.add(BasicModelItem(style: .default,
                             title: "Reviews",
                             accessoryType: .disclosureIndicator) { [unowned self] in
        self.perform(segue: StoryboardSegue.Settings.reviewSettings, sender: self)
      })
    model.add(BasicModelItem(style: .default,
                             title: "Radicals, Kanji & Vocabulary",
                             accessoryType: .disclosureIndicator) { [unowned self] in
        self.perform(segue: StoryboardSegue.Settings.subjectDetailsSettings, sender: self)
      })

    model.add(section: "Features")
    model.add(BasicModelItem(style: .default,
                             title: "AI Tutor",
                             accessoryType: .disclosureIndicator) { [unowned self] in
        let vc = AITutorSettingsViewController()
        self.navigationController?.pushViewController(vc, animated: true)
      })
    model.add(BasicModelItem(style: .default,
                             title: "Voicevox",
                             accessoryType: .disclosureIndicator) { [unowned self] in
        let vc = VoicevoxSettingsViewController()
        self.navigationController?.pushViewController(vc, animated: true)
      })

    model.add(section: "Diagnostics")
    if let coreVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
       let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
      let version = "\(coreVersion).\(build)"
      versionIndexPath = model
        .add(BasicModelItem(style: .value1, title: "Version", subtitle: version,
                            accessoryType: .none))
    }
    model.add(BasicModelItem(style: .subtitle,
                             title: "Export local database",
                             subtitle: "To attach to bug reports or email to the developer",
                             accessoryType: .disclosureIndicator) { [unowned self] in
        didTapSendBugReport()
      })
    model.add(BasicModelItem(style: .subtitle,
                             title: "Clear avatar image cache",
                             subtitle: "If you are having issues with your avatar not loading, try clearing the image cache.",
                             accessoryType: .none) { [unowned self] in didTapClearImageCache() })

    model.addSection()
    let logOutItem = BasicModelItem(style: .default,
                                    title: "Log out",
                                    subtitle: nil,
                                    accessoryType: .none) { [unowned self] in didTapLogOut() }
    logOutItem.textColor = .systemRed
    model.add(logOutItem)

    self.model = model
    model.reloadTable()
  }

  override func prepare(for segue: UIStoryboardSegue, sender _: Any?) {
    switch StoryboardSegue.Settings(segue) {
    case .reviewSettings:
      let vc = segue.destination as! ReviewSettingsViewController
      vc.setup(services: services)

    default:
      break
    }
  }

  // MARK: - UITableViewController

  override func tableView(_: UITableView, shouldShowMenuForRowAt indexPath: IndexPath) -> Bool {
    indexPath == versionIndexPath
  }

  override func tableView(_: UITableView, canPerformAction action: Selector, forRowAt _: IndexPath,
                          withSender _: Any?) -> Bool {
    action == #selector(copy(_:))
  }

  override func tableView(_ tableView: UITableView, performAction action: Selector,
                          forRowAt indexPath: IndexPath, withSender _: Any?) {
    if action == #selector(copy(_:)) {
      let cell = tableView.cellForRow(at: indexPath)
      UIPasteboard.general.string = cell?.detailTextLabel?.text
    }
  }

  // MARK: - Tap handlers

  private func didTapLogOut() {
    let c = UIAlertController(title: "Are you sure?", message: nil, preferredStyle: .alert)
    c.addAction(UIAlertAction(title: "Log out", style: .destructive, handler: { _ in
      NotificationCenter.default.post(name: .logout, object: self)
    }))
    c.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
    present(c, animated: true, completion: nil)
  }

  private func didTapSendBugReport() {
    let c = UIActivityViewController(activityItems: [LocalCachingClient.databaseUrl()],
                                     applicationActivities: nil)
    present(c, animated: true, completion: nil)
  }

  private func didTapClearImageCache() {
    HNKCache.shared().removeAllImages()
    let c = UIAlertController(title: "Image cache cleared", message: nil, preferredStyle: .alert)
    c.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
    present(c, animated: true, completion: nil)
  }
}

class VoicevoxSettingsViewController: UITableViewController, TKMViewController {
  private var model: TableModel?

  init() {
    super.init(style: .insetGrouped)
    self.title = "Voicevox"
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private let kFontSize: CGFloat = {
    let bodyFontDescriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body)
    return bodyFontDescriptor.pointSize
  }()

  // MARK: - TKMViewController

  var canSwipeToGoBack: Bool { true }

  // MARK: - UIViewController

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    navigationController?.isNavigationBarHidden = false
    rerender()
  }

  private func rerender() {
    let model = MutableTableModel(tableView: tableView)

    model.add(section: "VOICEVOX URL")
    let voiceVoxURLItem =
      EditableTextModelItem(text: NSAttributedString(string: Settings.voicevoxURL),
                            placeholderText: "e.g. http://192.168.1.2:50021",
                            rightButtonImage: nil,
                            font: UIFont.systemFont(ofSize: kFontSize),
                            autoCapitalizationType: .none,
                            maximumNumberOfLines: 1)
    voiceVoxURLItem.textChangedCallback = { (text: String) in
      Settings.voicevoxURL = text
    }
    model.add(voiceVoxURLItem)

    model.add(section: "")
    model.add(BasicModelItem(style: .default,
                             title: "Voicevox Voices",
                             accessoryType: .disclosureIndicator) { [unowned self] in
        let vc = UIHostingController(rootView: VoicevoxVoiceSelectionView())
        self.navigationController?.pushViewController(vc, animated: true)
      })

    self.model = model
    model.reloadTable()
  }
}
