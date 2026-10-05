# Sidewalk

A San Francisco walking-tour prototype: type a starting point and destination, optionally choose extra walking time / maximum distance, then generate a mapped itinerary. Numbered stops have sourced stories, device speech playback, pedestrian directions, and manual next-stop progression.

## Run

Node 22.13+ and npm. `npm install`, copy `.env.example` to `.env`, then `npm run dev`. `npm run build` creates the Cloudflare Worker output. `npx tsc --noEmit` checks types.

## Current behavior

- Server-side catalog of SF Planning landmarks and SF Film Commission filming locations; the normalized data is in `lib/data/places.json` with per-stop source links.
- Photon geocodes user-entered places. A small exact-name cache handles common landmarks. Search is limited to mainland San Francisco.
- FOSSGIS OSRM pedestrian matrices select up to five stops. Walking-time and distance budgets are enforced on the final street route. Sparse routes can have fewer than three stops. Two minutes per stop is a separate estimated allowance, not part of the extra walking budget.
- Category diversity and randomized scoring vary tours. This is a heuristic, not a global optimum.
- When `OPENAI_API_KEY` is set server-side, the Responses API writes short narratives using only supplied facts. `OPENAI_MODEL` defaults to `gpt-4.1-mini`. The model does not invent geographic coordinates or walking directions. Secrets never go to the browser.
- Without a key, or on an AI API error, the app honestly labels sourced-story mode and shows original source descriptions / factual templates. This mode is functional but is not live LLM generation.
- Browser speech synthesis provides narration where supported. There is no GPS tracking; next-stop progression is manual.
- The `plan_san_francisco_walk` WebMCP tool shares the UI planning action and rejects invalid input.

## Data refresh

Run `node scripts/import-sf.mjs` to fetch and normalize the public city datasets. It skips proposed landmarks, missing coordinates, broad filming areas, duplicates, and one known erroneous intersection record. City data can still contain approximate or incorrect coordinates and uneven descriptions. Sources do not establish present-day public access, current operating status, or closures. Outdoor stop locations should be editorially reviewed before a public launch. Wikidata enrichment is not yet implemented.

Sources:
- https://sfplanninggis.org/arcgiswa/rest/services/PlanningData/MapServer/11
- https://data.sf.gov/d/yitu-d5am
- https://citylights.com/our-story/a-short-history-of-city-lights/
- Photo: https://commons.wikimedia.org/wiki/File:Transamerica_Pyramid_from_Columbus.jpg (public domain)

## Services and deployment

This is a private low-volume prototype. Photon and the FOSSGIS pedestrian router are public demonstration services without availability guarantees. Requests are serialized per running instance and paced at least 1.15 seconds apart; geocoding results are cached per instance. Before broader use, replace these endpoints with hosted/self-hosted services and implement shared rate limiting and durable caching. Environment variables `GEOCODER_URL` and `ROUTER_URL` support changing providers without changing application logic (compatible API required). OSM attribution and an improve-the-map link are displayed.

For live AI, configure `OPENAI_API_KEY` as a Sites production secret and redeploy. The local `.env` is ignored by Git. No key is included in this project. The browser status endpoint reveals only whether AI is configured and catalog counts.

## Validation

TypeScript check; successful local HTTP rendering; complete itinerary / zero-detour / impossible-distance / identical-endpoints / unknown-place / real-address integration checks; WebMCP valid and invalid requests; UI start/next-stop checks; phone-width overflow and map asset checks. Live OpenAI generation requires credentials and has not been exercised without them.
