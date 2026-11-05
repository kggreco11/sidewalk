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

- Expand neighborhood coverage with editorially reviewed stories and verified pedestrian entrances.
- Complete place-photo coverage: 39 licensed covers integrated; 94 curated places still need reviewed images. See `lib/data/place-image-gaps.json`.
- Import reviewed POPOS (81 source rows) and separate 1% Public Art (65 source rows), with access review and deduplication. See `docs/PUBLIC-DATA-REVIEW.md`.
- Research additional structured history and local culture sources, including Wikidata enrichment.
- Account-backed saved places and collection sync.
- Current access/closure data and production routing/geocoding providers before broader launch.

## Native iOS — in progress

SwiftUI Explore, bookmarks, direct walking routes, and photo/note check-ins are implemented in `ios/`. Remaining: simulator/device visual QA, scenic multi-stop routing, continuous foreground GPS/navigation, camera capture, custom map styling, and distribution signing. See `ios/README.md`.

## Arrival unlocks — prototype implemented

- Preview photo/name/teaser/address before arriving; full stories unlock with an on-device foreground location check.
- 75 m arrival radius, reported accuracy at most 35 m, fix at most 15 seconds old; uncertainty must fit within 100 m.
- Unlocked stories persist locally. Existing manual stamps/photos/notes are preserved but do not count as verified unlocks.
- Production follow-up: review public-access arrival coordinates, field-test city GPS, account sync, and server-validated rewards if stamps gain monetary or competitive value. Client-side unlocks are an experience gate, not anti-cheat enforcement.
