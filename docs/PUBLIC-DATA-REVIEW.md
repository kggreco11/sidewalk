# Public data and place photographs: expansion review

Reviewed 2026-11-04 against primary publisher pages, API documentation, and live metadata. This is a source audit and implementation recommendation, not a claim that all sources below have been imported.

## Recommendation

Expand discovery with **POPOS and the separate 1% Public Art feed first**, enrich identity and photographs through **Wikidata + Wikimedia Commons**, then develop cultural walks using **SF Cultural Heritage, Cultural Districts and Legacy Businesses**. Add archival imagery selectively. More records alone will not fix the thin stories: a property inventory needs editorial selection and documented story evidence before becoming a stop.

The repository already uses SF Planning landmarks, SF Film Commission locations, Civic Art Collection (`r7bn-7v9c`) and Recreation & Parks properties (`gtr9-ntp6`). Those four are **existing sources**, not discoveries in this review. See [DATA-SOURCES.md](DATA-SOURCES.md). The two new city feeds below are distinct, though their physical locations may overlap existing records.

## Verified expansion candidates

### 1. Privately Owned Public Open Spaces — import next

[DataSF dataset](https://data.sf.gov/d/65ik-7wqd), [JSON API](https://data.sf.gov/resource/65ik-7wqd.json), [metadata](https://data.sf.gov/api/views/65ik-7wqd.json), [official map](https://sfplanninggis.org/POPOS/).

A live `count(*)` query returned **81 records**. Metadata reports PDDL and a row-update timestamp of **2026-11-04 12:02:30 UTC**. Verified schema includes `name`, `popos_address`, `description`, `hours`, `hours_type`, `accessibility`, `location`, `indoor`, `amenities`, `latitude`, `longitude`, and `point`. Excellent material for courtyards, rooftop gardens and small detours. The official map exposes opening-hours and amenities filters. Points are not verified accessible entrances. A refreshed dataset timestamp does not establish that individual hours were recently checked. Preserve the original hours string and show “Hours from source,” not a live-open badge. No photo field was present in the inspected schema. Database permission does not license separately linked photographs.

### 2. Public Art from the 1% Art Program — import next

[DataSF dataset](https://data.sf.gov/d/cf6e-9e4j), [JSON API](https://data.sf.gov/resource/cf6e-9e4j.json), [metadata](https://data.sf.gov/api/views/cf6e-9e4j.json).

Live count: **65 records**. Metadata reports PDDL and row-update **2024-01-13 12:03:23 UTC**. Fields include `name`, `title`, `type`, `medium`, `location`, `accessibil`, `descriptio`, `artistlink`, and `the_geom`. This expands beyond the existing city-owned Civic Art Collection. Description and access fields offer useful story seeds, but the older timestamp requires access/location review. Deduplicate using title, artist if available, and distance; do not merge every artwork at one address. No blanket artwork reproduction or linked-image permission follows from the dataset license.

### 3. SF Survey / SF Cultural Heritage — richer stories and broader neighborhoods

[SF Planning program](https://sfplanning.org/project/sf-survey-citywide-cultural-resources-survey), [public cultural inventory](https://sfculturalheritage.org/), [Historic Survey Ratings layer](https://sfplanninggis.org/arcgiswa/rest/services/PlanningData/MapServer/30).

The program documents architectural, community and cultural significance, and links to its evolving public inventory. The separately inspected Planning GIS layer supports structured ArcGIS queries; fields include `APN`, `EvalDate`, `SurveyName`, `Rating`, `FilePath`, and `Website`. Live count was **50,462 evaluation records**, not 50,462 unique attractions. The layer is not proven identical to the new Cultural Heritage inventory. Use document links to enrich existing places, and curate additional sites with substantive narratives. Survey ratings alone are not stories or public-access guarantees. The service’s copyright field was empty and no editing timestamp was returned: record-level evaluation dates and reuse terms need review. No supported bulk API or blanket media license for the new Cultural Heritage frontend was established in this audit.

### 4. Cultural Districts — thematic context, not destination centroids

[Official ArcGIS layer 109](https://sfplanninggis.org/arcgiswa/rest/services/PlanningData/MapServer/109), [community resource guide](https://sfplanning.org/fil/node/3371).

Live count: **10 polygon records**. Layer supports JSON/GeoJSON and WGS84 geometry; fields include `district_name`, `designationdate`, and `link`. Use polygon membership for themed discovery and links to district organizations for interpretation. Do not route to a polygon center or imply it is an attraction. The metadata copyright field was blank and there was no editing timestamp. Treat boundaries as public-access data with unresolved explicit reuse terms until confirmed; keep the citation and retrieval date. District designation dates are not record modification dates. The district organizations are valuable prospective editorial partners, not an automatically licensed story/photo feed.

### 5. Legacy Business Registry — local culture with practical destinations

[Current official program](https://www.sf.gov/legacy-business-program), [SF Heritage’s first-party program overview](https://www.sfheritage.org/saving-whats-special/legacy-businesses/).

This is highly aligned with the local-tourist idea: shops, institutions and other longstanding businesses connected to community history. `legacybusiness.org` currently redirects to the city program. The city page returned a JavaScript verification barrier in this audit, so a current bulk feed, schema, count, coordinates and explicit license were **not verified**. Do not substitute old annual-report maps as a current registry. Next step is an official downloadable registry or publisher-confirmed export; use narrative applications as individually cited evidence and verify operating address/status. Business and photographer images require their own rights records.

### 6. Wikidata — identity matching and structured enrichment

[Licensing](https://www.wikidata.org/wiki/Wikidata:Licensing), [coordinate property P625](https://www.wikidata.org/wiki/Property:P625), [image property P18](https://www.wikidata.org/wiki/Property:P18), [SPARQL query examples](https://www.wikidata.org/wiki/Wikidata:SPARQL_query_service/queries).

Structured data is CC0. Query coordinate-bearing SF entities, then match existing places by name/aliases, geographic proximity and type before saving a QID. P625 provides WGS84 coordinates; P18 can identify a relevant Commons illustration, which is not necessarily a current exterior photograph. Useful for deduplication, dates, architects and linking identities across feeds. References and claim ranks need inspection; community data is not automatically fact-checked. No SF coverage count was measured. Store retrieval/revision metadata and refresh in a server-side import process. CC0 applies to the structured data, **not the linked image**.

### 7. Wikimedia Commons — first choice for per-place cover photography

[Imageinfo API](https://www.mediawiki.org/wiki/API:Imageinfo), [geosearch API](https://www.mediawiki.org/wiki/API:Geosearch), [reuse requirements](https://commons.wikimedia.org/wiki/Commons:Reusing_content_outside_Wikimedia).

Use a verified file from the place’s Wikidata P18 or a manually confirmed Commons match. Imageinfo provides image URLs, dimensions and `extmetadata`; request metadata in small batches. Commons files have individual licenses and attribution requirements. Preserve creator, file page, license name and URL, source, and modifications/crop note. Sanitize metadata HTML before display. Geosearch helps discover candidates but a nearby camera coordinate does not prove the depicted subject: reject automatic nearest-photo assignment. Verify the actual image, date, subject and rights. Some files are diagrams, historical views or interiors rather than suitable covers. Coverage and currentness vary, so measure them instead of promising universal images.

### 8. OpenStreetMap — useful paths and small discoveries

[Data license](https://www.openstreetmap.org/copyright), [Overpass documentation](https://wiki.openstreetmap.org/wiki/Overpass_API).

Overpass is a read-only query interface suitable for location/tag-filtered extracts. Consider viewpoints, memorials, artworks, stairs, entrances and walking amenities; tags and completeness vary. OSM provides geometry and sometimes identity links rather than reliable narrative history or photos. Data is ODbL, with attribution and database-sharing obligations; keep source provenance and assess the combined database design before distribution. Open data does not imply unlimited free production tile/API hosting. Use periodic bounded imports, not a public Overpass dependency on every swipe. No SF candidate count or accessibility completeness was measured. Geometry timestamps indicate edits, not verified access conditions.

### 9. SFPL DigitalSF — strong archival “then and now” content

[Portal](https://digitalsf.org/), [official download FAQ](https://sfpl.libanswers.com/faq/431616), [permissions](https://sfpl.org/locations/main-library/historical-photographs/order-image-files/permissions).

DigitalSF provides historical photographs, documents and other archival records; the FAQ documents downloadable image files. This audit did not establish a supported bulk API or uniform coordinates. Match items using documented addresses/captions and manual review. The permissions page distinguishes public-domain works, library-owned copyright and third-party rights. **Publicly viewable is not blanket commercial reuse permission.** Use individually cleared/public-domain items with the supplied credit and record link. Historical views should be dated and labeled; do not present them as the current exterior. Prioritize a small curated then-and-now set over wholesale ingestion. Record date and digitization/update date are different concepts.

### 10. National Park Service — ready-made place narratives and tours

[API documentation](https://home.nps.gov/subjects/developer/api-documentation.htm), [content ownership policy](https://www.nps.gov/aboutus/disclaimer.htm).

The documented API includes `places`, `tours`, `articles`, `thingstodo`, `alerts`, `parks` and image/gallery resources. API calls require a key; none was created for this review. Start with SF-area park units and inspect individual response fields for coordinates, descriptions, image credit and access details. No live SF count was measured. NPS-created federal work is generally public domain unless indicated otherwise, but third-party material and marks are not automatically reusable. Excellent for coastal/history walks and alerts; separately timestamp alert retrieval. Park-level coordinates are not stop entrances, and tours should not be assumed walkable or free without checking their records.

### 11. Library of Congress / historic buildings documentation — architectural depth

[JSON/YAML API](https://www.loc.gov/apis/json-and-yaml/), [endpoint documentation](https://www.loc.gov/apis/json-and-yaml/requests/endpoints/), [image-use guidance](https://ask.loc.gov/faq/305466).

Search and item endpoints provide machine-readable bibliographic data and links to digitized material. Search SF buildings in the historic American building/engineering collections, then inspect item detail for photographs, drawings, historical notes and rights. Addresses often require reconciliation; this audit did not measure SF results or verify a uniform coordinate field. Useful for substantiating a building’s story and occasional archival covers. The Library states that users must determine item restrictions: collection access is not a blanket image license. Retain stable item identifiers, item rights links and dated image captions.

### 12. OpenSFHistory / Western Neighborhoods Project — exceptional reference, permission-sensitive media

[Publisher reproduction policy](https://opensfhistory.org/reproduction.php).

A promising source for neighborhood imagery and historical captions, especially outside the most tourist-heavy areas. The publisher permits its downloadable watermarked images for personal/educational use and explains that it does not own all represented copyrights. That is **not a general license for an app’s cover library**. Use source links and manually researched facts; seek suitable rights for selected images. No supported API, bulk export, current record count or blanket app-use license was verified. The image number is useful provenance; historic coordinates/captions still need matching to today’s location.

## Per-place cover implementation

A place-specific photograph is the goal. A generic city cover, generated landmark image or unrelated nearby photograph does not meet it.

1. Maintain a separate media manifest keyed by canonical place ID. Preserve IDs already used for saves/check-ins.
2. Start with existing well-known landmarks, parks and public art. Resolve exact Wikidata identities, inspect P18, then verify Commons file identity and image quality. Use geosearch/name search only to propose review candidates.
3. Record `filePage`, `imageURL`, `creator`, `license`, `licenseURL`, `credit`, `retrievedAt`, `depictedDate` when available, `matchMethod`, `reviewedAt` and crop/focal-point information. Also retain the source file name and QID where used. Keep attribution available from the image itself in iOS.
4. Require a usable licensed photo plus a verified subject match before publishing. Reject portraits of an architect, a film poster, a city panorama, vanished buildings presented as current, and images of adjacent places.
5. Download/cache only in accordance with the chosen provider’s rules and file license; ship appropriately sized derivatives and preserve attribution. Allow image failures to fall back gracefully to category artwork, with no claim that it is a photograph of the place.
6. Report **verified photos / visible places**, unmatched names, unsuitable files and unknown rights separately. No universal coverage claim until every visible record is checked. A missing photo is preferable to an incorrect one.
7. Later add dated SFPL/LOC/NPS archival images as a distinct “Then” view, and user-contributed photos with a clear upload permission model.

## Concrete delivery order

- **First:** verify and import the 81 POPOS and 65 separate public-art source rows, filter unusable coordinates/access, deduplicate and promote only useful stories. These are source-row counts, not promised new unique places. Build the per-place licensed-photo manifest in parallel.
- **Second:** enrich existing records from survey documents; create district-specific editorial sets and verify an official Legacy Business export. Avoid expanding only downtown: explicitly audit Richmond, Sunset, Bayview, Excelsior and other underrepresented neighborhoods.
- **Third:** NPS stories/alerts, bounded OSM discovery and entrance data, and individually cleared archival images.

Each import should capture source ID/URL, source update date when supplied, retrieval time, license, geometry kind and entrance certainty. Separate location evidence from story evidence and media rights. Review removals and changed access, reject truncated responses, keep import snapshots, and merge aliases without losing collections. This plan improves both breadth and trustworthiness without filling Explore with raw inventory rows.
