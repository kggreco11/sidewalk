# Data-source roadmap

Research checked **2026-11-04**. These are roadmap candidates, not newly imported content. No live API or account was connected. Recommendations below are product and implementation judgments; publisher terms and item rights remain the authority for reuse.

## What to prioritize

The strongest next release combines **POPOS and the separate 1% Public Art inventory**, already identified in [the earlier review](PUBLIC-DATA-REVIEW.md), with **better cultural stories and exact per-place photographs**. After that, add landmark trees and hill-aware route information. A large property database should remain a research pool rather than becoming thousands of undifferentiated Explore pins.

Already imported: SF Planning landmarks, Film Commission locations, Civic Art Collection, and Recreation & Parks properties. Already researched but not generally imported: POPOS, 1% Public Art, SF Survey, Cultural Districts, Legacy Businesses, Wikidata, Commons, OSM, DigitalSF, the NPS visitor API, Library of Congress and OpenSFHistory. The candidates below add new sources or resolve a previously underspecified integration path. Current media coverage and refresh commands remain in [PLACE-PHOTOS.md](PLACE-PHOTOS.md).

## Additional sources

### 1. SF Planning historic-context statements — first editorial investment

**New detail beyond the existing SF Survey review:** the current official index links completed documents on Counterculture (1965–1975), African American history, LGBTQ history, Japantown, Filipino heritage, Russian American history, earthquake shacks, and clubs/social halls, alongside architectural and neighborhood studies. These are especially useful for music, activism, community institutions and places whose significance is invisible from their facade. [Official index and document links](https://sfplanning.org/project/sf-histories-historic-context-statements).

**Access:** linked research documents; no uniform stop-level API established. Extract candidate addresses and page-level evidence into an editorial worksheet. Keep adoption/version dates and distinguish drafts from completed statements. Match historic address, aliases and time period to a current site; a demolished venue is a former-site stop, not an existing business. Public viewing does not establish a blanket text/photo license: write original short summaries, preserve citations and review document-specific credits. Proposed pilot: two five-stop neighborhood walks drawn from different community histories, with community/editorial review before release.

### 2. California OHP Built Environment Resource Directory — structured identity and history leads

**Access:** OHP publishes county CSV files, including the [San Francisco CSV](https://ohp.parks.ca.gov/pages/1068/files/San%20Francisco.csv). The [BERD documentation](https://ohp.parks.ca.gov/?page_id=30338) explains evaluation codes, the OTIS identifier and limitations. The download link was resolved; the browser could not parse its binary-served CSV, so this review does **not** claim an inspected schema or SF row count.

**Use:** reconcile existing building identities and find nominations/evaluations worth researching. Preserve OTIS IDs when available; address/APN, names and supporting documents should drive matching. Do not interpret every evaluated property as designated or publicly accessible. OHP explicitly says its inventory is incomplete, can reference undigitized documents and excludes confidential resources. No explicit redistribution license or reliable refresh cadence was established on the reviewed page; confirm terms before distributing a derived bulk catalog. Start as an internal enrichment source, not a new Explore category.

### 3. National Register bulk data — separate from the NPS visitor API

**Access:** [NPS downloads](https://www.nps.gov/subjects/nationalregister/data-downloads.htm) include an unrestricted spatial file geodatabase, listed/removed-property spreadsheets and documentation-form indexes. The page currently links a [listed-property XLSX snapshot through May 22, 2026](https://www.nps.gov/subjects/nationalregister/upload/national-register-listed_20260522.xlsx). This is a bulk preservation inventory; it is distinct from the keyed NPS visitor `places`/`tours` API reviewed previously. No key was obtained or download parsed here.

**Use:** add federal reference IDs to existing places, identify overlooked sites, and follow nominations for historical evidence. Match reference number first, then address/name and footprint. District polygons should group places, not produce a destination at their centroid. NPS warns coordinates/boundaries can need correction; the spreadsheet date is a snapshot cutoff, not a live designation check. Consult removed records as well. Retain publisher citation and inspect dataset terms and nomination/image credits separately; federal hosting does not automatically clear contributed photographs. Route only to a reviewed public viewing point.

### 4. Street trees plus designated landmark trees — a small nature collection

**Access:** [DataSF Street Tree Inventory `tkzw-k3nq`](https://data.sf.gov/City-Infrastructure/San-Francisco-Street-Tree-Inventory/tkzw-k3nq), with the [standard JSON endpoint](https://data.sf.gov/resource/tkzw-k3nq.json); [Public Works significant/landmark tree program](https://sfpublicworks.org/node/22071); [SF Environment landmark-tree map and list](https://www.sfenvironment.org/fil/node/3933?_disable_route_normalizer=true).

The inventory describes individual recorded street trees, excludes removed trees and notes a September 2026 correction after an asset-system migration. Reinspect identifiers and schema before writing an importer rather than assuming old clients remain valid. Metadata license and current row count were not independently retrieved in this pass.

**Use:** curate designated landmark trees and unusual, publicly visible specimens; use the larger inventory for species context. Join a landmark-list record to a tree only after address/species/location review. A “significant” tree is not synonymous with a designated landmark. Some protected trees stand on private property: route to a public sidewalk, not the trunk. Do not infer age, rarity, canopy shade or a historical anecdote from a species label. A dozen reviewed trees is a useful pilot; importing every tree as a collectible would overwhelm Explore.

### 5. USGS elevation — route effort rather than another pin layer

**Access:** the [Elevation Point Query Service API](https://epqs.nationalmap.gov/v1/docs) returns elevation for a coordinate; the [3DEP program](https://www.usgs.gov/3d-elevation-program/) provides terrain data. USGS-produced data is generally in the U.S. public domain, with exceptions for credited third-party content; retain the chosen product's metadata and source credit. [USGS reuse policy](https://www.usgs.gov/information-policies-and-instructions/copyrights-and-credits).

**Use:** sample an actual walking polyline, smooth noise and estimate ascent/descent; cache results by route geometry and dataset version. This could support “mostly flat” preferences and a visible climb estimate before Go. Terrain elevation does not resolve stairs, curb ramps, bridge decks or elevator access, so it cannot establish a wheelchair-accessible route. Pilot against manually checked SF hills before exposing numbers. No SF accuracy benchmark, endpoint throughput guarantee or production service commitment was established here; use a bounded import/cache or chosen production provider rather than issuing one request per GPS update.

### 6. SF sidewalk widths — supporting evidence with a major age caveat

**Access:** [DataSF `4g86-grxu`](https://data.sf.gov/d/4g86-grxu); the [federal catalog's publisher metadata](https://catalog.data.gov/dataset/sidewalk-widths-2014) links JSON/CSV/GeoJSON downloads. This describes street-segment sidewalks from a **2014 study**, despite later dataset metadata updates. Some segments lack information; negative widths mean varying widths and most zeros mean unknown.

**Use:** an internal route-review overlay, joined to the matching centerline segment after validating identifiers and geometry. It is insufficient for a current clear-width, accessibility or safety badge. Review explicit source terms before redistribution; the catalog listing alone is not a license. Combine with field checks and authoritative current changes before a user-facing route preference. Priority is below entrance validation, stairs and closures. Do not turn missing data into “no sidewalk,” and do not treat a 2025 catalog timestamp as a 2025 sidewalk survey.

### 7. DPLA / Calisphere — broader archival discovery with a workable aggregation path

**Access:** [DPLA developer tools](https://pro.dp.la/developers) provide a search API and bulk data; [bulk exports](https://pro.dp.la/developers/bulk-download) are documented as zipped JSON/Parquet in `s3://dpla-provider-export`. The [API guide](https://pro.dp.la/developers/api-codex) requires a key. No key or SF result count was obtained here. DPLA dedicates metadata to CC0; object/preview rights must be checked individually. [Metadata policy](https://pro.dp.la/hubs/metadata-application-profile), [item rights categories](https://dp.la/about/rights-categories).

Calisphere's [official API notice](https://help.oac.cdlib.org/support/solutions/articles/9000101639-calisphere-apis) says its old Solr API was retired in February 2024 and recommends DPLA while a new access strategy develops. Its January 2024 notice mentions a November 2023 snapshot: that is **not evidence of current DPLA freshness**. Verify provider export timestamps at integration time; do not implement against the obsolete Solr examples lower on that page.

**Use:** an editorial search tool for “Then” images, maps and neighborhood collections. Match depicted subject and historical address, not the holding library's address. Deduplicate institution IDs/ARKs across DigitalSF, Calisphere and DPLA; retain original institution links, depiction date and rights. Clear selected files before shipping them in the offline bundle.

### 8. FoundSF and Presidio guides — curated research, not assumed open feeds

[FoundSF](https://www.foundsf.org/index.php?title=FoundSF%3AAbout) supplies local narratives and contributed primary material. Its stated text license is attribution/noncommercial/share-alike; most photos are third-party one-time permissions that FoundSF cannot sublicense. Use it to identify leads and original sources, or seek a partnership; do not automatically import text into a commercial-capable app or reuse its photo library. No supported bulk API was verified.

The [Presidio's official downloadable maps](https://presidio.gov/visit/presidio-park-maps) identify trails, destinations, restrooms and shuttle connections, making them useful for a carefully checked western-city pilot. They are PDFs/interactive guides rather than a verified routable API. Record map revision dates, confirm entrances and restrictions, and inspect media/cartography permissions before copying assets. Pair editorial stops with separately verified walking geometry. A published map does not guarantee today's trail access.

## Delivery stages and acceptance criteria

These are proposed scopes, not promises of source yield.

| Stage | Deliverable | Acceptance criterion |
| --- | --- | --- |
| 1. Better existing places | Resolve photo gaps through exact Commons matches; curate POPOS and separate 1% art candidates from the earlier review | Every released stop has a public viewing/arrival point, useful original story, source evidence and reviewed image or honest illustration fallback. Source-row counts are never reported as unique new places. |
| 2. Cultural depth | Two five-stop context-statement walks; BERD/NRHP identity enrichment; investigate an official Legacy Business export | At least one walk outside the current downtown concentration. Each historical claim has a document/page citation; former sites and current venues are distinguished. No scraped generic-business list passed off as a verified Legacy registry. |
| 3. New kinds of discovery | A small landmark-tree set and a dated archival “Then” collection | Tree access checked from public space; every archival asset has subject/date/rights review and original institution link. |
| 4. Better walking decisions | Validate a hill estimate; review stairs, public entrances and closures with OSM/publisher data plus field checks | Compare estimated climb and chosen entrances against real walks. No accessibility, open-now or safety claims from incomplete/old inventories. |

## Import and editorial contract

Keep all publisher fetches outside the walking UI. Import snapshots into a review queue, validate pagination/truncation and geometry, then ship a small approved offline catalog. A new source must not replace existing place IDs used by saves, moments or tours.

Store source namespace/record ID, canonical place ID, aliases and historical address with dates, geometry kind, public entrance/arrival point and review date, publisher URL, source revision/update date separately from fetch date, license/attribution, and a record checksum. Keep **story evidence, coordinate evidence and photo rights separate**. Preserve conflicting claims for editorial review instead of silently preferring the newest fetch.

Use names, address/time period, entity type and geographic distance together for matching. Distinct artworks in one building remain distinct; a venue that moved must not inherit an old site's arrival coordinate. Use exact source identifiers/QIDs when established, with a human review queue for ambiguous candidates.

Track outcomes per import: source rows, usable candidates, duplicates, publicly visitable stops, approved stories, licensed exact-subject covers, neighborhood distribution and access reviews due. Start with monthly snapshot-diff reviews for ordinary inventories, revisiting cadence after observing publisher changes. Closure/opening information needs a separately justified freshness policy; an unchanged inventory timestamp does not prove current access.
