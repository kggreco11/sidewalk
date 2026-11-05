# Sidewalk for iPhone

Native SwiftUI prototype, iOS 17+. Open `Sidewalk.xcodeproj` in Xcode, select an iPhone simulator, and Run. For a physical phone, select your own signing team first. This project has not been distributed through TestFlight or the App Store.

## Included

- All 133 curated places bundled locally, including official SF art and parks records.
- No five-place cap: all matching places in the lazy place list and native clustered map.
- Search, category filters, map recentering, source-linked details.
- Saved places and visited field notes persist on this device.
- Typed starting point, Apple walking route, step list, location-confirmed visit stamps, library photo and note.

Apple MapKit supplies this native prototype's map and direct walking directions. Search and routing require a network connection. The existing web MapLibre style has not been ported yet. The private Sites backend is not embedded or made public.

- Rotating illustrated opening and semantic Dynamic Type text.
- On-device arrival check with denied, weak, stale, distant, and timeout handling. Visit stamps persist locally; stories are readable before arrival.

## Remaining native parity

- Multi-stop scenic routing and walking-time budgets.
- Outdoor validation of foreground GPS guidance, background navigation, and automatic rerouting.
- Camera capture (the native prototype currently selects existing photos).
- MapLibre Native field-guide styling, if retained as the final map provider.
- Outdoor device QA, VoiceOver audit, Dynamic Type extremes, and TestFlight distribution.
- Backup/export and photo retention policy before production. Native notes use atomic Application Support metadata with separate photo files; legacy UserDefaults migrate without deleting the recovery copy. Native data does not sync with the web prototype.

## Build

```sh
xcodebuild -project ios/Sidewalk.xcodeproj -scheme Sidewalk -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

The committed Xcode project is generated from `ios/project.yml` using XcodeGen. Regenerate after adding Swift source files. The bundled catalog follows `lib/place-catalog.ts`; regenerate from the source datasets when those change. Data provenance is in `docs/DATA-SOURCES.md`.

## Native quality pass — November 4

Explore uses a persistent map with three panel heights, readable place rows, and independent save actions. Route fields and live suggestions appear over that same map. Typed addresses submit directly; ambiguous results require selection. Route requests cancel when input changes. Current location is an explicit foreground action, with typed-address fallback.

The Field Guide separates Saved and Collected. Place details keep Walk here reachable and keep stories readable and award a visit stamp after verified arrival. Go enters foreground walking guidance with the next instruction, GPS-based distance and time remaining, a following map, and a recenter control. An off-route state offers a new route from the current location. Discovery markers remain visible. Stale or inaccurate GPS suppresses progress; background navigation and automatic rerouting are not implemented.

Run regression tests with `xcodebuild -project ios/Sidewalk.xcodeproj -scheme Sidewalk -destination 'platform=iOS Simulator,name=iPhone 17' test`. See `docs/IOS-SIMULATOR-AUDIT.md` for observed coverage and limitations.
