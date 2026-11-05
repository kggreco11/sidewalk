import SwiftUI
import MapKit

final class PlacePin: NSObject, MKAnnotation {
    let place: Place
    init(_ place: Place) { self.place=place }
    var coordinate: CLLocationCoordinate2D { place.coordinate }
    var title: String? { place.name }
}
struct PlacesMap: UIViewRepresentable {
    let places: [Place]
    let center: CLLocationCoordinate2D
    var city=false
    @Binding var selected: Place?
    var route: MKRoute? = nil
    var bottomInset:CGFloat = 140
    var recenter:Int = 0
    var navigating=false
    var followToken=0
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context:Context) -> MKMapView {
        let map=MKMapView(); map.delegate=context.coordinator; map.pointOfInterestFilter = .excludingAll
        map.register(MKMarkerAnnotationView.self,forAnnotationViewWithReuseIdentifier:"place")
        map.register(MKMarkerAnnotationView.self,forAnnotationViewWithReuseIdentifier:MKMapViewDefaultClusterAnnotationViewReuseIdentifier)
        map.mapType = .mutedStandard
        map.showsCompass=true
        map.isPitchEnabled=false
        map.isRotateEnabled=false
        map.accessibilityIdentifier="discovery-map"
        return map
    }
    func updateUIView(_ map:MKMapView,context:Context) {
        context.coordinator.parent=self
        map.layoutMargins=UIEdgeInsets(top:80,left:12,bottom:min(bottomInset+12,map.bounds.height*0.8),right:12)
        if context.coordinator.ids != places.map(\.id) {
            map.removeAnnotations(map.annotations.filter {$0 is PlacePin || $0 is MKClusterAnnotation}); map.addAnnotations(places.map(PlacePin.init)); context.coordinator.ids=places.map(\.id)
        }
        if context.coordinator.currentRoute !== route {
            map.removeOverlays(map.overlays)
            map.removeAnnotations(context.coordinator.endpoints)
            context.coordinator.endpoints=[]
            context.coordinator.currentRoute=route
            if let route {
                map.addOverlay(route.polyline)
                let points=route.polyline.points()
                if route.polyline.pointCount > 0 {
                    let start=MKPointAnnotation();start.title="Start";start.coordinate=points[0].coordinate
                    let end=MKPointAnnotation();end.title="Destination";end.coordinate=points[route.polyline.pointCount-1].coordinate
                    context.coordinator.endpoints=[start,end];map.addAnnotations([start,end])
                }
                map.setVisibleMapRect(route.polyline.boundingMapRect,edgePadding:UIEdgeInsets(top:100,left:20,bottom:20,right:20),animated:true)
            }
        }
        map.showsUserLocation=navigating
        if context.coordinator.following != navigating || context.coordinator.followToken != followToken {
            context.coordinator.following=navigating;context.coordinator.followToken=followToken
            map.setUserTrackingMode(navigating ? .follow : .none,animated:true)
        }
        let key="\(center.latitude),\(center.longitude),\(city),\(recenter)"
        if context.coordinator.centerKey != key {
            context.coordinator.centerKey=key
            let point=MKMapPoint(center)
            let width=(city ? 12000.0 : 1800.0)*MKMapPointsPerMeterAtLatitude(center.latitude)
            let rect=MKMapRect(x:point.x-width/2,y:point.y-width/2,width:width,height:width)
            map.setVisibleMapRect(rect,edgePadding:UIEdgeInsets(top:20,left:20,bottom:20,right:20),animated:context.coordinator.hasCentered)
            context.coordinator.hasCentered=true
        }
    }
    class Coordinator:NSObject,MKMapViewDelegate {
        var parent:PlacesMap; var ids:[String]=[]; var centerKey=""
        var currentRoute: MKRoute?
        var endpoints:[MKPointAnnotation]=[]
        var hasCentered=false
        var following=false
        var followToken=0
        func mapView(_ mapView:MKMapView,rendererFor overlay:MKOverlay)->MKOverlayRenderer {
            let renderer=MKPolylineRenderer(overlay:overlay);renderer.strokeColor=UIColor(ink);renderer.lineWidth=6;return renderer
        }
        init(_ parent:PlacesMap) {self.parent=parent}
        func mapView(_ mapView:MKMapView,viewFor annotation:MKAnnotation)->MKAnnotationView? {
            guard !(annotation is MKUserLocation) else{return nil}
            let cluster=annotation is MKClusterAnnotation
            let view=mapView.dequeueReusableAnnotationView(withIdentifier:cluster ? MKMapViewDefaultClusterAnnotationViewReuseIdentifier : "place",for:annotation) as! MKMarkerAnnotationView
            let endpoint=annotation is MKPointAnnotation
            view.markerTintColor=UIColor(endpoint ? FieldStyle.clay : ink); view.clusteringIdentifier=cluster || endpoint ? nil : "places"
            view.titleVisibility = endpoint ? .visible : .hidden
            view.subtitleVisibility = .hidden
            view.displayPriority = endpoint ? .required : .defaultLow
            view.glyphImage=cluster ? nil : UIImage(systemName:endpoint ? (annotation.title == "Start" ? "circle.fill" : "flag.fill") : (annotation as? PlacePin)?.place.icon ?? "mappin")
            if let group=annotation as? MKClusterAnnotation {view.glyphText="\(group.memberAnnotations.count)"} else {view.glyphText=nil}
            return view
        }
        func mapView(_ mapView:MKMapView,didSelect view:MKAnnotationView) {
            if let cluster=view.annotation as? MKClusterAnnotation {mapView.showAnnotations(cluster.memberAnnotations,animated:true)}
            else if let pin=view.annotation as? PlacePin {parent.selected=pin.place}
            if let annotation=view.annotation {mapView.deselectAnnotation(annotation,animated:false)}
        }
    }
}
