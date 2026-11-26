# Roadmap

Status: **proposals only**. Nothing on this page is implemented unless its entry says so.
Only big, distinctive features go here: ones that change what Docket can do, not polish
or fixes. Each entry says why it matters, how it would work, what data moves, what can go
wrong and when it counts as done. When work starts, move the detailed contract into its
feature doc and leave a link here.

This repository is public. `docket_server` is private. Entries describe the app/server
contract at the level of [the passes API](api/passes.md); server secrets, environment
values and deployment details never go here.

## Tap to send a pass

Status: proposal, 24 November 2026. Not started.

### Purpose

Hand a ticket to someone standing next to you by touching phones: a friend's movie seat,
a family member's train berth, a travel companion's boarding pass. Today that means
exporting a PNG through a chat app, which gives the receiver a picture instead of a live
Docket pass, and leaves a plaintext copy of the ticket in the chat. Tapping gives the receiver
the real pass, with its genuine code, artwork and status, and the sender keeps their copy.
The interaction is modelled on Apple's NameDrop: hold the phones together, feel a haptic,
and watch the pass leave one screen and land on the other.

### How it works

Android removed Android Beam in Android 10, so the phones cannot exchange data peer to peer
over NFC directly. Instead, one phone acts as the reader and the other as a card:

- **Receiver = card (host card emulation).** Docket registers a `HostApduService` for a
  private Docket AID. Android wakes it whenever a reader selects that AID, even when Docket
  is closed, as long as the screen is on and unlocked. So the receiver does not need to
  open the app first.
- **Sender = reader.** The sender opens a pass and chooses **Share > Tap to send**. This
  enables reader mode, reusing the IsoDep stack in
  [MainActivity](../android/app/src/main/kotlin/com/navadeep/docket/MainActivity.kt) that
  already reads passport chips.

The NFC exchange carries only a small token. The pass itself comes from the server:

1. The sender's app asks the server for a share token for that pass. The token works once
   and expires after a few minutes.
2. On touch, the sender SELECTs the Docket AID. The receiver replies with a protocol
   version, a fresh nonce and a public key generated for this exchange only.
3. The sender encrypts the share token to that key (`cryptography` package, already a
   dependency) and sends it in one APDU. The whole exchange is under 200 bytes and about
   200 ms.
4. The receiver's service wakes Docket to an **Incoming pass** screen that previews the pass
   and offers **Add to Docket / Decline**.
5. On Add, the receiver claims the token with their own signed-in session. The server
   copies the pass into the receiver's account and marks the token used.

Animation on both phones, at the moment of the tap:

- A glow ripples out from the top edge, with a haptic pulse.
- On the sender, the pass shrinks and flies up off the screen.
- On the receiver, the pass drops in from the top with a spring.

Build it with the existing `core/` motion helpers. It must also look right with reduced
motion enabled.

Mock mode sends a fixture pass's JSON directly over NFC so the whole flow can be demoed and
tested without a backend.

### What is shared

| Shared | Never shared |
|---|---|
| One train, movie, bus or flight pass the sender chose | Passports, national IDs, payment cards, attachments |
| A single-use share token over NFC | The pass itself over NFC (it comes from the server) |
| The sender's display name on the Incoming screen | Account tokens, email address, other passes |

The token, keys and pass contents never appear in logs.

### What can go wrong

| Risk | Mitigation |
|---|---|
| Someone taps a stranger's phone in a crowd | Nothing is added until the receiver taps Accept; the token expires and works once |
| Token intercepted or replayed | It is encrypted to a key created for this exchange only, claimed once, and the claim needs the receiver's signed-in session |
| A malicious reader probes the Docket AID | The card side only gives out a nonce and a throwaway public key; it holds nothing sensitive |
| Receiver signed out or offline | Keep the token pending and claim it once they sign in or reconnect, before it expires |
| Antennas don't line up / phones move apart too early | The exchange is a single short round trip; the sender UI shows "Hold near another phone" and retries |
| Receiver's phone locked or screen off | Android won't route to the service; the sender is told to ask them to unlock |
| Another app (e.g. a payment app) answers the tap | A private AID in the "other" category means card readers and payment terminals ignore it |
| iPhone receivers | Not supported: iOS doesn't allow general card emulation. Use image sharing instead |
| Sender changes or deletes the pass afterwards | The receiver's copy is independent; decide in the feature doc whether updates propagate |

### Work and done when

1. **Contract:** protocol, token lifetime and copy-vs-link decision recorded in
   [pass share](features/pass-share.md).
2. **Server:** create-share and claim-share endpoints in the private `docket_server`, plus
   the matching section in [the passes API](api/passes.md).
3. **Android:** `HostApduService`, its manifest and AID XML, and a sender reader handshake.
4. **Dart:** message codec, encryption, share controller, and the send and incoming screens.
5. **Animation:** sender and receiver motion, haptics and reduced-motion variant.

Done when:

- Unit tests cover the codec, tamper and expiry cases.
- The flow works between two physical Android phones in release builds, with Docket closed
  on the receiving phone.
- A second claim of the same token fails.
- No pass, token or key data appears in logs.
