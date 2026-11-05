import SwiftUI

/// Field-guide colors and controls shared by the native screens.
enum FieldStyle {
    static let clay = Color(red:0.67,green:0.32,blue:0.21)
    static let secondary = Color(red:0.36,green:0.40,blue:0.41)
    static let inset = Color(red:0.91,green:0.91,blue:0.88)
    static let radius:CGFloat = 24
}

struct FieldPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    @Environment(\.accessibilityReduceMotion) private var reduced
    func makeBody(configuration:Configuration)->some View {
        configuration.label.font(.headline).foregroundStyle(enabled ? paper : FieldStyle.secondary)
            .frame(maxWidth:.infinity,minHeight:52)
            .background(enabled ? ink : FieldStyle.inset,in:RoundedRectangle(cornerRadius:16))
            .scaleEffect(configuration.isPressed && !reduced ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.easeOut(duration:0.14),value:configuration.isPressed)
    }
}

struct FieldIconButton: View {
    let symbol:String
    let label:String
    let action:()->Void
    var body:some View {
        Button(action:action) {Image(systemName:symbol).font(.system(.body,weight:.semibold)).frame(width:44,height:44)}
            .buttonStyle(.plain).accessibilityLabel(label)
    }
}

struct PlaceRow:View {
    @EnvironmentObject var guide:FieldGuide
    @Environment(\.dynamicTypeSize) private var typeSize
    let place:Place
    let open:()->Void
    var body:some View {
        HStack(alignment:.top,spacing:12) {
            Button(action:open) {
                HStack(alignment:.top,spacing:12) {
                    if !typeSize.isAccessibilitySize {
                        PlaceCover(place:place).frame(width:76,height:88).clipped().clipShape(RoundedRectangle(cornerRadius:12)).accessibilityHidden(true)
                    }
                    VStack(alignment:.leading,spacing:5) {
                        Text(place.kind).font(.caption.weight(.medium)).foregroundStyle(FieldStyle.secondary)
                        Text(place.name).font(.system(.headline,design:.serif)).foregroundStyle(ink).fixedSize(horizontal:false,vertical:true)
                        Text(place.teaser ?? place.address ?? "San Francisco")
                            .font(.subheadline).foregroundStyle(FieldStyle.secondary).lineLimit(typeSize.isAccessibilitySize ? nil : 2)
                        if guide.unlocked.contains(place.id) {
                            Label("Collected",systemImage:"sparkle").font(.caption.weight(.medium)).foregroundStyle(FieldStyle.clay)
                        }
                    }.frame(maxWidth:.infinity,alignment:.leading)
                }.contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityElement(children:.combine)
            FieldIconButton(symbol:guide.saved.contains(place.id) ? "bookmark.fill" : "bookmark",label:"\(guide.saved.contains(place.id) ? "Unsave" : "Save") \(place.name)") {guide.toggle(place)}
        }.padding(.vertical,12)
    }
}

enum ExploreDetent:Int,CaseIterable {
    case map, browse, full
    func height(in available:CGFloat, accessibility:Bool=false)->CGFloat {
        let maximum=max(140,available-64)
        switch self {
        case .map:return min(maximum,140)
        case .browse:return min(maximum,max(320,available * (accessibility ? 0.72 : 0.53)))
        case .full:return maximum
        }
    }
    static func nearest(to height:CGFloat,in available:CGFloat,accessibility:Bool=false)->ExploreDetent {
        allCases.min {abs($0.height(in:available,accessibility:accessibility)-height) < abs($1.height(in:available,accessibility:accessibility)-height)} ?? .browse
    }
}
