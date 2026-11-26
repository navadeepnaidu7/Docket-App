# Payment cards

Credit and debit cards in Documents, beside Passport and ID Cards. This is the maintained
contract; it absorbs the earlier artwork-refinement, living-material and stack-experiment
notes. Revision history is at the bottom.

Status: implemented and smoke-tested on a Motorola Edge 30 (Android 14), installed over the
existing app. Owners: `lib/features/cards/` (`domain/card_number.dart`, `card_issuer.dart`,
`card_surface.dart`; `application/card_list_provider.dart`, `screen_secure.dart`,
`payment_card_stack_provider.dart`; `presentation/wallet_payment_card.dart`,
`living_card_material.dart`, `card_material.dart`, `bank_artwork.dart`, `network_mark.dart`,
`card_detail_screen.dart`, `card_copy_details.dart`, `card_scan_screen.dart`,
`card_review_screen.dart`, `payment_card_stack_view.dart`),
`lib/core/storage/card_scan_store.dart`.

## Storage and security (load-bearing)

- A `PaymentCard` record in its own secure-storage key, `saved_payment_cards`, in the same
  encrypted store as passports and IDs. It is **not** an `IdDocument` (an unknown ID type loads
  back as PAN). Never sent to the passes API. Number, CVV and OCR text are never logged.
- Record: network, kind (debit / credit / unset), confirmed bank name, issuer id, surface
  index, holder, number, expiry, CVV when present, attachment metadata. The stored surface
  index means deleting one card never recolours another, and a later bank-table update never
  renames or recolours a saved card.
- Scan photos are AES-GCM files under `card_scans/<cardId>/`, keyed by `card_scan_key_v1`,
  separate from ID attachments; only metadata rides in the record. A key that cannot be read,
  cannot be decoded, is the wrong length (32 bytes), or is missing while files exist **blocks
  further writes** instead of minting a new key.
- Trashed cards still own their files. The orphan sweep waits until the card list and trash
  are loaded and skips entirely when either list key or the scan key is unreadable.
- While a value is revealed (and during review), the window holds Android `FLAG_SECURE`
  (`screen_secure.dart`). Reveal state is never stored.

## Number, network and bank

