# Payment card stack experiment

Opt-in under Settings → Experimental → **Stack payment cards**. Off by default;
the preference persists across launches. The existing pass deck is independent.

Only payment cards are grouped. The group occupies the first payment card's
position in the document wallet; passports and IDs retain their own pages and
relative order. Filtering runs before grouping, and Manage remains a flat list
with the original saved order. No records or saved order are rewritten.

The overview uses a vertical, overlapping stack of the existing card faces,
with bank marks visible along the exposed top edges. Tapping a card lifts it
above the remaining stack; tapping that selected face opens CardDetailScreen.
The stack has no heading, instructional copy, count or All cards text. Pulling
the selected card down, the small return handle, or Back returns it to the stack.
Swiping the selected face horizontally selects the previous/next card. Card
numbers stay masked throughout the stack interaction.

Selection springs start from the current rendered position, and can be retargeted
mid-flight. A selected card stays pinned while the remaining deck scrolls below
it. Selecting a card from a scrolled deck starts at that visible position, without
resetting the scroll to the top. Motion includes touch-down feedback and direct
drag tracking, followed by a velocity-aware release. Reduced motion changes
positions immediately. Long stacks scroll inside their wallet page; the outer
page remains reachable from its margins. Keep readable exposed bank headers at
5, 10 and 15 cards instead of compressing every card into thin, unrecognizable
slivers. Verify every card can be selected at each of those counts.
Each card exposes an accessible select/open action and a distinct ending-in
label. Long press preserves the existing remove-card action.

Manage's reveal handoff must resolve an individual card to the group page and
bring that exact card forward. Removing or editing a selected card must resolve
against live provider data; returning from details retains the selection.

Verify preference persistence, mixed-document grouping, selection then detail
navigation, return/back, Manage reveal, removal, reduced motion, and long stacks.
Inspect light/dark renders at phone size before building and installing over the
existing app, preserving all saved documents.

## Verification

The stack tests and surrounding Manage, Settings scroll, card-face and copy-detail
tests passed (53 tests). A final handle-animation refinement was also checked
against all 23 stack tests. Scoped analysis of the changed widget and its tests
is clean.

Synthetic collections of 5, 10 and 15 cards verify that every individual card can
be reached, selected and opened. At each count, the selected face stays pinned
while the deck scrolls, and selecting the last card preserves its visible
starting position. Tests also cover rapid retargeting, direct drag tracking,
holding a lift mid-flight, swipe boundaries, cancellation, pull-down return,
reduced motion, narrow screens with large text, Manage reveal, and detail return.

Light/dark overview and selected renders were inspected. Each stress collection
also has top, bottom and selected renders; the 15-card case includes 80ms and
180ms lift frames. These are Flutter widget tests and renders, not physical-device
performance measurements with 15 cards. The small return handle follows its
face and fades in as the lift settles, without covering the face in flight.

The arm64 debug APK was installed over the existing app on the Motorola Edge 30
(Android 14) successfully. The preference and existing saved cards were retained.
The revised overview and selected layout were inspected on the phone. Left and
right swipes selected adjacent cards, and pulling down returned the selected
face to the overview. The phone was left on that overview. Detail navigation,
return selection, and preference persistence were also verified in tests; no
cards or documents were added, removed, or edited for QA.
