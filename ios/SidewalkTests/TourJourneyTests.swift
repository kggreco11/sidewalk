import MapKit
import XCTest

@testable import Sidewalk

enum TourFixtures {
  static func point(_ name: String, _ metres: Double, _ east: Double = 0) -> RoutePoint {
    RoutePoint(
      name: name,
      coordinate: .init(latitude: 37.8 + metres / 111111, longitude: -122.41 + east / 88000))
  }
  static func place(_ name: String, _ metres: Double, _ east: Double = 0) -> Place {
    let coordinate = point(name, metres, east).coordinate
    return Place(
      id: name, name: name, lat: coordinate.latitude, lng: coordinate.longitude,
      category: "History", story: "A sourced local story.", source: "https://sf.gov",
      sourceName: "City", address: nil, teaser: nil, image: nil, imageLocal: nil, imageCredit: nil,
      imageSource: nil, imageLicenseUrl: nil)
  }
  static func leg(_ origin: RoutePoint, _ destination: RoutePoint, duration: Double? = nil)
    -> WalkingLeg
  {
    let length = WalkingPath(coordinates: [origin.coordinate, destination.coordinate]).length
    return .init(
      origin: origin, destination: destination, points: [origin, destination],
      steps: [.init(id: 0, instruction: "Walk north", start: 0, maneuver: .start)],
      distance: length, duration: duration ?? length / 1.2)
  }
  static func fix(_ point: RoutePoint, accuracy: Double = 5, age: Double = 0, now: Date = Date())
    -> CLLocation
  {
    CLLocation(
      coordinate: point.coordinate, altitude: 0, horizontalAccuracy: accuracy, verticalAccuracy: 0,
      timestamp: now.addingTimeInterval(-age))
  }
}

