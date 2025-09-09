import SwiftUI
import WidgetKit

struct ReviewWidgetView: View {
    var entry: ReviewWidgetProvider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let item = entry.reviewItem {
                Text(item.japanese)
                    .font(.largeTitle)

                Text(item.reading)
                    .font(.title2)
                    .foregroundColor(.gray)

                Text(item.meaning)
                    .font(.body)
            } else {
                Text("No review available.")
            }
        }
        .padding()
        .containerBackground(for: .widget) {
            Color(UIColor.systemBackground)
        }
    }
}
