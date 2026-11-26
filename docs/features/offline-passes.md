# Offline passes

Status: **implemented contract** (25 November 2026). Device verification of offline cold
start and queued uploads is still required; see Verification.

Server-backed passes (trains, movies, buses, flights, and their archive) stay on the
phone. A user who opens Docket without a connection sees the passes and gate codes from
the last successful sync instead of a retry screen.

## Downloaded wallet

- Every successful `GET /v1/passes` is written to an encrypted snapshot in
  `FlutterSecureStorage` (`kDocketAndroidOptions`). Gate-code payloads arrive inside the
  pass list, so a saved pass stays scannable offline. Artwork uses the existing image caches.
- The snapshot is scoped to the API origin and signed-in account id. Another account or
  server never reads it. Mock passes and signed-out wallets are never saved.
- On open, the saved snapshot renders first and a sync starts immediately. A successful
  sync replaces the list and the snapshot. Removals made while online update it too.
- If the sync fails and a snapshot exists, the passes stay on screen with a quiet offline
  line. The retry screen appears only when no snapshot exists (for example, the first
  sign-in on a new phone while offline).
- The snapshot is a rebuildable cache, not primary data: an unreadable snapshot is
  discarded and refetched. This differs from `SecureDocumentStore`, which must never
  overwrite unreadable documents.
- Sign-out deletes every pass snapshot and queued upload.

## Queued additions

- Adding a pass by PNR or file while the network is unreachable queues it instead of failing.
  Only transport failures (no route, DNS, TLS, timeout) queue; server rejections still show
  the existing failure screen.
- A queued file is copied into app-private support storage and deleted after upload. The
  queue index is in secure storage and is account scoped like the snapshot.
- The Passes tab shows how many passes are waiting. The queue drains in order when the app
  resumes, after a successful pass sync, and on a bounded retry timer while items wait.
- An item the server rejects leaves the queue as a visible failure the user can dismiss.

## Not offline

Live train status, deleting a pass, and the first upload of a queued pass need the server.
Deleting while offline keeps the current behavior: the card returns and an error shows.

## Verification

No automated tests cover this yet; add snapshot scoping, offline fallback and queue drain
suites before release.
Device checks: airplane-mode cold start with saved passes; queue a PNR offline, reconnect,
and confirm it appears; sign out and confirm the snapshot is gone.
