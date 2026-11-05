import SwiftUI
import MapKit
import PhotosUI

struct WalkPlanner:View {
    @Environment(\.accessibilityReduceMotion) private var reduced
    @StateObject private var model:RoutePlannerModel
    @StateObject private var location=StartingLocation()
    @Environment(\.scenePhase) private var scenePhase
    @Binding var route:MKRoute?
    let close:()->Void
    @FocusState private var focused:RouteSearchField?
    @State private var checkIn=false
    @State private var visible=false
    init(destination:Place?,route:Binding<MKRoute?>,close:@escaping ()->Void) {
        _model=StateObject(wrappedValue:RoutePlannerModel(place:destination));_route=route;self.close=close
    }
    @EnvironmentObject private var guide:FieldGuide
    var body:some View {
        GeometryReader {geometry in
            VStack(spacing:0) {
                VStack(spacing:0) {
                    HStack {
                        FieldIconButton(symbol:"arrow.left",label:"Back to Explore") {focused=nil;model.cancel();close()}
                        Text(model.active ? "Your walk" : "Plan a walk").font(.headline)
                        Spacer()
                        if model.active {Button("Edit") {model.active=false}.frame(minHeight:44)}
                    }.padding(.horizontal,8)
                    if !model.active {
                        HStack(spacing:8) {
                            VStack(spacing:0) {
                                endpoint(.origin,symbol:"circle",placeholder:"Starting point")
                                Divider().padding(.leading,36)
                                endpoint(.destination,symbol:"mappin",placeholder:"Where to?")
                            }.padding(.horizontal,12).background(FieldStyle.inset,in:RoundedRectangle(cornerRadius:16))
                            FieldIconButton(symbol:"arrow.up.arrow.down",label:"Swap starting point and destination") {focused=nil;location.cancel();model.swap();if model.canPlan {model.startPlanning()}}
                        }.padding(.horizontal,16).padding(.bottom,12)
                        if focused == .origin || model.originText.isEmpty {
                            Button {
                                focused=nil
                                location.request {item in model.choose(.origin,item:item);if model.canPlan {model.startPlanning()} else {focused = .destination}}
                            } label: {HStack {if location.busy {ProgressView()} else {Image(systemName:"location")};Text(location.busy ? "Finding your location…" : "Use current location");Spacer()}.font(.subheadline.weight(.medium)).frame(minHeight:44).padding(.horizontal,20)}.buttonStyle(.plain).disabled(location.busy)
                        }
                        if let message=location.message {Text(message).font(.callout).foregroundStyle(FieldStyle.clay).padding(.horizontal,20).padding(.bottom,8)}
                        if let field=focused {
                            LocationSuggestions(query:model.text(for:field),places:guide.places) {item,place in
                                location.cancel()
                                model.choose(field,item:item,place:place)
                                focused=nil
                                if model.canPlan {model.startPlanning()}
                            }.id(field).frame(maxHeight:max(100,min(260,geometry.size.height*0.38)))
                        }
                    }
                }.background(paper,in:UnevenRoundedRectangle(bottomLeadingRadius:24,bottomTrailingRadius:24))
                    .shadow(color:ink.opacity(0.07),radius:12,y:4)
                    .offset(y:visible || reduced ? 0 : -24).opacity(visible ? 1 : 0)
                Spacer(minLength:8)
                VStack(alignment:.leading,spacing:12) {
                    if focused == nil,let route=model.route {
                        HStack(alignment:.firstTextBaseline) {
                            Text("\(Int(ceil(route.expectedTravelTime/60))) min").font(.system(.title,design:.rounded).weight(.semibold)).monospacedDigit()
                            Text(String(format:"%.1f km",route.distance/1000)).font(.body).foregroundStyle(FieldStyle.secondary)
                            Spacer()
                            Image(systemName:"figure.walk").font(.title2).foregroundStyle(FieldStyle.clay)
                        }
                        Text(model.destination?.name ?? model.destinationText).font(.headline).lineLimit(2)
                        if model.active {
                            Text("Walking directions").font(.subheadline).foregroundStyle(FieldStyle.secondary)
                            ScrollView {
                                VStack(alignment:.leading,spacing:16) {ForEach(Array(route.steps.filter{!$0.instructions.isEmpty}.enumerated()),id:\.offset) {index,step in
                                    HStack(alignment:.top,spacing:12) {Text("\(index+1)").font(.caption.monospacedDigit()).frame(width:24,height:24).background(FieldStyle.inset,in:Circle());Text(step.instructions).font(.body)}
                                }}}.frame(maxHeight:160)
                            Button {model.openInMaps()} label: {Label("Navigate in Apple Maps",systemImage:"arrow.up.right.square").frame(minHeight:44)}.buttonStyle(.plain)
                        } else {Text("Direct walking route").font(.subheadline).foregroundStyle(FieldStyle.secondary)}
                    } else if focused == nil && !model.busy {
                        Text("Where shall we walk?").font(.system(.title2,design:.serif).weight(.semibold))
                    }
                    if let error=model.error {Label(error,systemImage:"exclamationmark.circle").font(.callout).foregroundStyle(FieldStyle.clay).fixedSize(horizontal:false,vertical:true).accessibilityIdentifier("route-error")}
                    Button(action:primaryAction) {
                        HStack {if model.busy {ProgressView().tint(paper)};Text(model.busy ? "Finding your route…" : model.active ? (model.place == nil ? "Finish walk" : "I’m here") : model.route == nil ? "Find route" : "Go");if !model.busy {Image(systemName:model.active ? "checkmark" : "arrow.right")}}
                    }.buttonStyle(FieldPrimaryButtonStyle()).disabled(model.busy || !model.canPlan)
                }.padding(20).background(paper,in:UnevenRoundedRectangle(topLeadingRadius:24,topTrailingRadius:24))
                    .background(alignment:.bottom) {paper.frame(height:geometry.safeAreaInsets.bottom+20).offset(y:geometry.safeAreaInsets.bottom)}
                    .offset(y:visible || reduced ? 0 : 24).opacity(visible ? 1 : 0)
            }.foregroundStyle(ink)
        }.onAppear {withAnimation(SidewalkMotion.spring(reduced)) {visible=true}}
            .onReceive(model.$route) {route=$0}
            .onDisappear {model.cancel();location.cancel()}
            .onChange(of:scenePhase) {_,phase in if phase == .background {location.cancel()}}
            .sheet(isPresented:$checkIn) {if let place=model.place {CheckIn(place:place).environmentObject(guide)}}
    }
    private func endpoint(_ field:RouteSearchField,symbol:String,placeholder:String)->some View {
        HStack(spacing:12) {
            Image(systemName:symbol).font(.body.weight(.medium)).foregroundStyle(field == .origin ? ink : FieldStyle.clay).frame(width:24)
            TextField(placeholder,text:Binding(get:{model.text(for:field)},set:{location.cancel();model.edit(field,text:$0)}))
                .font(.body).focused($focused,equals:field).autocorrectionDisabled().submitLabel(.route)
                .accessibilityIdentifier(field == .origin ? "route-origin" : "route-destination")
                .onSubmit {submit()}
            if !model.text(for:field).isEmpty {
                FieldIconButton(symbol:"xmark.circle.fill",label:field == .origin ? "Clear starting point" : "Clear destination") {location.cancel();model.edit(field,text:"");focused=field}
            }
        }.frame(minHeight:52)
    }
    private func submit() {
        if model.text(for:.origin).isEmpty {focused = .origin}
        else if model.text(for:.destination).isEmpty {focused = .destination}
        else {focused=nil;model.startPlanning()}
    }
    private func primaryAction() {
        focused=nil
        if model.active {if model.place != nil {checkIn=true} else {close()}}
        else if model.route != nil {withAnimation(SidewalkMotion.spring(reduced)) {model.active=true}}
        else {submit()}
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
                if let error=guide.error {Section {Text(error).foregroundStyle(FieldStyle.clay)}}
                Section {Button("Keep this moment") {if guide.collect(place,note:note,photo:photo) {dismiss()}}.frame(minHeight:52)}
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
