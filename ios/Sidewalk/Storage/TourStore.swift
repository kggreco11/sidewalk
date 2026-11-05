import Foundation
import MapKit

struct TourArchive: Codable {
  var current: TourSession?
  var history: [TourSession] = []
}
struct TourStore {
  let url: URL
  init(directory: URL? = nil) {
    let base =
      directory
      ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("Sidewalk")
    url = base.appendingPathComponent("tours-v1.json")
  }
  func load() throws -> TourArchive {
    guard FileManager.default.fileExists(atPath: url.path) else { return TourArchive() }
    let archive = try JSONDecoder().decode(TourArchive.self, from: Data(contentsOf: url))
    for session in [archive.current].compactMap({ $0 }) + archive.history {
      guard !session.stops.isEmpty, session.stops.count == session.legs.count,
        Set(session.stops.map(\.id)).count == session.stops.count,
        (0...session.stops.count).contains(session.activeIndex),
        session.phase == .finished || session.activeIndex < session.stops.count,
        session.legProgress.map({ $0.isFinite && $0 >= 0 }) ?? true,
        session.stops.allSatisfy({ CLLocationCoordinate2DIsValid($0.point.coordinate) }),
        session.legs.allSatisfy({
          $0.points.count >= 2
            && $0.points.allSatisfy { CLLocationCoordinate2DIsValid($0.coordinate) }
            && $0.distance.isFinite && $0.distance >= 0 && $0.duration.isFinite && $0.duration >= 0
        })
      else {
        throw CocoaError(.fileReadCorruptFile)
      }
    }
    return archive
  }
  func save(_ archive: TourArchive) throws {
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try JSONEncoder().encode(archive).write(
      to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
  }
}
