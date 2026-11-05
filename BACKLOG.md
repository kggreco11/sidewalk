# Backlog

## Narration — deferred

The initial device-generated voiceover was removed after user feedback about poor voice quality. Keep the app text-only for now; do not restore browser speech synthesis.

Before reintroducing audio:
- Evaluate natural-sounding voices using actual San Francisco stop stories.
- Let the user approve sample voice, pronunciation, pacing, and tone.
- Provide intentional play/pause/stop controls; no autoplay.
- Keep written stories and sources available without audio.
- Confirm cost and API setup before connecting a paid service.

## Product constraints

- Keep UI copy functional. No slogans, motivational filler, decorative captions, or API-setup prompts in the walking flow.
- Live LLM integration is deferred at the user's request. No API key setup is needed for the current prototype.

## Explore prototype — implemented

- Explore home, all matching suggestions with clustered map pins, map/card details, neighborhood and interest filters.
- Save places locally; Walk here creates a route to the exact place and supports its destination stamp.
- Curated Civic Art Collection and Recreation & Parks records with source links and a repeatable importer.

## Next discovery work

Prioritized research and acceptance criteria: [Data-source roadmap](docs/DATA-SOURCE-ROADMAP.md).

- Expand neighborhood coverage with editorially reviewed stories and verified pedestrian entrances.
- Complete place-photo coverage: 39 licensed covers integrated; 94 curated places still need reviewed images. See `lib/data/place-image-gaps.json`.
- Import reviewed POPOS (81 source rows) and separate 1% Public Art (65 source rows), with access review and deduplication. See `docs/PUBLIC-DATA-REVIEW.md`.
- Build two reviewed cultural walks from SF Planning context statements; enrich identities using OHP BERD and NRHP bulk records.
- Pilot landmark trees and an archival “Then” collection, with public-viewing points and item-level image rights.
- Validate route ascent estimates against real SF hills using USGS terrain; keep accessibility claims separate from elevation.
- Account-backed saved places and collection sync.
- Current access/closure data and production routing/geocoding providers before broader launch.

## Native iOS — in progress

SwiftUI Explore, multi-stop walking tours, numbered routed stops, pause/resume, foreground/background guidance, camera/library notes and walk history are implemented in `ios/`. The tour regression suite has 52 passing tests. Remaining: outdoor GPS/entrance/battery/camera validation, complete VoiceOver and device-size QA, reviewed route-access data, broader cover images, backup/export and TestFlight/App Store distribution. See `ios/README.md` and `docs/design/WALKING-TOUR-BUILD.md`.

## Arrival unlocks — prototype implemented

- Stories are readable before arrival. On-device location confirmation earns a visit stamp; personal notes/photos remain available without verification.
- 75 m arrival radius, reported accuracy at most 35 m, fix at most 15 seconds old; uncertainty must fit within 100 m.
- Visit stamps and dated moments persist locally; new verification preserves an existing personal note/photo. Earlier manual moments remain distinct from verified stamps.
- Production follow-up: review public-access arrival coordinates, field-test city GPS, account sync, and server-validated rewards if stamps gain monetary or competitive value. Client-side unlocks are an experience gate, not anti-cheat enforcement.
