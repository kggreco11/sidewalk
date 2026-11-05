import MapKit
import SwiftUI

@MainActor final class TourController: ObservableObject {
  @Published private(set) var session: TourSession?
  @Published private(set) var history: [TourSession] = []
  @Published private(set) var busy = false
  @Published var error: String?
  @Published var notice: String?
  private let store: TourStore
  private let router: any TourRouting
  private var writable = true
  private var generation = UUID()
  init(store: TourStore = TourStore(), router: (any TourRouting)? = nil) {
    self.store = store
    self.router = router ?? AppleTourRouting()
    do {
      let archive = try store.load()
      session = archive.current
      history = archive.history
      if var restored = session, restored.phase == .walking {
        restored.runningSince = nil
        restored.pause(reason: "Your walk is ready to resume.")
        session = restored
        try store.save(.init(current: restored, history: history))
      }
    } catch {
      writable = false
      self.error =
        "Your saved walks couldn’t be opened. Existing data has been preserved. Restart to try again."
    }
  }
  @discardableResult private func commit(
    _ next: TourSession?, history nextHistory: [TourSession]? = nil
  ) -> Bool {
    guard writable else {
      error = "Saved walks are unavailable. Restart before making changes."
      return false
    }
    do {
      try store.save(.init(current: next, history: nextHistory ?? history))
      generation = UUID()
      busy = false
      session = next
      if let nextHistory { history = nextHistory }
      return true
    } catch {
      self.error = "Couldn’t save the walk. Your previous walk is safe. Try again."
      return false
    }
  }
  func cancelWork() {
    generation = UUID()
    busy = false
  }
  private func buildLegs(origin: RoutePoint, stops: [TourStop]) async throws -> [WalkingLeg] {
    var source = origin
    var legs: [WalkingLeg] = []
    for stop in stops {
      try Task.checkCancellation()
      legs.append(try await router.leg(from: source, to: stop.point))
      source = stop.point
    }
    return legs
  }
  func prepare(
    origin: RoutePoint, target: TourStop, catalog: [Place], count: Int, extraMinutes: Int,
    direct: WalkingLeg
  ) async {
    guard !busy else { return }
    let token = UUID()
    generation = token
    busy = true
    error = nil
    notice = nil
    defer { if token == generation { busy = false } }
    do {
      let stops = TourSuggestions.stops(from: origin, to: target, catalog: catalog, count: count)
      let legs = stops.count == 1 ? [direct] : try await buildLegs(origin: origin, stops: stops)
      try Task.checkCancellation()
      guard token == generation else { return }
      let extra = legs.reduce(0) { $0 + $1.duration } - direct.duration
      guard stops.count == 1 || extra <= Double(extraMinutes * 60) + 30 else {
        error =
          "These stops add about \(Int(ceil(extra / 60))) minutes. Increase extra walking time or choose fewer stops."
        return
      }
      if commit(.init(origin: origin, stops: stops, legs: legs)), stops.count < count {
        notice =
          "Found \(stops.count) distinct stops near this route. You can add more from the map."
      }
    } catch is CancellationError {} catch {
      if token == generation {
        self.error =
          "Couldn’t build the walk. Check your connection and try again. Your previous walk is still available."
      }
    }
  }
  func start() {
    guard var next = session, next.phase != .finished, next.currentLeg != nil else { return }
    next.phase = .walking
    next.startedAt = next.startedAt ?? Date()
    next.runningSince = Date()
    next.pauseReason = nil
    commit(next)
  }
  func pause(reason: String? = nil, progress: Double? = nil) {
    guard var next = session, next.phase == .walking else { return }
    if let progress, progress.isFinite, progress >= 0 { next.legProgress = progress }
    next.pause(reason: reason)
    commit(next)
  }
  func checkpoint(at now: Date = Date(), progress: Double? = nil, force: Bool = false) {
    guard !busy, var next = session, next.phase == .walking, let since = next.runningSince,
      force || now.timeIntervalSince(since) >= 30
    else { return }
    next.walkingSeconds = next.elapsed(at: now)
    next.runningSince = now
    if let progress, progress.isFinite, progress >= 0 { next.legProgress = progress }
    commit(next)
  }
  func recordArrival(verified: Bool, recordID: UUID? = nil, stopID: String? = nil) {
    guard var next = session, next.stops.indices.contains(next.activeIndex), next.phase != .preview,
      next.phase != .finished
    else { return }
    guard stopID == nil || next.currentStop?.id == stopID else { return }
    next.stops[next.activeIndex].status = .visited
    next.stops[next.activeIndex].visitedAt = next.stops[next.activeIndex].visitedAt ?? Date()
    if verified { next.stops[next.activeIndex].verifiedAt = Date() }
    if let recordID { next.stops[next.activeIndex].visitRecordID = recordID }
    commit(next)
  }
  func attachMoment(_ recordID: UUID, stopID: String? = nil) {
    guard var next = session, next.stops.indices.contains(next.activeIndex) else { return }
    guard stopID == nil || next.currentStop?.id == stopID else { return }
    next.stops[next.activeIndex].visitRecordID = recordID
    commit(next)
  }
  func advance(skipping: Bool, from location: RoutePoint?) async {
    guard !busy, var next = session, next.currentStop != nil, next.phase != .finished else {
      return
    }
    let token = UUID()
    generation = token
    busy = true
    error = nil
    notice = nil
    defer { if token == generation { busy = false } }
    let current = next.activeIndex
    if skipping {
      next.stops[current].status = .skipped
    } else {
      next.stops[current].status = .visited
      next.stops[current].visitedAt = next.stops[current].visitedAt ?? Date()
    }
    if current + 1 == next.stops.count {
      next.activeIndex = next.stops.count
      finish(next)
      return
    }
    do {
      if skipping {
        let source = location ?? next.currentLeg!.origin
        next.legs[current + 1] = try await router.leg(
          from: source, to: next.stops[current + 1].point)
        if location == nil {
          notice =
            "The next leg uses the planned start. Update from your location when GPS is available."
        }
      }
      try Task.checkCancellation()
      guard token == generation else { return }
      next.activeIndex += 1
      next.legProgress = nil
      commit(next)
    } catch is CancellationError {} catch {
      if token == generation {
        self.error = "Couldn’t route to the next stop. Your current walk is unchanged. Try again."
      }
    }
  }
  func reroute(from origin: RoutePoint) async {
    guard !busy, var next = session, let stop = next.currentStop else { return }
    let token = UUID()
    generation = token
    busy = true
    error = nil
    defer { if token == generation { busy = false } }
    do {
      let replacement = try await router.leg(from: origin, to: stop.point)
      try Task.checkCancellation()
      guard token == generation else { return }
      next.legs[next.activeIndex] = replacement
      next.legProgress = nil
      commit(next)
    } catch is CancellationError {} catch {
      if token == generation {
        self.error = "Couldn’t update directions. The previous path and steps are still available."
      }
    }
  }
  func add(_ place: Place) async {
    guard !busy, var next = session, next.phase != .finished else { return }
    guard !next.stops.contains(where: { $0.id == place.id }) else {
      notice = "This place is already in your walk."
      return
    }
    let token = UUID()
    generation = token
    busy = true
    error = nil
    defer { if token == generation { busy = false } }
    do {
      let insertion = next.phase == .preview ? max(0, next.stops.count - 1) : next.activeIndex + 1
      next.stops.insert(TourStop(place), at: insertion)
      let origin = insertion == 0 ? next.origin : next.stops[insertion - 1].point
      let suffix = try await buildLegs(origin: origin, stops: Array(next.stops[insertion...]))
      try Task.checkCancellation()
      guard token == generation else { return }
      next.legs = Array(next.legs.prefix(insertion)) + suffix
      if commit(next) { notice = "Added \(place.name) as stop \(insertion + 1)." }
    } catch is CancellationError {} catch {
      if token == generation {
        self.error = "Couldn’t add this stop. Your existing walk is unchanged."
      }
    }
  }
  func end() { if let session { finish(session) } }
  private func finish(_ session: TourSession) {
    notice = nil
    error = nil
    var next = session
    next.walkingSeconds = next.elapsed()
    next.runningSince = nil
    next.phase = .finished
    next.finishedAt = Date()
    var updated = history.filter { $0.id != next.id }
    updated.insert(next, at: 0)
    commit(next, history: updated)
  }
  func dismissFinished() { if session?.phase == .finished { commit(nil) } }
  func discardPreview() { if session?.phase == .preview { commit(nil) } }
  func reorder(from offsets: IndexSet, to destination: Int) async {
    guard !busy, var next = session, next.phase == .preview else { return }
    let token = UUID()
    generation = token
    busy = true
    error = nil
    defer { if token == generation { busy = false } }
    next.stops.move(fromOffsets: offsets, toOffset: destination)
    do {
      next.legs = try await buildLegs(origin: next.origin, stops: next.stops)
      try Task.checkCancellation()
      guard token == generation else { return }
      commit(next)
    } catch is CancellationError {} catch {
      if token == generation {
        self.error = "Couldn’t reorder the walk. The previous stop order is still available."
      }
    }
  }
}
