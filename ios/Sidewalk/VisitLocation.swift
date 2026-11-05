import SwiftUI
import CoreLocation

/// A foreground, user-requested fix. Coordinates are never persisted.
@MainActor final class VisitLocation: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
    @Published var checking = false
    @Published var message: String?
    private let manager = CLLocationManager()
    private var target: CLLocation?
    private var completion: (() -> Void)?
    private var timeout: Task<Void, Never>?

    override init() { super.init(); manager.delegate = self; manager.desiredAccuracy = kCLLocationAccuracyBest }

    func verify(_ place: Place, onArrival: @escaping () -> Void) {
        guard !checking else { return }
        target = CLLocation(latitude: place.lat, longitude: place.lng)
        completion = onArrival; checking = true; message = nil
        timeout = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(20)) } catch { return }
            self?.finish("Location took too long. Try again with a clear view of the sky.")
        }
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse: manager.requestLocation()
        default: finish("Allow location for Sidewalk in Settings to unlock this story.")
        }
    }
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard checking else { return }
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse: manager.requestLocation()
        case .denied, .restricted: finish("Allow location for Sidewalk in Settings to unlock this story.")
        default: break
        }
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard checking, let fix = locations.last, let target else { return }
        let age = Date().timeIntervalSince(fix.timestamp)
        guard age >= -1, age <= 15, fix.horizontalAccuracy >= 0, fix.horizontalAccuracy <= 35 else {
            finish("GPS is still a little fuzzy. Enable Precise Location and try again outdoors."); return
        }
        let distance = fix.distance(from: target)
        guard distance <= 75, distance + fix.horizontalAccuracy <= 100 else {
            finish("You’re about \(Int(distance.rounded())) m away. Check in within 75 m from a public path."); return
        }
        let arrived = completion
        finish(nil)
        arrived?()
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard checking else { return }
        finish("Couldn’t confirm your location. Try again outdoors.")
    }
    func cancel() { finish(nil) }
    private func finish(_ text: String?) {
        timeout?.cancel(); timeout = nil; manager.stopUpdatingLocation()
        checking = false; message = text; completion = nil; target = nil
    }
}

struct ArrivalUnlock: View {
    @EnvironmentObject var guide: FieldGuide
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var location = VisitLocation()
    let place: Place
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Unlock this story", systemImage: "sparkle").font(.headline)
            Text("Visit this place to unlock its story. Check in within 75 m.").font(.body)
            Button {
                location.verify(place) { guide.unlock(place) }
            } label: {
                HStack { Text(location.checking ? "Checking location…" : "I’m here · unlock story"); Spacer(); if location.checking { ProgressView().tint(paper) } else { Image(systemName: "location") } }
                    .frame(minHeight: 52)
            }.foregroundStyle(paper).buttonStyle(FieldPrimaryButtonStyle()).disabled(location.checking)
            if let message = location.message { Text(message).font(.body).accessibilityLabel(message) }
            Text("Stay on a public path. Location is checked on your device.").font(.subheadline).foregroundStyle(.secondary)
        }.padding(16).background(ink.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
            .onDisappear { location.cancel() }
            .onChange(of: scenePhase) { _, phase in if phase == .background { location.cancel() } }
    }
}
