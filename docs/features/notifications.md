# Notifications

Status: **app implemented; device verification pending** (26 November 2026). Server
implementation is tracked in the sibling server repository. This page is the contract for
both reminders scheduled on the phone and booking updates pushed by the server, plus
account deletion, which shares the device-registration lifecycle. Mark sections
implemented as they land; device checks are listed under Verification.

App status: reminder planner/reconciliation, Firebase gateway, device registration,
preference synchronization, contextual permission sheet, Settings and account deletion
are implemented. Firebase configuration and real-device checks remain release work.

### App implementation decisions

- Code lives in `lib/features/notifications/`; the runtime is mounted below
  `MaterialApp` and initializes after its first frame. Nothing joins the wallet
  startup barrier. Reconciliation runs on wallet/settings/account changes, resume,
  and a one-minute retry while the app is open. Reboot/update receivers restore
  scheduled inexact alarms.
- No pass model exposes an added/created timestamp. The scheduler persists the first
  observed timestamp per pass id in `notification_first_seen_v1` preferences. This
  includes the first load of existing wallets; a pass first seen within 15 minutes
  of its adjusted reminder time is suppressed. First-seen values survive restart,
  removal and restore.
- Train boarding departure, movie showtime and bus departure use the existing
  `passStartTime` parser: valid machine timestamps first, otherwise a complete date
  plus a valid display clock. There is no midnight/date-only fallback. The current
  bus model has no separate reporting-time field. Display-only times follow the
  phone-local semantics of the existing app for scheduling; notification labels
  retain the printed clock or the ISO wall clock, even when the phone is abroad.
  Flight instants use `AirportTime`'s
  retained UTC offset; content keeps the airport clock. The existing model's
  zone-less flight fallback remains phone-local. Only the first upcoming leg of a
  linked flight trip is reminded; resume/reconciliation advances to the next leg.
- Quiet hours and the 21:00 previous-evening adjustment use the device IANA zone,
  including daylight-saving rules and legacy IANA aliases. Default lead times,
  settings choices, exact 15-minute and 10-minute boundaries are unit tested.
- Grouping requires the same pass kind, event/service and venue/station/route,
  with all starts within 10 minutes of the first. Reminder ids use a stable FNV-1a
  hash of the representative pass id. No booking references, passenger names or
  code payloads enter notification content. Android notifications use PRIVATE
  visibility; Android controls redaction in the locked view.
- Pass archive is represented by `expired` status; removal takes the pass out of
  the list. Both cancel reminders. Restoring/reloading an active pass reconciles
  it. Train and flight cancellation/departure states are checked; movie and bus
  models do not expose a separate cancellation field.
- Local settings and a pending-upload flag use SharedPreferences. The FCM
  registration record (including token) is in secure storage. Failed sync retries
  on the next change/resume/periodic attempt. Server preferences still synchronize
  when Firebase is unavailable. Developer sessions now carry a persisted marker
  and do not register push or expose account deletion.
- The gateway deliberately uses Firebase's token APIs for the HTTP v1 token
  contract; the newer FID registration APIs are a different server contract.
  Foreground messages match FCM's `(id: 0, tag: ticketId:channel)` replacement pair.
- Deletion runs in `AuthController`: a confirmed 204 precedes push teardown,
  session/identity and offline/pending-pass cleanup, reminder cancellation and
  Google sign-out. Failed deletion restores any credentials changed by an auth
  retry and performs no cleanup. Local identity documents are never touched.
- Dependencies are constrained to Dart 3.11-compatible releases:
  flutter_local_notifications 22.3.3, timezone 0.11.2, flutter_timezone 5.1.1,
  firebase_core 5.1.0 and firebase_messaging 17.0.1. The lockfile also retains
  compatible Firebase platform/web dependencies. Desugaring uses 2.1.4; AGP remains
  8.11.1. Plugin/GSON consumer rules provide Java keeps; the drawable is explicitly
  preserved for resource shrinking. No exact-alarm permissions are declared.

## Goal

Keep people informed about the moments that matter for a pass, without making Docket
an app they mute. The default experience is **one well-timed notification per moment**,
not a stream of status changes.

Five rules shape everything below:

1. **Only send what someone would act on or want to know now.** A waitlist moving from
   WL 24 to WL 23 is not news. WL to confirmed is.
2. **Update in place.** Each pass has at most one visible notification per category. A
   newer one replaces the older one; nothing stacks up.
3. **Respect the night.** Quiet hours hold non-urgent updates and deliver one summary
   when quiet hours end.
4. **Merge bursts.** Changes that arrive together (chart prepared, confirmed, berth
   allotted) go out as one message.
5. **Nothing sensitive on the lock screen.** Notifications are private by default; the
   locked view shows only the app name and "Contents hidden".

## Categories

Each category is an Android notification channel and a toggle in Settings, so people
can mute one kind without losing the others.

