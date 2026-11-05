# Native simulator audit — November 4, 2026

Interacted with the SwiftUI app on iPhone 17 / iOS 26.3 Simulator: Explore, place detail, destination picker, walk planner, generated route, Start walk, and arrival sheet. This is a native SwiftUI/MapKit implementation, but the navigation and layout still need work to feel native.

## Fixed and built

- Start a walk had navy text on a navy button; set explicit light foreground.
- Walk here lost the selected destination during sheet handoff. Present an identifiable request and initialize planner state from it. Retested Paper Doll Bar → Walk here → populated planner → successful route from Ferry Building.
- Removed duplicate address fallback from locked place details.
- Added opaque 1024px app icon with a rounded lower tail, plus version/build metadata.
- Simulator and signed device builds passed. Updated app installed on the connected iPhone.

## Remaining priorities

1. Native walking mode is a static direct route and directions list. Add live position, next-stop progression, arrival prompts, and scenic intermediate stops.
2. Explore stacks a map, headings, search, filters, carousel and action vertically. Simplify hierarchy and use native navigation between Explore, Saved and Field Guide.
3. Replace the long destination popup menu with a searchable selection sheet.
4. Route preview leaves substantial unused sheet space; make the map the primary full-screen surface with a compact bottom sheet.
5. Direction rows use the same right-turn symbol even for left turns.
6. Map labels overlap, some card titles wrap awkwardly, and many places still have generic image placeholders.
7. Native map styling does not yet match the web field-guide palette; photo capture currently uses the library rather than a camera flow.

## Limits

Arrival sheet rendered its locked state. Successful on-site geolocation, camera capture, Dynamic Type extremes, VoiceOver, and physical walking were not verified in this pass.
