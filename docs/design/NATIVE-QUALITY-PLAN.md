# Sidewalk native quality pass

## Intent and visual direction

The person is outdoors, often using one thumb, deciding where to walk or looking up from a place they have just reached. The primary task is discover → choose → walk → remember. The interface should feel like a pocket field guide with the predictability of a native map.

Domain: footpaths, marginal notes, local stories, discoveries, collected stamps, street corners.
Color world: ivory paper, navy printing ink, terracotta facades, fog gray, park sage.
Signature: a terracotta four-point discovery star connects the opening, collected stories, and guide; the map remains the continuous spatial context.
Avoid: a scrolling webpage of map plus cards (use a bounded discovery panel); generic JSON-like metadata (show one useful teaser); decorative badges everywhere (reserve the star for discovery and collection).

## Component decisions before implementation

| Component | Intent / focal point | Palette and depth | Type and spacing |
|---|---|---|---|
| Explore shell | Browse without losing the map; the nearby places panel leads | Paper panel above muted map; subtle shadow; ink controls, clay star | Serif brand and place names; system controls; 4pt rhythm, 16pt content insets, 44pt minimum targets |
| Drawer | Move between map and places with one thumb | One continuous paper surface, 24pt top radius | Persistent 44pt accessible grip/title area; detents constrained to available height |
| Place row | Recognize a place and decide to open or save | Actual cover where available; quiet category fallback | Headline name, subheadline teaser, clear independent bookmark target |
| Directions | Choose endpoints and see one resulting route | Inset fields above same map; paper summary below | 17pt editable fields; suggestions directly underneath; readable error and single primary action |
| Place detail | Teaser before arrival; story after verified arrival | Photo/illustration, paper reading surface; clay discovery marker | Serif title and story, source links secondary, bottom action stays reachable |
| Field guide | Find saved places and collected notes | Same rows and paper surface; star for verified visits | Native segmented categories; explicit empty states; no modal nesting beyond edit/detail |

## Audit findings to address

- Critical: asynchronous search/route work can outlive a changed field; split routing state from rendering and cancel superseded work.
- Critical: manually entered addresses require deterministic submission and actionable ambiguity errors.
- High: map accessibility flattens hundreds of annotations ahead of controls; group the map and panels.
- High: drawer sizing, keyboard and Dynamic Type compete; constrain each surface, expose accessible expand/collapse.
- High: collection stores photos in UserDefaults; migrate atomically to Application Support, preserve the legacy copy, do not silently overwrite unreadable data.
- High: save-note dismissal can hide persistence failure; only dismiss after successful save.
- High: route screen describes static directions as a walk; be explicit about current capability and provide Apple Maps handoff for navigation.
- Medium: all map annotations show labels at once; suppress labels until selection and keep legal attribution clear of panels.
- Medium: repeated large brand/title controls reduce usable map area; compact navigation, clear hierarchy.
- Medium: source text and covers are uneven; distinguish image absence from a broken image and document coverage.

## Release evidence required

Builds alone are insufficient. Verify typed address, selected search result, back/edit, panel gestures, detail/save, field-guide empty and populated states. Exercise larger Dynamic Type, offline/ambiguous search, cancellation, storage migration and failed writes. Record what was actually checked. Physical walking, battery behavior, GPS accuracy, TestFlight signing/distribution and privacy disclosure remain release gates until tested; do not describe a development install as production-ready.