| Channel id | Name | Source | Examples | Default |
|---|---|---|---|---|
| `trip_reminders` | Trip reminders | Phone | Movie starts in 2 hours; flight tomorrow 05:40 | On, high importance |
| `booking_updates` | Booking updates | Server | WL 12 is now confirmed; chart prepared; berth changed; cancelled | On, high importance |
| `journey_live` | Live journey | Server | Train delayed 40 min; about an hour from destination | On, default importance |

## Trip reminders (scheduled on the phone)

Reminders need no account and no network. They are derived from the pass list, so they
work for mock passes, local copies of server passes and offline snapshots alike.

### When a reminder fires

One reminder per pass, at a lead time before its start:

| Pass | Start used | Default lead | Choices |
|---|---|---|---|
| Movie | Showtime | 2 hours | Off, 30 min, 1 h, 2 h, 3 h |
| Flight | Scheduled departure of the first upcoming leg | 3 hours | Off, 2 h, 3 h, 4 h |
| Train | Departure from the boarding station | 2 hours | Off, 1 h, 2 h, 3 h |
| Bus | Departure / reporting time | 1 hour | Off, 30 min, 1 h, 2 h |

Smart adjustments:

- **Night-before shift.** If the reminder would land inside quiet hours, it fires at
  21:00 the evening before instead ("Tomorrow 05:40 - Flight 6E 2134 to Bengaluru").
  If that evening time has already passed, it fires when quiet hours end, provided that
  is still before the start.
- **No reminder for something just added.** If a pass is added or imported less than
  15 minutes before its reminder time, or after it, no reminder is scheduled. The user
  is clearly already aware.
- **Group same-event passes.** Passes whose start times fall within 10 minutes of each
  other at the same venue or station (several seats for one show, family members' train
  tickets on one PNR) produce a single reminder ("2 tickets - Dune: Part Three at 18:30").
- **Skip what is over or irrelevant.** Past, archived, trashed and cancelled passes have
  no reminders. Moving a pass to trash cancels its reminder; restoring re-schedules it.
- **Times are honest.** Missing or unparseable start times mean no reminder, never a
  guessed one. Times use the pass's own local time as the app already displays it.

### Reconciliation

Scheduling is idempotent: the scheduler computes the full desired set from the current
wallet and settings, cancels anything Docket scheduled that is no longer wanted, and
schedules what is missing. It runs after the pass list loads or changes, after settings
change, on app resume, and after device reboot / app update (the plugin's boot receiver
re-registers alarms; the app re-reconciles on next open). Notification ids are derived
stably from the pass identity so re-running never duplicates. This work runs after
`runApp`, never inside the startup barrier.

Reminders use inexact alarms (`AndroidScheduleMode.inexactAllowWhileIdle`); a few
minutes of drift is acceptable and avoids the exact-alarm permission.

### Content

- Title: what and when ("Dune: Part Three at 18:30", "Train 12627 departs 06:10").
- Body: where, plus one useful detail if known (screen and seats; platform is not known
  in advance, so coach/berth instead; flight terminal if present).
- Never: PNR, booking reference, passenger names, gate-code payloads.
- Tapping opens that pass's detail screen.

## Booking updates and live journey (pushed by the server)

The server already detects PNR and live-running changes and queues them in its
notification outbox. This section defines how those become calm notifications.

### What is worth sending

| Change | Sent? | Timing |
|---|---|---|
| Booking phase changes: WL to RAC, WL/RAC to confirmed, anything to cancelled | Yes | Immediately (after merge window) |
| Waitlist position improves without a phase change | Condensed | At most one per pass per day, at the first delivery window after 09:00 local, showing the latest position ("WL 24 to WL 9 since yesterday"). Only if it improved by at least 3 places since the last notified position. Worsening positions are never sent. |
| Chart prepared | Yes, as the final status | Combined with the final booking phase and coach/berth in one message ("Chart prepared - Confirmed, B2 34 lower") |
| Seat / coach / berth change | Yes | Immediately, merged with any phase change |
| First enrichment of a newly added PNR | No | The user just added it and sees the result in the app |
| Train started | No | Only noise for the passenger already on it |
| Delay | Yes, stepped | When delay first reaches 15 minutes, then only when it grows by another 30 minutes or more, or recovers by 30 minutes or more. Only before arrival at the destination. |
| Approaching destination | Yes | Once, about an hour out (existing server policy) |
| Approaching boarding station | Yes, only if delayed | Once, about 30 minutes out, when the train is running 15 minutes or more late |

### Merge window and quiet hours

- When the first event for a pass is enqueued, delivery waits **2 minutes**. Every event
  for the same user, pass and channel that arrives inside the window merges into one
  message built from the **latest** state, not a list of history.
- **Quiet hours** default to 22:30 to 07:00 in the device's time zone (user adjustable,
  or off). Non-urgent messages generated in quiet hours are held and delivered as one
  merged message per pass when quiet hours end.
- **Urgent bypasses quiet hours:** a cancellation, or any update for a pass whose
  departure is before quiet hours end plus 2 hours (the person is about to travel).
- **Daily ceiling:** at most 4 server notifications per pass per day outside urgent ones.
  Beyond that, updates still reach the app but are not pushed.

### Delivery format

The server sends FCM HTTP v1 *notification* messages (displayed by Android even when
Docket is not running) with:

