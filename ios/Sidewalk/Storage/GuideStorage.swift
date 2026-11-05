import Foundation

struct GuideStorage {
  struct Record: Codable {
    var saved: Set<String>
    var unlocked: Set<String>
    var visits: [String: StoredVisit]
    var history: [StoredHistory]? = nil
  }
  struct StoredVisit: Codable {
    var note: String
    var date: Date
    var photoFile: String?
  }
  struct StoredHistory: Codable {
    var id: UUID
    var placeID: String
    var visit: StoredVisit
    var verified: Bool
  }
  struct Snapshot {
    var saved: Set<String>
    var unlocked: Set<String>
    var visits: [String: Visit]
    var history: [VisitRecord] = []
  }
  let directory: URL
  private var metadata: URL { directory.appendingPathComponent("guide-v1.json") }
  init(directory: URL? = nil) {
    self.directory =
      directory
      ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("Sidewalk", isDirectory: true)
  }
  private func photoURL(_ file: String?) throws -> URL? {
    guard let file else { return nil }
    guard file.hasPrefix("photo-"), file.hasSuffix(".jpg"),
      file == URL(fileURLWithPath: file).lastPathComponent
    else { throw CocoaError(.fileReadCorruptFile) }
    let url = directory.appendingPathComponent(file)
    guard FileManager.default.fileExists(atPath: url.path) else {
      throw CocoaError(.fileReadNoSuchFile)
    }
    return url
  }
  private func snapshot(_ record: Record) throws -> Snapshot {
    var visits: [String: Visit] = [:]
    for (identity, value) in record.visits {
      visits[identity] = Visit(
        note: value.note, date: value.date, photoURL: try photoURL(value.photoFile))
    }
    let history =
      try record.history?.map { entry in
        VisitRecord(
          id: entry.id, placeID: entry.placeID, note: entry.visit.note, date: entry.visit.date,
          photoURL: try photoURL(entry.visit.photoFile), verified: entry.verified)
      }
      ?? visits.map {
        VisitRecord(
          placeID: $0.key, note: $0.value.note, date: $0.value.date, photoURL: $0.value.photoURL,
          verified: record.unlocked.contains($0.key))
      }
    return Snapshot(
      saved: record.saved, unlocked: record.unlocked, visits: visits,
      history: history.sorted { $0.date > $1.date })
  }
  func load(legacy: UserDefaults = .standard) throws -> Snapshot {
    if FileManager.default.fileExists(atPath: metadata.path) {
      return try snapshot(JSONDecoder().decode(Record.self, from: Data(contentsOf: metadata)))
    }
    let visits =
      try legacy.data(forKey: "visits").map {
        try JSONDecoder().decode([String: Visit].self, from: $0)
      } ?? [:]
    let unlocked = Set(legacy.stringArray(forKey: "unlockedPlaces") ?? [])
    let history = visits.map {
      VisitRecord(
        placeID: $0.key, note: $0.value.note, date: $0.value.date, photo: $0.value.photo,
        verified: unlocked.contains($0.key))
    }
    return try save(
      Snapshot(
        saved: Set(legacy.stringArray(forKey: "savedPlaces") ?? []), unlocked: unlocked,
        visits: visits, history: history))
  }
  @discardableResult func save(_ state: Snapshot) throws -> Snapshot {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let old =
      FileManager.default.fileExists(atPath: metadata.path)
      ? try JSONDecoder().decode(Record.self, from: Data(contentsOf: metadata)) : nil
    var record = Record(saved: state.saved, unlocked: state.unlocked, visits: [:], history: [])
    var staged: [URL] = []
    func storePhoto(_ data: @autoclosure () -> Data?, source: URL?, existing: String?) throws
      -> String?
    {
      if let source {
        guard
          source.deletingLastPathComponent().standardizedFileURL == directory.standardizedFileURL,
          try photoURL(source.lastPathComponent) != nil
        else { throw CocoaError(.fileReadCorruptFile) }
        return source.lastPathComponent
      }
      guard let data = data() else { return nil }
      if let existing, let prior = try? photoURL(existing), (try? Data(contentsOf: prior)) == data {
        return existing
      }
      let filename = "photo-\(UUID().uuidString).jpg"
      let destination = directory.appendingPathComponent(filename)
      try data.write(
        to: destination, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
      staged.append(destination)
      return filename
    }
    do {
      for (identity, visit) in state.visits {
        let file = try storePhoto(
          visit.photo, source: visit.photoURL, existing: old?.visits[identity]?.photoFile)
        record.visits[identity] = .init(note: visit.note, date: visit.date, photoFile: file)
      }
      for entry in state.history {
        let existing =
          old?.history?.first { $0.id == entry.id }?.visit.photoFile
          ?? record.visits[entry.placeID]?.photoFile
        let file = try storePhoto(entry.photo, source: entry.photoURL, existing: existing)
        record.history?.append(
          .init(
            id: entry.id, placeID: entry.placeID,
            visit: .init(note: entry.note, date: entry.date, photoFile: file),
            verified: entry.verified))
      }
      let normalized = try snapshot(record)
      try JSONEncoder().encode(record).write(
        to: metadata, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
      return normalized
    } catch {
      for file in staged { try? FileManager.default.removeItem(at: file) }
      throw error
    }
  }
}
