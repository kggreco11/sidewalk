# Native walking-tour implementation

November 4, 2026. Implements the journey defined in `WALKING-TOUR-JOURNEY-AUDIT.md`.

## The implemented journey

1. Enter a start and destination on the existing map. Search includes curated places and Apple results; recognized Apple results retain their curated identity.
2. Choose one, three or five stops and an extra-walking allowance. Suggestions use the bundled catalog, select distinct places near the origin/destination corridor, and request real pedestrian directions through every stop. The measured walking-time increase is checked against the allowance. If fewer suitable places are available, the actual count is disclosed.
3. Review numbered map markers and a matching stop list, walking time and distance. Optional discoveries remain visible with quieter category markers and `+` cluster counts. Preview order can be changed through Stops → Edit. Adding a discovery calculates its actual walking legs before committing the change.
4. Start the current leg. The app displays its maneuver, next place, leg distance/time, written directions, itinerary, follow/recenter and whole-walk overview. Directions and saved route geometry remain readable without GPS or a network connection.
5. Approach and read the stop. Check-in is optional. A valid fresh fix can be reused for a verified stamp; otherwise the app makes a bounded acquisition attempt, allowing weak GPS to improve. Permission denial never gates the story or personal notes.
6. Keep an optional note, camera photo or library photo. A note can be saved without a stamp. Verifying that same visit preserves its note/photo and identity. Drafts restore after interruption; cancellation asks before discarding changes.
7. Continue or skip. The active stop advances without reentering the origin. Skipping routes around the stop; a failed request preserves the previous session. Stamps are associated with a specific stop so a delayed callback cannot stamp another one.
8. Finish with visited, stamped and skipped counts and the walk's notes/photos. The summary remains in Field Guide → Walks. Closing an active walk pauses and preserves it; reopening returns to the same stop.

## Session and navigation behavior

`TourSession` stores ordered place IDs, leg geometry/instructions, active index, stop status, visit-record references, elapsed active time and along-leg progress. `TourController` commits changes atomically and retains the previous session when search/routing/storage fails. Pausing and periodic checkpoints save progress without recording a location trace. Relaunch restores an interrupted walk as paused and uses its saved along-leg position to avoid snapping to an earlier pass through an intersection.

`ProgressTracker` uses a plausible range around prior progress and movement direction to distinguish nearby/repeated segments. It retains a turn until the walker has passed the maneuver with an accuracy-aware margin. Maneuver symbols are derived from route geometry rather than English string matching. Invalid, stale or imprecise fixes do not advance progress or verify visits.

