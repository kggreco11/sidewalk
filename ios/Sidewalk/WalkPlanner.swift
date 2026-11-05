import SwiftUI
import MapKit
import PhotosUI

struct WalkPlanner: View {
    @EnvironmentObject var guide:FieldGuide
    @Environment(\.dismiss) var dismiss
    let destination:Place?
    @State private var from="Ferry Building"
    @State private var target:Place?
    @State private var route:MKRoute?
    @State private var busy=false
    @State private var error:String?
    @State private var active=false
    @State private var checkIn=false
    init(destination:Place?) {
        self.destination=destination
        _target=State(initialValue:destination)
    }
    var body:some View {
        NavigationStack {
            Group {
                if let route,let target {
                    ScrollView { VStack(spacing:0) {
                        Map { MapPolyline(route.polyline).stroke(ink,lineWidth:6); Marker(target.name,coordinate:target.coordinate) }
                            .mapStyle(.standard(pointsOfInterest:.excludingAll)).frame(minHeight:260)
                        VStack(alignment:.leading,spacing:16) {
                            Text(target.name).font(.system(.title2,design:.serif))
                            Text("\(Int(ceil(route.expectedTravelTime/60))) min · \(route.distance/1000,specifier:"%.1f") km").font(.subheadline)
                            if active {
                                ScrollView { VStack(alignment:.leading,spacing:16) { ForEach(Array(route.steps.filter{!$0.instructions.isEmpty}.enumerated()),id:\.offset) { _,step in Label(step.instructions,systemImage:"arrow.turn.up.right").font(.body) } } }.frame(minHeight:130,maxHeight:240)
                                Button { checkIn=true } label: {Text("I’m here").frame(maxWidth:.infinity,minHeight:52)}.buttonStyle(.borderedProminent)
                            } else {
                                Text("Direct walking route").font(.body).foregroundStyle(.secondary)
                                Button { active=true } label: {Text("Start walk").frame(maxWidth:.infinity,minHeight:52)}.buttonStyle(.borderedProminent)
                            }
                        }.padding(20).background(paper)
                    } }
                } else {
                    Form {
                        Section("Starting place") { TextField("Where from?",text:$from) }
                        Section("Destination") {
                            if let target {Text(target.name)}
                            else { Picker("Choose a place",selection:$target) { Text("Select a destination").tag(nil as Place?); ForEach(guide.places.sorted{$0.name<$1.name}) {p in Text(p.name).tag(Optional(p))} } }
                        }
                        if let error {Section {Text(error).foregroundStyle(.red)}}
                        Section { Button { Task { await plan() } } label: { HStack {Text(busy ? "Finding a walk…" : "Go"); Spacer(); if busy {ProgressView()} else {Image(systemName:"arrow.up.right")} } }.disabled(busy || target == nil || from.trimmingCharacters(in:.whitespaces).isEmpty) }
                    }.scrollContentBackground(.hidden).background(paper)
                }
            }.navigationTitle(route == nil ? "Start a walk" : "Your walk").navigationBarTitleDisplayMode(.inline)
                .toolbar {ToolbarItem(placement:.topBarLeading) {Button("Close") {dismiss()}}}
                .sheet(isPresented:$checkIn) { if let target {CheckIn(place:target).environmentObject(guide)} }
        }
    }
    func plan() async {
        guard let target else{return}; busy=true; error=nil; defer{busy=false}
        do {
            let request=MKLocalSearch.Request(); request.naturalLanguageQuery=from+", San Francisco"; request.region=MKCoordinateRegion(center:.init(latitude:37.775,longitude:-122.438),span:.init(latitudeDelta:0.15,longitudeDelta:0.15))
            let response=try await MKLocalSearch(request:request).start()
            guard let source=response.mapItems.first, (37.70...37.84).contains(source.placemark.coordinate.latitude),(-122.53 ... -122.35).contains(source.placemark.coordinate.longitude) else {error="Choose a starting place in San Francisco.";return}
            let directions=MKDirections.Request(); directions.source=source; directions.destination=MKMapItem(placemark:MKPlacemark(coordinate:target.coordinate));directions.transportType = .walking
            let result=try await MKDirections(request:directions).calculate()
            guard let first=result.routes.first else{error="No walking route found.";return};route=first
        } catch {self.error="Could not get a walking route. Check your connection and try again."}
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
