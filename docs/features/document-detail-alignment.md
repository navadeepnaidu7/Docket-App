# Document and payment detail alignment

## Scope

Align the lower detail areas of PAN/Aadhaar and payment-card screens with the
existing movie, train and bus detail UI. Preserve document/card artwork,
original attachment flows, copy/reveal behavior and navigation. Passports use
an in-place booklet flip and have no separate lower detail section.

## Implementation

- Promote the existing pass typography and information-card shell to shared
  detail components, retaining the pass API and its current appearance.
- Use the same 15px section title, 13px label/value roles, 16px inset and border
  treatment in document and payment details. Keep 48px action hit targets;
  stack label/value text when narrow widths or large text need it.
- Match lower-section gutters and gaps to pass screens. Keep originals and
  secure reveal/copy handling intact.
- Apply a Discover-only optical logo size correction in NetworkMark.

## Verification

Run flutter analyze, existing card copy/reveal tests with updated light/dark
goldens, and rendered PAN/Aadhaar/payment/pass comparisons. Exercise narrow
screens, large text, long values, missing values and the document copy action.
Use synthetic records for screenshots; do not access personal device records.

## Verified

- 27 focused tests pass: copy/reveal, document row and icon copying, missing
  values, large text at 320dp, Discover under loose row constraints, bundled
  fonts, pass typography and train layouts.
- Reviewed light/dark document and payment detail renders against the pass
  information card, plus a gallery of all network marks. Updated the existing
  payment-detail goldens and added document-detail goldens.
- `flutter analyze --no-pub lib test`: four existing info-level notices in
  settings and chip payloads; no errors or warnings. Repository-wide analysis
  also includes unrelated errors in old build snapshots and the bus preview tool.
- Physical-device verification on 19 Nov 2026: debug APK built successfully and
  installed with `adb install -r` over the existing app on a Motorola edge 30
  (Android 14, 1080x2400). Existing wallet records remained available.
- Inspected PAN and Aadhaar details, payment details and the Discover mark on
  the stacked wallet, expanded card and detail screen. Inspected Aadhaar and
  payment details in light/dark mode and compared the dark detail layout with
  the train Journey/Booking groups. No clipping or overflow was observed.
- Confirmed document copy feedback (checkmark, copied label and Android
  clipboard overlay), card-number reveal changing its control to Hide, and
  automatic re-masking after the reveal timeout. The checked Discover test
  card had no CVV; CVV behavior remains covered by widget tests.
- App-process logcat reported no RenderFlex overflows, widget/rendering
  exceptions or `E/flutter` messages during the check. Original light-theme
  preference and 60-second screen timeout were restored afterward.
