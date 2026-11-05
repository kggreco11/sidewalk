# Place cover photographs

The initial set contains 39 place-specific covers out of 133 Explore places. The other 94 retain a category illustration; they are tracked individually in `data/place-image-gaps.json`. This is not complete photographic coverage.

## Matching and rights

Candidate identities were drawn from Wikidata P625 coordinates and P18 images within San Francisco. Names plus geographic distance proposed matches; explicit aliases were reviewed for the same site. Unrelated nearest-place matches were rejected. `data/place-image-matches.json` retains canonical place ID, Commons file, Wikidata identity and matching distance/method.

Every published image has Commons imageinfo author and supported license metadata. Original metadata, file page, license link when supplied, image description, depiction date when supplied, and retrieval date are retained in `data/place-images.json`. The metadata review excluded the V. C. Morris archival interior; it is not an exterior cover. Remaining photographs vary in date and do not prove current appearance or access. UI crops are labeled “Cropped to fit.” Wikimedia licenses apply individually, not as a blanket media license.

The web and iOS app use cached thumbnail assets with source/credit links in details; the web card also links directly to the photo credit. The native bundle includes these assets for offline discovery. Failed images fall back to category artwork. No generated image is used as a place photograph.

## Refresh

1. Review/add exact identities in `data/place-image-matches.json`.
2. `node scripts/import-place-images.mjs` retrieves file-level metadata and rejects missing authors, unsupported licenses or missing thumbnails.
3. Review filenames/descriptions and image suitability before approving new matches.
4. `node scripts/cache-place-images.mjs` downloads appropriately sized thumbnails into web and iOS assets.
5. `node scripts/sync-ios-catalog.mjs` merges the catalog and media manifest and reports remaining gaps.
6. `xcodegen generate --spec ios/project.yml` includes new native resources.

Do not reassign nearby photos merely to achieve 100% coverage. Next candidates should come from exact Commons file searches, individually cleared SFPL/LOC items, official publisher permission or user-provided photographs. Retain a dated historical image as such, not as a current exterior.

Sources: [Wikidata data access](https://www.wikidata.org/wiki/Help:Data_access), [MediaWiki imageinfo](https://www.mediawiki.org/wiki/API:Imageinfo), [Commons reuse](https://commons.wikimedia.org/wiki/Commons:Reusing_content_outside_Wikimedia).
