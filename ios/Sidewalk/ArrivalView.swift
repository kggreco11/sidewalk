import SwiftUI

struct ArrivalView:View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("arrivalArtworkIndex") private var nextArtwork=0
    @State private var artwork=0
    @State private var showing=true
    private let artworks=["hillside","coast","neighborhood"]
    var body:some View {
        ZStack {
            ExploreView().accessibilityHidden(showing).allowsHitTesting(!showing)
            if showing {
                GeometryReader {geometry in
                    ZStack {
                        Image(artworks[artwork]).resizable().scaledToFill().frame(width:geometry.size.width,height:geometry.size.height).clipped().accessibilityHidden(true)
                        VStack {
                            VStack(spacing:10) {
                                Text("sidewalk").font(.system(.largeTitle,design:.serif)).fontWeight(.medium)
                                Text("San Francisco, on foot").font(.body)
                            }.padding(24).background(paper.opacity(0.95),in:RoundedRectangle(cornerRadius:8))
                            Spacer()
                            Button(action:enter) {HStack{Text("Explore");Spacer();Image(systemName:"arrow.up.right")}.font(.headline).padding(.horizontal,24).frame(minHeight:56)}.buttonStyle(.borderedProminent).controlSize(.large)
                        }.padding(.horizontal,24).padding(.top,max(64,geometry.safeAreaInsets.top+24)).padding(.bottom,geometry.safeAreaInsets.bottom+24)
                    }.background(paper)
                }.ignoresSafeArea().transition(.opacity)
            }
        }.task {
            artwork=(nextArtwork % artworks.count + artworks.count) % artworks.count
            nextArtwork=(artwork+1)%artworks.count
            do {try await Task.sleep(for:.seconds(2.6));enter()}catch{}
        }
    }
    private func enter(){guard showing else{return};withAnimation(reduceMotion ? nil : .easeOut(duration:0.24)){showing=false}}
}
