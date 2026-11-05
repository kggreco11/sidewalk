# Earlier web prototype

These notes describe the earlier web app. The current product is the [native iPhone app](../ios/README.md).

A San Francisco walking-tour prototype with an Explore home: browse a few nearby discoveries, save places for later, or choose Walk here. You can also type a starting point and destination, optionally choose extra walking time / maximum distance, then generate a mapped itinerary. Numbered stops have sourced stories, pedestrian directions, and manual next-stop progression.

## iPhone app

The native SwiftUI prototype lives in `ios/`. Open `ios/Sidewalk.xcodeproj` in Xcode. See `ios/README.md` for implemented features and the remaining parity work. iOS is the product target; the hosted web app remains a prototype.

## Run

Node 22.13+ and npm. `npm install`, copy `.env.example` to `.env`, then `npm run dev`. `npm run build` creates the Cloudflare Worker output. `npx tsc --noEmit` checks types.

## Current behavior

- Explore shows all matching suggestions with clustered map pins, with neighborhood and interest filters, explicit Explore this area after panning, and browser-local bookmarks separate from visited stamps.
- Walk here preserves the selected catalog destination, asks for a typed starting point or explicitly requested location, and supports collecting the destination itself.
- 24 curated source records (16 public artworks and 8 parks) enrich the catalog; overlapping park identities preserve prior stamps. See `docs/DATA-SOURCES.md` for provenance, snapshot dates, and import instructions.

- MapLibre GL renders a custom field-guide vector style in `lib/map-style.ts`, using OpenFreeMap tiles. The map worker is copied from the installed package into generated public assets by the Vite config.
- Server-side catalog of SF Planning landmarks and SF Film Commission filming locations; the normalized data is in `lib/data/places.json` with per-stop source links.
- Photon geocodes user-entered places. A small exact-name cache handles common landmarks. Search is limited to mainland San Francisco.
- FOSSGIS OSRM pedestrian matrices select up to five stops. Walking-time and distance budgets are enforced on the final street route. Sparse routes can have fewer than three stops. Two minutes per stop is a separate estimated allowance, not part of the extra walking budget.
- Category diversity and randomized scoring vary tours. This is a heuristic, not a global optimum.
- When `OPENAI_API_KEY` is set server-side, the Responses API writes short narratives using only supplied facts. `OPENAI_MODEL` defaults to `gpt-4.1-mini`. The model does not invent geographic coordinates or walking directions. Secrets never go to the browser.
- Without a key, or on an AI API error, the app honestly labels sourced-story mode and shows original source descriptions / factual templates. This mode is functional but is not live LLM generation.
- “I’m here” collects a stamp and opens an optional photo/note editor. Visits, notes, one compressed photo per place, and completed-walk milestones persist in browser localStorage; no account sync or server photo upload. Photos are resized to 960px and encoded as JPEG. Browser storage limits are reported without claiming a failed save succeeded. Clearing browser data removes the collection.
- Audio is disabled. Better narration is deferred in BACKLOG.md. Live walking uses foreground GPS with a follow/recenter map, route-distance and upcoming-instruction card, and a nearby state within 50 m when GPS accuracy is 50 m or better. Fixes older than 20 seconds are stale. Off-route detection does not reroute. Location watching pauses when the page is hidden and stops when the walk ends. Arrival and next-stop progression remain manual. Live GPS fixes are not persisted or sent to the app server. Choosing Use my location when planning sends that starting coordinate to the app server and routing provider; map tile requests reflect the displayed area.
- The `plan_san_francisco_walk` WebMCP tool shares the UI planning action and rejects invalid input.

## Data refresh

Run `node scripts/import-sf.mjs` to fetch and normalize the public city datasets. It skips proposed landmarks, missing coordinates, broad filming areas, duplicates, and one known erroneous intersection record. City data can still contain approximate or incorrect coordinates and uneven descriptions. Sources do not establish present-day public access, current operating status, or closures. Outdoor stop locations should be editorially reviewed before a public launch. Wikidata enrichment is not yet implemented.

Sources:
- https://sfplanninggis.org/arcgiswa/rest/services/PlanningData/MapServer/11
- https://data.sf.gov/d/yitu-d5am
- https://citylights.com/our-story/a-short-history-of-city-lights/
- Photo: https://commons.wikimedia.org/wiki/File:Transamerica_Pyramid_from_Columbus.jpg (public domain)

## Services and deployment

This is a private low-volume prototype. Photon and the FOSSGIS pedestrian router are public demonstration services without availability guarantees. Requests are serialized per running instance and paced at least 1.15 seconds apart; geocoding results are cached per instance. Before broader use, replace these endpoints with hosted/self-hosted services and implement shared rate limiting and durable caching. Environment variables `GEOCODER_URL` and `ROUTER_URL` support changing providers without changing application logic (compatible API required). OpenFreeMap, OpenMapTiles, and OpenStreetMap attribution is displayed.

For live AI, configure `OPENAI_API_KEY` as a Sites production secret and redeploy. The local `.env` is ignored by Git. No key is included in this project. The browser status endpoint reveals only whether AI is configured and catalog counts.

## Validation

TypeScript check; successful local HTTP rendering; complete itinerary / zero-detour / impossible-distance / identical-endpoints / unknown-place / real-address integration checks; WebMCP valid and invalid requests; UI start/next-stop checks; phone-width overflow and map asset checks. Live OpenAI generation requires credentials and has not been exercised without them.
