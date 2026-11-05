import MapKit
import SwiftUI

/// Projects a fix onto the walking path, keeping along-path and cross-path distances separate.
struct WalkingPath {
    let points:[MKMapPoint]
    var length:Double {zip(points,points.dropFirst()).reduce(0) {$0 + $1.0.distance(to:$1.1)}}
    init(_ polyline:MKPolyline) {points=Array(UnsafeBufferPointer(start:polyline.points(),count:polyline.pointCount))}
    init(coordinates:[CLLocationCoordinate2D]) {points=coordinates.map(MKMapPoint.init)}
    func project(_ coordinate:CLLocationCoordinate2D)->(along:Double,away:Double) {
        let p=MKMapPoint(coordinate)
        var best=(along:0.0,away:Double.infinity),walked=0.0
        for (a,b) in zip(points,points.dropFirst()) {
            let dx=b.x-a.x,dy=b.y-a.y,denom=dx*dx+dy*dy
            let t=denom > 0 ? max(0,min(1,((p.x-a.x)*dx+(p.y-a.y)*dy)/denom)) : 0
            let near=MKMapPoint(x:a.x+t*dx,y:a.y+t*dy),away=p.distance(to:near)
            if away < best.away {best=(walked+a.distance(to:near),away)}
            walked += a.distance(to:b)
        }
        return best
    }
    static func usable(_ fix:CLLocation,now:Date=Date())->Bool {
        (-1...15).contains(now.timeIntervalSince(fix.timestamp)) && (0...35).contains(fix.horizontalAccuracy)
    }
}

@MainActor final class WalkNavigation:NSObject,ObservableObject,@preconcurrency CLLocationManagerDelegate {
    @Published private(set) var running=false
    @Published private(set) var fix:CLLocation?
    @Published private(set) var message:String?
    @Published private(set) var remaining:Double?
    @Published private(set) var instruction="Finding your position…"
    @Published private(set) var maneuverDistance:Double?
    @Published private(set) var arrived=false
    @Published private(set) var offRoute=false
    @Published var recenter=0
    private let manager=CLLocationManager()
    private var route:MKRoute?
    private var path:WalkingPath?
    private var freshness:Task<Void,Never>?
    var minutes:Int? {
        guard let remaining,let route,let path,path.length > 0 else {return nil}
        return max(1,Int(ceil(route.expectedTravelTime * remaining/path.length/60)))
    }
    override init() {
        super.init();manager.delegate=self;manager.desiredAccuracy=kCLLocationAccuracyBest
        manager.distanceFilter=3;manager.activityType = .fitness
    }
    func start(_ route:MKRoute) {
        stop();self.route=route;path=WalkingPath(route.polyline);running=true
        instruction="Finding your position…";message="Keep Sidewalk open for live walking directions."
        authorize()
        freshness=Task {[weak self] in
            while !Task.isCancelled {
                do {try await Task.sleep(for:.seconds(5))} catch {return}
                guard let self else {return}
                guard self.manager.authorizationStatus == .authorizedAlways || self.manager.authorizationStatus == .authorizedWhenInUse else {continue}
                if self.fix.map({!WalkingPath.usable($0)}) ?? true {
                    self.clearProgress("Waiting for a precise GPS location. Directions will update when it returns.")
                }
            }
        }
    }
    func stop() {
        freshness?.cancel();freshness=nil;manager.stopUpdatingLocation();running=false
        fix=nil;remaining=nil;maneuverDistance=nil;arrived=false;offRoute=false;message=nil
    }
    private func authorize() {
        switch manager.authorizationStatus {
        case .notDetermined:manager.requestWhenInUseAuthorization()
        case .authorizedAlways,.authorizedWhenInUse:manager.startUpdatingLocation()
        default:clearProgress("Location is off. Enable it in Settings to follow your walk.")
        }
    }
    func locationManagerDidChangeAuthorization(_ manager:CLLocationManager) {if running {authorize()}}
    func locationManager(_ manager:CLLocationManager,didUpdateLocations locations:[CLLocation]) {
        guard running,let latest=locations.last else {return}
        guard WalkingPath.usable(latest) else {clearProgress("GPS is imprecise. Try a clear view of the sky.");return}
        update(latest)
    }
    private func update(_ latest:CLLocation) {
        guard let path,let route,let end=path.points.last else {return}
        fix=latest
        let projection=path.project(latest.coordinate)
        let distanceToEnd=MKMapPoint(latest.coordinate).distance(to:end)
        arrived=distanceToEnd <= 40 && distanceToEnd+latest.horizontalAccuracy <= 65
        offRoute=projection.away > max(45,latest.horizontalAccuracy+20)
        if arrived {remaining=0;instruction="You’re here";maneuverDistance=nil;message=nil;return}
        if offRoute {
            remaining=nil;maneuverDistance=nil;instruction="You’re away from the route"
            message="Return to the highlighted path, or update the route from here.";return
        }
        remaining=max(0,path.length-projection.along);message=nil
        let maneuvers=route.steps.compactMap {step -> (Double,String)? in
            guard !step.instructions.isEmpty,step.polyline.pointCount > 0 else {return nil}
            return (path.project(step.polyline.points()[0].coordinate).along,step.instructions)
        }
        if let next=maneuvers.first(where:{$0.0 > projection.along+12}) {
            instruction=next.1;maneuverDistance=next.0-projection.along
        } else {instruction="Continue to your destination";maneuverDistance=remaining}
    }
    private func clearProgress(_ reason:String) {
        fix=nil;remaining=nil;maneuverDistance=nil;arrived=false;offRoute=false
        instruction="Location needed";message=reason
    }
    func locationManager(_ manager:CLLocationManager,didFailWithError error:Error) {
        if running {clearProgress("Location is unavailable. Keep the app open and try outdoors.")}
    }
    static func distance(_ metres:Double)->String {metres < 1000 ? "\(Int((metres/5).rounded())*5) m" : String(format:"%.1f km",metres/1000)}
}

struct WalkingInstruction:View {
    @ObservedObject var navigation:WalkNavigation
    var body:some View {
        HStack(alignment:.top,spacing:16) {
            Image(systemName:navigation.arrived ? "checkmark.circle.fill" : "figure.walk").font(.largeTitle).foregroundStyle(FieldStyle.clay).frame(width:44)
            VStack(alignment:.leading,spacing:6) {
                if let distance=navigation.maneuverDistance {Text("In \(WalkNavigation.distance(distance))").font(.subheadline).foregroundStyle(FieldStyle.secondary)}
                Text(navigation.instruction).font(.title3.weight(.semibold)).fixedSize(horizontal:false,vertical:true)
                if let message=navigation.message {Text(message).font(.subheadline).foregroundStyle(FieldStyle.secondary)}
            }
            Spacer(minLength:0)
        }.padding(.horizontal,20).padding(.bottom,16).accessibilityElement(children:.combine)
    }
}
