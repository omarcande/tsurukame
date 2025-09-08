import SwiftUI
import WidgetKit
import WaniKaniAPI

struct ReviewWidgetView: View {
    var entry: ReviewWidgetProvider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let subject = entry.subject {
                Text(subject.japanese)
                    .font(.largeTitle)

                if let reading = subject.primaryReading {
                    Text(reading.reading)
                        .font(.title2)
                        .foregroundColor(.gray)
                }

                if let meaning = subject.primaryMeaning {
                    Text(meaning.meaning)
                        .font(.body)
                }
            } else {
                Text("No review available.")
            }
        }
        .padding()
    }
}

extension TKMSubject {
    var primaryReading: TKMReading? {
        readings.first(where: { $0.isPrimary })
    }

    var primaryMeaning: TKMMeaning? {
        meanings.first(where: { $0.type == .primary })
    }
}
