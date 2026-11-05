# Sidewalk for iPhone

Native SwiftUI prototype, iOS 17+. Open `Sidewalk.xcodeproj` in Xcode, select an iPhone simulator, and Run. For a physical phone, select your own signing team first. This project has not been distributed through TestFlight or the App Store.

## Included

- All 133 curated places bundled locally, including official SF art and parks records.
- No five-place cap: all matching places in the lazy card list and native clustered map.
- Search, category filters, neighborhood map positioning, source-linked details.
- Saved places and visited field notes persist on this device.
- Typed starting point, Apple walking route, step list, location-confirmed story unlock/check-in, library photo and note.

Apple MapKit supplies this native prototype's map and direct walking directions. Search and routing require a network connection. The existing web MapLibre style has not been ported yet. The private Sites backend is not embedded or made public.

- Rotating illustrated opening and semantic Dynamic Type text.
- On-device arrival check with denied, weak, stale, distant, and timeout handling. Stories remain unlocked locally.

## Remaining native parity

- Multi-stop scenic routing and walking-time budgets.
- Foreground GPS, approaching-stop prompts, and route progress.
- Camera capture (the native prototype currently selects existing photos).
- MapLibre Native field-guide styling, if retained as the final map provider.
- Visual simulator/device QA, Dynamic Type layout review, application icon and distribution signing.
- Native storage migration and backup policy before production; current notes/photos use UserDefaults and do not sync with the web prototype.

## Build

```sh
xcodebuild -project ios/Sidewalk.xcodeproj -scheme Sidewalk -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

The committed Xcode project is generated from `ios/project.yml` using XcodeGen. Regenerate after adding Swift source files. The bundled catalog follows `lib/place-catalog.ts`; regenerate from the source datasets when those change. Data provenance is in `docs/DATA-SOURCES.md`.
