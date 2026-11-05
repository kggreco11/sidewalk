# Native simulator audit — November 4, 2026

## Map and navigation follow-up

Discovery markers are restored during route preview and walking. Go now presents the next instruction and destination with foreground GPS path progress, remaining distance/time, map following and recenter. Off-route fixes offer an explicit route update. Backgrounding stops location updates; returning resumes the current walk. Stale/imprecise fixes do not drive progress.

Stories are now readable before arrival. The simplified Check in button earns a local visit stamp; it no longer gates the story. Notes/photos still belong to a confirmed visit.

Four additional deterministic tests cover route projection, off-route distance, endpoint clamping and stale/inaccurate fix rejection (17 total). Physical outdoor navigation and background navigation remain unverified/not implemented respectively.

## Earlier quality pass

Native SwiftUI/MapKit, iPhone 17 Simulator. The app was interacted with through accessibility controls; compilation alone was not treated as UI verification.

### Implemented

- Persistent full-screen map, compact brand controls, bounded Explore panel with map/browse/full detents and accessible collapse/expand controls.
- Readable vertical place rows, actual covers where supplied, independent bookmarks, Saved/Collected field guide.
- Inline starting-point and destination fields, live Apple search suggestions, keyboard route submission, direct typed-address resolution, and cancellation of superseded requests.
- Route framing corrected: map layout margins and route-fit padding previously counted the bottom panel twice and zoomed out to the Bay Area.
- Quieter annotations and map accessibility grouping keep app controls discoverable.
- Single foreground current-location request with denial, accuracy, stale fix and timeout handling; typed entry cancels that request and clears its warning.
- Static walking directions are labeled accurately, with explicit Apple Maps navigation handoff.
- Atomic on-device metadata and separate photos; legacy preferences migrate while retaining the old recovery copy. Failed saves do not dismiss the note editor or silently overwrite unreadable data.

### Interactive evidence

- Explore opens with 133 places; collapse exposes the map and expand restores the list.
- Saved Paper Doll Bar appears in Field Guide and persists across app relaunch.
- Detail → Walk here correctly returns through the library and prefills the destination.
- Typed Ferry Building address → Paper Doll Bar yields a 27-minute, 1.8-km route, with both endpoints framed.
- Find route works on the first tap while editing. City Hall ambiguity is reported; selecting the inline City Hall result yields a 46-minute, 3.0-km route. Go displays steps and Edit returns to endpoints.
- Location refusal leaves stories locked and offers typed-address fallback. Typing clears the location warning.
- Four preferred-text-size increments keep Explore, collapse, route fields and Go reachable. Original simulator text size restored afterward.
- Simulator location permission was denied for failure-path testing. Physical-device permissions were not changed.

### Automated evidence

13 unit tests cover blank/typed/ambiguous/unmatched endpoints, stale asynchronous results, route invalidation and unchanged text commits, swapping endpoints, legacy photo migration, corrupt-store preservation, failed-write rollback, drawer bounds and projected snap targets. Latest simulator test run passes.

### Limits and release gates

- Coordinate-based simulator gestures failed in the automation layer. Collapse/expand controls were exercised, and detent mathematics tested; actual finger dragging still needs physical-device validation.
- Physical GPS arrival success, outdoor walking, battery consumption, background/foreground transitions during real navigation, maximum Dynamic Type and full VoiceOver were not verified.
- Current native route is direct and static. Live progress/rerouting, approaching-stop prompts and scenic multi-stop routing remain to build.
- Photos currently come from the library; no native camera capture yet.
- 39 of 133 places have bundled covers; remaining places use category artwork. Broader cover and editorial coverage remains necessary.
- Backup/export, obsolete-photo retention, large-library I/O performance, privacy disclosures and TestFlight distribution remain release work.
- Signed generic iOS build passes. The iPhone was unavailable for installation; this pass is verified in Simulator and has not yet updated the phone.
