import SwiftUI
import MapKit

struct ExploreView: View {
    @EnvironmentObject private var guide:FieldGuide
    @Environment(\.accessibilityReduceMotion) private var reduced
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var filter="All"
    @State private var query=""
    @State private var selected:Place?
    @State private var pendingWalk:Place?
    @State private var walkRequest:WalkRequest?
    @State private var route:MKRoute?
    @State private var library=false
    @State private var detent:ExploreDetent = .browse
    @State private var drag:CGFloat=0
    @State private var recenter=0
    @FocusState private var searching:Bool
    private let center=CLLocationCoordinate2D(latitude:37.800,longitude:-122.407)
    private let filters=["All","Architecture","History","Culture","Art","Parks","Saved"]

    private var matches:[Place] {
        guide.places.filter {place in
            (filter == "All" || (filter == "Saved" ? guide.saved.contains(place.id) : place.kind == filter)) &&
            (query.isEmpty || (place.name+" "+(place.address ?? "")+" "+place.category).localizedCaseInsensitiveContains(query))
        }.sorted {distance($0)<distance($1)}
    }
    private func distance(_ p:Place)->Double {pow(p.lat-center.latitude,2)+pow((p.lng-center.longitude)*0.79,2)}

    var body:some View {
        GeometryReader {geometry in
            let height=max(140,min(geometry.size.height-64,detent.height(in:geometry.size.height,accessibility:typeSize.isAccessibilitySize)-drag))
            ZStack(alignment:.bottom) {
                PlacesMap(places:route == nil ? matches : [],center:center,selected:$selected,route:route,bottomInset:walkRequest == nil ? height : 220,recenter:recenter)
                    .ignoresSafeArea().accessibilityElement(children:.contain).accessibilityLabel("Map of places").accessibilitySortPriority(-1)
                if let request=walkRequest {
                    WalkPlanner(destination:request.destination,route:$route) {
                        withAnimation(SidewalkMotion.spring(reduced)) {walkRequest=nil;route=nil}
                    }.id(request.id).transition(.opacity)
                } else {
                    VStack {
                        HStack(spacing:8) {
                            HStack(spacing:8) {
                                DiscoveryStar().fill(FieldStyle.clay).frame(width:18,height:18).accessibilityHidden(true)
                                Text("sidewalk").font(.system(.title2,design:.serif).weight(.semibold)).tracking(-0.6)
                            }.padding(.leading,16)
                            Spacer()
                            FieldIconButton(symbol:"book.closed",label:"Open field guide") {library=true}
                        }.padding(.trailing,8).padding(.vertical,4).background(paper,in:Capsule())
                            .shadow(color:ink.opacity(0.08),radius:12,y:4)
                            .accessibilityElement(children:.contain)
                        HStack {Spacer();FieldIconButton(symbol:"scope",label:"Show nearby places") {recenter += 1}.background(paper,in:Circle())}
                        Spacer()
                    }.padding(.horizontal,16).padding(.top,8).transition(SidewalkMotion.transition(edge:.top,reduced:reduced))
                    VStack(spacing:0) {
                        drawerHeader(available:geometry.size.height)
                        ScrollView {
                            VStack(alignment:.leading,spacing:16) {
                                HStack(spacing:10) {
                                    Image(systemName:"magnifyingglass").foregroundStyle(FieldStyle.secondary)
                                    TextField("Find a discovery",text:$query).focused($searching).autocorrectionDisabled().submitLabel(.search)
                                    if !query.isEmpty {FieldIconButton(symbol:"xmark.circle.fill",label:"Clear search") {query=""}}
                                }.padding(.horizontal,12).frame(minHeight:48).background(FieldStyle.inset,in:RoundedRectangle(cornerRadius:12))
                                ScrollView(.horizontal,showsIndicators:false) {
                                    HStack(spacing:8) {ForEach(filters,id:\.self) {value in
                                        Button {filter=value} label: {Text(value).font(.subheadline.weight(.medium)).padding(.horizontal,16).frame(minHeight:44)
                                            .background(filter == value ? ink : FieldStyle.inset,in:Capsule()).foregroundStyle(filter == value ? paper : ink)}
                                            .buttonStyle(.plain).accessibilityAddTraits(filter == value ? .isSelected : [])
                                    }}
                                }
                                if matches.isEmpty {
                                    ContentUnavailableView(filter == "Saved" && query.isEmpty ? "Your next discoveries" : "No places found",systemImage:filter == "Saved" ? "bookmark" : "magnifyingglass",description:Text(filter == "Saved" && query.isEmpty ? "Save a place to find it here." : "Try another name or category."))
                                } else {
                                    Text("\(matches.count) places").font(.subheadline).foregroundStyle(FieldStyle.secondary)
                                    LazyVStack(spacing:0) {ForEach(matches) {place in
                                        PlaceRow(place:place) {searching=false;selected=place}
                                        if place.id != matches.last?.id {Divider().overlay(ink.opacity(0.04))}
                                    }}
                                }
                            }.padding(.horizontal,20).padding(.bottom,16)
                        }.scrollDismissesKeyboard(.interactively).scrollBounceBehavior(.basedOnSize)
                            .frame(maxHeight:detent == .map && drag == 0 ? 0 : .infinity)
                            .opacity(detent == .map && drag == 0 ? 0 : 1).clipped()
                            .accessibilityHidden(detent == .map)
                        Button {beginWalk(nil)} label: {Label("Start a walk",systemImage:"figure.walk")}
                            .buttonStyle(FieldPrimaryButtonStyle()).padding(.horizontal,20).padding(.top,8).padding(.bottom,12)
                    }.frame(height:height).background(paper,in:UnevenRoundedRectangle(topLeadingRadius:24,topTrailingRadius:24))
                        .background(alignment:.bottom) {paper.frame(height:geometry.safeAreaInsets.bottom+20).offset(y:geometry.safeAreaInsets.bottom)}
                        .shadow(color:ink.opacity(0.08),radius:16,y:-4)
                        .accessibilitySortPriority(1)
                        .transition(SidewalkMotion.transition(edge:.bottom,reduced:reduced))
                }
            }.foregroundStyle(ink)
            .onChange(of:searching) {_,focused in if focused {withAnimation(SidewalkMotion.spring(reduced)) {detent = .full}}}
        }
        .sheet(item:$selected,onDismiss:{if let place=pendingWalk {pendingWalk=nil;beginWalk(place)}}) {place in
            PlaceDetail(place:place) {pendingWalk=place;selected=nil}.environmentObject(guide)
        }
        .sheet(isPresented:$library,onDismiss:{if let place=pendingWalk {pendingWalk=nil;beginWalk(place)}}) {
            FieldGuideView {place in pendingWalk=place;library=false}.environmentObject(guide)
        }
        .alert("Couldn’t save",isPresented:Binding(get:{guide.error != nil},set:{if !$0 {guide.error=nil}})) {Button("OK") {guide.error=nil}} message:{Text(guide.error ?? "")}
    }
    private func beginWalk(_ place:Place?) {
        searching=false
        withAnimation(SidewalkMotion.spring(reduced)) {walkRequest=WalkRequest(destination:place)}
    }
    private func drawerHeader(available:CGFloat)->some View {
        VStack(spacing:0) {
            Capsule().fill(ink.opacity(0.22)).frame(width:32,height:5).padding(.top,10).padding(.bottom,4)
            HStack {
                Text("Explore").font(.system(.title2,design:.serif).weight(.semibold))
                Spacer()
                FieldIconButton(symbol:detent == .map ? "chevron.up" : "chevron.down",label:detent == .map ? "Show places" : "Show full map") {
                    searching=false
                    withAnimation(SidewalkMotion.spring(reduced)) {detent = detent == .map ? .browse : .map}
                }
            }.padding(.horizontal,20)
        }.frame(minHeight:64).contentShape(Rectangle())
            .accessibilityAdjustableAction {direction in
                withAnimation(SidewalkMotion.spring(reduced)) {
                    detent=ExploreDetent(rawValue:max(0,min(2,detent.rawValue+(direction == .increment ? 1 : -1)))) ?? .browse
                }
            }
            .gesture(DragGesture(minimumDistance:8).onChanged {value in drag=value.translation.height}.onEnded {value in
                searching=false
                let projected=detent.height(in:available,accessibility:typeSize.isAccessibilitySize)-value.predictedEndTranslation.height
                withAnimation(SidewalkMotion.spring(reduced)) {detent = .nearest(to:projected,in:available,accessibility:typeSize.isAccessibilitySize);drag=0}
            })
    }
}
