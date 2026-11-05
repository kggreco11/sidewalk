import SwiftUI

struct StopStory: View {
  @Environment(\.dismiss) private var dismiss
  let stop: TourStop
  var continueWalk: (() -> Void)? = nil
  var collect: (() -> Void)? = nil
  var keepNote: (() -> Void)? = nil
  var lastStop = false
  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          if let place = stop.place {
            PlaceCover(place: place).frame(height: 210).clipped().clipShape(
              RoundedRectangle(cornerRadius: 20)
            ).accessibilityHidden(true)
          }
          Text(stop.point.name).font(.system(.largeTitle, design: .serif).weight(.semibold))
          if let place = stop.place {
            if let teaser = place.teaser, !teaser.isEmpty, teaser != place.story {
              Text(teaser).font(.headline).lineSpacing(4)
            }
            if let address = place.address {
              Label(address, systemImage: "mappin").font(.subheadline).foregroundStyle(
                FieldStyle.secondary)
            }
            Text(place.story).font(.system(.body, design: .serif)).lineSpacing(6).textSelection(
              .enabled)
            DisclosureGroup("Sources & photo credits") {
              VStack(alignment: .leading, spacing: 12) {
                if let url = URL(string: place.source), url.scheme == "https" {
                  Link(place.sourceName, destination: url).frame(minHeight: 44)
                }
                if let credit = place.imageCredit, let source = place.imageSource,
                  let url = URL(string: source), url.scheme == "https"
                {
                  Link(credit, destination: url).frame(minHeight: 44)
                }
                if let license = place.imageLicenseUrl, let url = URL(string: license),
                  url.scheme == "https"
                {
                  Link("Photo license · cropped to fit", destination: url).frame(minHeight: 44)
                }
              }.font(.subheadline).padding(.top, 8)
            }.font(.subheadline)
          } else {
            Text("Your final destination. Check the address and use a public entrance.").font(.body)
          }
        }.padding(20)
      }.background(paper).foregroundStyle(ink).navigationTitle("At this stop")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { Button("Done") { dismiss() } }
        .safeAreaInset(edge: .bottom) {
          VStack(spacing: 8) {
            HStack {
              if let collect { Button("Check in", action: collect).frame(minHeight: 44) }
              Spacer()
              if let keepNote { Button("Note / photo", action: keepNote).frame(minHeight: 44) }
            }
            Button(continueWalk == nil ? "Back to walk" : lastStop ? "Finish walk" : "Continue") {
              if let continueWalk { continueWalk() } else { dismiss() }
            }.buttonStyle(FieldPrimaryButtonStyle())
            if continueWalk != nil, stop.verifiedAt == nil {
              Text("Continuing records a visit without a verified stamp.").font(.caption)
                .foregroundStyle(FieldStyle.secondary)
            }
          }.padding(16).background(paper)
        }
    }
  }
}
