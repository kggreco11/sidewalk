import MapKit

struct Place: Codable, Identifiable, Hashable {
  let id: String
  let name: String
  let lat: Double
  let lng: Double
  let category: String
  let story: String
  let source: String
  let sourceName: String
  let address: String?
  let teaser: String?
  let image: String?
  let imageLocal: String?
  let imageCredit: String?
  let imageSource: String?
  let imageLicenseUrl: String?
  var coordinate: CLLocationCoordinate2D { .init(latitude: lat, longitude: lng) }
  var kind: String {
    let text = category.lowercased()
    if text.contains("art") || text.contains("mural") { return "Art" }
    if text.contains("park") || text.contains("garden") { return "Parks" }
    if text.contains("architecture") { return "Architecture" }
    if text.contains("film") || text.contains("culture") || text.contains("literature") {
      return "Culture"
    }
    return "History"
  }
  var icon: String {
    [
      "Art": "paintpalette", "Parks": "leaf", "Architecture": "building.2", "Culture": "book",
      "History": "building.columns",
    ][kind] ?? "mappin"
  }
}
