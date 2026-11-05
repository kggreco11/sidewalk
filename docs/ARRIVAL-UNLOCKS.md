# Arrival unlock prototype

Before arrival, place photography, name, category, address, teaser, saving and routing remain available. Full field notes and their story-source links appear after an explicit location check. No continuous background check or automatic modal is introduced.

The web and native app both require a fix no older than 15 seconds, accuracy of 35 m or better, distance within 75 m, and distance plus reported accuracy within 100 m. The radius is a prototype choice, to be field-tested around buildings and public viewing locations. Users are told to stay on a public path. A denied, unavailable, inaccurate, stale or distant fix never unlocks a story. Requests time out, allow retry, and do not save coordinates.

Unlock IDs are stored locally and survive restart. Existing manual stamps and personal photos/notes are preserved; those old stamps do not automatically unlock stories. A completed walk requires its stops to have been checked in. The native prototype still has direct routes only; continuous navigation and scenic multi-stop parity remain in the backlog.

This is an experience gate. The catalog is bundled/client-accessible and local persistence can be altered. Competitive or monetary rewards would need authenticated server verification and an anti-spoofing design. No claim of tamper-proof presence verification is made.

## Review

- Browser interaction and screenshots reviewed: Explore, place details, Walk here, planner, detour options, route overview, stop detail, live walk, locked field-notes modal, collection, existing photo/note editor, Sources.
- Browser unavailable-location request showed a retry error and kept the story locked.
- Pure policy tests: near, far, stale, future, inaccurate, invalid and uncertainty-boundary fixes (10 cases).
- Native compilation checked. Native source reviewed across opening, Explore/search/filters, detail, route/form, check-in/photo/note and collection. Simulator UI automation unavailable; physical arrival, VoiceOver, Dynamic Type interaction and native permission-sheet QA remain pending.
- Phone browser review at the actual 422 px viewport. No claim of full device-matrix coverage or a live on-site GPS test.
