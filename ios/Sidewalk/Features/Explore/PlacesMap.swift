import MapKit
import SwiftUI

final class PlacePin: NSObject, MKAnnotation {
  let place: Place
  init(_ place: Place) { self.place = place }
  var coordinate: CLLocationCoordinate2D { place.coordinate }
  var title: String? { place.name }
}
final class TourPin: NSObject, MKAnnotation {
  let stop: TourStop
  let number: Int
  let active: Bool
  init(stop: TourStop, number: Int, active: Bool) {
    self.stop = stop
    self.number = number
    self.active = active
  }
  var coordinate: CLLocationCoordinate2D { stop.point.coordinate }
  var title: String? { "\(number). \(stop.point.name)" }
}
final class WalkingLine: MKPolyline {
  var emphasis = true
  var completed = false
}

struct PlacesMap: UIViewRepresentable {
  let places: [Place]
  let center: CLLocationCoordinate2D
  @Binding var selected: Place?
  var session: TourSession?
  var topInset: CGFloat = 80
  var bottomInset: CGFloat = 140
  var recenter = 0
  var navigating = false
  var followToken = 0
  var overview = true
  var onFollowing: (Bool) -> Void = { _ in }
  var onStopSelected: (TourStop) -> Void = { _ in }
  func makeCoordinator() -> Coordinator { Coordinator(self) }
  func makeUIView(context: Context) -> MKMapView {
    let map = MKMapView()
    map.delegate = context.coordinator
    map.register(MKMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: "place")
    map.register(
      MKMarkerAnnotationView.self,
      forAnnotationViewWithReuseIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier)
    map.pointOfInterestFilter = .excludingAll
    map.mapType = .mutedStandard
    map.showsCompass = true
    map.isPitchEnabled = false
    map.accessibilityIdentifier = "discovery-map"
    return map
  }
  func updateUIView(_ map: MKMapView, context: Context) {
    let coordinator = context.coordinator
    coordinator.parent = self
    map.layoutMargins = UIEdgeInsets(
      top: 0, left: 10, bottom: min(bottomInset + 10, map.bounds.height * 0.7), right: 10)
    let included = Set(session?.stops.map(\.id) ?? [])
    let discoveries = places.filter { !included.contains($0.id) }
    let pinsKey =
      discoveries.map(\.id).joined(separator: ",")
      + (session?.stops.enumerated().map {
        "\($0.element.id):\($0.element.status.rawValue):\($0.offset == session?.activeIndex)"
      }.joined() ?? "")
    if coordinator.pinsKey != pinsKey {
      coordinator.pinsKey = pinsKey
      map.removeAnnotations(map.annotations.filter { !($0 is MKUserLocation) })
      map.addAnnotations(discoveries.map(PlacePin.init))
      if let session {
        map.addAnnotations(
          session.stops.enumerated().map {
            TourPin(
              stop: $0.element, number: $0.offset + 1, active: $0.offset == session.activeIndex)
          })
        let start = MKPointAnnotation()
        start.title = "Start"
        start.coordinate = session.origin.coordinate
        map.addAnnotation(start)
      }
    }
    let routeKey =
      (session?.legs.map { $0.id.uuidString }.joined() ?? "")
      + "\(session?.activeIndex ?? -1):\(session?.phase.rawValue ?? "")"
    if coordinator.routeKey != routeKey {
      coordinator.routeKey = routeKey
      map.removeOverlays(map.overlays)
      if let session {
        for (index, leg) in session.legs.enumerated() {
          if session.stops[index].status == .skipped { continue }
          let coordinates = leg.points.map(\.coordinate)
          let line = WalkingLine(coordinates: coordinates, count: coordinates.count)
          line.emphasis = session.phase == .preview || index == session.activeIndex
          line.completed = index < session.activeIndex
          map.addOverlay(line)
        }
      }
    }
    map.showsUserLocation = navigating
    let cameraKey =
      "\(routeKey):\(overview):\(Int(map.bounds.width)):\(Int(map.bounds.height)):\(Int(topInset)):\(Int(bottomInset)):\(recenter)"
    if coordinator.cameraKey != cameraKey, map.bounds.width > 0 {
      coordinator.cameraKey = cameraKey
      if overview || session == nil {
        map.setUserTrackingMode(.none, animated: false)
        var rect = MKMapRect.null
        for leg in session?.legs ?? [] { rect = rect.union(leg.polyline.boundingMapRect) }
        if rect.isNull || rect.width + rect.height < 1 {
          let point = MKMapPoint(center)
          let width = 1800 * MKMapPointsPerMeterAtLatitude(center.latitude)
          rect = MKMapRect(
            x: point.x - width / 2, y: point.y - width / 2, width: width, height: width)
        }
        map.setVisibleMapRect(
          rect, edgePadding: UIEdgeInsets(top: topInset + 20, left: 28, bottom: 20, right: 28),
          animated: coordinator.hasFramed)
        coordinator.hasFramed = true
      }
    }
    if coordinator.followToken != followToken || coordinator.navigating != navigating
      || coordinator.overview != overview
    {
      coordinator.followToken = followToken
      coordinator.navigating = navigating
      coordinator.overview = overview
      if navigating && !overview {
        map.setUserTrackingMode(.follow, animated: true)
      } else {
        map.setUserTrackingMode(.none, animated: true)
      }
    }
  }
  class Coordinator: NSObject, MKMapViewDelegate {
    var parent: PlacesMap
    var pinsKey = "", routeKey = "", cameraKey = ""
    var followToken = 0
    var navigating = false, overview = true, hasFramed = false
    init(_ parent: PlacesMap) { self.parent = parent }
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
      let renderer = MKPolylineRenderer(overlay: overlay)
      let line = overlay as? WalkingLine
      renderer.strokeColor = UIColor(line?.emphasis == true ? ink : FieldStyle.sage.opacity(0.55))
      renderer.lineWidth = line?.emphasis == true ? 6 : 4
      if line?.emphasis != true { renderer.lineDashPattern = [4, 6] }
      return renderer
    }
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
      guard !(annotation is MKUserLocation) else { return nil }
      let cluster = annotation as? MKClusterAnnotation
      let view =
        mapView.dequeueReusableAnnotationView(
          withIdentifier: cluster == nil
            ? "place" : MKMapViewDefaultClusterAnnotationViewReuseIdentifier, for: annotation)
        as! MKMarkerAnnotationView
      view.glyphImage = nil
      view.glyphText = nil
      view.subtitleVisibility = .hidden
      if let pin = annotation as? TourPin {
        view.clusteringIdentifier = nil
        view.markerTintColor = UIColor(
          pin.stop.status == .skipped
            ? FieldStyle.secondary.opacity(0.45)
            : pin.stop.status == .visited ? FieldStyle.sage : pin.active ? FieldStyle.clay : ink)
        view.glyphText = "\(pin.number)"
        view.displayPriority = .required
        view.titleVisibility = .hidden
        view.accessibilityLabel =
          "Stop \(pin.number), \(pin.stop.point.name), \(pin.stop.status.rawValue)"
      } else if let cluster {
        view.markerTintColor = UIColor(ink.opacity(0.65))
        view.clusteringIdentifier = nil
        view.glyphText = "+\(cluster.memberAnnotations.count)"
        view.titleVisibility = .hidden
        view.displayPriority = .defaultLow
        view.accessibilityLabel = "\(cluster.memberAnnotations.count) optional discoveries nearby"
      } else if let pin = annotation as? PlacePin {
        view.markerTintColor = UIColor(ink.opacity(0.65))
        view.clusteringIdentifier = "discoveries"
        view.glyphImage = UIImage(systemName: pin.place.icon)
        view.titleVisibility = .hidden
        view.displayPriority = .defaultLow
        view.accessibilityLabel = "Optional discovery, \(pin.place.name)"
      } else {
        view.clusteringIdentifier = nil
        view.markerTintColor = UIColor(FieldStyle.clay)
        view.glyphImage = UIImage(systemName: "circle.fill")
        view.titleVisibility = .visible
        view.displayPriority = .required
      }
      return view
    }
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
      if let cluster = view.annotation as? MKClusterAnnotation {
        mapView.showAnnotations(cluster.memberAnnotations, animated: true)
      } else if let pin = view.annotation as? PlacePin {
        parent.selected = pin.place
      } else if let pin = view.annotation as? TourPin {
        parent.onStopSelected(pin.stop)
      }
    }
    func mapView(_ mapView: MKMapView, didChange mode: MKUserTrackingMode, animated: Bool) {
      DispatchQueue.main.async { self.parent.onFollowing(mode != .none) }
    }
  }
}
