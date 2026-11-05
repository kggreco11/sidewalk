import Foundation
import MapKit

@MainActor protocol WalkingService {
  func search(_ query: String, addressesOnly: Bool) async throws -> [MKMapItem]
  func route(from: MKMapItem, to: MKMapItem) async throws -> MKRoute
}

@MainActor struct AppleWalkingService: WalkingService {
  func search(_ query: String, addressesOnly: Bool = false) async throws -> [MKMapItem] {
    let request = MKLocalSearch.Request()
    request.naturalLanguageQuery = query
    request.resultTypes = addressesOnly ? .address : [.address, .pointOfInterest]
    request.region = MKCoordinateRegion(
      center: .init(latitude: 37.775, longitude: -122.438),
      span: .init(latitudeDelta: 0.15, longitudeDelta: 0.15))
    let search = MKLocalSearch(request: request)
    return try await withTaskCancellationHandler {
      try await search.start().mapItems
    } onCancel: {
      search.cancel()
    }
  }
  func route(from: MKMapItem, to: MKMapItem) async throws -> MKRoute {
    let request = MKDirections.Request()
    request.source = from
    request.destination = to
    request.transportType = .walking
    let directions = MKDirections(request: request)
    let response = try await withTaskCancellationHandler {
      try await directions.calculate()
    } onCancel: {
      directions.cancel()
    }
    guard let route = response.routes.first else {
      throw RouteFailure("No walking route connects these places. Try a nearby starting point.")
    }
    return route
  }
}

struct RouteFailure: LocalizedError {
  let message: String
  init(_ message: String) { self.message = message }
  var errorDescription: String? { message }
}

@MainActor final class RoutePlannerModel: ObservableObject {
  @Published private(set) var originText = ""
  @Published private(set) var destinationText = ""
  @Published private(set) var origin: MKMapItem?
  @Published private(set) var destination: MKMapItem?
  @Published private(set) var place: Place?
  @Published private(set) var route: MKRoute?
  @Published private(set) var busy = false
  @Published private(set) var error: String?
  @Published var active = false
  private let service: any WalkingService
  var catalog: [Place] = []
  private var originPlace: Place?
  private var generation = UUID()
  private var work: Task<Void, Never>?
  var canPlan: Bool {
    !originText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && !destinationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  init(place: Place? = nil, service: (any WalkingService)? = nil) {
    self.service = service ?? AppleWalkingService()
    if let place {
      let item = MKMapItem(placemark: MKPlacemark(coordinate: place.coordinate))
      item.name = place.name
      self.place = place
      destination = item
      destinationText = place.name
    }
  }
  func text(for field: RouteSearchField) -> String {
    field == .origin ? originText : destinationText
  }
  func edit(_ field: RouteSearchField, text: String) {
    guard text != self.text(for: field) else { return }
    invalidate()
    if field == .origin {
      originText = text
      origin = nil
      originPlace = nil
    } else {
      destinationText = text
      destination = nil
      place = nil
    }
  }
  func choose(_ field: RouteSearchField, item: MKMapItem, place: Place? = nil) {
    invalidate()
    let identity = place ?? PlaceIdentity.match(item, in: catalog)
    if field == .origin {
      origin = item
      originText = item.name ?? item.placemark.title ?? "Starting point"
      originPlace = identity
    } else {
      destination = item
      destinationText = item.name ?? item.placemark.title ?? "Destination"
      self.place = identity
    }
  }
  func swap() {
    invalidate()
    (origin, destination) = (destination, origin)
    (originText, destinationText) = (destinationText, originText)
    (originPlace, place) = (place, originPlace)
  }
  func cancel() {
    work?.cancel()
    work = nil
    generation = UUID()
    busy = false
  }
  private func invalidate() {
    cancel()
    route = nil
    active = false
    error = nil
  }
  func startPlanning() {
    work?.cancel()
    work = Task { await plan() }
  }
  func plan() async {
    guard !Task.isCancelled else { return }
    guard canPlan else {
      error = "Enter a starting point and destination."
      return
    }
    let token = UUID()
    generation = token
    busy = true
    error = nil
    let from = originText.trimmingCharacters(in: .whitespacesAndNewlines)
    let to = destinationText.trimmingCharacters(in: .whitespacesAndNewlines)
    defer { if generation == token { busy = false } }
    do {
      let source: MKMapItem
      if let origin {
        source = origin
      } else {
        source = try await resolve(from, label: "starting point")
      }
      try Task.checkCancellation()
      guard generation == token else { return }
      origin = source
      originPlace = originPlace ?? PlaceIdentity.match(source, in: catalog)
      let end: MKMapItem
      if let destination {
        end = destination
      } else {
        end = try await resolve(to, label: "destination")
      }
      try Task.checkCancellation()
      guard generation == token else { return }
      destination = end
      place = place ?? PlaceIdentity.match(end, in: catalog)
      let result = try await service.route(from: source, to: end)
      try Task.checkCancellation()
      guard generation == token else { return }
      route = result
    } catch is CancellationError {
      // Superseded searches and closed screens never surface an error.
    } catch {
      guard generation == token else { return }
      self.error =
        (error as? RouteFailure)?.message
        ?? "Couldn’t load directions. Check your connection and try again."
    }
  }
  private func resolve(_ text: String, label: String) async throws -> MKMapItem {
    let results = try await service.search(text, addressesOnly: text.first?.isNumber == true)
    guard !results.isEmpty else {
      throw RouteFailure(
        "No match for that \(label). Include the street number and city, or select a suggestion.")
    }
    guard results.count == 1, let item = results.first else {
      throw RouteFailure(
        "More than one place matches your \(label). Tap the field and select the correct suggestion."
      )
    }
    return item
  }
  func openInMaps() {
    guard let origin, let destination else { return }
    MKMapItem.openMaps(
      with: [origin, destination],
      launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
  }
}
