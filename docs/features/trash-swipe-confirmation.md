# Swipe to empty Trash

Status: implemented and loaded on the Motorola Edge 30, 29 October 2026.

The populated Trash screen uses a dedicated bottom control. The document list
scrolls independently above it; the empty state and per-document actions remain
separate. No new storage or attachment deletion path is introduced.

## Appearance and interaction

- Graphite track, satin silver handle, fine highlight rim, contact shadows and
  monochrome progress. Geist typography follows Docket's existing roles.
- The track is 68 points high, with an 8-point inset around the 52-point handle.
  Footer side padding is 24 points; bottom clearance is 20 points inside the
  dashboard's existing safe area.
- Drag begins on the handle and preserves the grab offset. Short swipes and
  pointer cancellation spring home. Velocity alone never completes the gesture.
- Reaching 92% and releasing settles the handle, then crossfades into confirmation
  inside the same control. Normal text stays at the same height; narrow layouts
  and enlarged text use stacked content.
- Confirmation uses one two-line question: Delete N docs permanently? (1 doc for
  the singular), with Cancel and Delete. There is no separate subtitle or popup.
- The idle Slide to empty label has a soft white light sweep and diffused halo.
  It pauses while dragging or confirming; reduced motion uses a static label.
- Cancel, Back or Escape restores the slider. Only a separate Delete activation
  calls the existing deletion provider. Progress remains in the footer while the
  operation runs; errors are surfaced through the existing scaffold.
- The control has explicit sliding, settling, confirming and deleting states.
  Repeat activation is latched, outgoing transition children cannot receive
  pointer / focus / accessibility input, and row actions are blocked while
  deleting.
- Any change to the reviewed document identities resets confirmation. The view
  rechecks the identity set when Delete is activated before calling the provider.
- Keyboard / screen-reader activation reveals the same inline confirmation.
  Cancel receives keyboard focus first. RTL mirrors the gesture; reduced motion
  removes decorative settling and transition motion. Existing haptic preferences
  are respected.

## Verification

Focused dart analysis of the swipe control, shared shining label and Trash view:
No issues found. git diff --check passed. The latest typography and glow changes
were hot reloaded successfully (2,783 ms); no APK rebuild.

Checked the populated Trash screen on the phone: the control is anchored at the
bottom, and confirmation stays inside that footer. Cancel restored the slider.
A second swipe followed by the phone's Back action also restored it. The existing
one-document Trash contents remained present. The updated confirmation was then
checked with four existing Trash documents: Delete 4 docs / permanently?, with
Cancel and Delete actions. Two idle captures confirmed the light sweep changes
the label; the soft halo was visually checked. Cancel restored the slider. The
Delete action was not exercised; no documents were deleted. No automated test
suite was run.

Cropped local reference frames are under ignored build/id-tools-review.