@MainActor final class TourJourneyTests: XCTestCase {
  final class Router: TourRouting {
    var calls: [(RoutePoint, RoutePoint)] = []
    var fail = false
    var duration: Double?
    var suspended: CheckedContinuation<Void, Error>?
    var suspend = false
    var began: (() -> Void)?
    func leg(from: RoutePoint, to: RoutePoint) async throws -> WalkingLeg {
      calls.append((from, to))
      if suspend {
        try await withCheckedThrowingContinuation {
          suspended = $0
          began?()
        }
      }
      if fail { throw RouteFailure("Offline") }
      return TourFixtures.leg(from, to, duration: duration)
    }
  }
  var root: URL!
  var router: Router!
  var controller: TourController!
  let origin = TourFixtures.point("Start", 0)
  var target: TourStop { TourStop(TourFixtures.place("Final", 600)) }
  var catalog: [Place] {
    [
      TourFixtures.place("First", 180), TourFixtures.place("Second", 380),
      TourFixtures.place("Final", 600),
    ]
  }
  override func setUp() async throws {
    root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    router = Router()
    controller = TourController(store: TourStore(directory: root), router: router)
  }
  override func tearDown() async throws { try? FileManager.default.removeItem(at: root) }
  func prepare(_ count: Int = 3) async {
    await controller.prepare(
      origin: origin, target: target, catalog: catalog, count: count, extraMinutes: 15,
      direct: TourFixtures.leg(origin, target.point))
  }
  func testCompleteThreeStopJourneyWithSkipAndStamp() async throws {
    await prepare()
    XCTAssertEqual(controller.session?.stops.count, 3)
    XCTAssertEqual(controller.session?.stops.map(\.id), ["First", "Second", "Final"])
    controller.start()
    controller.recordArrival(verified: true)
    await controller.advance(skipping: false, from: nil)
    XCTAssertEqual(controller.session?.activeIndex, 1)
    await controller.advance(skipping: true, from: TourFixtures.point("Current", 250))
    XCTAssertEqual(controller.session?.activeIndex, 2)
    await controller.advance(skipping: false, from: nil)
    let finished = try XCTUnwrap(controller.session)
    XCTAssertEqual(finished.phase, .finished)
    XCTAssertEqual(finished.visitedCount, 2)
    XCTAssertEqual(finished.stampCount, 1)
    XCTAssertEqual(finished.skippedCount, 1)
    XCTAssertEqual(controller.history.count, 1)
    controller.dismissFinished()
    let restored = TourController(store: TourStore(directory: root), router: router)
    XCTAssertNil(restored.session)
    XCTAssertEqual(restored.history.first?.id, finished.id)
  }
  func testPauseAndRelaunchPreserveStopAndOfflineGeometry() async throws {
    await prepare()
    controller.start()
    await controller.advance(skipping: false, from: nil)
    controller.pause(reason: "Pocketed phone", progress: 120)
    let identity = controller.session?.currentLeg?.id
    router.fail = true
    let restored = TourController(store: TourStore(directory: root), router: router)
    XCTAssertEqual(restored.session?.phase, .paused)
    XCTAssertEqual(restored.session?.activeIndex, 1)
    XCTAssertEqual(restored.session?.currentLeg?.id, identity)
    XCTAssertEqual(restored.session?.legProgress, 120)
    XCTAssertFalse(try XCTUnwrap(restored.session?.currentLeg?.steps).isEmpty)
    restored.start()
    XCTAssertEqual(restored.session?.phase, .walking)
  }
  func testUncleanRelaunchRestoresPausedWithoutCountingUnknownTime() async {
    await prepare()
    controller.start()
    let restored = TourController(store: TourStore(directory: root), router: router)
    XCTAssertEqual(restored.session?.phase, .paused)
    XCTAssertNil(restored.session?.runningSince)
    XCTAssertLessThan(restored.session?.walkingSeconds ?? 100, 2)
  }
  func testFailedRerouteKeepsWalkingStateLegAndStop() async {
    await prepare()
    controller.start()
    let before = controller.session
    router.fail = true
    await controller.reroute(from: TourFixtures.point("Current", 90))
    XCTAssertEqual(controller.session, before)
    XCTAssertNotNil(controller.error)
    XCTAssertFalse(controller.busy)
  }
  func testSuccessfulRerouteKeepsStopAndNavigationPhase() async {
    await prepare()
    controller.start()
    let stopID = controller.session?.currentStop?.id
    let oldLeg = controller.session?.currentLeg?.id
    await controller.reroute(from: TourFixtures.point("Current", 90))
    XCTAssertEqual(controller.session?.phase, .walking)
    XCTAssertEqual(controller.session?.currentStop?.id, stopID)
    XCTAssertNotEqual(controller.session?.currentLeg?.id, oldLeg)
    XCTAssertEqual(controller.session?.currentLeg?.origin.name, "Current")
  }
  func testSkipFailureDoesNotLoseOrMarkCurrentStop() async {
    await prepare()
    controller.start()
    let before = controller.session
    router.fail = true
    await controller.advance(skipping: true, from: TourFixtures.point("Current", 30))
    XCTAssertEqual(controller.session, before)
  }
  func testPauseDuringRerouteCannotResurrectWalking() async {
    await prepare()
    controller.start()
    let oldLeg = controller.session?.currentLeg?.id
    router.suspend = true
    let began = expectation(description: "rerouting")
    router.began = { began.fulfill() }
    let work = Task { await controller.reroute(from: TourFixtures.point("Current", 20)) }
    await fulfillment(of: [began], timeout: 2)
    controller.pause()
    router.suspended?.resume()
    await work.value
    XCTAssertEqual(controller.session?.phase, .paused)
    XCTAssertEqual(controller.session?.currentLeg?.id, oldLeg)
    XCTAssertFalse(controller.busy)
  }
  func testAddingDiscoveryPreservesCurrentLegAndFinalDestination() async {
    await prepare()
    controller.start()
    let oldLeg = controller.session?.currentLeg?.id
    await controller.add(TourFixtures.place("Extra", 260, 60))
    XCTAssertEqual(controller.session?.stops.map(\.id), ["First", "Extra", "Second", "Final"])
    XCTAssertEqual(controller.session?.currentLeg?.id, oldLeg)
    XCTAssertEqual(controller.session?.phase, .walking)
    XCTAssertEqual(controller.session?.legs.count, 4)
  }
  func testAddingExistingStopDoesNotDuplicateIt() async {
    await prepare()
    let before = controller.session
    await controller.add(catalog[0])
    XCTAssertEqual(controller.session, before)
  }
  func testReorderingPreviewRebuildsLegsButFailureKeepsOrder() async {
    await prepare()
    router.fail = true
    await controller.reorder(from: IndexSet(integer: 0), to: 2)
    XCTAssertEqual(controller.session?.stops.map(\.id), ["First", "Second", "Final"])
    router.fail = false
    await controller.reorder(from: IndexSet(integer: 0), to: 2)
    XCTAssertEqual(controller.session?.stops.map(\.id), ["Second", "First", "Final"])
    XCTAssertEqual(controller.session?.legs[0].destination.name, "Second")
    XCTAssertEqual(controller.session?.legs[1].origin.name, "Second")
  }
  func testBudgetFailurePreservesPreviouslyPreparedWalk() async {
    await prepare(1)
    let before = controller.session
    router.duration = 2000
    await prepare(3)
    XCTAssertEqual(controller.session, before)
    XCTAssertTrue(controller.error?.contains("minutes") == true)
  }
  func testEndingEarlySavesPartialSummaryOnlyOnce() async {
    await prepare()
    controller.start()
    controller.recordArrival(verified: false)
    controller.end()
    controller.end()
    XCTAssertEqual(controller.history.count, 1)
    XCTAssertEqual(controller.history[0].visitedCount, 1)
    XCTAssertEqual(controller.history[0].stops.filter { $0.status == .pending }.count, 2)
  }
  func testDelayedVerificationCannotStampAnotherStop() async {
    await prepare()
    controller.start()
    let firstID = controller.session!.currentStop!.id
    await controller.advance(skipping: false, from: nil)
    controller.recordArrival(verified: true, recordID: UUID(), stopID: firstID)
    XCTAssertNil(controller.session?.currentStop?.verifiedAt)
    XCTAssertEqual(controller.session?.currentStop?.status, .pending)
  }
  func testCorruptArchiveIsPreservedAndCannotBeOverwritten() throws {
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let file = root.appendingPathComponent("tours-v1.json")
    let bad = Data("broken".utf8)
    try bad.write(to: file)
    let broken = TourController(store: TourStore(directory: root), router: router)
    XCTAssertNotNil(broken.error)
    XCTAssertEqual(try Data(contentsOf: file), bad)
  }
}

