# Payment cards

The latest [artwork refinement](payment-card-artwork.md) replaces repeated line
fields with sculptural relief, carved geometry and contained engraving. Existing
bank palettes, accents, face layout and interactions are retained.

An optional [payment card stack experiment](payment-card-stack.md) groups bank
cards into one wallet page, with select-then-open navigation. Settings →
Experimental → Stack payment cards controls it independently of the pass deck.

## Card craft revision — current implementation plan

### Unlabelled face refinement

The number-reveal hint below the face is centered and uses the existing tertiary
label color (52% ink in dark mode, 40% in light), making it quieter than section
labels while preserving theme behavior.
Both themed detail renders were inspected; six relevant tests passed and scoped
analysis was clean. The updated arm64 debug APK was installed over the existing
app on the Edge 30.

Remove visible number, cardholder and expiry labels from the face, including
"Ending in". Keep accessible descriptions and the labelled information group.
Use a single four-dot mask before the last four digits. Center the bank symbol
and name on the same line; place Credit/Debit beneath the network mark.
Name and date remain aligned on the bottom baseline without captions.
Replace box, grid and step artwork with contours, diagonal grooves and fans,
while retaining the established bank palettes and other distinct motifs.
Hard folded panels and vertical bars are also softened into curved bands and
grooves, including Canara's blue/gold design. This preserves bank recognition
without the rectangular panel treatment.

Verification: 40 targeted tests pass with the current rendered baselines and
scoped analysis is clean. Tests check a single four-dot mask, absence of visible
face labels, bank logo/name alignment and card type placement below the network.
Inspected the bank gallery, same-bank variants and detail renders in both themes.
The final arm64 debug build was installed over the existing app and visually
checked on the Edge 30. The unlabelled face, short mask and softened Canara
artwork are present; the labelled copy-details section remains separate.
Real card values were neither revealed nor copied, and records were unchanged.

### Bank recognition and face layout revision

Move the security code entirely to the existing information group; it no longer
appears on the face. Replace repeated number dots with a prominent last-four
identifier ("Ending in"), retaining tap-to-reveal for the full PAN. Put the
network at the upper right and align Cardholder / Expires in a shared footer.

Give all 23 supported banks dedicated dark/light color families and explicit
art directions: blocks, rings, diagonal planes, ribbons, folds, flutes, rays,
grids, arches and woven bands. Combine each motif with a deliberate bank accent
and composition, rather than assigning patterns randomly. These are original
Docket representations, not claims to reproduce an official card product.
Existing issuer ids and shade indices remain stored as before; palettes for
banks that previously fell back to neutral are intentionally updated. Additional
cards from the same bank keep shade variants and distinct visible last fours.

Render and inspect a representative bank sheet, same-bank variants, every network,
the copy-details screen and narrow/large-text states before building for the phone.

Verification: 40 targeted tests passed in the final run; scoped analysis reported
no issues. Inspected the 15-face representative gallery, both HDFC shades, every
network and the detail/entry renders. The arm64 debug APK built and was installed
over the existing app on the Edge 30. On-phone inspection confirmed the Canara
blue/gold artwork, last-four identity, aligned footer and security code confined
to the information group. Copy controls remain available there. No real card
values were revealed or copied, and stored records were not rewritten.

### Earlier copy-details refinement

Remove the decorative chip; enlarge card type, holder and
expiry typography and use "Valid through" in sentence case. Add a separate
copyable information group below issuer/network/type: number, security code,
holder and expiry. Number and security code stay masked until revealed; copy
buttons copy the actual field, with confirmation that does not repeat its value.
Keep this utility section separate from the face and reuse grouped-row styling.

Latest refinement verification: 39 targeted card tests passed, scoped analysis
reported no issues, and the Android arm64 debug APK built. Inspected light/dark
detail renders and the updated network-face sheet. Tests cover exact clipboard
values without reveal, independent reveal expiry, hiding on background, absent
fields and narrow layouts with large text. After the Motorola reconnected, the
APK was installed over the existing app on 13 November 2026 at 14:40 local time.
The on-phone detail screen was visually inspected: no chip, larger face labels,
and the separate masked information group with four copy buttons. Existing
records remain intact; no real card values were copied or revealed during this
installation check. The updated detail screen was left open for inspection.

Scope: payment-card faces, their entry/review screen and detail screen only.
The previous HTML and face specification below describe the first iteration.
The latest user direction supersedes those visual decisions.

- Automatic network detection only. Remove all manual network choices, including
  "No mark". Identify prefixes during typing; validate complete lengths and Luhn
  separately. Unknown networks may be stored without inventing a logo.
