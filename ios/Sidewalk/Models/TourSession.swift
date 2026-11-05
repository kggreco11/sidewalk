import Foundation
import MapKit

struct RoutePoint: Codable, Equatable {
  var name: String
  var latitude: Double
  var longitude: Double
  var coordinate: CLLocationCoordinate2D { .init(latitude: latitude, longitude: longitude) }
  var mapItem: MKMapItem {
    let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
    item.name = name
    return item
  }
  init(name: String, coordinate: CLLocationCoordinate2D) {
    self.name = name
    latitude = coordinate.latitude
    longitude = coordinate.longitude
  }
  init(_ item: MKMapItem) {
    self.init(name: item.name ?? "Place", coordinate: item.placemark.coordinate)
  }
}

enum Maneuver: String, Codable {
  case start, straight, left, right, turnAround, arrive
  var symbol: String {
    switch self {
    case .start: return "location.north.fill"
    case .straight: return "arrow.up"
    case .left: return "arrow.turn.up.left"
    case .right: return "arrow.turn.up.right"
    case .turnAround: return "arrow.uturn.down"
    case .arrive: return "flag.checkered"
    }
  }
}

struct WalkingStep: Codable, Equatable, Identifiable {
  var id: Int
  var instruction: String
  var start: Double
  var maneuver: Maneuver
}

struct WalkingLeg: Codable, Equatable, Identifiable {
  var id = UUID()
  var origin: RoutePoint
  var destination: RoutePoint
  var points: [RoutePoint]
  var steps: [WalkingStep]
  var distance: Double
  var duration: Double
  var polyline: MKPolyline {
    let coordinates = points.map(\.coordinate)
    return MKPolyline(coordinates: coordinates, count: coordinates.count)
  }
  init(origin: RoutePoint, destination: RoutePoint, route: MKRoute) {
    self.origin = origin
    self.destination = destination
    points = (0..<route.polyline.pointCount).map {
      RoutePoint(name: "", coordinate: route.polyline.points()[$0].coordinate)
    }
    distance = route.distance
    duration = route.expectedTravelTime
    let length = WalkingPath(coordinates: points.map(\.coordinate)).length
    let scale = distance > 0 ? length / distance : 1
    var travelled = 0.0
    var priorBearing: Double?
    var output: [WalkingStep] = []
    for step in route.steps {
      let geometry = (0..<step.polyline.pointCount).map { step.polyline.points()[$0].coordinate }
      if !step.instructions.isEmpty {
        let bearing = geometry.count > 1 ? Self.bearing(geometry[0], geometry[1]) : priorBearing
        var maneuver: Maneuver = output.isEmpty ? .start : .straight
        if let previous = priorBearing, let bearing {
          let change = (bearing - previous + 540).truncatingRemainder(dividingBy: 360) - 180
          if abs(change) > 145 {
            maneuver = .turnAround
          } else if change > 30 {
            maneuver = .right
          } else if change < -30 {
            maneuver = .left
          }
        }
        output.append(
          .init(
            id: output.count, instruction: step.instructions, start: travelled * scale,
            maneuver: maneuver))
      }
      if geometry.count > 1 {
        priorBearing = Self.bearing(geometry[geometry.count - 2], geometry[geometry.count - 1])
      }
      travelled += step.distance
    }
    steps =
      output.isEmpty
      ? [
        .init(id: 0, instruction: "Follow the highlighted walking path", start: 0, maneuver: .start)
      ] : output
  }
  init(
    origin: RoutePoint, destination: RoutePoint, points: [RoutePoint], steps: [WalkingStep],
    distance: Double, duration: Double
  ) {
    self.origin = origin
    self.destination = destination
    self.points = points
    self.steps = steps
    self.distance = distance
    self.duration = duration
  }
  static func bearing(_ origin: CLLocationCoordinate2D, _ destination: CLLocationCoordinate2D)
    -> Double
  {
    let first = origin.latitude * .pi / 180
    let second = destination.latitude * .pi / 180
    let delta = (destination.longitude - origin.longitude) * .pi / 180
    return atan2(
      sin(delta) * cos(second), cos(first) * sin(second) - sin(first) * cos(second) * cos(delta))
      * 180 / .pi
  }
}

enum StopStatus: String, Codable { case pending, visited, skipped }
struct TourStop: Codable, Identifiable, Equatable {
  var id: String
  var point: RoutePoint
  var place: Place?
  var status: StopStatus = .pending
  var visitedAt: Date?
  var verifiedAt: Date?
  var visitRecordID: UUID?
  init(point: RoutePoint, place: Place? = nil) {
    self.point = point
    self.place = place
    id = place?.id ?? "coordinate-\(point.latitude)-\(point.longitude)"
  }
  init(_ place: Place) {
    self.init(point: RoutePoint(name: place.name, coordinate: place.coordinate), place: place)
  }
}