final class TestLocationManager: CLLocationManager {
  var status: CLAuthorizationStatus = .authorizedWhenInUse
  var starts = 0
  var stops = 0
  var permissionRequests = 0
  override var authorizationStatus: CLAuthorizationStatus { status }
  override var accuracyAuthorization: CLAccuracyAuthorization { .fullAccuracy }
  override func startUpdatingLocation() { starts += 1 }
  override func stopUpdatingLocation() { stops += 1 }
  override func requestWhenInUseAuthorization() { permissionRequests += 1 }
}

@MainActor final class LocationJourneyTests: XCTestCase {
  func testWeakFixThenPreciseFixCanVerifyInOneAttempt() {
    let source = TestLocationManager()
    let place = TourFixtures.place("Stop", 200)
    let verifier = VisitLocation(manager: source)
    var callbacks = 0
    verifier.verify(place) { callbacks += 1 }
    XCTAssertTrue(verifier.checking)
    XCTAssertEqual(source.starts, 1)
    verifier.locationManager(
      source, didUpdateLocations: [TourFixtures.fix(TourFixtures.point("Here", 200), accuracy: 90)])
    XCTAssertTrue(verifier.checking)
    XCTAssertEqual(callbacks, 0)
    verifier.locationManager(
      source, didUpdateLocations: [TourFixtures.fix(TourFixtures.point("Here", 200))])
    XCTAssertFalse(verifier.checking)
    XCTAssertEqual(callbacks, 1)
    verifier.locationManager(
      source, didUpdateLocations: [TourFixtures.fix(TourFixtures.point("Here", 200))])
    XCTAssertEqual(callbacks, 1)
  }
  func testPreciseRecentNavigationFixAvoidsAnotherAcquisition() {
    let source = TestLocationManager()
    let place = TourFixtures.place("Stop", 200)
    let verifier = VisitLocation(manager: source)
    var verified = false
    verifier.verify(place, preferredFix: TourFixtures.fix(TourFixtures.point("Here", 200))) {
      verified = true
    }
    XCTAssertTrue(verified)
    XCTAssertEqual(source.starts, 0)
  }
  func testDeniedAndRestrictedDoNotAcquireOrVerify() {
    for status: CLAuthorizationStatus in [.denied, .restricted] {
      let source = TestLocationManager()
      source.status = status
      let verifier = VisitLocation(manager: source)
      var verified = false
      verifier.verify(TourFixtures.place("Stop", 200)) { verified = true }
      XCTAssertFalse(verifier.checking)
      XCTAssertFalse(verified)
      XCTAssertEqual(source.starts, 0)
      XCTAssertEqual(verifier.canOpenSettings, status == .denied)
    }
  }
  func testCancelledPermissionRequestCannotRestartVerification() {
    let source = TestLocationManager()
    source.status = .notDetermined
    let verifier = VisitLocation(manager: source)
    verifier.verify(TourFixtures.place("Stop", 200)) { XCTFail("Cancelled verification completed") }
    XCTAssertEqual(source.permissionRequests, 1)
    verifier.cancel()
    source.status = .authorizedWhenInUse
    verifier.locationManagerDidChangeAuthorization(source)
    XCTAssertEqual(source.starts, 0)
    XCTAssertFalse(verifier.checking)
  }
  func testStartingPointWaitsForPreciseFixAndCancelsCleanly() {
    let manager = TestLocationManager()
    let starting = StartingLocation(manager: manager)
    var received: MKMapItem?
    starting.request { received = $0 }
    starting.locationManager(
      manager, didUpdateLocations: [TourFixtures.fix(TourFixtures.point("Here", 50), accuracy: 80)])
    XCTAssertTrue(starting.busy)
    XCTAssertNil(received)
    starting.locationManager(
      manager, didUpdateLocations: [TourFixtures.fix(TourFixtures.point("Here", 50))])
    XCTAssertFalse(starting.busy)
    XCTAssertNotNil(received)
    starting.request { _ in XCTFail("Cancelled request completed") }
    starting.cancel()
    starting.locationManager(
      manager, didUpdateLocations: [TourFixtures.fix(TourFixtures.point("Here", 50))])
    XCTAssertFalse(starting.busy)
  }
  func testNavigationKeepsLastProgressWhenGpsBecomesImprecise() {
    let source = TestLocationManager()
    let navigation = WalkNavigation(manager: source)
    let origin = TourFixtures.point("Start", 0)
    let end = TourFixtures.point("End", 300)
    navigation.start(TourFixtures.leg(origin, end), target: end.coordinate)
    navigation.locationManager(
      source, didUpdateLocations: [TourFixtures.fix(TourFixtures.point("Here", 50))])
    let before = navigation.progress?.along
    XCTAssertTrue(navigation.live)
    navigation.locationManager(
      source, didUpdateLocations: [TourFixtures.fix(TourFixtures.point("Here", 250), accuracy: 100)]
    )
    XCTAssertFalse(navigation.live)
    XCTAssertEqual(navigation.state, .imprecise)
    XCTAssertEqual(navigation.progress?.along, before)
    navigation.stop()
    XCTAssertFalse(navigation.running)
  }
  func testBackgroundLocationOnlyRunsDuringAnAuthorizedActiveWalk() {
    let manager = TestLocationManager()
    let saved = UserDefaults.standard.object(forKey: "backgroundGuidance")
    let active = WalkNavigation(manager: manager)
    defer {
      active.stop()
      if let saved {
        UserDefaults.standard.set(saved, forKey: "backgroundGuidance")
      } else {
        UserDefaults.standard.removeObject(forKey: "backgroundGuidance")
      }
    }
    active.backgroundEnabled = true
    XCTAssertFalse(manager.allowsBackgroundLocationUpdates)
    let origin = TourFixtures.point("Start", 0)
    let end = TourFixtures.point("End", 300)
    active.start(TourFixtures.leg(origin, end), target: end.coordinate)
    XCTAssertEqual(
      Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String], ["location"])
    XCTAssertTrue(active.canContinueInBackground)
    XCTAssertTrue(manager.allowsBackgroundLocationUpdates)
    active.backgroundEnabled = false
    XCTAssertFalse(active.canContinueInBackground)
    XCTAssertFalse(manager.allowsBackgroundLocationUpdates)
    active.backgroundEnabled = true
    active.stop()
    XCTAssertFalse(manager.allowsBackgroundLocationUpdates)
    XCTAssertFalse(active.canContinueInBackground)
  }
}

