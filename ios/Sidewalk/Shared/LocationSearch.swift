import MapKit
import SwiftUI

struct LocationSuggestions: View {
  let query: String
  let places: [Place]
  let select: (MKMapItem, Place?) -> Void
  @State private var results: [MKMapItem] = []
  @State private var loading = false
  @State private var error: String?
  @State private var searched = false
  private var curated: [Place] {
    let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
    return Array(
      places.filter {
        term.isEmpty || ($0.name + " " + ($0.address ?? "")).localizedCaseInsensitiveContains(term)
      }.prefix(term.isEmpty ? 6 : 8))
  }

  var body: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 0) {
        if !curated.isEmpty {
          Section("From the field guide") {
            ForEach(curated) { place in
              Button {
                let item = MKMapItem(placemark: MKPlacemark(coordinate: place.coordinate))
                item.name = place.name
                select(item, place)
              } label: {
                row(place.name, place.address ?? place.kind)
              }
            }
          }
        }
        if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          if loading {
            HStack {
              ProgressView()
              Text("Searching places…")
            }
          }
          if let error { Text(error).foregroundStyle(.secondary) }
          ForEach(Array(results.enumerated()), id: \.offset) { _, item in
            Button {
              select(item, PlaceIdentity.match(item, in: places))
            } label: {
              row(item.name ?? "Place", item.placemark.title ?? "")
            }
          }
          if searched && !loading && results.isEmpty && curated.isEmpty && error == nil {
            ContentUnavailableView.search(text: query)
          }
        }
      }.padding(.horizontal, 16)
    }.frame(maxHeight: 260).background(paper).tint(ink)
      .scrollDismissesKeyboard(.interactively)
      .task(id: query) { await search() }
  }
  private func row(_ name: String, _ address: String) -> some View {
    HStack(spacing: 14) {
      Image(systemName: "mappin.circle").font(.title2).frame(width: 32)
      VStack(alignment: .leading, spacing: 6) {
        Text(name).font(.headline).foregroundStyle(ink)
        Text(address).font(.subheadline).foregroundStyle(.secondary).fixedSize(
          horizontal: false, vertical: true)
      }
    }.padding(.vertical, 8).frame(maxWidth: .infinity, alignment: .leading).contentShape(
      Rectangle())
  }
  @MainActor private func search() async {
    let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
    results = []
    error = nil
    searched = false
    loading = !term.isEmpty
    guard !term.isEmpty else { return }
    do {
      try await Task.sleep(for: .milliseconds(300))
      try Task.checkCancellation()
      let request = MKLocalSearch.Request()
      request.naturalLanguageQuery = term
      request.resultTypes = [.address, .pointOfInterest]
      request.region = MKCoordinateRegion(
        center: .init(latitude: 37.775, longitude: -122.438),
        span: .init(latitudeDelta: 0.15, longitudeDelta: 0.15))
      let search = MKLocalSearch(request: request)
      let response = try await withTaskCancellationHandler {
        try await search.start()
      } onCancel: {
        search.cancel()
      }
      try Task.checkCancellation()
      results = response.mapItems
      loading = false
      searched = true
    } catch {
      guard !Task.isCancelled else { return }
      loading = false
      searched = true
      self.error = "Couldn’t search places. Check your connection or try another search."
    }
  }
}

enum RouteSearchField: String, Identifiable {
  case origin, destination
  var id: String { rawValue }
  var title: String { self == .origin ? "Starting point" : "Where to?" }
}
