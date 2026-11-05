import SwiftUI

struct WalkSummaryContent: View {
  @EnvironmentObject private var guide: FieldGuide
  let session: TourSession
  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      HStack {
        DiscoveryStar().fill(FieldStyle.clay).frame(width: 34, height: 34).accessibilityHidden(true)
        Text("Walk complete").font(.system(.title2, design: .serif).weight(.semibold))
      }
      Text(
        "\(session.visitedCount) visited · \(session.stampCount) stamped · \(session.skippedCount) skipped"
      ).font(.headline)
      Text(
        "\(Int(session.elapsed() / 60)) min active · \(WalkNavigation.distance(session.distance)) planned route"
      ).font(.subheadline).foregroundStyle(FieldStyle.secondary)
      ForEach(Array(session.stops.enumerated()), id: \.element.id) { index, stop in
        VStack(alignment: .leading, spacing: 10) {
          Label(
            "\(index + 1). \(stop.point.name)",
            systemImage: stop.verifiedAt != nil
              ? "checkmark.seal.fill"
              : stop.status == .visited
                ? "checkmark.circle" : stop.status == .skipped ? "forward.end" : "circle"
          ).font(.headline)
          Text(
            stop.verifiedAt != nil
              ? "Verified visit"
              : stop.status == .visited
                ? "Visited · no stamp" : stop.status == .skipped ? "Skipped" : "Not visited"
          ).font(.subheadline).foregroundStyle(FieldStyle.secondary)
          if let moment = guide.visitHistory.first(where: { $0.id == stop.visitRecordID }) {
            if !moment.note.isEmpty { Text(moment.note).font(.body) }
            if let data = moment.photo, let image = UIImage(data: data) {
              Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 180).clipShape(
                RoundedRectangle(cornerRadius: 12))
            }
          }
        }.frame(maxWidth: .infinity, alignment: .leading)
      }
    }
  }
}