- Add American Express, Discover, UnionPay, JCB and Diners Club, with proper
  lengths, grouping and Amex's four-digit security code. Keep existing serialized
  enum names and legacy manual metadata readable.
- Compact native entry layout: live masked card preview, grouped fields,
  logo-bearing bank suggestions, segmented debit/credit choice and one save action.
  Keyboard, small displays, large text and inline errors must remain usable.
- Craft the face with an etched line composition, directional material lighting,
  a fine physical edge, network at the upper right and disciplined
  bank / number / holder / expiry typography. Keep stored bank color families,
  the ID-1 proportions, masked values and independent reveal behavior.
- Bring the detail screen into the same hierarchy, with compact grouped actions
  and photos. No changes to dashboard navigation or other document artwork.
- Verify real Flutter renders in light/dark, unknown/long bank names, supported
  networks, validation and keyboard states; inspect the installed result on the
  connected phone. Use synthetic card details and clean them up afterward.

Implementation: the face uses a static vector material painter, with a finer
edge and engraved contours. The decorative chip was removed after feedback.
Network marks
sit at the lower right. The entry form has a live masked preview, grouped
number/name/expiry/code fields, automatic prefix-driven network logos, a bank
picker with local logos, and a compact debit/credit/not-set control. The detail
screen groups issuer, network and type, followed by separate copyable card
information and scanned photos. Copyable information includes number, security
code, holder and expiry. Sensitive rows reveal independently for five seconds,
hide on background and hold Android's secure flag while revealed. Copy actions
copy the actual value without revealing it and acknowledge success with a check.

