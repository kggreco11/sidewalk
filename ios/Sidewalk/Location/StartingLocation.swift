import CoreLocation
import MapKit

@MainActor
final class StartingLocation: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate
{
  @Published private(set) var busy = false
  @Published private(set) var message: String?
  private let manager: CLLocationManager
  private var timeout: Task<Void, Never>?
  private var completion: ((MKMapItem) -> Void)?
  init(manager: CLLocationManager? = nil) {
    self.manager = manager ?? CLLocationManager()
    super.init()
    self.manager.delegate = self
    self.manager.desiredAccuracy = kCLLocationAccuracyBest
  }
  func request(_ completion: @escaping (MKMapItem) -> Void) {
    cancel()
    self.completion = completion
    busy = true
    switch manager.authorizationStatus {
    case .notDetermined: manager.requestWhenInUseAuthorization()
    case .authorizedAlways, .authorizedWhenInUse: acquire()
    default: finish("Location is unavailable. Enable it in Settings or type a starting address.")
    }
  }
  private func acquire() {
    guard busy, timeout == nil else { return }
    manager.startUpdatingLocation()
    timeout = Task { [weak self] in
      do { try await Task.sleep(for: .seconds(15)) } catch { return }
      self?.finish("Location took too long. Type a starting address or try again.")
    }
  }
  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    guard busy else { return }
    switch manager.authorizationStatus {
    case .authorizedAlways, .authorizedWhenInUse: acquire()
    case .denied, .restricted: finish("Location is unavailable. You can type a starting address.")
    default: break
    }
  }
  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard busy, let fix = locations.last else { return }
    guard WalkingPath.usable(fix) else {
      message = "GPS is settling. Waiting for a precise starting point…"
      return
    }
    let callback = completion
    let item = MKMapItem(placemark: MKPlacemark(coordinate: fix.coordinate))
    item.name = "Current location"
    finish(nil)
    callback?(item)
  }
  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    guard busy else { return }
    if (error as? CLError)?.code == .locationUnknown { return }
    finish("Couldn’t get your location. Type an address or try again.")
  }
  func cancel() { finish(nil) }
  private func finish(_ message: String?) {
    timeout?.cancel()
    timeout = nil
    manager.stopUpdatingLocation()
    busy = false
    completion = nil
    self.message = message
  }
}
