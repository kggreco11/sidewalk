import Foundation

struct MomentDraft {
  var placeID: String
  var recordID: UUID?
  var note: String
  var photo: Data?
}
actor MomentDraftStore {
  static let shared = MomentDraftStore()
  private struct Metadata: Codable {
    var placeID: String
    var recordID: UUID?
    var note: String
    var photoFile: String?
  }
  private let directory: URL
  init(directory: URL? = nil) {
    self.directory =
      directory
      ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("Sidewalk/Drafts")
  }
  private func metadataURL(_ key: String) -> URL {
    let encoded = Data(key.utf8).base64EncodedString().replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "+", with: "-")
    return directory.appendingPathComponent("draft-\(encoded).json")
  }
  private func photoURL(_ file: String) throws -> URL {
    guard file.hasPrefix("draft-photo-"), file.hasSuffix(".jpg"),
      file == URL(fileURLWithPath: file).lastPathComponent
    else { throw CocoaError(.fileReadCorruptFile) }
    return directory.appendingPathComponent(file)
  }
  func load(_ key: String) throws -> MomentDraft? {
    let url = metadataURL(key)
    guard FileManager.default.fileExists(atPath: url.path) else { return nil }
    let metadata = try JSONDecoder().decode(Metadata.self, from: Data(contentsOf: url))
    let photo = try metadata.photoFile.map { try Data(contentsOf: photoURL($0)) }
    return .init(
      placeID: metadata.placeID, recordID: metadata.recordID, note: metadata.note, photo: photo)
  }
  func save(_ draft: MomentDraft, key: String) throws {
    try Task.checkCancellation()
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let url = metadataURL(key)
    let previous =
      FileManager.default.fileExists(atPath: url.path)
      ? try JSONDecoder().decode(Metadata.self, from: Data(contentsOf: url)) : nil
    var file: String?
    var staged: URL?
    do {
      if let photo = draft.photo {
        if let prior = previous?.photoFile, let priorURL = try? photoURL(prior),
          (try? Data(contentsOf: priorURL)) == photo
        {
          file = prior
        } else {
          let filename = "draft-photo-\(UUID().uuidString).jpg"
          let destination = directory.appendingPathComponent(filename)
          try photo.write(
            to: destination,
            options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
          file = filename
          staged = destination
        }
      }
      let metadata = Metadata(
        placeID: draft.placeID, recordID: draft.recordID, note: draft.note, photoFile: file)
      try JSONEncoder().encode(metadata).write(
        to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    } catch {
      if let staged { try? FileManager.default.removeItem(at: staged) }
      throw error
    }
    if let prior = previous?.photoFile, prior != file, let priorURL = try? photoURL(prior) {
      try? FileManager.default.removeItem(at: priorURL)
    }
  }
  func clear(_ key: String) throws {
    let url = metadataURL(key)
    let metadata = try? JSONDecoder().decode(Metadata.self, from: Data(contentsOf: url))
    if FileManager.default.fileExists(atPath: url.path) {
      try FileManager.default.removeItem(at: url)
    }
    if let file = metadata?.photoFile { try? FileManager.default.removeItem(at: photoURL(file)) }
  }
}
