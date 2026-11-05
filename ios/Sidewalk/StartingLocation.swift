import CoreLocation
import MapKit

/// Requests a single foreground location only after the person taps the control.
@MainActor final class StartingLocation:NSObject,ObservableObject,@preconcurrency CLLocationManagerDelegate {
    @Published private(set) var busy=false
    @Published private(set) var message:String?
    private let manager=CLLocationManager()
    private var timeout:Task<Void,Never>?
    private var completion:((MKMapItem)->Void)?
    override init() {super.init();manager.delegate=self;manager.desiredAccuracy=kCLLocationAccuracyNearestTenMeters}
    func request(_ completion:@escaping (MKMapItem)->Void) {
        cancel();self.completion=completion;busy=true;message=nil
        timeout=Task {[weak self] in
            do {try await Task.sleep(for:.seconds(15))} catch {return}
            self?.finish("Location took too long. Enter a starting address instead.")
        }
        switch manager.authorizationStatus {
        case .notDetermined:manager.requestWhenInUseAuthorization()
        case .authorizedAlways,.authorizedWhenInUse:manager.requestLocation()
        default:finish("Location is unavailable. Allow it in Settings or enter a starting address.")
        }
    }
    func locationManagerDidChangeAuthorization(_ manager:CLLocationManager) {
        guard busy else {return}
        switch manager.authorizationStatus {
        case .authorizedAlways,.authorizedWhenInUse:manager.requestLocation()
        case .denied,.restricted:finish("Location is unavailable. Allow it in Settings or enter a starting address.")
        default:break
        }
    }
    func locationManager(_ manager:CLLocationManager,didUpdateLocations locations:[CLLocation]) {
        guard busy,let fix=locations.last else {return}
        let age=Date().timeIntervalSince(fix.timestamp)
        guard (-1...15).contains(age),(0...100).contains(fix.horizontalAccuracy) else {finish("Couldn’t get a clear location. Try outdoors or enter an address.");return}
        let callback=completion
        let item=MKMapItem(placemark:MKPlacemark(coordinate:fix.coordinate));item.name="Current location"
        finish(nil);callback?(item)
    }
    func locationManager(_ manager:CLLocationManager,didFailWithError error:Error) {if busy {finish("Couldn’t get your location. Enter an address or try again.")}}
    func cancel() {finish(nil)}
    private func finish(_ message:String?) {timeout?.cancel();timeout=nil;manager.stopUpdatingLocation();busy=false;completion=nil;self.message=message}
}
