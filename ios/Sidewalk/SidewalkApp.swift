import SwiftUI
import MapKit
import PhotosUI

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
