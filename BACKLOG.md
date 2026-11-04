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
- Add licensed place photography with attribution; no artwork images are imported from the new datasets.
- Research additional structured history and local culture sources, including Wikidata enrichment.
- Account-backed saved places and collection sync.
- Current access/closure data and production routing/geocoding providers before broader launch.

## Native iOS — in progress

SwiftUI Explore, bookmarks, direct walking routes, and photo/note check-ins are implemented in `ios/`. Remaining: simulator/device visual QA, scenic multi-stop routing, foreground GPS/proximity, camera capture, custom map styling, and distribution signing. See `ios/README.md`.
