import MapKit
import SwiftUI

enum WalkingLocationState: Equatable {
  case waiting, tracking, imprecise, denied, restricted, unavailable, paused
  var title: String {
    switch self {
    case .waiting: return "Locating…"
    case .tracking: return "Walking"
    case .imprecise: return "GPS is settling"
    case .denied: return "Location off"
    case .restricted: return "Location restricted"
    case .unavailable: return "GPS unavailable"
    case .paused: return "Walk paused"
    }
  }
  var message: String? {
    switch self {
    case .waiting: return "Finding your position…"
    case .tracking: return nil
    case .imprecise: return "Waiting for precise GPS. The path and directions remain available."
    case .denied: return "Location is off. Enable it to follow your position."
    case .restricted:
      return "Location is restricted on this iPhone. You can still read the directions."
    case .unavailable: return "GPS is unavailable. Directions will resume when it returns."
    case .paused: return "Walk paused. Your stops and directions are saved."
    }
  }
}

@MainActor
final class WalkNavigation: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
  @Published private(set) var running = false
  @Published private(set) var fix: CLLocation?
  @Published private(set) var progress: WalkingProgress?
  @Published private(set) var state: WalkingLocationState = .paused
  @Published var recenter = 0
  @Published var overview = true
  @Published var following = false
  @Published var backgroundEnabled =
    UserDefaults.standard.object(forKey: "backgroundGuidance") as? Bool ?? true
  {
    didSet {
      UserDefaults.standard.set(backgroundEnabled, forKey: "backgroundGuidance")
      manager.allowsBackgroundLocationUpdates =
        running && backgroundEnabled && Self.backgroundConfigured
    }
  }
  @Published var haptics = UserDefaults.standard.bool(forKey: "walkingHaptics") {
    didSet { UserDefaults.standard.set(haptics, forKey: "walkingHaptics") }
  }
  private let manager: CLLocationManager
  private var tracker: ProgressTracker?
  private var target: CLLocationCoordinate2D?
  private var freshness: Task<Void, Never>?
  private var startedAt = Date()
  private var lastAnnouncement = Date.distantPast
  private var announced = ""
  private var approachNotified = false
  private var arrivalNotified = false
  var onCheckpoint: ((Double) -> Void)?
  private static var backgroundConfigured: Bool {
    (Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String])?.contains(
      "location") == true
  }
  var canContinueInBackground: Bool {
    running && backgroundEnabled && Self.backgroundConfigured
      && (manager.authorizationStatus == .authorizedAlways
        || manager.authorizationStatus == .authorizedWhenInUse)
  }
  var canOpenSettings: Bool { state == .denied || state == .imprecise }
  var remaining: Double? { progress?.remaining }
  var live: Bool { state == .tracking && (fix.map { WalkingPath.usable($0) } ?? false) }
  init(manager: CLLocationManager? = nil) {
    self.manager = manager ?? CLLocationManager()
    super.init()
    self.manager.delegate = self
    self.manager.desiredAccuracy = kCLLocationAccuracyBest
    self.manager.distanceFilter = kCLDistanceFilterNone
    self.manager.activityType = .fitness
    self.manager.pausesLocationUpdatesAutomatically = false
    self.manager.showsBackgroundLocationIndicator = true
  }
  func start(_ leg: WalkingLeg, target: CLLocationCoordinate2D, seedProgress: Double? = nil) {
    freshness?.cancel()
    manager.stopUpdatingLocation()
    if tracker?.leg.id != leg.id {
      tracker = ProgressTracker(leg: leg, seedProgress: seedProgress)
      progress = nil
      approachNotified = false
      arrivalNotified = false
    }
    self.target = target
    running = true
    fix = nil
    state = .waiting
    startedAt = Date()
    overview = false
    recenter += 1
    manager.allowsBackgroundLocationUpdates = backgroundEnabled && Self.backgroundConfigured
    authorize()
    freshness = Task { [weak self] in
      while !Task.isCancelled {
        do { try await Task.sleep(for: .seconds(5)) } catch { return }
        guard let self, self.running else { return }
        guard self.state != .denied, self.state != .restricted else { continue }
        if let fix = self.fix, !WalkingPath.usable(fix) {
          self.fix = nil
          self.state = .unavailable
        } else if self.fix == nil, Date().timeIntervalSince(self.startedAt) > 20,
          self.state == .waiting
        {
          self.state = .unavailable
        }
      }
    }
  }
  func stop() {
    freshness?.cancel()
    freshness = nil
    manager.stopUpdatingLocation()
    running = false
    fix = nil
    state = .paused
    following = false
    manager.allowsBackgroundLocationUpdates = false
    onCheckpoint = nil
  }
  private func authorize() {
    switch manager.authorizationStatus {
    case .notDetermined: manager.requestWhenInUseAuthorization()
    case .authorizedAlways, .authorizedWhenInUse: manager.startUpdatingLocation()
    case .restricted:
      state = .restricted
      fix = nil
      overview = true
    default:
      state = .denied
      fix = nil
      overview = true
    }
  }
  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    if running { authorize() }
  }
  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard running, let newest = locations.last, let target else { return }
    guard WalkingPath.usable(newest) else {
      fix = nil
      state = .imprecise
      return
    }
    guard let updated = tracker?.update(newest, target: target) else { return }
    let justApproached = updated.approaching && !approachNotified
    let justArrived = updated.arrived && !arrivalNotified
    if justApproached { approachNotified = true }
    if justArrived { arrivalNotified = true }
    fix = newest
    progress = updated
    state = .tracking
    if !updated.offRoute { onCheckpoint?(updated.along) }
    if haptics && (justApproached || justArrived) {
      UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    if UIApplication.shared.applicationState == .active, UIAccessibility.isVoiceOverRunning,
      updated.instruction != announced, Date().timeIntervalSince(lastAnnouncement) >= 10
    {
      UIAccessibility.post(notification: .announcement, argument: updated.instruction)
      announced = updated.instruction
      lastAnnouncement = Date()
    }
  }
  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    guard running else { return }
    if (error as? CLError)?.code == .locationUnknown { return }
    fix = nil
    state = .unavailable
  }
  static func distance(_ metres: Double) -> String {
    guard metres.isFinite else { return "—" }
    return metres < 1000
      ? "\(max(0, Int((metres / 5).rounded()) * 5)) m" : String(format: "%.1f km", metres / 1000)
  }
}
