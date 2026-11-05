import CoreLocation
import SwiftUI

@MainActor
final class VisitLocation: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
  @Published private(set) var checking = false
  @Published private(set) var message: String?
  @Published private(set) var canOpenSettings = false
  private let manager: CLLocationManager
  private var target: CLLocationCoordinate2D?
  private var completion: (() -> Void)?
  private var timeout: Task<Void, Never>?
  init(manager: CLLocationManager? = nil) {
    self.manager = manager ?? CLLocationManager()
    super.init()
    self.manager.delegate = self
    self.manager.desiredAccuracy = kCLLocationAccuracyBest
  }
  func verify(_ place: Place, preferredFix: CLLocation? = nil, onArrival: @escaping () -> Void) {
    guard !checking else { return }
    cancel()
    target = place.coordinate
    completion = onArrival
    checking = true
    canOpenSettings = false
    if let preferredFix, ArrivalPolicy.canVerify(preferredFix, at: place.coordinate) {
      succeed()
      return
    }
    switch manager.authorizationStatus {
    case .notDetermined:
      message = "Allow location to verify this visit."
      manager.requestWhenInUseAuthorization()
    case .authorizedAlways, .authorizedWhenInUse: acquire()
    case .restricted:
      finish("Location is restricted on this iPhone. You can still keep a personal note.")
    default:
      canOpenSettings = true
      finish("Enable location to earn a verified stamp. You can save a note without it.")
    }
  }
  private func acquire() {
    guard checking, timeout == nil else { return }
    message = "Finding a precise location…"
    manager.startUpdatingLocation()
    timeout = Task { [weak self] in
      do { try await Task.sleep(for: .seconds(20)) } catch { return }
      self?.finish("Couldn’t confirm a precise location yet. Try again, or keep a personal note.")
    }
  }
  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    guard checking else { return }
    switch manager.authorizationStatus {
    case .authorizedAlways, .authorizedWhenInUse: acquire()
    case .denied:
      canOpenSettings = true
      finish("Location is off. You can still read the story and save a note.")
    case .restricted: finish("Location is restricted. You can still save a personal note.")
    default: break
    }
  }
  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard checking, let fix = locations.last, let target else { return }
    guard WalkingPath.usable(fix) else {
      message = "GPS is settling. Waiting for a more accurate location…"
      canOpenSettings = manager.accuracyAuthorization == .reducedAccuracy
      return
    }
    if ArrivalPolicy.canVerify(fix, at: target) {
      succeed()
    } else {
      finish(
        "You’re about \(WalkNavigation.distance(ArrivalPolicy.distance(fix, to: target))) away. Check in within 75 m from a public path."
      )
    }
  }
  private func succeed() {
    let callback = completion
    finish(nil)
    callback?()
  }
  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    guard checking else { return }
    if (error as? CLError)?.code == .locationUnknown {
      message = "Still finding your location…"
      return
    }
    finish("Location is unavailable. Try again or save a personal note.")
  }
  func cancel() { finish(nil) }
  private func finish(_ message: String?) {
    timeout?.cancel()
    timeout = nil
    manager.stopUpdatingLocation()
    checking = false
    completion = nil
    target = nil
    self.message = message
  }
}

struct ArrivalUnlock: View {
  @EnvironmentObject private var guide: FieldGuide
  @Environment(\.scenePhase) private var scenePhase
  @StateObject private var location = VisitLocation()
  let place: Place
  var preferredFix: CLLocation? = nil
  var recordID: UUID? = nil
  var onCollected: ((UUID) -> Void)? = nil
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Label("Collect a visit stamp", systemImage: "sparkle").font(.headline)
      Text("Check in within 75 m. Notes and stories are always available.").font(.subheadline)
        .foregroundStyle(FieldStyle.secondary)
      Button {
        location.verify(place, preferredFix: preferredFix) {
          if let identity = guide.verifyVisit(place, recordID: recordID) { onCollected?(identity) }
        }
      } label: {
        HStack(spacing: 10) {
          if location.checking {
            ProgressView().tint(paper)
          } else {
            Image(systemName: "location.fill")
          }
          Text(location.checking ? "Checking location…" : "Check in")
        }
      }.buttonStyle(FieldPrimaryButtonStyle()).disabled(location.checking)
      if let message = location.message {
        Text(message).font(.callout).accessibilityIdentifier("check-in-status")
      }
      if location.canOpenSettings {
        Button("Open Settings") {
          UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
        }.frame(minHeight: 44)
      }
      if let error = guide.error { Text(error).font(.callout).foregroundStyle(FieldStyle.clay) }
    }.padding(.vertical, 8).onDisappear { location.cancel() }
      .onChange(of: scenePhase) { _, phase in if phase == .background { location.cancel() } }
  }
}
