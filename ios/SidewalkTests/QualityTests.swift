import XCTest
import MapKit
@testable import Sidewalk

@MainActor final class RoutePlannerTests:XCTestCase {
    final class FakeService:WalkingService {
        var addressFlags:[Bool]=[]
        var searchResult:[MKMapItem]=[]
        var routeCalls=0
        var suspended:CheckedContinuation<[MKMapItem],Error>?
        var started:(()->Void)?
        var suspend=false
        func search(_ query:String,addressesOnly:Bool) async throws -> [MKMapItem] {
            addressFlags.append(addressesOnly)
            if suspend {return try await withCheckedThrowingContinuation {suspended=$0;started?()}}
            return searchResult
        }
        func route(from:MKMapItem,to:MKMapItem) async throws -> MKRoute {routeCalls += 1;return MKRoute()}
    }
    func item(_ name:String)->MKMapItem {
        let value=MKMapItem(placemark:MKPlacemark(coordinate:.init(latitude:37.79,longitude:-122.41)));value.name=name;return value
    }
    func testBlankFieldsNeverRequestRoute() async {
        let service=FakeService();let model=RoutePlannerModel(service:service)
        await model.plan()
        XCTAssertFalse(model.canPlan);XCTAssertEqual(service.routeCalls,0);XCTAssertNotNil(model.error)
    }
    func testTypedStreetAddressResolvesBeforeRouting() async {
        let service=FakeService();service.searchResult=[item("City Hall")]
        let model=RoutePlannerModel(service:service)
        model.edit(.origin,text:"1 Dr Carlton B Goodlett Place")
        model.choose(.destination,item:item("Ferry Building"))
        await model.plan()
        XCTAssertEqual(service.addressFlags,[true]);XCTAssertEqual(service.routeCalls,1);XCTAssertNotNil(model.route);XCTAssertFalse(model.busy)
    }
    func testAmbiguousAddressRequiresSelection() async {
        let service=FakeService();service.searchResult=[item("First"),item("Second")]
        let model=RoutePlannerModel(service:service)
        model.edit(.origin,text:"Market Street");model.choose(.destination,item:item("Ferry Building"))
        await model.plan()
        XCTAssertEqual(service.routeCalls,0);XCTAssertNil(model.route);XCTAssertTrue(model.error?.contains("More than one") == true)
    }
    func testNoMatchIsActionable() async {
        let model=RoutePlannerModel(service:FakeService());model.edit(.origin,text:"unknown");model.choose(.destination,item:item("Destination"))
        await model.plan();XCTAssertTrue(model.error?.contains("No match") == true);XCTAssertFalse(model.busy)
    }
    func testEditingResolvedEndpointInvalidatesRoute() async {
        let service=FakeService();let model=RoutePlannerModel(service:service)
        model.choose(.origin,item:item("Origin"));model.choose(.destination,item:item("Destination"));await model.plan()
        model.active=true;model.edit(.origin,text:"Different address")
        XCTAssertNil(model.origin);XCTAssertNil(model.route);XCTAssertFalse(model.active)
    }
    func testSupersededSearchCannotRestoreOldRoute() async {
        let service=FakeService();service.suspend=true
        let began=expectation(description:"search started");service.started={began.fulfill()}
        let model=RoutePlannerModel(service:service)
        model.edit(.origin,text:"Old address");model.choose(.destination,item:item("Destination"))
        let task=Task {await model.plan()}
        await fulfillment(of:[began],timeout:2)
        model.edit(.origin,text:"New address")
        service.suspended?.resume(returning:[item("Old address")]);await task.value
        XCTAssertEqual(model.originText,"New address");XCTAssertNil(model.origin);XCTAssertNil(model.route);XCTAssertEqual(service.routeCalls,0)
    }
    func testUnchangedTextCommitPreservesResolvedRoute() async {
        let model=RoutePlannerModel(service:FakeService())
        model.choose(.origin,item:item("Origin"));model.choose(.destination,item:item("Destination"))
        await model.plan()
        model.edit(.origin,text:"Origin")
        XCTAssertNotNil(model.origin);XCTAssertNotNil(model.route)
    }
    func testSwapPreservesEndpointsAndClearsRoute() async {
        let model=RoutePlannerModel(service:FakeService())
        model.choose(.origin,item:item("A"));model.choose(.destination,item:item("B"));await model.plan();model.swap()
        XCTAssertEqual(model.originText,"B");XCTAssertEqual(model.destinationText,"A");XCTAssertNil(model.route)
    }
}