final class MomentDraftTests: XCTestCase {
  func testDraftPhotoAndNoteSurviveReopeningAndClear() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = MomentDraftStore(directory: root)
    let identity = UUID()
    try await store.save(
      .init(placeID: "place", recordID: identity, note: "Unsaved thought", photo: Data([1, 2, 3])),
      key: "place/new")
    let reopened = MomentDraftStore(directory: root)
    let draft = try await reopened.load("place/new")
    XCTAssertEqual(draft?.note, "Unsaved thought")
    XCTAssertEqual(draft?.photo, Data([1, 2, 3]))
    XCTAssertEqual(draft?.recordID, identity)
    try await reopened.clear("place/new")
    let cleared = try await reopened.load("place/new")
    XCTAssertNil(cleared)
    XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.path).count, 0)
  }
  func testCancelledDraftWriteDoesNotReplaceSavedDraft() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = MomentDraftStore(directory: root)
    try await store.save(.init(placeID: "place", note: "Current", photo: nil), key: "key")
    let task = Task {
      do {
        try await Task.sleep(for: .seconds(1))
        try await store.save(.init(placeID: "place", note: "Obsolete", photo: nil), key: "key")
      } catch {}
    }
    task.cancel()
    await task.value
    let draft = try await store.load("key")
    XCTAssertEqual(draft?.note, "Current")
  }
}

