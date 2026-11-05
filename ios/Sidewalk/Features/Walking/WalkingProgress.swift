import MapKit

struct WalkingPath {
  let points: [MKMapPoint]
  private let cumulative: [Double]
  var length: Double { cumulative.last ?? 0 }
  init(_ polyline: MKPolyline) {
    self.init(coordinates: (0..<polyline.pointCount).map { polyline.points()[$0].coordinate })
  }
  init(coordinates: [CLLocationCoordinate2D]) {
    points = coordinates.map(MKMapPoint.init)
    var lengths = [0.0]
    for (origin, destination) in zip(points, points.dropFirst()) {
      lengths.append(lengths.last! + origin.distance(to: destination))
    }
    cumulative = lengths
  }
  func project(
    _ coordinate: CLLocationCoordinate2D, near range: ClosedRange<Double>? = nil,
    course: Double? = nil
  ) -> (along: Double, away: Double) {
    let location = MKMapPoint(coordinate)
    var best = (along: 0.0, away: Double.infinity)
    var bestScore = Double.infinity
    for index in 0..<max(0, points.count - 1) {
      let origin = points[index]
      let destination = points[index + 1]
      let segmentLength = cumulative[index + 1] - cumulative[index]
      guard segmentLength > 0 else { continue }
      let lower = max(0, ((range?.lowerBound ?? 0) - cumulative[index]) / segmentLength)
      let upper = min(1, ((range?.upperBound ?? length) - cumulative[index]) / segmentLength)
      guard lower <= upper else { continue }
      let deltaX = destination.x - origin.x
      let deltaY = destination.y - origin.y
      let fraction = max(
        lower,
        min(
          upper,
          ((location.x - origin.x) * deltaX + (location.y - origin.y) * deltaY)
            / (deltaX * deltaX + deltaY * deltaY)))
      let nearest = MKMapPoint(x: origin.x + fraction * deltaX, y: origin.y + fraction * deltaY)
      let away = location.distance(to: nearest)
      var score = away
      if let course {
        let bearing = WalkingLeg.bearing(origin.coordinate, destination.coordinate)
        let difference = abs((bearing - course + 540).truncatingRemainder(dividingBy: 360) - 180)
        score += difference * 0.10
      }
      if score < bestScore {
        bestScore = score
        best = (cumulative[index] + fraction * segmentLength, away)
      }
    }
    return best
  }
  static func usable(_ fix: CLLocation, now: Date = Date()) -> Bool {
    (-1...15).contains(now.timeIntervalSince(fix.timestamp))
      && (0...35).contains(fix.horizontalAccuracy)
  }
}

enum ArrivalPolicy {
  static func distance(_ fix: CLLocation, to coordinate: CLLocationCoordinate2D) -> Double {
    fix.distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
  }
  static func canVerify(
    _ fix: CLLocation, at coordinate: CLLocationCoordinate2D, now: Date = Date()
  ) -> Bool {
    let distance = distance(fix, to: coordinate)
    return WalkingPath.usable(fix, now: now) && distance <= 75
      && distance + fix.horizontalAccuracy <= 100
  }
}

struct WalkingProgress {
  var along: Double
  var remaining: Double
  var distanceToPlace: Double
  var offRoute: Bool
  var approaching: Bool
  var nearby: Bool
  var arrived: Bool
  var instruction: String
  var upcoming: String?
  var maneuver: Maneuver
  var maneuverDistance: Double?
  var backtracking: Bool
}

struct ProgressTracker {
  let leg: WalkingLeg
  let path: WalkingPath
  private(set) var lastFix: CLLocation?
  private(set) var lastProgress: WalkingProgress?
  private var maneuverIndex = 0
  private var seedProgress: Double?
  init(leg: WalkingLeg, seedProgress: Double? = nil) {
    self.leg = leg
    path = WalkingPath(coordinates: leg.points.map(\.coordinate))
    self.seedProgress = seedProgress.flatMap { $0.isFinite ? min(path.length, max(0, $0)) : nil }
  }
  mutating func update(_ fix: CLLocation, target: CLLocationCoordinate2D, now: Date = Date())
    -> WalkingProgress?
  {
    guard WalkingPath.usable(fix, now: now), path.length > 0 else { return nil }
    var range: ClosedRange<Double>?
    if let seedProgress {
      range = max(0, min(path.length, seedProgress) - 80)...min(path.length, seedProgress + 80)
    }
    if let previous = lastProgress, let previousFix = lastFix {
      let movement = fix.distance(from: previousFix)
      let elapsed = max(0, fix.timestamp.timeIntervalSince(previousFix.timestamp))
      let allowance = min(
        max(35, movement * 1.7 + fix.horizontalAccuracy),
        max(45, elapsed * 3 + fix.horizontalAccuracy * 2))
      range = max(0, previous.along - allowance)...min(path.length, previous.along + allowance)
    }
    var course: Double?
    if fix.course >= 0, fix.speed >= 0.6 {
      course = fix.course
    } else if let prior = lastFix, fix.distance(from: prior) > 4 {
      course = WalkingLeg.bearing(prior.coordinate, fix.coordinate)
    }
    let projection = path.project(fix.coordinate, near: range, course: course)
    let distance = ArrivalPolicy.distance(fix, to: target)
    let offRoute = projection.away > max(45, fix.horizontalAccuracy + 20)
    let backwards = lastProgress.map { projection.along < $0.along - 18 } ?? false
    let steps = leg.steps
    if !offRoute {
      while maneuverIndex + 1 < steps.count,
        projection.along > steps[maneuverIndex + 1].start + max(12, fix.horizontalAccuracy + 5)
      { maneuverIndex += 1 }
      while maneuverIndex > 0, projection.along < steps[maneuverIndex].start - 30 {
        maneuverIndex -= 1
      }
    }
    let next = steps.indices.contains(maneuverIndex + 1) ? steps[maneuverIndex + 1] : nil
    let distanceToTurn = next.map { max(0, $0.start - projection.along) }
    let approachingTurn = next != nil && (distanceToTurn ?? .infinity) <= 60
    var instruction =
      maneuverIndex == 0
      ? (steps.first?.instruction ?? "Follow the highlighted path")
      : "Continue along the highlighted path"
    var maneuver: Maneuver = .straight
    var maneuverDistance: Double?
    if approachingTurn, let next {
      instruction = next.instruction
      maneuver = next.maneuver
      maneuverDistance = distanceToTurn
    }
    if backwards {
      instruction = "You’re heading back along the path"
      maneuver = .turnAround
    }
    let arrived = !offRoute && distance <= 40 && distance + fix.horizontalAccuracy <= 65
    if offRoute {
      instruction = "Return to the highlighted path"
      maneuverDistance = nil
    }
    if arrived {
      instruction = "You’re at the stop"
      maneuver = .arrive
      maneuverDistance = nil
    }
    let acceptedAlong = offRoute ? lastProgress?.along ?? 0 : projection.along
    let result = WalkingProgress(
      along: acceptedAlong, remaining: max(0, path.length - acceptedAlong),
      distanceToPlace: distance,
      offRoute: offRoute, approaching: !offRoute && distance <= 120,
      nearby: !offRoute && ArrivalPolicy.canVerify(fix, at: target, now: now), arrived: arrived,
      instruction: instruction, upcoming: approachingTurn ? nil : next?.instruction,
      maneuver: maneuver,
      maneuverDistance: maneuverDistance, backtracking: backwards)
    if !offRoute {
      lastProgress = result
      lastFix = fix
      seedProgress = nil
    }
    return result
  }
}