An active, authorized walk supports background location while the phone is locked. The iOS location indicator remains enabled. Walk options include Keep guiding when locked; turning that off returns to explicit pause/resume when leaving Sidewalk. Pause, End, and closing the walk stop location updates. There is no Always authorization request and no automatic stamp collection. Background behavior follows [Apple's CLLocationManager guidance](https://developer.apple.com/documentation/corelocation/cllocationmanager/allowsbackgroundlocationupdates); physical lock-screen and battery behavior still require field validation.

Images are stored separately from metadata and loaded on demand. The legacy guide/preferences migration retains the old recovery values. Dated visit records distinguish repeat visits from lifetime collection status. Notes/photo drafts use separate atomic files, and photo-loading tasks cancel superseded selections.

## Design decisions

The same paper, ink, clay discovery star and sage completion colors connect the preview, current stop, visit stamp and summary. Current-leg ink is solid; future legs are quieter dashed lines. Numbered stop pins never cluster with optional discoveries. The map camera receives measured top/bottom panel sizes.

Walking panels have bounded scrollable content so maximum Dynamic Type cannot consume the entire map. Text respects the user's type setting; icon-only controls keep a stable glyph inside a 44-point target. Primary actions stay pinned. Status recovery actions stack at accessibility sizes. Field-guide tabs and stop-count choices expose separate named buttons with 44-point minimum targets.

Calculated contrast on paper: ink 10.01:1, secondary 5.29:1, clay 4.73:1, sage 5.68:1. Color is supplemented by labels, numbered markers and line patterns. Optional approach haptics are off by default. Meaningful maneuver changes announce to VoiceOver when the app is active, with throttling to avoid GPS chatter. Narration remains deferred.

## Audit disposition

| Finding | Implementation |
|---|---|
| W01: tour entity | Persistent ordered session, routed legs, current stop, continuation, skip and summary |
| W02: misleading markers | Distinct numbered itinerary pins, optional discovery/cluster styling, Add to walk and real routing |
| W03: identity loss | Curated search results, conservative external-result matching, identity retained through swaps and rerouting |
| W04: early turns | Explicit maneuver progression with passage margin and directional glyphs |
| W05: route matching | Local progress window, direction matching, backtracking state and restored progress seed |
| W06: interruption | Pause/resume, active-walk background configuration, saved progress, protected End and persistent session |
| W07: GPS dead end | State-specific status, Settings recovery, retained directions, planned/last-known labels |
| W08: reroute reset | Transactional current-leg replacement that preserves active phase and stop identity |
| W09: arrival handoff | Nearby/arrival state, direct optional check-in, stamp saved, Continue/Finish; stories always readable |
| W10: first weak fix | Bounded continuous acquisition, wait for better accuracy, transient-error handling, timeout after authorization |
| W11: no finish | Explicit partial/full summary, saved moments, durable walk history and Done |
| W12: large-text map loss | Bounded panels, measured map insets, scrollable large text and stable icon controls |
| W13: visual attention | Maneuver/approach cues, stop number, story/cover/address, optional haptics and VoiceOver announcements |
| W14: memory semantics | Dated visits, optional unverified notes, preserved note-to-stamp upgrade, drafts, camera/library/remove-photo controls |
| W15: effort/access | Actual routed estimates, extra-time budget and explicit unknown-access disclosure; no unsupported step-free claim |

This disposition means the application paths are implemented. It does not certify outdoor GPS, pedestrian entrances, accessibility of a physical route, or a production release.

## Verification

52 automated tests pass. Coverage includes complete three-stop progression with a stamp and a skip; full/partial summaries; restore with geometry and progress; failed reroute/skip/reorder; adding a stop without changing the current leg; route budget rejection; corrupt-store preservation; search identity; turn boundaries; out-and-back and repeated intersections; bad GPS and implausible jump rejection; weak-to-precise verification; cancellation; background-location enable/disable; note-to-stamp preservation; migration; lazy photos; draft restoration and cleanup.

Interactive Simulator verification includes:

- Three-stop Ferry Building → Paper Doll Bar tour, ~29 min / 1.9 km, with matching numbered pins and real legs.
- Saving an unverified field note, Cancel → Save note protection, continuing to stop two, skipping it, closing/reopening at stop three, finishing and recovering the note in the summary after relaunch.
- Field Guide → Walks → archived summary.
- Apple search result City Lights retained its curated story/address. Five-stop tour built at ~25 min / 1.5 km with five matching markers.
- Location-denied recovery, readable directions, stable current-stop state and named accessible controls.
- Maximum preferred-text layout inspected and corrected; all temporary Simulator text-size changes restored.

Screenshots are saved under `/Users/kevingreco/Documents/Codex/2026-10-04/can-x20/outputs/walking-tour-build/`. Native simulator tests and signed iOS builds pass. No GPS arrival was falsely recorded in the interactive simulator journey; verification-success tests use isolated synthetic fixtures.

Final validation: 52 tests passed with zero failures on November 4, 2026. Result bundle: `/tmp/sidewalk-ios-build/Logs/Test/Test-Sidewalk-2026.11.04_21-21-09--0800.xcresult`. The final signed build was installed on the connected iPhone, and the same revision was installed and launched in Simulator. `git diff --check` passes.

## Remaining release gates

- Physically walk a complete tour: noisy city GPS, repeated streets, approach/arrival, correct public entrance, photo capture, lock/unlock, background location and battery use.
- Full VoiceOver and smaller-device/landscape evaluation beyond the inspected iPhone 17 and maximum-type states.
- Broader reviewed photo/entrance/access coverage. Missing images use category artwork; unknown hills, stairs and step-free access are explicitly disclosed.
- TestFlight/App Store signing, privacy disclosures, backup/export and long-term photo retention. The installed app remains a development build.
- Rerouting is an explicit action so the walker controls changing the path. Physical navigation performance remains subject to field validation.