final class GuideStorageTests:XCTestCase {
    var root:URL!
    var defaults:UserDefaults!
    var suite:String!
    override func setUpWithError() throws {
        root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString,isDirectory:true)
        suite="SidewalkTests.\(UUID().uuidString)";defaults=UserDefaults(suiteName:suite)!
    }
    override func tearDownWithError() throws {try? FileManager.default.removeItem(at:root);defaults.removePersistentDomain(forName:suite)}
    func testLegacyMigrationPreservesPhotoNoteAndSavedPlaces() throws {
        let visit=Visit(note:"Remember this",date:Date(timeIntervalSince1970:100),photo:Data([1,2,3]))
        defaults.set(try JSONEncoder().encode(["p":visit]),forKey:"visits");defaults.set(["p"],forKey:"savedPlaces");defaults.set(["p"],forKey:"unlockedPlaces")
        let storage=GuideStorage(directory:root)
        _=try storage.load(legacy:defaults)
        let loaded=try storage.load(legacy:defaults)
        XCTAssertEqual(loaded.visits["p"]?.note,visit.note);XCTAssertEqual(loaded.visits["p"]?.photo,visit.photo)
        XCTAssertTrue(loaded.saved.contains("p"));XCTAssertTrue(loaded.unlocked.contains("p"));XCTAssertNotNil(defaults.data(forKey:"visits"))
        let data=try Data(contentsOf:root.appendingPathComponent("guide-v1.json"))
        let record=try JSONDecoder().decode(GuideStorage.Record.self,from:data)
        XCTAssertNotNil(record.visits["p"]?.photoFile)
    }
    func testCorruptStoreIsNotOverwrittenByMigration() throws {
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        let url=root.appendingPathComponent("guide-v1.json"),bad=Data("invalid".utf8)
        try bad.write(to:url)
        XCTAssertThrowsError(try GuideStorage(directory:root).load(legacy:defaults))
        XCTAssertEqual(try Data(contentsOf:url),bad)
    }
    func testFailedWriteLeavesCommittedMetadataIntact() throws {
        let storage=GuideStorage(directory:root)
        try storage.save(.init(saved:["original"],unlocked:[],visits:[:]))
        let before=try Data(contentsOf:root.appendingPathComponent("guide-v1.json"))
        // Encoding a non-finite date fails after staging the new photo.
        let bad=Visit(note:"bad",date:Date(timeIntervalSince1970:.infinity),photo:Data([4,5,6]))
        XCTAssertThrowsError(try storage.save(.init(saved:[],unlocked:[],visits:["bad":bad])))
        XCTAssertEqual(try Data(contentsOf:root.appendingPathComponent("guide-v1.json")),before)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath:root.path).count,1)
    }
}

final class DrawerTests:XCTestCase {
    func testDetentsStayWithinAvailableHeight() {
        for height:CGFloat in [320,600,844,1000] {
            for large in [false,true] {
                let values=ExploreDetent.allCases.map {$0.height(in:height,accessibility:large)}
                XCTAssertEqual(values,values.sorted());XCTAssertLessThanOrEqual(values.last!,height)
            }
        }
    }
    func testProjectedSwipeChoosesExpectedStop() {
        XCTAssertEqual(ExploreDetent.nearest(to:130,in:844),.map)
        XCTAssertEqual(ExploreDetent.nearest(to:440,in:844),.browse)
        XCTAssertEqual(ExploreDetent.nearest(to:800,in:844),.full)
    }
}
