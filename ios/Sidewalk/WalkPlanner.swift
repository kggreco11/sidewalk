import SwiftUI
import MapKit
import PhotosUI

struct WalkPlanner: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var controlsVisible=false
    @EnvironmentObject var guide:FieldGuide
    let destination:Place?
    @State private var origin: MKMapItem?
    @State private var destinationItem: MKMapItem?
    @State private var target:Place?
    @Binding var route:MKRoute?
    let close: () -> Void
    @State private var busy=false
    @State private var error:String?
    @State private var active=false
    @State private var checkIn=false
    @State private var searchField: RouteSearchField?
    @State private var requestID = UUID()
    init(destination:Place?, route:Binding<MKRoute?>, close:@escaping () -> Void) {
        self.destination=destination
        _route=route
        self.close=close
        _target=State(initialValue:destination)
        if let destination {
            let item=MKMapItem(placemark:MKPlacemark(coordinate:destination.coordinate));item.name=destination.name
            _destinationItem=State(initialValue:item)
        }
    }
    var body:some View {
        VStack(spacing:0) {
            VStack(spacing:0) {
                HStack {
                    Button(action:close) {Image(systemName:"arrow.left").frame(width:44,height:44)}.accessibilityLabel("Back to Explore")
                    Text(active ? "Your walk" : "Directions").font(.headline)
                    Spacer()
                }.padding(.horizontal,12)
                if !active {
                    VStack(spacing:12) {
                        Button {searchField = .origin} label: {HStack {Image(systemName:"circle");Text(origin?.name ?? "Choose starting point").frame(maxWidth:.infinity,alignment:.leading);Image(systemName:"magnifyingglass")}.frame(minHeight:44)}.buttonStyle(.plain)
                        Divider()
                        Button { searchField = .destination } label: { HStack { Image(systemName:"mappin.circle.fill"); Text(destinationItem?.name ?? "Where to?").frame(maxWidth:.infinity,alignment:.leading); Image(systemName:"magnifyingglass") }.frame(minHeight:44) }.buttonStyle(.plain)
                    }.padding(16).background(paper)
                }
            }.background(paper)
                .offset(y:controlsVisible || reduceMotion ? 0 : -36).opacity(controlsVisible ? 1 : 0)
            Spacer()
            Group {
                VStack(alignment:.leading,spacing:12) {
                    if let route {
                        Text("\(Int(ceil(route.expectedTravelTime/60))) min · \(route.distance/1000,specifier:"%.1f") km").font(.title2.bold())
                        Text(destinationItem?.name ?? "Walking route").font(.body)
                        if active {
                            ScrollView { VStack(alignment:.leading,spacing:16) { ForEach(Array(route.steps.filter{!$0.instructions.isEmpty}.enumerated()),id:\.offset) { _,step in Text(step.instructions).font(.body) } } }.frame(maxHeight:150)
                        }
                    } else { Text(busy ? "Finding a walking route…" : origin == nil ? "Choose your starting point" : "Choose your destination").font(.headline) }
                    if let error { Text(error).font(.callout).foregroundStyle(.red) }
                    Button {
                        if active {if target != nil {checkIn=true} else {close()}}
                        else if route != nil {active=true}
                        else {Task {await plan()}}
                    } label: {
                        HStack { if busy {ProgressView().tint(paper)}; Label(active ? (target == nil ? "Finish walk" : "I’m here") : route == nil ? "Find route" : "Go",systemImage:active ? "mappin" : "figure.walk") }.foregroundStyle(paper).frame(maxWidth:.infinity,minHeight:52)
                    }.buttonStyle(.borderedProminent).disabled(busy || destinationItem == nil || origin == nil)
                }.padding(20).background(paper,in:UnevenRoundedRectangle(topLeadingRadius:24,topTrailingRadius:24))
            }
            .offset(y:controlsVisible || reduceMotion ? 0 : 48).opacity(controlsVisible ? 1 : 0)
            .onAppear {withAnimation(SidewalkMotion.spring(reduceMotion)) {controlsVisible=true}}
            .animation(SidewalkMotion.spring(reduceMotion),value:active)
            .animation(SidewalkMotion.spring(reduceMotion),value:route != nil)
            .onDisappear {requestID=UUID()}
            .sheet(item:$searchField) {field in
                LocationSearch(title:field.title,places:guide.places) {item,place in
                    requestID=UUID();busy=false;route=nil;active=false;error=nil
                    if field == .origin {origin=item} else {destinationItem=item;target=place}
                    if origin != nil && destinationItem != nil {Task {await plan()}}
                }
            }
            .sheet(isPresented:$checkIn) {if let target {CheckIn(place:target).environmentObject(guide)}}
        }.foregroundStyle(ink)
    }
    func plan() async {
        guard let origin,let destinationItem else{return}
        let token=UUID();requestID=token;busy=true;error=nil;defer {if requestID == token {busy=false}}
        do {
            let directions=MKDirections.Request();directions.source=origin;directions.destination=destinationItem;directions.transportType = .walking
            let result=try await MKDirections(request:directions).calculate()
            guard requestID == token else {return}
            guard let first=result.routes.first else{error="No walking route found.";return};route=first
        } catch {if requestID == token {self.error="Could not get a walking route. Check your connection and try again."}}
    }
}
struct CheckIn:View {
    @EnvironmentObject var guide:FieldGuide
    @Environment(\.dismiss) var dismiss
    let place:Place
    @State private var note=""
    @State private var photoItem:PhotosPickerItem?
    @State private var photo:Data?
    @State private var photoError:String?
    var body:some View {
        NavigationStack {
            Form {
                if !guide.unlocked.contains(place.id) { Section { ArrivalUnlock(place:place) } }
                else {
                Section {Text(place.name).font(.system(.title2,design:.serif));Text(place.story).font(.body);TextField("Worth a footnote?",text:$note,axis:.vertical).lineLimit(3...6)}
                Section {
                    PhotosPicker(selection:$photoItem,matching:.images) {Label("A little proof you wandered",systemImage:"camera")}
                    if let photo,let image=UIImage(data:photo) {Image(uiImage:image).resizable().scaledToFit().frame(maxHeight:200)}
                    if let photoError {Text(photoError).foregroundStyle(.red)}
                }
                Section {Button("Keep this moment") {guide.collect(place,note:note,photo:photo);dismiss()}.frame(minHeight:52)}
                }
            }.navigationTitle("I’m here").toolbar{Button("Cancel"){dismiss()}}
                .onAppear {if let visit=guide.visits[place.id]{note=visit.note;photo=visit.photo}}
                .onChange(of:photoItem) {_,item in Task {
                    do {guard let data=try await item?.loadTransferable(type:Data.self),let image=UIImage(data:data) else {photoError="Could not open that photo.";return}
                        let scale=min(1,960/max(image.size.width,image.size.height));let size=CGSize(width:image.size.width*scale,height:image.size.height*scale)
                        let format=UIGraphicsImageRendererFormat();format.scale=1
                        photo=UIGraphicsImageRenderer(size:size,format:format).image{_ in image.draw(in:CGRect(origin:.zero,size:size))}.jpegData(compressionQuality:0.75);photoError=nil
                    }catch{photoError="Could not open that photo. Try again."}
                }}
        }.presentationDetents([.large])
    }
}
