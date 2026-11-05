import SwiftUI

struct PlaceDetail: View {
  @EnvironmentObject private var guide: FieldGuide
  @Environment(\.dismiss) private var dismiss
  @State private var checkIn = false
  let place: Place
  var actionTitle = "Walk here"
  var actionSymbol = "figure.walk"
  let walk: () -> Void
  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          PlaceCover(place: place).frame(height: 220).clipped().clipShape(
            RoundedRectangle(cornerRadius: 20)
          ).accessibilityHidden(true)
          VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
              Text(place.kind).font(.subheadline.weight(.medium)).foregroundStyle(
                FieldStyle.secondary)
              if guide.unlocked.contains(place.id) {
                Label("Collected", systemImage: "sparkle").font(.subheadline.weight(.medium))
                  .foregroundStyle(FieldStyle.clay)
              }
            }
            Text(place.name).font(.system(.largeTitle, design: .serif).weight(.semibold)).tracking(
              -0.5
            ).fixedSize(horizontal: false, vertical: true)
            if let address = place.address {
              Label(address, systemImage: "mappin").font(.subheadline).foregroundStyle(
                FieldStyle.secondary
              ).fixedSize(horizontal: false, vertical: true)
            }
          }
          Text(place.story).font(.system(.body, design: .serif)).lineSpacing(6).textSelection(
            .enabled)
          if guide.unlocked.contains(place.id) {
            Button {
              checkIn = true
            } label: {
              Label(
                guide.visits[place.id] == nil ? "Keep this moment" : "Edit field note",
                systemImage: "square.and.pencil"
              ).font(.headline).frame(maxWidth: .infinity, minHeight: 48).background(
                FieldStyle.inset, in: RoundedRectangle(cornerRadius: 12))
            }.buttonStyle(.plain)
          } else {
            ArrivalUnlock(place: place)
            Button {
              checkIn = true
            } label: {
              Label("Keep a personal note", systemImage: "square.and.pencil").frame(minHeight: 44)
            }.buttonStyle(.plain)
          }
          DisclosureGroup("Sources & photo credits") {
            VStack(alignment: .leading, spacing: 12) {
              if let url = URL(string: place.source), url.scheme == "https" {
                Link(place.sourceName, destination: url).frame(minHeight: 44, alignment: .leading)
              }
              if let credit = place.imageCredit, let source = place.imageSource,
                let url = URL(string: source), url.scheme == "https"
              {
                Link(credit, destination: url).frame(minHeight: 44, alignment: .leading)
              }
              if let license = place.imageLicenseUrl, let url = URL(string: license),
                url.scheme == "https"
              {
                Link("Photo license · cropped to fit", destination: url).frame(
                  minHeight: 44, alignment: .leading)
              }
            }.font(.subheadline).padding(.top, 8)
          }.font(.subheadline).foregroundStyle(FieldStyle.secondary)
        }.padding(20)
      }.background(paper)
        .safeAreaInset(edge: .bottom, spacing: 0) {
          HStack(spacing: 12) {
            Button(action: walk) { Label(actionTitle, systemImage: actionSymbol) }.buttonStyle(
              FieldPrimaryButtonStyle())
            FieldIconButton(
              symbol: guide.saved.contains(place.id) ? "bookmark.fill" : "bookmark",
              label: guide.saved.contains(place.id) ? "Unsave place" : "Save place"
            ) { guide.toggle(place) }
            .frame(width: 52, height: 52).background(
              FieldStyle.inset, in: RoundedRectangle(cornerRadius: 16))
          }.padding(.horizontal, 20).padding(.vertical, 12).background(paper)
        }
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        .toolbarBackground(paper, for: .navigationBar).toolbarBackground(
          .visible, for: .navigationBar
        )
        .sheet(isPresented: $checkIn) {
          CheckIn(
            place: place, recordID: guide.visitHistory.first(where: { $0.placeID == place.id })?.id
          ).environmentObject(guide)
        }
        .alert(
          "Couldn’t save",
          isPresented: Binding(get: { guide.error != nil }, set: { if !$0 { guide.error = nil } })
        ) {
          Button("OK") { guide.error = nil }
        } message: {
          Text(guide.error ?? "")
        }
    }.foregroundStyle(ink).presentationDragIndicator(.visible)
  }
}