Network lengths, grouping and security-code sizes for the added networks follow
[Braintree credit-card-type](https://github.com/braintree/credit-card-type/blob/main/src/lib/card-types.ts).
Specific RuPay slices continue to precede the broad Discover 65 prefix.
Amex's four-digit CID is recognized by OCR and preferred over a three-digit
back-side code. Existing serialized network names remain compatible; no manual
network controls are offered on the new entry screen. Unknown prefixes are
stored without a guessed logo.

Desktop verification: 33 targeted tests passed without updating goldens in the
final run. Scoped analysis reported no issues. Light/dark entry renders and
all eight network faces were inspected; screenshots are in `test/goldens/card_*`.
The bank-mark regression also covers all 23 bank logos at wallet and thumbnail
sizes. The Android arm64 debug APK built successfully.

Phone revision check: installed over the existing app on the Edge 30. Confirmed
early Amex detection from `37`, 4-6-5 grouping, automatic expiry formatting,
three-digit CID rejection and four-digit CID save. Tested local bank search and
selection with the keyboard open. Inspected the engraved face and revised detail
screen using a synthetic card ending 0005, then permanently removed that specific
test record. Other cards and documents were left intact. Two observed finish
issues were corrected: dismiss the search keyboard before closing the bank
picker, and show the network logo alone in the detail row to avoid a duplicated,
wrapped network name. Photos/camera OCR accuracy on a real printed card remains
outside this visual revision's verification.

Final installed build recheck: bank selection returns to the full form with
`mInputShown=false`; the redundant custom-name choice for recognized aliases is
removed. The final detail row uses the network logo without duplicate text,
and values align to the trailing edge. The synthetic record was deleted from
Trash; real cards remain on the phone.

## First iteration and earlier verification (historical)

Status: built in the app and smoke-tested on a Motorola Edge 30 (Android 14)
over wireless ADB on 13 November 2026. Installed over the existing app without
clearing its data. Printed-card OCR accuracy still needs a card in camera view.

Cards (credit and debit) join Documents, beside Passport and ID Cards. The wallet face is an ID-1 card in the same frame Aadhaar and PAN already use. The bank name and the network mark sit at the top, and the number sits low, so two cards can be told apart at a glance. Color does the rest: each bank has its own family, and a second card from that bank takes the next shade.

The faces to approve are in `payment-cards-preview.html`. Sample names and numbers only.

## Network from the number

The first 6 to 8 digits are the issuer identification number (IIN, still often called a BIN). Each network owns published ranges. Matching those digits names the network. Nothing else is calculated from the number.

The Luhn check is a separate test. It catches a mistyped or misread digit. It does not say Visa, Mastercard, or RuPay.

Offline rules for the first version:

| Network | Rule |
| --- | --- |
| Visa | Starts with 4, and the length is 13, 16, or 19. Almost every card in hand is 16. |
| Mastercard | Length 16, and the number starts with 51–55 or 2221–2720. |
| RuPay | Length 16 and the number falls in a known RuPay slice: 508500–508999, 606985–606999, 607000–607984, 608000–608999, 652150–652999, 653000–653149. |

RuPay has no single leading digit. `6` also covers Discover and UnionPay, so a card is RuPay only inside those slices. A Luhn-valid number outside the table is saved as a card with no network mark, and the review step offers Visa, Mastercard, or RuPay as a manual choice. The guess never overrides a range match.

Debit versus credit is not in the number in a way we can trust offline. The person picks Debit, Credit, or neither on the review step.

The bank name comes from the same digits. A bundled table maps the first 6 digits to a display name. The first version includes prefixes checked for HDFC and ICICI. Typing SBI, Axis, or Kotak still selects that bank's color. Other banks stay blank until a prefix is checked and added. Longest prefix wins. The number is never sent to a BIN website. The review step shows the matched name and lets the person edit it. What they confirm is what the face prints. A miss leaves the name blank until they type one, and the face says "Card" until then. Saved cards keep the confirmed name and the stored shade, so a later table update does not rename or recolor them.

## Add flow

Documents `+` gains a Cards tile, sublabel "Visa, Mastercard, RuPay". It sits next to Passport and ID Cards, not inside the government-ID list.

1. The tile opens the camera. It does not ask which network.
2. First capture is the front.
3. Second capture is the back. The screen says why: some cards print the number, name, and expiry on the front and the CVV on the back; some Indian cards print the number on the back.
4. On-device text recognition (the ML Kit recogniser the ID scanner already uses) proposes number, name, expiry, and CVV. Nothing saves from the shutter alone.
5. A review step shows those fields, the detected network, and Debit / Credit / skip. The person can correct every field. "Type it instead" is on the first camera step, because a metal face and a hologram often defeat OCR.
6. Save is refused while the number fails Luhn. An expired date is allowed and labeled Expired. A missing CVV is allowed.
7. The card joins the documents carousel through the existing wallet order. Adding and deleting reconcile that order.

## Face

One layout. Same canvas as the other ID-1 documents: aspect `1.586`, design size 440 × 277, corner radius 24, then scaled by `WalletCardCanvas`.

The type has three voices, in Geist, with the number in Roboto Mono. The bank name is the title: top left, semibold, tight tracking. Credit or Debit sits under it, smaller and quieter. The network mark is a small stamp at the top right, not a second title. The number sits low, larger than the name: four round dots and the last four while it is hidden, four even groups when it is shown. The CVV is three dots on that same line, revealed on its own tap. The holder name and the expiry are a caption under the number, with no field labels.

Color is how a stack of cards stays readable. Each known bank has an ordered family of two or three surfaces. The first card from that bank takes the first surface. The next card from the same bank takes the next surface, so two HDFC Visas are not twins. The families in the preview:

| Bank | First card | Next card |
| --- | --- | --- |
| HDFC | Ink navy | Ice blue |
| ICICI | Burnt orange | Sand |
| State Bank of India | Cobalt | A pale blue that is not HDFC's ice |
| Axis | Wine | Blush |
| Kotak | Crimson | Rose |

A bank with no family yet, or an unknown bank, takes the next free neutral: graphite, silver, then warm stone. The chosen surface is stored on the card. Deleting one card does not recolor the others.

The network mark follows the number. Visa is the wordmark, white on a dark surface and Visa blue on a light one. Mastercard is the red and amber circles. RuPay keeps the orange and green arrows, and the word takes the card's ink so it still reads on a dark surface. A number outside the network table has no mark until the person picks one.

The hidden number is `•••• 2291`. A tap shows the full number in four groups. The CVV shows as three dots until its own tap. A second tap hides each one, and each hides on its own after a few seconds. The last four stay visible. An empty CVV draws no CVV. There is no placeholder number.

The marks in the preview are the network logos, drawn as vectors. They are trademarks. The app draws the same marks. Bank card art is not fetched. Issuers do not publish a stable art catalog, and the partnerships Apple Wallet and Google Wallet use are not available here.

## Storage

A new `PaymentCard` record in its own secure-storage key. It does not become an `IdDocument`. That type only has PAN and Aadhaar, and an unknown type currently loads back as PAN.

The record holds network, kind (debit, credit, or unset), confirmed bank name, surface index, holder name, number, expiry, CVV when present, and attachment metadata. It stays on the device, in the same encrypted store as passports and IDs. It is never sent to the passes API. Number, CVV, and OCR text are never logged.

Scan photos, when kept, are encrypted files under `card_scans/<cardId>/`, with their own key `card_scan_key_v1`. They are not stored with ID attachments. Bytes stay on disk and only the file metadata is in the secure record. A key that cannot be read, cannot be decoded, is the wrong length, or is missing while files already exist blocks further writes. The wallet face is the metal card, not the photograph. Trashed cards still own their files. The orphan sweep does not run until the card list and trash are loaded, and it skips entirely when either list key or the scan key is unreadable.

While a value is revealed, the screen blocks screenshots (`FLAG_SECURE` on Android). Reveal state is not stored.

## Bank logos extension

Bundle offline SVG symbols from auraveni/global-bank-logos, pinned to commit
`ad33060ca976397a9fcb46dd40c2d77bce5ce7e1`, with its MIT notice and source hashes.
Add the symbol beside the existing bank title, keeping the network mark and
current surfaces. Cover HDFC, ICICI, SBI, Axis, Kotak, PNB, Bank of Baroda,
Canara, Union Bank of India, IDFC FIRST, IndusInd, YES, Federal and RBL;
international coverage is HSBC, Standard Chartered, Citi, Chase, Bank of America,
Wells Fargo, Barclays, Deutsche Bank and DBS.
Match confirmed names and explicit aliases, without expanding the BIN table.
Unknown names retain text only. Existing saved names can gain a logo without
changing stored colors or rewriting records. Validate alias collisions, asset
decoding and layout on dark/light surfaces and at wallet thumbnail scale.

Implemented with 23 bundled marks (about 42 KB before normalization), explicit
name aliases, and a white field beside the bank title to preserve original
colors on dark faces. Federal Bank and Wells Fargo CSS fills are inlined for
Flutter compatibility; the other 21 SVGs are unchanged. Source and bundled
hashes are recorded in `tool/design_src/bank_logos/sources.json`, and
`tool/bundle_bank_logos.py` reproduces the bundle. No new BIN guesses or
network requests were added to the app. Unsupported confirmed names suppress
any stale issuer hint instead of showing a different bank's mark.

Verification: 19 targeted card tests passed, including decoding all 23 marks
on two surfaces at wallet and thumbnail sizes, unknown-bank fallback, alias
collisions, and the existing reveal/review tests. Rendered golden examples
were inspected on dark and light surfaces. Scoped static analysis passed.
Physical-device rendering was subsequently checked for HDFC and Chase; see below.

### Physical-device verification — 13 November 2026

Built and installed the debug APK over the existing installation on a Motorola
Edge 30, Android 14/API 34, using wireless ADB. Existing passport, Aadhaar and PAN
records still load; the pre-upgrade PAN record was also checked after cleanup.
The development machine's configured JDK was missing its executables. Installed
a checksum-verified Temurin 21 JDK under `D:/dev/jdk-21/` and corrected Flutter's
JDK setting before building.

Using a synthetic Visa number and a holder named "Docket test":

- Documents -> Cards opens the physical camera. Front capture advances to back;
  back capture reaches review. Nothing saves from the shutter alone.
- Invalid-number validation disables Save. Manual entry reaches review, and
  duplicate-number saves are refused.
- Saving adds a masked card to the wallet. HDFC and Chase marks were visually
  inspected on the phone; editing the confirmed bank changes the mark.
- Number and CVV reveal independently, then hide after five seconds.
  Android's window SECURE flag is present during reveal and review, and
  screenshot capture yields no image while secure. Normal capture works once
  values are hidden and the flag is released.
- Both captured photos are listed; the front photo viewer opens without an
  error under SECURE.
- The saved card and its issuer survive force-stop/relaunch.
- Removing the synthetic card puts it in Trash; deleting that specific test
  card permanently leaves Trash empty. Existing documents were not removed.

The camera had no printed card in view, so recognition accuracy, glare handling,
and extraction from real front/back layouts remain unverified. This was a debug
build smoke test, not release-build validation or a full secure-storage migration
audit. No source changes were needed during the device check.

## Out of this version

Amex, Discover, UnionPay, and Maestro. NFC tap-to-pay. Photographic card art.

## Verification

The model, matcher, bank table, face, two-step scan, review, and Documents tile are in the app. Tests cover the network rules, a known bank prefix, an unknown prefix, the next shade, the scan-store interlock, the face reveal, and a review that refuses a number that fails the check. `flutter test` on this machine passed the card tests and the wallet wiring they touch. Two older goldens still miss by a small color shift against the committed images: the passes add sheet and the passport cover art. Those screens were not part of this change, and their goldens were left as they were. Passport, Aadhaar, and PAN faces are unchanged. A physical device was not attached, so the camera, `FLAG_SECURE`, and an install over an existing build are still unchecked.
