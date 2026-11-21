# Archive scrubber refinement

## Direction

Use the installed Good Air Android app as the reference, inspected on the
connected Motorola on 20 Nov 2026. Its scrubber uses fine rounded ticks, faded
edges, a longer coral marker that travels along the scale, and a compact date /
time badge above the selection.

Apply this only to the shared movie, train and bus archive browser. Preserve
the cards, category screens, navigation, sorting, removal flow and card-swipe
physics. Existing unrelated working-tree edits must remain intact.

## Implementation

- Replace the moving dial with a finite ruler spanning the archive. The first
  pass is at the left and the last at the right; card swipes update its marker.
- Taps and drags select the corresponding position directly, with nearest-pass
  settling on release. A sweep reaches the end even in a large archive.
- Keep fine, rounded ticks and edge fading, with the archive's existing coral
  marker. Put the selected month/year in a compact badge above it, clamped
  inside the viewport. A quiet ordinal below gives context for repeated dates.
- Retain adjustable screen-reader semantics, pass haptics and reduced-motion
  handling. A one-pass folder has a centered marker and no artificial travel.
- Use existing AppFonts and theme surface/label tokens for the new readout.

## Verification

Run the archive gesture/layout suites and static analysis. Inspect the result
on the connected phone in movie, train and single-pass bus folders; verify
tapping, dragging, card-to-marker synchronization and the final pass.

Verified so far: all 28 tests in `archive_pass_deck_test.dart`,
`archive_layout_test.dart`, and `pass_history_folders_test.dart` pass. Final
scoped analysis of the deck and its tests reports no issues. Tap coverage also caught an existing interruption
race: completing an old snap could reset a newer selection; interrupted snaps
now cancel their completion future.

On-device verification: loaded current source into the running debug app via
`flutter attach` / hot reload. Movies: tapping the center selects 5/9, dragging
to the right reaches 9/9, and the date badge remains inside both edges. Trains:
a card swipe advances 1/3 to 2/3 and moves the marker to the center. Buses: the
single-pass folder keeps its centered marker and 1/1 count after scrubbing.
Light-mode screenshots were inspected; both themes and 2x text on a 320x568
viewport are covered by the widget tests. Standalone APK packaging was canceled
after contention with an existing Flutter build; hardware verification used
the running debug session, not a separately installed final APK.