enum TourPhase: String, Codable { case preview, walking, paused, finished }
struct TourSession: Codable, Identifiable, Equatable {
  var id = UUID()
  var origin: RoutePoint
  var stops: [TourStop]
  var legs: [WalkingLeg]
  var activeIndex = 0
  var legProgress: Double?
  var phase: TourPhase = .preview
  var createdAt = Date()
  var startedAt: Date?
  var finishedAt: Date?
  var walkingSeconds = 0.0
  var runningSince: Date?
  var pauseReason: String?
  var currentStop: TourStop? { stops.indices.contains(activeIndex) ? stops[activeIndex] : nil }
  var currentLeg: WalkingLeg? { legs.indices.contains(activeIndex) ? legs[activeIndex] : nil }
  var distance: Double {
    legs.enumerated().reduce(0) {
      $0 + (stops[$1.offset].status == .skipped ? 0 : $1.element.distance)
    }
  }
  var duration: Double {
    legs.enumerated().reduce(0) {
      $0 + (stops[$1.offset].status == .skipped ? 0 : $1.element.duration)
    }
  }
  var visitedCount: Int { stops.filter { $0.status == .visited }.count }
  var stampCount: Int { stops.filter { $0.verifiedAt != nil }.count }
  var skippedCount: Int { stops.filter { $0.status == .skipped }.count }
  func elapsed(at date: Date = Date()) -> Double {
    walkingSeconds + (runningSince.map { max(0, date.timeIntervalSince($0)) } ?? 0)
  }
  mutating func pause(reason: String?, at date: Date = Date()) {
    walkingSeconds = elapsed(at: date)
    runningSince = nil
    if phase == .walking { phase = .paused }
    pauseReason = reason
  }
}

enum PlaceIdentity {
  static func normalized(_ name: String) -> String {
    name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).filter(
      \.isLetter)
  }
  static func match(_ item: MKMapItem, in catalog: [Place]) -> Place? {
    let name = normalized(item.name ?? "")
    guard name.count >= 5 else { return nil }
    let location = CLLocation(
      latitude: item.placemark.coordinate.latitude, longitude: item.placemark.coordinate.longitude)
    let candidates = catalog.filter { place in
      let candidate = normalized(place.name)
      let named =
        candidate == name
        || (min(candidate.count, name.count) >= 8
          && (candidate.hasPrefix(name) || name.hasPrefix(candidate)))
      return named
        && location.distance(from: CLLocation(latitude: place.lat, longitude: place.lng)) <= 70
    }
    return candidates.count == 1 ? candidates[0] : nil
  }
}

enum TourSuggestions {
  static func stops(from origin: RoutePoint, to target: TourStop, catalog: [Place], count: Int)
    -> [TourStop]
  {
    guard count > 1 else { return [target] }
    let start = MKMapPoint(origin.coordinate)
    let end = MKMapPoint(target.point.coordinate)
    let deltaX = end.x - start.x
    let deltaY = end.y - start.y
    let denominator = deltaX * deltaX + deltaY * deltaY
    guard denominator > 0, start.distance(to: end) > 150 else { return [target] }
    var candidates: [(Place, Double, Double)] = []
    for place in catalog where place.id != target.id {
      let point = MKMapPoint(place.coordinate)
      let fraction = ((point.x - start.x) * deltaX + (point.y - start.y) * deltaY) / denominator
      guard (0.05...0.95).contains(fraction), point.distance(to: end) > 65 else { continue }
      let onLine = MKMapPoint(x: start.x + fraction * deltaX, y: start.y + fraction * deltaY)
      let offset = point.distance(to: onLine)
      if offset < 260 { candidates.append((place, fraction, offset)) }
    }
    var chosen: [(Place, Double, Double)] = []
    for slot in 1..<min(count, 6) {
      let desired = Double(slot) / Double(count)
      let remaining = candidates.filter { candidate in
        !chosen.contains { existing in
          existing.0.id == candidate.0.id
            || MKMapPoint(existing.0.coordinate).distance(to: MKMapPoint(candidate.0.coordinate))
              < 90
        }
      }
      let best = remaining.min { first, second in
        abs(first.1 - desired) * 800 + first.2 < abs(second.1 - desired) * 800 + second.2
      }
      if let best { chosen.append(best) }
    }
    return chosen.sorted { $0.1 < $1.1 }.map { TourStop($0.0) } + [target]
  }
}
