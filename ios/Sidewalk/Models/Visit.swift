import Foundation

struct Visit: Codable {
  var note: String
  var date: Date
  private var photoData: Data?
  var photoURL: URL?
  var photo: Data? {
    get { photoData ?? photoURL.flatMap { try? Data(contentsOf: $0) } }
    set {
      photoData = newValue
      photoURL = nil
    }
  }
  init(note: String, date: Date, photo: Data?) {
    self.note = note
    self.date = date
    photoData = photo
  }
  init(note: String, date: Date, photoURL: URL?) {
    self.note = note
    self.date = date
    self.photoURL = photoURL
  }
  private enum CodingKeys: String, CodingKey { case note, date, photo }
  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    note = try values.decode(String.self, forKey: .note)
    date = try values.decode(Date.self, forKey: .date)
    photoData = try values.decodeIfPresent(Data.self, forKey: .photo)
  }
  func encode(to encoder: Encoder) throws {
    var values = encoder.container(keyedBy: CodingKeys.self)
    try values.encode(note, forKey: .note)
    try values.encode(date, forKey: .date)
    try values.encodeIfPresent(photo, forKey: .photo)
  }
}
struct VisitRecord: Identifiable {
  var id: UUID = UUID()
  var placeID: String
  var note: String
  var date: Date
  private var photoData: Data?
  var photoURL: URL?
  var verified: Bool
  var photo: Data? {
    get { photoData ?? photoURL.flatMap { try? Data(contentsOf: $0) } }
    set {
      photoData = newValue
      photoURL = nil
    }
  }
  init(id: UUID = UUID(), placeID: String, note: String, date: Date, photo: Data?, verified: Bool) {
    self.id = id
    self.placeID = placeID
    self.note = note
    self.date = date
    photoData = photo
    self.verified = verified
  }
  init(id: UUID = UUID(), placeID: String, note: String, date: Date, photoURL: URL?, verified: Bool)
  {
    self.id = id
    self.placeID = placeID
    self.note = note
    self.date = date
    self.photoURL = photoURL
    self.verified = verified
  }
}
