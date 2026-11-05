import SwiftUI

@MainActor final class FieldGuide: ObservableObject {
  @Published var places: [Place] = []
  @Published private(set) var saved: Set<String> = []
  @Published private(set) var visits: [String: Visit] = [:]
  @Published private(set) var unlocked: Set<String> = []
  @Published private(set) var visitHistory: [VisitRecord] = []
  @Published var error: String?
  private let storage: GuideStorage
  private var writable = false
  init(storage: GuideStorage = GuideStorage(), legacy: UserDefaults = .standard) {
    self.storage = storage
    do {
      guard let url = Bundle.main.url(forResource: "places", withExtension: "json") else {
        throw CocoaError(.fileNoSuchFile)
      }
      places = try JSONDecoder().decode([Place].self, from: Data(contentsOf: url))
    } catch { self.error = "The place catalog could not be loaded." }
    do {
      let state = try storage.load(legacy: legacy)
      saved = state.saved
      visits = state.visits
      unlocked = state.unlocked
      visitHistory = state.history
      writable = true
    } catch {
      self.error =
        "Your saved field guide could not be opened. Your existing data has been preserved. Restart the app to try again."
    }
  }
  @discardableResult private func commit(
    saved: Set<String>, unlocked: Set<String>, visits: [String: Visit],
    history: [VisitRecord]? = nil
  ) -> Bool {
    guard writable else {
      error = "Your field guide is unavailable. Restart the app before saving changes."
      return false
    }
    do {
      let normalized = try storage.save(
        .init(saved: saved, unlocked: unlocked, visits: visits, history: history ?? visitHistory))
      self.saved = saved
      self.unlocked = unlocked
      self.visits = normalized.visits
      self.visitHistory = normalized.history
      return true
    } catch {
      self.error = "Couldn’t save this change. Your previous field guide is safe. Please try again."
      return false
    }
  }
  func toggle(_ place: Place) {
    var next = saved
    if next.contains(place.id) { next.remove(place.id) } else { next.insert(place.id) }
    commit(saved: next, unlocked: unlocked, visits: visits)
  }
  @discardableResult func unlock(_ place: Place) -> Bool {
    verifyVisit(place) != nil
  }
  @discardableResult func verifyVisit(_ place: Place, recordID: UUID? = nil) -> UUID? {
    var history = visitHistory
    let index = recordID.flatMap { identity in
      history.firstIndex { $0.id == identity && $0.placeID == place.id }
    }
    var record =
      index.map { history[$0] }
      ?? VisitRecord(placeID: place.id, note: "", date: Date(), photo: nil, verified: true)
    record.verified = true
    if let index { history[index] = record } else { history.insert(record, at: 0) }
    var next = visits
    next[place.id] = Visit(note: "", date: record.date, photo: nil)
    next[place.id] = Visit(note: record.note, date: record.date, photo: record.photo)
    return commit(
      saved: saved, unlocked: unlocked.union([place.id]), visits: next, history: history)
      ? record.id : nil
  }
  @discardableResult func saveMoment(
    _ place: Place, note: String, photo: Data?, recordID: UUID? = nil
  ) -> Bool {
    var history = visitHistory
    let index = recordID.flatMap { identity in
      history.firstIndex { $0.id == identity && $0.placeID == place.id }
    }
    var record =
      index.map { history[$0] }
      ?? VisitRecord(placeID: place.id, note: "", date: Date(), photo: nil, verified: false)
    record.note = note
    record.photo = photo
    if let index { history[index] = record } else { history.insert(record, at: 0) }
    var next = visits
    next[place.id] = Visit(note: note, date: record.date, photo: photo)
    return commit(saved: saved, unlocked: unlocked, visits: next, history: history)
  }
  @discardableResult func collect(_ place: Place, note: String, photo: Data?) -> Bool {
    guard unlocked.contains(place.id) else {
      error = "Confirm your arrival to collect this place."
      return false
    }
    return saveMoment(
      place, note: note, photo: photo,
      recordID: visitHistory.first(where: { $0.placeID == place.id && $0.verified })?.id)
  }
}
