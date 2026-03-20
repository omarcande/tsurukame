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
import UIKit

class ContextAndNuancesModelItem: TableModelItem {
  let viewModel: ContextAndNuancesViewModel
  var font: UIFont

  init(viewModel: ContextAndNuancesViewModel, font: UIFont) {
    self.viewModel = viewModel
    self.font = font
  }

  var cellFactory: TableModelCellFactory {
    .fromFunction {
      ContextAndNuancesModelCell(style: .default, reuseIdentifier: "ContextAndNuancesModelCell")
    }
  }
}

class ContextAndNuancesModelCell: TableModelCell {
  @TypedModelItem var item: ContextAndNuancesModelItem

  let activityIndicator = UIActivityIndicatorView(style: .medium)
  let label = UILabel()

  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)

    selectionStyle = .none

    label.numberOfLines = 0
    label.translatesAutoresizingMaskIntoConstraints = false
    contentView.addSubview(label)

    activityIndicator.translatesAutoresizingMaskIntoConstraints = false
    activityIndicator.hidesWhenStopped = true
    contentView.addSubview(activityIndicator)

    NSLayoutConstraint.activate([
      label.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),
      label.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor),
      label.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
      label.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),

      activityIndicator.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
      activityIndicator.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
      activityIndicator.topAnchor
        .constraint(greaterThanOrEqualTo: contentView.layoutMarginsGuide.topAnchor,
                    constant: 10),
      activityIndicator.bottomAnchor
        .constraint(lessThanOrEqualTo: contentView.layoutMarginsGuide.bottomAnchor,
                    constant: -10),
    ])
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func update() {
    super.update()

    label.font = item.font

    item.viewModel.onStateChange = { [weak self] state in
      self?.updateState(state)
    }

    updateState(item.viewModel.state)

    if case .loading = item.viewModel.state {
      Task {
        await item.viewModel.fetchResponse()
      }
    }
  }

  private func updateState(_ state: ContextAndNuancesViewModel.State) {
    switch state {
    case .loading:
      activityIndicator.startAnimating()
      label.text = nil
    case let .success(text):
      activityIndicator.stopAnimating()
      label.text = text
      label.textColor = TKMStyle.Color.label

      triggerTableViewUpdate()
    case let .error(error):
      activityIndicator.stopAnimating()
      label.text = error
      label.textColor = TKMStyle.Color.grey33

      triggerTableViewUpdate()
    }
  }

  private func triggerTableViewUpdate() {
    var view: UIView? = self
    while let v = view {
      if let tv = v as? UITableView {
        tv.beginUpdates()
        tv.endUpdates()
        return
      }
      view = v.superview
    }
  }
}
