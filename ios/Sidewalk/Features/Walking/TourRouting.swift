import MapKit

@MainActor protocol TourRouting {
  func leg(from: RoutePoint, to: RoutePoint) async throws -> WalkingLeg
}
@MainActor struct AppleTourRouting: TourRouting {
  func leg(from: RoutePoint, to: RoutePoint) async throws -> WalkingLeg {
    let route = try await AppleWalkingService().route(from: from.mapItem, to: to.mapItem)
    guard route.polyline.pointCount > 1 else {
      throw RouteFailure("No walking path was returned for this stop.")
    }
    return WalkingLeg(origin: from, destination: to, route: route)
  }
}