final class WalkingGuidanceTests: XCTestCase {
  func tracker() -> ProgressTracker {
    let origin = TourFixtures.point("Start", 0)
    let end = TourFixtures.point("End", 300)
    var leg = TourFixtures.leg(origin, end)
    let length = WalkingPath(coordinates: [origin.coordinate, end.coordinate]).length
    leg.steps = [
      .init(id: 0, instruction: "Walk north", start: 0, maneuver: .start),
      .init(id: 1, instruction: "Turn left", start: length / 3, maneuver: .left),
      .init(id: 2, instruction: "Turn right", start: length * 2 / 3, maneuver: .right),
    ]
    return ProgressTracker(leg: leg)
  }
  func testTurnStaysVisibleBeforeAtAndJustAfterJunction() throws {
    var tracker = tracker()
    for metres in [50.0, 85, 89, 99, 100, 105, 110] {
      let result = try XCTUnwrap(
        tracker.update(
          TourFixtures.fix(TourFixtures.point("Here", metres)),
          target: TourFixtures.point("End", 300).coordinate))
      XCTAssertEqual(result.instruction, "Turn left", "Position \(metres)")
    }
    let after = try XCTUnwrap(
      tracker.update(
        TourFixtures.fix(TourFixtures.point("Here", 120)),
        target: TourFixtures.point("End", 300).coordinate))
    XCTAssertNotEqual(after.instruction, "Turn left")
  }
  func testInitialInstructionIsNotSkipped() {
    var tracker = tracker()
    XCTAssertEqual(
      tracker.update(
        TourFixtures.fix(TourFixtures.point("Start", 0)),
        target: TourFixtures.point("End", 300).coordinate)?.instruction, "Walk north")
  }
  func testRepeatedIntersectionUsesLocalProgressWindow() {
    let points = [
      TourFixtures.point("Start", 0), TourFixtures.point("Cross", 100),
      TourFixtures.point("Corner", 100, 100), TourFixtures.point("Cross", 100),
      TourFixtures.point("End", 200),
    ]
    let path = WalkingPath(coordinates: points.map(\.coordinate))
    let expected = WalkingPath(coordinates: Array(points.prefix(4)).map(\.coordinate)).length
    let result = path.project(points[3].coordinate, near: (expected - 25)...(expected + 25))
    XCTAssertEqual(result.along, expected, accuracy: 1)
  }
  func testRestoredProgressReacquiresTheCorrectPassAtAnIntersection() throws {
    let points = [
      TourFixtures.point("Start", 0), TourFixtures.point("Cross", 100),
      TourFixtures.point("Corner", 100, 100), TourFixtures.point("Cross", 100),
      TourFixtures.point("End", 300),
    ]
    let length = WalkingPath(coordinates: points.map(\.coordinate)).length
    let expected = WalkingPath(coordinates: Array(points.prefix(4)).map(\.coordinate)).length
    let leg = WalkingLeg(
      origin: points[0], destination: points[4], points: points,
      steps: [.init(id: 0, instruction: "Walk", start: 0, maneuver: .start)], distance: length,
      duration: 500)
    var restored = ProgressTracker(leg: leg, seedProgress: expected - 15)
    let fix = TourFixtures.fix(points[3])
    let result = try XCTUnwrap(restored.update(fix, target: points[4].coordinate))
    XCTAssertEqual(result.along, expected, accuracy: 1)
  }
  func testOutAndBackProgressFollowsMovementDirection() throws {
    let points = [
      TourFixtures.point("Start", 0), TourFixtures.point("Cross", 100),
      TourFixtures.point("Corner", 100, 100), TourFixtures.point("Cross", 100),
      TourFixtures.point("End", 200),
    ]
    let length = WalkingPath(coordinates: points.map(\.coordinate)).length
    let leg = WalkingLeg(
      origin: points[0], destination: points[4], points: points,
      steps: [.init(id: 0, instruction: "Walk", start: 0, maneuver: .start)], distance: length,
      duration: 400)
    var tracker = ProgressTracker(leg: leg)
    for metres in stride(from: 0.0, through: 100, by: 10) {
      _ = tracker.update(
        TourFixtures.fix(TourFixtures.point("Here", metres)), target: points[4].coordinate)
    }
    for east in stride(from: 10.0, through: 100, by: 10) {
      _ = tracker.update(
        TourFixtures.fix(TourFixtures.point("Here", 100, east)), target: points[4].coordinate)
    }
    for east in stride(from: 90.0, through: 0, by: -10) {
      _ = tracker.update(
        TourFixtures.fix(TourFixtures.point("Here", 100, east)), target: points[4].coordinate)
    }
    let result = try XCTUnwrap(tracker.lastProgress)
    let expected = WalkingPath(coordinates: Array(points.prefix(4)).map(\.coordinate)).length
    XCTAssertEqual(result.along, expected, accuracy: 8)
  }
  func testBadFixCannotChangeProgressOrCreateArrival() {
    var tracker = tracker()
    let target = TourFixtures.point("End", 300).coordinate
    _ = tracker.update(TourFixtures.fix(TourFixtures.point("Here", 40)), target: target)
    let before = tracker.lastProgress?.along
    XCTAssertNil(
      tracker.update(
        TourFixtures.fix(TourFixtures.point("End", 300), accuracy: 100), target: target))
    XCTAssertEqual(tracker.lastProgress?.along, before)
  }
  func testImplausibleGpsJumpCannotAdvanceOrAnnounceArrival() throws {
    var tracker = tracker()
    let target = TourFixtures.point("End", 300).coordinate
    let now = Date()
    _ = tracker.update(
      TourFixtures.fix(TourFixtures.point("Here", 40), now: now), target: target, now: now)
    let before = tracker.lastProgress?.along
    let result = try XCTUnwrap(
      tracker.update(
        TourFixtures.fix(TourFixtures.point("End", 300), now: now.addingTimeInterval(1)),
        target: target, now: now.addingTimeInterval(1)))
    XCTAssertTrue(result.offRoute)
    XCTAssertFalse(result.arrived)
    XCTAssertFalse(result.nearby)
    XCTAssertEqual(result.along, before)
    XCTAssertEqual(tracker.lastProgress?.along, before)
  }
  func testArrivalPolicyRejectsDistantStaleOrUncertainFixes() {
    let destination = TourFixtures.point("Stop", 100)
    XCTAssertTrue(
      ArrivalPolicy.canVerify(TourFixtures.fix(destination), at: destination.coordinate))
    XCTAssertFalse(
      ArrivalPolicy.canVerify(TourFixtures.fix(destination, age: 20), at: destination.coordinate))
    XCTAssertFalse(
      ArrivalPolicy.canVerify(
        TourFixtures.fix(destination, accuracy: 40), at: destination.coordinate))
    XCTAssertFalse(
      ArrivalPolicy.canVerify(
        TourFixtures.fix(TourFixtures.point("Far", 0)), at: destination.coordinate))
  }
  func testSuggestionSelectionAvoidsDuplicatePlaceCoordinates() {
    let first = TourFixtures.place("First", 200)
    let duplicate = TourFixtures.place("Duplicate", 201)
    let second = TourFixtures.place("Second", 400)
    let target = TourStop(TourFixtures.place("End", 600))
    let stops = TourSuggestions.stops(
      from: TourFixtures.point("Start", 0), to: target, catalog: [first, duplicate, second],
      count: 5)
    XCTAssertEqual(stops.count, 3)
    XCTAssertEqual(Set(stops.map(\.id)).count, 3)
    XCTAssertEqual(stops.last?.id, target.id)
  }
}

