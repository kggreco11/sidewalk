import SwiftUI
import MapKit
import PhotosUI

struct Place: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let lat: Double
    let lng: Double
    let category: String
    let story: String
    let source: String
    let sourceName: String
    let address: String?
    let teaser: String?
    let image: String?
    let imageLocal: String?
    let imageCredit: String?
    let imageSource: String?
    let imageLicenseUrl: String?
    var coordinate: CLLocationCoordinate2D { .init(latitude: lat, longitude: lng) }
    var kind: String {
        let text = category.lowercased()
        if text.contains("art") || text.contains("mural") { return "Art" }
        if text.contains("park") || text.contains("garden") { return "Parks" }
        if text.contains("architecture") { return "Architecture" }
        if text.contains("film") || text.contains("culture") || text.contains("literature") { return "Culture" }
        return "History"
    }
    var icon: String { ["Art":"paintpalette", "Parks":"leaf", "Architecture":"building.2", "Culture":"book", "History":"building.columns"][kind] ?? "mappin" }
}
struct Visit: Codable { var note: String; var date: Date; var photo: Data? }
@MainActor final class FieldGuide: ObservableObject {
    @Published var places: [Place] = []
    @Published var saved: Set<String> = []
    @Published var visits: [String: Visit] = [:]
    @Published var error: String?
    @Published var unlocked: Set<String> = Set(UserDefaults.standard.stringArray(forKey: "unlockedPlaces") ?? [])
    init() {
        do {
            guard let url = Bundle.main.url(forResource: "places", withExtension: "json") else { throw CocoaError(.fileNoSuchFile) }
            places = try JSONDecoder().decode([Place].self, from: Data(contentsOf: url))
            saved = Set(UserDefaults.standard.stringArray(forKey: "savedPlaces") ?? [])
            if let data = UserDefaults.standard.data(forKey: "visits") { visits = try JSONDecoder().decode([String:Visit].self, from: data) }
        } catch { self.error = "Could not load the field guide. \(error.localizedDescription)" }
    }
    func toggle(_ place: Place) {
        if saved.contains(place.id) { saved.remove(place.id) } else { saved.insert(place.id) }
        UserDefaults.standard.set(Array(saved), forKey: "savedPlaces")
    }
    func unlock(_ place: Place) {
        unlocked.insert(place.id)
        UserDefaults.standard.set(Array(unlocked), forKey: "unlockedPlaces")
    }
    func collect(_ place: Place, note: String, photo: Data?) {
        guard unlocked.contains(place.id) else { error = "Confirm your arrival to collect this place."; return }
        visits[place.id] = Visit(note: note, date: Date(), photo: photo)
        do { UserDefaults.standard.set(try JSONEncoder().encode(visits), forKey: "visits") }
        catch { self.error = "Your field note could not be saved." }
    }
}
let paper = Color(red: 0.96, green: 0.95, blue: 0.92)
let ink = Color(red: 0.16, green: 0.24, blue: 0.31)

