import SwiftUI

struct ArrivalView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showing = true
    private let artwork: UIImage?

    init() {
        let names = ["Arrival-hillside", "Arrival-coast", "Arrival-neighborhood"]
        let stored = UserDefaults.standard.integer(forKey: "arrivalArtworkIndex")
        let index = (stored % names.count + names.count) % names.count
        // Decode the bundled artwork before the welcome screen's first frame.
        let image = UIImage(named: names[index]) ?? UIImage(named: names[0])
        artwork = image?.preparingForDisplay() ?? image
        UserDefaults.standard.set((index + 1) % names.count, forKey: "arrivalArtworkIndex")
    }

    var body: some View {
        ZStack {
            ExploreView()
                .accessibilityHidden(showing)
                .allowsHitTesting(!showing)
                .scaleEffect(showing && !reduceMotion ? 0.98 : 1)
            if showing {
                GeometryReader { geometry in
                    ZStack {
                        if let artwork {
                            Image(uiImage: artwork).resizable().scaledToFill()
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .clipped().accessibilityHidden(true)
                        }
                        VStack {
                            VStack(spacing: 12) {
                                DiscoveryStar().fill(Color(red: 0.72, green: 0.40, blue: 0.28))
                                    .frame(width: 30, height: 30).accessibilityHidden(true)
                                Text("sidewalk").font(.system(.largeTitle, design: .serif)).fontWeight(.medium)
                            }.foregroundStyle(ink).padding(24)
                                .background(paper.opacity(0.95), in: RoundedRectangle(cornerRadius: 16))
                            Spacer()
                            Button(action: enter) {
                                HStack { Text("Explore"); Spacer(); Image(systemName: "arrow.up.right") }
                                    .font(.headline).foregroundStyle(paper)
                                    .padding(.horizontal, 24).frame(minHeight: 56)
                            }.buttonStyle(.borderedProminent).controlSize(.large)
                        }.padding(.horizontal, 24)
                            .padding(.top, max(64, geometry.safeAreaInsets.top + 24))
                            .padding(.bottom, geometry.safeAreaInsets.bottom + 24)
                    }.background(paper)
                }.ignoresSafeArea().transition(SidewalkMotion.welcome(reduced:reduceMotion)).zIndex(1)
            }
        }.background(paper).task {
            do {
                try await Task.sleep(for: .seconds(2.6))
                enter()
            } catch {}
        }
    }

    private func enter() {
        guard showing else { return }
        withAnimation(.easeInOut(duration: reduceMotion ? 0.15 : 0.65)) { showing = false }
    }
}

/// The discovery mark is shared with the app identity, without implying a rating.
struct DiscoveryStar: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width, h = rect.height
        path.move(to: CGPoint(x: w * 0.5, y: 0))
        path.addCurve(to: CGPoint(x: w, y: h * 0.5), control1: CGPoint(x: w * 0.65, y: h * 0.35), control2: CGPoint(x: w * 0.65, y: h * 0.35))
        path.addCurve(to: CGPoint(x: w * 0.5, y: h), control1: CGPoint(x: w * 0.65, y: h * 0.65), control2: CGPoint(x: w * 0.65, y: h * 0.65))
        path.addCurve(to: CGPoint(x: 0, y: h * 0.5), control1: CGPoint(x: w * 0.35, y: h * 0.65), control2: CGPoint(x: w * 0.35, y: h * 0.65))
        path.addCurve(to: CGPoint(x: w * 0.5, y: 0), control1: CGPoint(x: w * 0.35, y: h * 0.35), control2: CGPoint(x: w * 0.35, y: h * 0.35))
        path.closeSubpath()
        return path
    }
}