- The network comes from the IIN prefix only, detected while typing. Supported: Visa,
  Mastercard, RuPay, American Express, Discover, UnionPay, JCB, Diners Club. Lengths, grouping
  and security-code sizes follow
  [Braintree credit-card-type](https://github.com/braintree/credit-card-type/blob/main/src/lib/card-types.ts).
  Specific RuPay slices are checked before Discover's broad `65`. Amex uses 4-6-5 grouping and
  a four-digit CID (OCR prefers it over a three-digit back code).
- Luhn is a separate check that catches mistyped digits; it says nothing about the network.
  Save is refused while Luhn fails. Expired dates are allowed and labelled; a missing CVV is
  allowed. Duplicate numbers are refused.
- There is no manual network choice. An unknown prefix is stored with no mark rather than a
  guessed logo. Existing serialized network names and legacy manual metadata stay readable.
- Debit vs credit is chosen by the person; it is not trusted from the number.
- Bank name: a bundled prefix table proposes it (no BIN website is ever called), plus
  explicit name aliases; the person confirms or edits it on review, and the face prints what
  they confirmed. Unsupported confirmed names show text only and suppress any stale issuer
  hint rather than another bank's mark.
- 23 bundled bank symbols from auraveni/global-bank-logos at commit
  `ad33060ca976397a9fcb46dd40c2d77bce5ce7e1` (MIT). Federal Bank and Wells Fargo have CSS
  fills inlined for Flutter; the rest are unchanged. Hashes:
  `tool/design_src/bank_logos/sources.json`; rebuild with `tool/bundle_bank_logos.py`. Logos
  sit on a white field so their colours survive dark faces.

## Add flow

Documents `+` -> Cards. The camera opens directly; front capture, then back (the screen says
why: some cards print the number on the back). On-device ML Kit proposes number, name, expiry
and CVV; **nothing saves from the shutter alone**. "Type it instead" is on the first step,
because metal faces and holograms defeat OCR. The entry form has a live masked preview,
grouped fields, local bank search with logos (keyboard dismissed before the picker closes),
and a debit / credit / not-set control. New cards join the documents carousel through wallet
order, and adds and deletes reconcile it.

## Face

ID-1 canvas shared with Aadhaar/PAN: aspect 1.586, design size 440 x 277, radius 24, scaled by
`WalletCardCanvas`. Geist type, number in Roboto Mono.

- No visible field labels on the face (no "Ending in", no Cardholder/Expires captions);
  accessible descriptions remain. Bank symbol and name centred on one line; network mark upper
  right with Credit/Debit beneath it; a single four-dot mask before the last four; holder and
  expiry share the bottom baseline. No chip. The security code is never on the face.
- Colour keeps a stack readable: each of the 23 banks has dark/light families and an accent
  (`card_surface.dart`, accents in `bank_artwork.dart`); a second card from the same bank takes
  the next shade. Unknown banks take the next free neutral. These are original Docket
  representations, not reproductions of real card products. Bank card art is never fetched.
- **Material** (`LivingCardMaterial` + `CardMaterial`): "atmospheric satin". Diffuse elliptical
  light in the saved bank palette, header/footer shading for text contrast, satin grain and a
  fine edge. The earlier line/relief motifs are no longer painted. Only the active face
  animates: slow 16-24 s ambient light, a broad touch reflection and slight spring tilt
  (mass 1, stiffness 180, damping 27, retargeted from current velocity), touch-down light.
  Information and marks sit in a retained repaint boundary and never move independently.
  Ticks stop on route coverage, hidden tabs, lifecycle changes and scroll-out; resting deck
  cards use a stable frame. Touch is observed through `Listener` so tap-to-open, reveal,
  long-press and stack swipes keep ownership. Reduced motion keeps brief colour feedback only.
  No shader, package or art asset was added.

## Detail screen

Issuer, network (logo only, no duplicated name) and type, then a separate copyable
information group: number, security code, holder, expiry. Number and code stay masked until
revealed; each reveals independently for five seconds and hides on background. Copy copies
the actual value **without revealing it** and confirms with a check, never echoing the value.
Scanned photos follow. Lower-section layout follows `detail-typography.md`.

## Stack experiment

Settings -> Experimental -> **Stack payment cards** (`experimental_payment_card_stack`), off by
default, independent of the pass deck.

- Groups only payment cards, at the first card's position; passports and IDs keep their own
  pages and relative order. Filtering runs before grouping. Manage stays flat. No records or
  saved order are rewritten.
- Vertical overlapping stack with bank marks on the exposed edges; no heading, count or
  instructional copy. Tap lifts a card; tapping the lifted face opens `CardDetailScreen`.
  Pull down, the small return handle, or Back returns it. Horizontal swipe on the lifted face
  selects the neighbour. Numbers stay masked throughout.
- Springs start from the rendered position and retarget mid-flight; the lifted card stays
  pinned while the rest scrolls; selection from a scrolled deck starts where the card is.
  Exposed headers stay readable at 5, 10 and 15 cards, and every card stays reachable (tested
  at each count). Reduced motion moves immediately.
- Each card has a select/open semantics action and a distinct ending-in label; long press
  keeps the remove action. Manage reveal resolves a card to the group page and brings that card
  forward; removal and editing resolve against live provider data; returning from details
  keeps the selection.

## Still unverified

Printed-card OCR accuracy (glare, real front/back layouts), release-build behaviour, a full
secure-storage migration audit, release frame timing and battery impact of the living
material, and physical-device performance with 15 stacked cards.

## History

- 13 Nov 2026: first version (Visa/Mastercard/RuPay, manual network fallback, engraved line
  face, chip). Approval mock `payment-cards-preview.html` removed from the tree; it is in git
  history.
- Mid Nov: automatic-only detection and the four extra networks; copy-details group; bank
  logos; per-bank art directions; unlabelled face; relief artwork (six silhouettes replacing
  eleven line patterns).
- 18 Nov 2026: living satin material replaced the painted motifs.