@main struct SidewalkApp: App {
    @StateObject private var guide = FieldGuide()
    var body: some Scene { WindowGroup { ArrivalView().environmentObject(guide).tint(ink).preferredColorScheme(.light) } }
}
struct WalkRequest: Identifiable {
    let id = UUID()
    var destination: Place?
}
struct ExploreView: View {
    @EnvironmentObject var guide: FieldGuide
    @Environment(\.dynamicTypeSize) private var textSize
    @State private var filter = "All"
    @State private var search = ""
    @State private var selected: Place?
    @State private var walkDestination: Place?
    @State private var walkRequest: WalkRequest?
    @State private var plannedRoute: MKRoute?
    @State private var collection = false
    @State private var center = CLLocationCoordinate2D(latitude: 37.800, longitude: -122.407)
    @State private var panelLevel = 1
    @GestureState private var panelDrag: CGFloat = 0
    @State private var area = "North Beach"
    let areas = ["North Beach", "Waterfront", "Mission", "Civic Center", "Golden Gate Park", "All San Francisco"]
    var matches: [Place] {
        guide.places.filter { p in
            (filter == "All" || (filter == "Saved" ? guide.saved.contains(p.id) : p.kind == filter)) &&
            (search.isEmpty || (p.name + " " + p.category).localizedCaseInsensitiveContains(search))
        }.sorted { distance($0) < distance($1) }
    }
    func distance(_ p: Place) -> Double { pow(p.lat-center.latitude,2) + pow((p.lng-center.longitude)*0.79,2) }
    var body: some View {
        GeometryReader { geometry in
        ZStack(alignment:.bottom) {
            PlacesMap(places: matches, center: center, city: false, selected: $selected, route:plannedRoute).ignoresSafeArea()
            if let request=walkRequest {
                WalkPlanner(destination:request.destination,route:$plannedRoute) { withAnimation(.easeInOut(duration:0.3)) {walkRequest=nil;plannedRoute=nil} }.id(request.id).transition(.opacity)
            } else {
            VStack { HStack {
                Text("sidewalk").font(.system(.largeTitle, design: .serif)).tracking(-1.5)
                Spacer()
                Button { collection = true } label: { Image(systemName: "book.closed").font(.title3).frame(width:44,height:44) }.accessibilityLabel("My field guide")
            }.padding(.horizontal,20).padding(.vertical,8).background(paper.opacity(0.96))
                Spacer()
            }
            VStack(spacing:0) {
                VStack(spacing:4) {
                    Capsule().fill(ink.opacity(0.25)).frame(width:36,height:5).padding(.top,10)
                    HStack { Text("Explore").font(.title2.bold()); Spacer(); Button { withAnimation(.snappy) { panelLevel = panelLevel == 0 ? 1 : 0 } } label: { Image(systemName:panelLevel == 0 ? "chevron.up" : "chevron.down").frame(width:44,height:44) }.accessibilityLabel(panelLevel == 0 ? "Show places" : "Show full map") }.padding(.horizontal,16)
                }.contentShape(Rectangle()).gesture(DragGesture().updating($panelDrag) { value,state,_ in state=value.translation.height }.onEnded { value in withAnimation(.snappy) { if value.predictedEndTranslation.height > 50 { panelLevel=max(0,panelLevel-1) } else if value.predictedEndTranslation.height < -50 { panelLevel=min(2,panelLevel+1) } } })
                if panelLevel > 0 {
            ScrollView { VStack(spacing: 0) {
            VStack(alignment:.leading, spacing:12) {

                HStack { Image(systemName:"magnifyingglass"); TextField("Find a place",text:$search).textInputAutocapitalization(.never); if !search.isEmpty { Button { search = "" } label: { Image(systemName:"xmark.circle.fill").frame(width:44,height:44) }.accessibilityLabel("Clear search") } }.padding(10).background(.white.opacity(0.65),in:RoundedRectangle(cornerRadius:10))
                ScrollView(.horizontal,showsIndicators:false) { HStack { ForEach(["All","Architecture","History","Culture","Art","Parks","Saved"],id:\.self) { value in
                    Button(value) { filter = value }.font(.body).padding(.horizontal,14).frame(minHeight:44).background(filter == value ? ink : .clear,in:Capsule()).foregroundStyle(filter == value ? paper : ink).overlay(Capsule().stroke(ink.opacity(0.15))).accessibilityAddTraits(filter == value ? .isSelected : [])
                } } }
                HStack { Text("\(matches.count) places"); Spacer(); Text("Nearby").foregroundStyle(.secondary) }.font(.body)
                LazyVStack(spacing:12) { ForEach(matches) { place in
                        HStack(alignment:.top,spacing:12) {
                            Button { selected = place } label: {
                                HStack(alignment:.top,spacing:12) {
                                    PlaceCover(place:place).frame(width:88,height:100).clipped().clipShape(RoundedRectangle(cornerRadius:6))
                                    VStack(alignment:.leading,spacing:7) {
                                        Text(place.kind.uppercased()).font(.subheadline.monospaced())
                                        Text(place.name).font(.system(.title2,design:.serif)).fixedSize(horizontal:false,vertical:true)
                                        Text(place.teaser ?? place.address ?? place.kind).font(.body).foregroundStyle(.secondary)
                                    }.frame(maxWidth:.infinity,alignment:.leading)
                                }
                            }.buttonStyle(.plain)
                            Button { guide.toggle(place) } label: { Image(systemName:guide.saved.contains(place.id) ? "bookmark.fill" : "bookmark").frame(width:44,height:44) }.accessibilityLabel("Save \(place.name)")
                        }.padding(12).frame(maxWidth:.infinity,alignment:.topLeading).background(.white.opacity(0.7),in:RoundedRectangle(cornerRadius:10))
                    } }
                if matches.isEmpty { Text("No matches. Try another interest or search.").font(.body) }

            }.padding(16).background(paper)
        } }.scrollDismissesKeyboard(.interactively).scrollBounceBehavior(.basedOnSize)
                }
                Button { withAnimation(.easeInOut(duration:0.3)) { walkRequest = WalkRequest(destination:nil) } } label: { Label("Start a walk",systemImage:"figure.walk").foregroundStyle(paper).frame(maxWidth:.infinity,minHeight:52) }.buttonStyle(.borderedProminent).padding(.horizontal,16).padding(.bottom,8)
            }.frame(height:max(134,min(geometry.size.height-70,(panelLevel == 0 ? 134 : geometry.size.height * (panelLevel == 1 ? 0.56 : 0.9))-panelDrag)))
                .background(paper,in:UnevenRoundedRectangle(topLeadingRadius:24,topTrailingRadius:24))
                .clipped()
            }
        }
        }.background(paper).foregroundStyle(ink)
        .sheet(item:$selected,onDismiss:{if let destination=walkDestination {walkRequest=WalkRequest(destination:destination);walkDestination=nil}}) { p in PlaceDetail(place:p) { walkDestination = p; selected = nil }.environmentObject(guide) }
        .sheet(isPresented:$collection) { NavigationStack { List(guide.places.filter { guide.visits[$0.id] != nil || guide.unlocked.contains($0.id) }) { p in VStack(alignment:.leading,spacing:8) { Text(p.name).font(.headline); if guide.unlocked.contains(p.id) { Text(p.story).font(.body) }; Text(guide.visits[p.id]?.note ?? ""); if let data=guide.visits[p.id]?.photo,let image=UIImage(data:data) { Image(uiImage:image).resizable().scaledToFit().frame(maxHeight:180) } } }.navigationTitle("Field guide").overlay { if guide.visits.isEmpty && guide.unlocked.isEmpty { ContentUnavailableView("No stamps yet",systemImage:"book.closed",description:Text("Check in at a place to collect it.")) } }.toolbar { Button("Done") { collection=false } } } }
        .alert("Field guide",isPresented:Binding(get:{guide.error != nil},set:{if !$0 {guide.error=nil}})) { Button("OK") {guide.error=nil} } message: {Text(guide.error ?? "")}
    }
}
struct PlaceDetail: View {
    @EnvironmentObject var guide: FieldGuide
    @Environment(\.dismiss) private var dismiss
    @State private var checkIn = false
    let place: Place
    let walk: () -> Void
    var body: some View {
        NavigationStack { ScrollView { VStack(alignment:.leading,spacing:20) {
            PlaceCover(place:place).frame(height:200).clipped()
            if let credit=place.imageCredit, let source=place.imageSource, let url=URL(string:source) {Link(credit,destination:url).font(.body).frame(minHeight:44);if let license=place.imageLicenseUrl,let licenseURL=URL(string:license){Link("Image license",destination:licenseURL).font(.body).frame(minHeight:44)};Text("Cropped to fit").font(.subheadline).foregroundStyle(.secondary)}
            Text(place.kind.uppercased()).font(.subheadline.monospaced())
            Text(place.name).font(.system(.largeTitle,design:.serif))
            if guide.unlocked.contains(place.id) {
                Label("Story unlocked",systemImage:"lock.open").font(.headline)
                Text(place.story).font(.system(.body,design:.serif)).lineSpacing(5)
                Button { checkIn = true } label: { Label(guide.visits[place.id] == nil ? "Keep this moment" : "Edit field note",systemImage:"book").frame(maxWidth:.infinity,minHeight:52) }.buttonStyle(.bordered)
            } else {
                if let teaser=place.teaser { Text(teaser).font(.body) }
                ArrivalUnlock(place:place)
            }
            if let address=place.address { Label(address,systemImage:"mappin").font(.body) }
            if guide.unlocked.contains(place.id), let url=URL(string:place.source) { Link(place.sourceName,destination:url).font(.body).frame(minHeight:44) }
            VStack(spacing:12) {
                Button(action:walk) { Label("Walk here",systemImage:"figure.walk").frame(maxWidth:.infinity,minHeight:52) }.buttonStyle(.borderedProminent)
                Button { guide.toggle(place) } label: { Image(systemName:guide.saved.contains(place.id) ? "bookmark.fill" : "bookmark").frame(width:44,height:44) }.buttonStyle(.bordered).accessibilityLabel("Save place")
            }
        }.padding(24) }.background(paper)
            .toolbar { ToolbarItem(placement:.topBarTrailing) { Button("Done") { dismiss() }.frame(minHeight:44) } }
            .sheet(isPresented:$checkIn) { CheckIn(place:place).environmentObject(guide) }
        }.presentationDragIndicator(.visible)
    }
}
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
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context:Context) -> MKMapView {
        let map=MKMapView(); map.delegate=context.coordinator; map.pointOfInterestFilter = .excludingAll
        map.register(MKMarkerAnnotationView.self,forAnnotationViewWithReuseIdentifier:"place")
        map.register(MKMarkerAnnotationView.self,forAnnotationViewWithReuseIdentifier:MKMapViewDefaultClusterAnnotationViewReuseIdentifier)
        map.showsCompass=false
        return map
    }
    func updateUIView(_ map:MKMapView,context:Context) {
        context.coordinator.parent=self
        if context.coordinator.ids != places.map(\.id) {
            map.removeAnnotations(map.annotations); map.addAnnotations(places.map(PlacePin.init)); context.coordinator.ids=places.map(\.id)
        }
        if context.coordinator.currentRoute !== route {
            map.removeOverlays(map.overlays)
            context.coordinator.currentRoute=route
            if let route {
                map.addOverlay(route.polyline)
                map.setVisibleMapRect(route.polyline.boundingMapRect,edgePadding:UIEdgeInsets(top:210,left:45,bottom:240,right:45),animated:true)
            }
        }
        let key="\(center.latitude),\(center.longitude),\(city)"
        if context.coordinator.centerKey != key {
            context.coordinator.centerKey=key
            map.setRegion(MKCoordinateRegion(center:center,span:.init(latitudeDelta:city ? 0.15 : 0.025,longitudeDelta:city ? 0.15 : 0.025)),animated:false)
        }
    }
    class Coordinator:NSObject,MKMapViewDelegate {
        var parent:PlacesMap; var ids:[String]=[]; var centerKey=""
        var currentRoute: MKRoute?
        func mapView(_ mapView:MKMapView,rendererFor overlay:MKOverlay)->MKOverlayRenderer {
            let renderer=MKPolylineRenderer(overlay:overlay);renderer.strokeColor=UIColor(ink);renderer.lineWidth=6;return renderer
        }
        init(_ parent:PlacesMap) {self.parent=parent}
        func mapView(_ mapView:MKMapView,viewFor annotation:MKAnnotation)->MKAnnotationView? {
            guard !(annotation is MKUserLocation) else{return nil}
            let cluster=annotation is MKClusterAnnotation
            let view=mapView.dequeueReusableAnnotationView(withIdentifier:cluster ? MKMapViewDefaultClusterAnnotationViewReuseIdentifier : "place",for:annotation) as! MKMarkerAnnotationView
            view.markerTintColor=UIColor(ink); view.clusteringIdentifier=cluster ? nil : "places"
            view.glyphImage=cluster ? nil : UIImage(systemName:(annotation as? PlacePin)?.place.icon ?? "mappin")
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

struct PlaceCover:View {
    let place:Place
    var body:some View {
        if let local=place.imageLocal,let image=UIImage(named:local) {
            Image(uiImage:image).resizable().scaledToFill().accessibilityLabel(place.name)
        } else if let image=place.image,let url=URL(string:image), url.scheme == "https" {
            AsyncImage(url:url) {phase in
                if let image=phase.image {image.resizable().scaledToFill().accessibilityLabel(place.name)}
                else {fallback}
            }
        } else {fallback}
    }
    var fallback:some View {ZStack{ink.opacity(0.06);Image(systemName:place.icon).font(.system(size:36,weight:.light)).foregroundStyle(ink)}.accessibilityLabel(place.name)}
}
