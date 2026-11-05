import Foundation

/// One atomic metadata file; photos live separately so preferences never contain image blobs.
struct GuideStorage {
    struct Record:Codable {var saved:Set<String>;var unlocked:Set<String>;var visits:[String:StoredVisit]}
    struct StoredVisit:Codable {var note:String;var date:Date;var photoFile:String?}
    struct Snapshot {var saved:Set<String>;var unlocked:Set<String>;var visits:[String:Visit]}
    let directory:URL
    private var metadata:URL {directory.appendingPathComponent("guide-v1.json")}
    init(directory:URL?=nil) {
        self.directory=directory ?? FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("Sidewalk",isDirectory:true)
    }
    func load(legacy:UserDefaults = .standard) throws -> Snapshot {
        if FileManager.default.fileExists(atPath:metadata.path) {
            let record=try JSONDecoder().decode(Record.self,from:Data(contentsOf:metadata))
            var visits:[String:Visit]=[:]
            for (id,value) in record.visits {
                let photo:Data?
                if let file=value.photoFile {
                    guard file == URL(fileURLWithPath:file).lastPathComponent else {throw CocoaError(.fileReadCorruptFile)}
                    photo=try Data(contentsOf:directory.appendingPathComponent(file))
                } else {photo=nil}
                visits[id]=Visit(note:value.note,date:value.date,photo:photo)
            }
            return Snapshot(saved:record.saved,unlocked:record.unlocked,visits:visits)
        }
        let visits=try legacy.data(forKey:"visits").map {try JSONDecoder().decode([String:Visit].self,from:$0)} ?? [:]
        let snapshot=Snapshot(saved:Set(legacy.stringArray(forKey:"savedPlaces") ?? []),unlocked:Set(legacy.stringArray(forKey:"unlockedPlaces") ?? []),visits:visits)
        try save(snapshot)
        // Keep the legacy values as a recovery copy until a separately reviewed cleanup.
        return snapshot
    }
    func save(_ snapshot:Snapshot) throws {
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        var record=Record(saved:snapshot.saved,unlocked:snapshot.unlocked,visits:[:])
        // Preserve the currently committed photo files until the new metadata commits.
        let old=try? JSONDecoder().decode(Record.self,from:Data(contentsOf:metadata))
        var staged:[URL]=[]
        do {
            for (id,visit) in snapshot.visits {
                var photoFile:String?
                if let photo=visit.photo {
                    if let existing=old?.visits[id]?.photoFile,
                       (try? Data(contentsOf:directory.appendingPathComponent(existing))) == photo {
                        photoFile=existing
                    } else {
                        let file="photo-\(UUID().uuidString).jpg"
                        let url=directory.appendingPathComponent(file)
                        try photo.write(to:url,options:[.atomic,.completeFileProtectionUntilFirstUserAuthentication])
                        staged.append(url);photoFile=file
                    }
                }
                record.visits[id]=StoredVisit(note:visit.note,date:visit.date,photoFile:photoFile)
            }
            let data=try JSONEncoder().encode(record)
            try data.write(to:metadata,options:[.atomic,.completeFileProtectionUntilFirstUserAuthentication])
        } catch {
            for file in staged {try? FileManager.default.removeItem(at:file)}
            throw error
        }
        // Old photos remain recoverable; cleanup is a separate retention concern.
    }
}
