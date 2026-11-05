# Explore data sources

Explore adds **24 curated places** to the existing SF Planning landmarks and SF Film Commission catalog: **16 public artworks and 8 parks**. These are real source records, not demo coordinates. The initial import is curated; Explore now exposes all matching curated records without a five-place cap.

## New structured feeds

| Source | Dataset | Imported fields | Coverage |
| --- | --- | --- | --- |
| San Francisco Arts Commission, Civic Art Collection | [r7bn-7v9c](https://data.sf.gov/d/r7bn-7v9c) | Accession number, title, artist, date, materials, site description, neighborhood, latitude/longitude | 16 curated publicly-sited outdoor works |
| San Francisco Recreation & Parks, Properties | [gtr9-ntp6](https://data.sf.gov/d/gtr9-ntp6) | Stable property ID, name, acreage, address, neighborhood, latitude/longitude | 8 small parks/gardens |

Both DataSF dataset metadata records identify the **Open Data Commons Public Domain Dedication and License 1.0**. See [PDDL](https://opendatacommons.org/licenses/pddl/1-0/). This covers the datasets; it does not grant rights to photographs or reproductions of artworks. The separate licensed-photo manifest is documented in [PLACE-PHOTOS.md](PLACE-PHOTOS.md). These photos come from individually licensed Commons files, not the city dataset license.

## Stories and provenance

Short teasers and stories are editorially written in `scripts/import-explore.mjs`. Factual claims come from dataset records or linked official SF Recreation & Parks / SF Arts Commission pages. Each place retains a visible `source` and `sourceName`. The art feed is sparse, so prompts to notice materials or change viewing angle are clearly invitations, not invented historical anecdotes.

Park stories use these additional primary sources:

- [Ina Coolbrith Park](https://sfrecpark.org/Facilities/Facility/Details/Ina-Coolbrith-Park-175): hillside and views.
- [Francisco Park](https://www.sfrecpark.org/facilities/facility/details/Francisco-Park-442): former reservoir, 2022 opening, terraces and rainwater system.
- [Fay Park](https://sfrecpark.org/891/Fay-Park): three terraces, stairs/ramps, two gazebos and planting.
- [Lafayette Park](https://www.sfrecpark.org/512/Lafayette-Park): public/private land history.
- [Alta Plaza concept-design approval](https://www.sfrecpark.org/DocumentCenter/View/1873/Concept-Design-Approval-PDF): former quarry, boundaries and views.
- [South Park](https://www.sfrecpark.org/576/South-Park): strolling-park design and 2017 renovation.
- [Allyne Park](https://sfrecpark.org/795/Allyne-Park-Picnic-Area): lawn and address; acreage from the structured feed.
- [Cottage Row commission agenda](https://www.sfrecpark.org/AgendaCenter/ViewFile/Agenda/_10262019-8?html=true): Issei Garden and 2019 plaque proposal. We do not assert that the proposal was completed.

Language of the Birds also uses its [SFAC collection record](https://kiosk.sfartscommission.org/objects-1/info/3435), which describes the suspended books and their bird-like forms.

## Repeatable refresh

From the repository root:

```sh
node scripts/import-explore.mjs
```

For replay from previously captured raw responses, provide a directory containing `art.json` and `parks.json`:

```sh
node scripts/import-explore.mjs /path/to/raw-data
```

The importer joins curated records by accession/property ID, validates San Francisco bounds and unique IDs, and fails on missing records or art no longer marked Public Display. It rejects a response reaching the request limit rather than silently accepting truncation. It writes `data/explore-places.json` and `data/explore-sources.json`; existing landmark/film files are not overwritten. Stories deliberately stay curated across refreshes. Review changed source records before publishing.

The manifest records the fetch date separately from the source's `data_as_of` date. In particular, the Civic Art feed still reports **2024-04-17** as its source snapshot. A successful refresh does not establish that every artwork remains accessible today.

## Location and availability limits

Artwork locations may be approximate intersections; grouped artworks may share a point. Park coordinates are property points, not verified accessible entrances. Routing may snap to nearby streets. Hours, construction closures, stair accessibility, temporary removals and on-site condition are not live-verified. No claim of current opening status is made. Large parks with deep interior centroid targets and known changed/removal candidates such as the Embarcadero Fountain were excluded from this initial selection.

Explore must deduplicate these additions against existing landmark/film locations when presenting a view; stable prefixed IDs prevent collisions but do not alone imply distinct physical sites. Saved places should retain those IDs across importer runs.

## Further expansion review

See [PUBLIC-DATA-REVIEW.md](PUBLIC-DATA-REVIEW.md) for twelve additional sources, verified dataset counts, licensing constraints and recommended import order. Those sources are audited candidates, not all imported feeds.