- `android.notification.channel_id`: `booking_updates` or `journey_live`.
- `android.notification.tag` and `android.collapse_key`: `<ticketId>:<channel>`, so a
  newer message replaces the older one on the device and in the FCM queue.
- `android.notification.visibility`: `PRIVATE`.
- `data`: `{ "type", "ticketId", "channel" }` only. No PNR, names or seats in `data`.
- Title and body: no PNR, booking reference or passenger names. Train number and name,
  phase, coach/berth are fine.

### Preferences on the server

Server pushes honour the same Settings the phone uses. The phone uploads them; the
server applies them when it composes and schedules a message.

## App/server contract

All endpoints require the signed-in session.

| Method | Path | Body | Notes |
|---|---|---|---|
| `POST` | `/v1/devices` | `{ token, platform: "android", deviceLabel?, timezone }` | Existing; gains `timezone` (IANA, e.g. `Asia/Kolkata`). Upsert. Called after sign-in, on FCM token refresh, and on app start when the stored registration is stale (token, account or time zone changed, or older than 7 days). |
| `DELETE` | `/v1/devices` | `{ token }` | Existing. Called on sign-out before the session is cleared. |
| `GET` | `/v1/me/notification-preferences` | - | Returns the stored preferences or defaults. |
| `PUT` | `/v1/me/notification-preferences` | see below | Full replace. Returns the stored document. |
| `DELETE` | `/v1/me` | `{ confirm: "DELETE" }` | Permanently deletes the account. `204` on success. |

Preferences document:

```json
{
  "bookingUpdates": true,
  "journeyLive": true,
  "quietHours": { "enabled": true, "start": "22:30", "end": "07:00" },
  "timezone": "Asia/Kolkata"
}
```

Trip reminder settings (per pass type lead times, `tripReminders` toggle) are stored
only on the phone; the server never sees them.

## Permission

- Docket does not ask for notification permission at launch or during onboarding.
- The first time a pass with a future start is added (or the first time the wallet
  loads with one, for existing users), a short Docket sheet explains the benefit and
  offers **Turn on** / **Not now**. **Turn on** triggers the Android 13+ system prompt.
- **Not now** is remembered; Docket does not ask again on its own. Settings always shows
  the current state and, if the system permission is denied, a row that opens the
  system notification settings for Docket.
- Push registration happens only when signed in. Reminders need only the permission.

## Settings

A **Notifications** section in Settings:

- Trip reminders (switch) with per-type lead time rows (movie, flight, train, bus).
- Booking updates (switch; signed-in only).
- Live journey (switch; signed-in only).
- Quiet hours (switch plus start/end).
- System permission status row when blocked.

Changes apply immediately: reminders reconcile, and server preferences are uploaded
(retried quietly when offline).

## Account deletion

Settings > Account > **Delete account**, visible only when signed in with a real
account (not the mock or Developer token).

- A confirmation sheet states what is deleted: the Docket account, all server passes
  and their history, calendar connection, notification registrations and preferences.
  It also states what is **kept**: passports, IDs, payment cards and attachments stored on
  this phone, because those never leave the phone.
- The user confirms with a destructive button after a short delay or a typed
  confirmation. Network failure leaves everything as it was and says so.
- Server: `DELETE /v1/me` deletes in one transaction the user, tickets and their
  snapshots, sync jobs, train run links owned only by that user, device tokens, outbox
  rows, refresh sessions, notification preferences and calendar integration, and
  best-effort revokes the stored Google Calendar token. It is idempotent for an already
  deleted user only in the sense that the old session no longer authenticates.
- App, after `204`: unregister local push state, clear the session, offline pass
  snapshot, pending-pass queue and cached account identity, cancel reminders for server
  passes, sign out of Google, and return to the signed-out Settings state.
- Google Play also requires a web link where people can request deletion without the
  app. That is release work, recorded here so it is not forgotten.

## Firebase setup (developer)

`android/app/google-services.json` is per developer and untracked. Without it the app
builds, reminders work, and push registration reports itself unavailable; Settings shows
booking updates as unavailable on this build rather than failing. The server sends real
pushes only when its FCM credentials are configured; otherwise it logs them.

## Verification

App checks (26 November 2026): `flutter analyze --no-pub lib test tool` passed
with no issues. The five `notification_*_test.dart` suites plus the touched
`auth_session_test.dart` passed (38 tests total). `python tool/check_docs.py` and
`git diff --check` passed. No full-suite run or APK build was performed. UI review
was source-based plus the deletion-sheet widget test; no rendered device review
or deployed-server integration check is claimed.

Unit tests cover reminder planning (lead times, night-before shift, grouping, skips,
stable ids), preference serialization, registration staleness and the sign-out and
deletion cleanup order. Server tests cover the worth-sending table, merge window, quiet
hours, urgency, daily ceiling, message format and deletion cascade.

Device checks still required: reminder delivery after reboot and in Doze, tap routing
from a killed app, channel muting, Android 13+ permission flow, real FCM delivery with a
configured Firebase project, and account deletion against a deployed server.
