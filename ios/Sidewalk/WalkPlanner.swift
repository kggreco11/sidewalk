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
    @FocusState private var searchField: RouteSearchField?
    @State private var originText=""
    @State private var destinationText=""
    @State private var requestID = UUID()
    init(destination:Place?, route:Binding<MKRoute?>, close:@escaping () -> Void) {
        self.destination=destination
        _route=route
        self.close=close
        _target=State(initialValue:destination)
        _destinationText=State(initialValue:destination?.name ?? "")
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
                        HStack {
                            Image(systemName:"circle")
                            TextField("Starting point",text:input(.origin)).focused($searchField,equals:.origin)
                                .submitLabel(.route).autocorrectionDisabled().onSubmit {Task {await plan()}}
                            if !originText.isEmpty {Button {input(.origin).wrappedValue="";searchField = .origin} label: {Image(systemName:"xmark.circle.fill").frame(width:44,height:44)}.accessibilityLabel("Clear starting point")}
                        }.frame(minHeight:44)
                        Divider()
                        HStack {
                            Image(systemName:"mappin.circle.fill")
                            TextField("Where to?",text:input(.destination)).focused($searchField,equals:.destination)
                                .submitLabel(.route).autocorrectionDisabled().onSubmit {Task {await plan()}}
                            if !destinationText.isEmpty {Button {input(.destination).wrappedValue="";searchField = .destination} label: {Image(systemName:"xmark.circle.fill").frame(width:44,height:44)}.accessibilityLabel("Clear destination")}
                        }.frame(minHeight:44)
                    }.padding(16).background(paper)
                    if let field=searchField {
                        LocationSuggestions(query:field == .origin ? originText : destinationText,places:guide.places) {item,place in
                            invalidateRoute()
                            if field == .origin {origin=item;originText=item.name ?? "Selected place"}
                            else {destinationItem=item;destinationText=item.name ?? "Selected place";target=place}
                            searchField=nil
                            if origin != nil && destinationItem != nil {Task {await plan()}}
                        }.id(field)
                    }
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
                    }.buttonStyle(.borderedProminent).disabled(busy || originText.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty || destinationText.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty)
                }.padding(20).background(paper,in:UnevenRoundedRectangle(topLeadingRadius:24,topTrailingRadius:24))
            }
            .offset(y:controlsVisible || reduceMotion ? 0 : 48).opacity(controlsVisible ? 1 : 0)
            .onAppear {withAnimation(SidewalkMotion.spring(reduceMotion)) {controlsVisible=true}}
            .animation(SidewalkMotion.spring(reduceMotion),value:active)
            .animation(SidewalkMotion.spring(reduceMotion),value:route != nil)
            .sheet(isPresented:$checkIn) {if let target {CheckIn(place:target).environmentObject(guide)}}
        }.foregroundStyle(ink).onDisappear {requestID=UUID()}
    }
    private func input(_ field:RouteSearchField)->Binding<String> {
        Binding(get: {field == .origin ? originText : destinationText},set: {value in
            invalidateRoute()
            if field == .origin {originText=value;origin=nil}
            else {destinationText=value;destinationItem=nil;target=nil}
        })
    }
    private func invalidateRoute() {requestID=UUID();busy=false;route=nil;active=false;error=nil}
    @MainActor private func resolve(_ text:String, label:String) async throws -> MKMapItem {
        let request=MKLocalSearch.Request()
        request.naturalLanguageQuery=text
        request.resultTypes=text.first?.isNumber == true ? .address : [.address,.pointOfInterest]
        request.region=MKCoordinateRegion(center:.init(latitude:37.775,longitude:-122.438),span:.init(latitudeDelta:0.15,longitudeDelta:0.15))
        let response=try await MKLocalSearch(request:request).start()
        guard response.mapItems.count == 1,let item=response.mapItems.first else {
            throw AddressError(message:response.mapItems.isEmpty ? "Couldn’t find that \(label). Include the street number and city, or choose a suggestion." : "Several places match your \(label). Choose the correct suggestion below the field.")
        }
        return item
    }
    @MainActor func plan() async {
        let from=originText.trimmingCharacters(in:.whitespacesAndNewlines)
        let to=destinationText.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !from.isEmpty else {searchField = .origin;return}
        guard !to.isEmpty else {searchField = .destination;return}
        let token=UUID();requestID=token;busy=true;error=nil;defer {if requestID == token {busy=false}}
        do {
            let source:MKMapItem
            if let origin {source=origin} else {source=try await resolve(from,label:"starting address")}
            guard requestID == token else {return}
            origin=source
            let end:MKMapItem
            if let destinationItem {end=destinationItem} else {end=try await resolve(to,label:"destination")}
            guard requestID == token else {return}
            destinationItem=end
            searchField=nil
            let directions=MKDirections.Request();directions.source=source;directions.destination=end;directions.transportType = .walking
            let result=try await MKDirections(request:directions).calculate()
            guard requestID == token else {return}
            guard let first=result.routes.first else{error="No walking route found between these places.";return};route=first
        } catch {
            guard requestID == token else {return}
            self.error=(error as? AddressError)?.message ?? "Could not get a walking route. Check your connection and try again."
        }
    }
    private struct AddressError: Error {let message:String}

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
