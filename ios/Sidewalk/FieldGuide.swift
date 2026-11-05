import SwiftUI
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
        if text.contains("film") || text.contains("culture") || text.contains("literature") { return "Culture" }
        return "History"
    }
    var icon: String { ["Art":"paintpalette", "Parks":"leaf", "Architecture":"building.2", "Culture":"book", "History":"building.columns"][kind] ?? "mappin" }
}
struct Visit: Codable { var note: String; var date: Date; var photo: Data? }
@MainActor final class FieldGuide: ObservableObject {
    @Published var places:[Place]=[]
    @Published private(set) var saved:Set<String>=[]
    @Published private(set) var visits:[String:Visit]=[:]
    @Published private(set) var unlocked:Set<String>=[]
    @Published var error:String?
    private let storage:GuideStorage
    private var writable=false
    init(storage:GuideStorage=GuideStorage(),legacy:UserDefaults = .standard) {
        self.storage=storage
        do {
            guard let url=Bundle.main.url(forResource:"places",withExtension:"json") else {throw CocoaError(.fileNoSuchFile)}
            places=try JSONDecoder().decode([Place].self,from:Data(contentsOf:url))
        } catch {self.error="The place catalog could not be loaded."}
        do {
            let state=try storage.load(legacy:legacy)
            saved=state.saved;visits=state.visits;unlocked=state.unlocked;writable=true
        } catch {self.error="Your saved field guide could not be opened. Your existing data has been preserved. Restart the app to try again."}
    }
    @discardableResult private func commit(saved:Set<String>,unlocked:Set<String>,visits:[String:Visit])->Bool {
        guard writable else {error="Your field guide is unavailable. Restart the app before saving changes.";return false}
        do {
            try storage.save(.init(saved:saved,unlocked:unlocked,visits:visits))
            self.saved=saved;self.unlocked=unlocked;self.visits=visits
            return true
        } catch {self.error="Couldn’t save this change. Your previous field guide is safe. Please try again.";return false}
    }
    func toggle(_ place:Place) {
        var next=saved
        if next.contains(place.id) {next.remove(place.id)} else {next.insert(place.id)}
        commit(saved:next,unlocked:unlocked,visits:visits)
    }
    func unlock(_ place:Place) {commit(saved:saved,unlocked:unlocked.union([place.id]),visits:visits)}
    @discardableResult func collect(_ place:Place,note:String,photo:Data?)->Bool {
        guard unlocked.contains(place.id) else {error="Confirm your arrival to collect this place.";return false}
        var next=visits
        next[place.id]=Visit(note:note,date:visits[place.id]?.date ?? Date(),photo:photo)
        return commit(saved:saved,unlocked:unlocked,visits:next)
    }
}
