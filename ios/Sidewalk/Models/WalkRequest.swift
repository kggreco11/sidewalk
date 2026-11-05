import Foundation

struct WalkRequest: Identifiable {
  let id = UUID()
  var destination: Place?
}
