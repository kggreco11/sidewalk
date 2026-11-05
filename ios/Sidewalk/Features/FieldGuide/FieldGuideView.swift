import SwiftUI

struct FieldGuideView: View {
  @EnvironmentObject private var guide: FieldGuide
  @EnvironmentObject private var tour: TourController
  @Environment(\.dynamicTypeSize) private var typeSize
  @Environment(\.dismiss) private var dismiss
  @State private var tab = 0
  @State private var selected: Place?
  @State private var pending: Place?
  let walk: (Place) -> Void
  private var places: [Place] {
    guide.places.filter {
      tab == 0
        ? guide.saved.contains($0.id) : guide.unlocked.contains($0.id) || guide.visits[$0.id] != nil
    }
    .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
  }
  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        HStack(alignment: .center, spacing: 12) {
          DiscoveryStar().fill(FieldStyle.clay).frame(width: 32, height: 32).accessibilityHidden(
            true)
          VStack(alignment: .leading, spacing: 4) {
            Text("Your field guide").font(.system(.title, design: .serif).weight(.semibold))
            Text("\(guide.unlocked.count) stamped · \(guide.saved.count) saved").font(.subheadline)
              .foregroundStyle(FieldStyle.secondary)
          }
          Spacer()
        }.padding(20)
        let tabs =
          typeSize.isAccessibilitySize
          ? AnyLayout(VStackLayout(spacing: 4)) : AnyLayout(HStackLayout(spacing: 4))
        tabs {
          ForEach(Array(["Saved", "Visits", "Walks"].enumerated()), id: \.offset) { index, title in
            Button {
              tab = index
            } label: {
              Text(title).font(.subheadline.weight(.semibold)).frame(
                maxWidth: .infinity, minHeight: 44
              ).background(tab == index ? paper : .clear, in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain).accessibilityAddTraits(tab == index ? .isSelected : [])
          }
        }.padding(4).background(FieldStyle.inset, in: RoundedRectangle(cornerRadius: 14)).padding(
          .horizontal, 20
        ).padding(.bottom, 12)
        if tab == 2 {
          if tour.history.isEmpty {
            ContentUnavailableView(
              "Your walks", systemImage: "figure.walk",
              description: Text("Completed walks and their moments will appear here."))
          } else {
            List(tour.history) { session in
              NavigationLink {
                ScrollView { WalkSummaryContent(session: session).padding(20) }.background(paper)
                  .navigationTitle("Your walk").navigationBarTitleDisplayMode(.inline)
              } label: {
                VStack(alignment: .leading, spacing: 8) {
                  Text(session.stops.last?.point.name ?? "Walking tour").font(
                    .system(.headline, design: .serif))
                  Text("\(session.visitedCount) visited · \(session.stampCount) stamped").font(
                    .subheadline)
                  Text(session.finishedAt ?? session.createdAt, style: .date).font(.subheadline)
                    .foregroundStyle(FieldStyle.secondary)
                }.padding(.vertical, 8)
              }
            }.listStyle(.plain)
          }
        } else if places.isEmpty {
          ContentUnavailableView(
            tab == 0 ? "Places for another day" : "Your first discovery awaits",
            systemImage: tab == 0 ? "bookmark" : "sparkle",
            description: Text(
              tab == 0
                ? "Save a place while exploring to keep it here."
                : "Visit a place and check in to collect a visit stamp."))
        } else {
          ScrollView {
            LazyVStack(spacing: 0) {
              ForEach(places) { place in
                PlaceRow(place: place) { selected = place }
                if tab == 1, let visit = guide.visits[place.id] {
                  VStack(alignment: .leading, spacing: 12) {
                    if !visit.note.isEmpty { Text(visit.note).font(.body).foregroundStyle(ink) }
                    if let data = visit.photo, let image = UIImage(data: data) {
                      Image(uiImage: image).resizable().scaledToFill().frame(height: 180).clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    Text(visit.date, style: .date).font(.caption).foregroundStyle(
                      FieldStyle.secondary)
                    if !guide.unlocked.contains(place.id) {
                      Text("Personal note · no verified stamp").font(.caption).foregroundStyle(
                        FieldStyle.secondary)
                    }
                    let history = guide.visitHistory.filter { $0.placeID == place.id }
                    if history.count > 1 {
                      DisclosureGroup("Past visits (\(history.count))") {
                        ForEach(history) { entry in
                          VStack(alignment: .leading, spacing: 6) {
                            Text(entry.date, style: .date).font(.subheadline.weight(.semibold))
                            Text(entry.verified ? "Verified visit" : "Personal note").font(.caption)
                            if !entry.note.isEmpty { Text(entry.note).font(.body) }
                          }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 8)
                        }
                      }
                    }
                  }.frame(maxWidth: .infinity, alignment: .leading).padding(.bottom, 16)
                }
                Divider()
              }
            }.padding(.horizontal, 20)
          }
        }
      }.background(paper).foregroundStyle(ink)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        .sheet(
          item: $selected,
          onDismiss: {
            if let place = pending {
              pending = nil
              walk(place)
            }
          }
        ) { place in
          PlaceDetail(
            place: place,
            actionTitle: tour.session != nil && tour.session?.phase != .finished
              ? "Add to walk" : "Walk here",
            actionSymbol: tour.session != nil && tour.session?.phase != .finished
              ? "plus" : "figure.walk"
          ) {
            pending = place
            selected = nil
          }.environmentObject(guide)
        }
    }
  }
}
