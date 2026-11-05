import SwiftUI

struct FieldGuideView:View {
    @EnvironmentObject private var guide:FieldGuide
    @Environment(\.dismiss) private var dismiss
    @State private var tab=0
    @State private var selected:Place?
    @State private var pending:Place?
    let walk:(Place)->Void
    private var places:[Place] {
        guide.places.filter {tab == 0 ? guide.saved.contains($0.id) : guide.unlocked.contains($0.id) || guide.visits[$0.id] != nil}
            .sorted {$0.name.localizedStandardCompare($1.name) == .orderedAscending}
    }
    var body:some View {
        NavigationStack {
            VStack(spacing:0) {
                HStack(alignment:.center,spacing:12) {
                    DiscoveryStar().fill(FieldStyle.clay).frame(width:32,height:32).accessibilityHidden(true)
                    VStack(alignment:.leading,spacing:4) {
                        Text("Your field guide").font(.system(.title,design:.serif).weight(.semibold))
                        Text("\(guide.unlocked.count) collected · \(guide.saved.count) saved").font(.subheadline).foregroundStyle(FieldStyle.secondary)
                    }
                    Spacer()
                }.padding(20)
                Picker("Collection",selection:$tab) {Text("Saved").tag(0);Text("Collected").tag(1)}.pickerStyle(.segmented).padding(.horizontal,20).padding(.bottom,12)
                if places.isEmpty {
                    ContentUnavailableView(tab == 0 ? "Places for another day" : "Your first discovery awaits",systemImage:tab == 0 ? "bookmark" : "sparkle",description:Text(tab == 0 ? "Save a place while exploring to keep it here." : "Visit a place and check in to collect a visit stamp."))
                } else {
                    ScrollView {
                        LazyVStack(spacing:0) {ForEach(places) {place in
                            PlaceRow(place:place) {selected=place}
                            if tab == 1,let visit=guide.visits[place.id] {
                                VStack(alignment:.leading,spacing:12) {
                                    if !visit.note.isEmpty {Text(visit.note).font(.body).foregroundStyle(ink)}
                                    if let data=visit.photo,let image=UIImage(data:data) {Image(uiImage:image).resizable().scaledToFill().frame(height:180).clipped().clipShape(RoundedRectangle(cornerRadius:16))}
                                    Text(visit.date,style:.date).font(.caption).foregroundStyle(FieldStyle.secondary)
                                }.frame(maxWidth:.infinity,alignment:.leading).padding(.bottom,16)
                            }
                            Divider()
                        }}.padding(.horizontal,20)
                    }
                }
            }.background(paper).foregroundStyle(ink)
                .toolbar {ToolbarItem(placement:.topBarTrailing) {Button("Done") {dismiss()}}}
                .sheet(item:$selected,onDismiss:{if let place=pending {pending=nil;walk(place)}}) {place in
                    PlaceDetail(place:place) {pending=place;selected=nil}.environmentObject(guide)
                }
        }
    }
}
