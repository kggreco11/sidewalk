import SwiftUI

@main struct SidewalkApp: App {
  @StateObject private var guide = FieldGuide()
  @StateObject private var tour = TourController()
  var body: some Scene {
    WindowGroup {
      ArrivalView().environmentObject(guide).environmentObject(tour).tint(ink).preferredColorScheme(
        .light)
    }
  }
}
