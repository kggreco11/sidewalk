# Code guide

The product is the native SwiftUI app. The repository also retains the earlier web prototype and the shared catalog import tools.

```text
ios/
  project.yml                 XcodeGen source of truth
  Sidewalk/
    App/                      Entry point and illustrated opening
    Features/
      Explore/                Discovery map and place details
      Walking/                Planning, tour state, routing and navigation
      FieldGuide/             Saved places, visits and check-in editor
    Models/                   Place, dated visit and persistent tour values
    Location/                 Starting-position and arrival acquisition
    Storage/                  Atomic guide, tour and draft persistence
    Shared/                   Visual styles, motion, covers and search UI
    Resources/                Bundled catalog, licensed covers and assets
  SidewalkTests/              Journey, routing, location and storage regressions
lib/data/                     Shared normalized catalog and media manifests
scripts/                      Import, image and catalog maintenance
docs/                         Source research, design decisions and evidence
app/, components/, lib/       Earlier web prototype
```

## Where changes belong

- `TourController` owns tour transitions and commits. Screens invoke it instead of editing saved sessions directly. `TourRouting` is the replaceable routing interface; `AppleTourRouting` uses MapKit.
- `TourSession` and related models contain durable values. Keep their Codable names compatible with existing on-device saves. `TourStore` rejects corrupt archives and writes atomically before publishing state.
- `WalkNavigation` owns live guidance and its location lifecycle. `WalkingProgress` matches fixes to route geometry; `ArrivalPolicy` defines the shared verification rules. `StartingLocation` and `VisitLocation` handle bounded one-shot acquisition.
- `FieldGuide` owns saves, stamps and dated moments. `GuideStorage` persists them; `MomentDraftStore` protects unfinished edits. Photo bytes stay separate from metadata.
- `WalkPlanner` composes planning and walking panels over the existing map. `StopStory` and `WalkSummaryContent` are shared by the active journey and archive.
- Shared appearance lives in `DesignSystem` and `SidewalkMotion`. Respect Dynamic Type and Reduce Motion; keep controls at least 44 points.

## Commands

Run from the repository root. XcodeGen regenerates the committed project after source additions or moves.

```sh
xcodegen generate --spec ios/project.yml
xcrun swift-format format --in-place --recursive ios/Sidewalk ios/SidewalkTests
xcrun swift-format lint --strict --recursive ios/Sidewalk ios/SidewalkTests
xcodebuild -project ios/Sidewalk.xcodeproj -scheme Sidewalk \
  -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Choose an installed simulator name if yours differs. Run the existing regression suite after changes to routing, GPS, persistence or check-in behavior.

## Catalog maintenance

Edit or import reviewed records under `lib/data/`, then run `node scripts/sync-ios-catalog.mjs` to regenerate the bundled native catalog and cover-gap list. Keep place IDs stable: saves, moments and tour stops refer to them. Image credits and licenses belong in the media manifest; public visibility alone is not reuse permission. See [data provenance](DATA-SOURCES.md) and [source roadmap](DATA-SOURCE-ROADMAP.md).

The [web prototype notes](WEB-PROTOTYPE.md) retain its separate Node setup and deployment details. Keep its runtime files separate from native feature work.