@MainActor final class PlaceAndMomentTests: XCTestCase {
  func testSearchAndSwapPreserveCatalogIdentity() {
    let place = TourFixtures.place("City Lights Bookstore", 200)
    let item = TourFixtures.point("City Lights", 200).mapItem
    XCTAssertEqual(PlaceIdentity.match(item, in: [place])?.id, place.id)
    XCTAssertNil(PlaceIdentity.match(TourFixtures.point("City Lights", 2000).mapItem, in: [place]))
    let model = RoutePlannerModel()
    model.catalog = [place]
    model.choose(.origin, item: item)
    model.choose(.destination, item: TourFixtures.point("Other", 400).mapItem)
    model.swap()
    XCTAssertEqual(model.place?.id, place.id)
  }
  func testPersonalNoteDoesNotEarnStampAndRepeatedVisitsKeepDates() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let suite = "TourTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer {
      try? FileManager.default.removeItem(at: root)
      defaults.removePersistentDomain(forName: suite)
    }
    let guide = FieldGuide(storage: GuideStorage(directory: root), legacy: defaults)
    let place = TourFixtures.place("Place", 100)
    XCTAssertTrue(guide.saveMoment(place, note: "Before arriving", photo: nil))
    XCTAssertFalse(guide.unlocked.contains(place.id))
    XCTAssertFalse(guide.visitHistory[0].verified)
    XCTAssertTrue(guide.unlock(place))
    let first = guide.visitHistory[0]
    XCTAssertTrue(
      guide.saveMoment(place, note: "At the place", photo: Data([1, 2]), recordID: first.id))
    XCTAssertEqual(guide.visitHistory.first?.date, first.date)
    XCTAssertTrue(guide.unlock(place))
    XCTAssertNotEqual(guide.visitHistory[0].id, first.id)
    XCTAssertEqual(guide.visitHistory.count, 3)
    let restored = FieldGuide(storage: GuideStorage(directory: root), legacy: defaults)
    XCTAssertEqual(restored.visitHistory.count, 3)
    XCTAssertEqual(restored.visitHistory.first(where: { $0.id == first.id })?.photo, Data([1, 2]))
    XCTAssertNotNil(restored.visitHistory.first(where: { $0.id == first.id })?.photoURL)
  }
  func testVerifyingAnExistingPersonalNoteKeepsItsIdentityAndPhoto() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let suite = "TourTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer {
      try? FileManager.default.removeItem(at: root)
      defaults.removePersistentDomain(forName: suite)
    }
    let guide = FieldGuide(storage: GuideStorage(directory: root), legacy: defaults)
    let place = TourFixtures.place("Stop", 200)
    XCTAssertTrue(guide.saveMoment(place, note: "Before arrival", photo: Data([4, 5])))
    let identity = try XCTUnwrap(guide.visitHistory.first?.id)
    XCTAssertEqual(guide.verifyVisit(place, recordID: identity), identity)
    XCTAssertEqual(guide.visitHistory.count, 1)
    XCTAssertTrue(guide.visitHistory[0].verified)
    XCTAssertEqual(guide.visitHistory[0].note, "Before arrival")
    XCTAssertEqual(guide.visitHistory[0].photo, Data([4, 5]))
  }
}
