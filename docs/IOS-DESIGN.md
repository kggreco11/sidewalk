# iOS design pass

Sidewalk is used outdoors, on foot, often one-handed. The interface should feel like a readable field notebook: maps, landmarks, walking paths, stamps and margin notes. Its palette comes from ivory paper, navy ink, sage planting, terracotta facades and fog. The signature is sourced place photography and collected field notes paired with illustrated San Francisco arrivals.

## Decisions

- Native semantic Dynamic Type fonts: body for controls and descriptions, subheadline for category metadata, serif title/largeTitle for place headings and brand.
- Minimum44pt interactive targets; primary actions52–56pt. Native bookmark hit area44×44pt. Web prototype mirrors this with44px targets and17px main text on phone widths.
- Keep one persistent map behind a bounded discovery panel. Three detents expose the map, browsing, or a larger list. Content scrolls inside the panel; place rows grow with Dynamic Type and omit thumbnail imagery at accessibility sizes.
- Keep maps prominent but make the supporting discovery controls readable. Horizontal filters scroll without shrinking their labels.
- Three original illustrations cycle between cold app launches / full page loads. No fake progress bar and no account system added. The opening is shown after the hosting sign-in gate in the web version.
- Opening lasts2.6seconds, can be skipped immediately, then fades for240ms. Reduced Motion removes the fade. Background web content is inert during the opening; focus moves to the home container on dismissal.
- Returning from details, filters, or a walk does not replay the opening.

## Guidance used

- [Apple buttons](https://developer.apple.com/design/human-interface-guidelines/buttons)
- [Apple layout and Dynamic Type](https://developer.apple.com/design/human-interface-guidelines/layout)
- Installed interface-design and accessibility-review skills.

## Verification

Native simulator builds and model/storage regression tests pass. Interactive checks cover Explore collapse/expand, typed routing, saved-place handoff, detail/check-in denial, and four larger preferred-text increments. Full VoiceOver, maximum Dynamic Type, physical GPS and outdoor walking remain unverified. See IOS-SIMULATOR-AUDIT.md for current evidence. This is not a full accessibility certification.
