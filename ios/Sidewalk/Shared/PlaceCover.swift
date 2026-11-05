import SwiftUI

struct PlaceCover: View {
  let place: Place
  var body: some View {
    if let local = place.imageLocal, let image = UIImage(named: local) {
      Image(uiImage: image).resizable().scaledToFill().accessibilityLabel(place.name)
    } else if let image = place.image, let url = URL(string: image), url.scheme == "https" {
      AsyncImage(url: url) { phase in
        if let image = phase.image {
          image.resizable().scaledToFill().accessibilityLabel(place.name)
        } else {
          fallback
        }
      }
    } else {
      fallback
    }
  }
  var fallback: some View {
    ZStack {
      ink.opacity(0.06)
      Image(systemName: place.icon).font(.system(size: 36, weight: .light)).foregroundStyle(ink)
    }.accessibilityLabel(place.name)
  }
}
