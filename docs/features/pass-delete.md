# Pass delete

Remove a pass from the wallet the same way an ID leaves it: long-press,
confirm, gone. Expired passes in Archive use the same confirm.

## Why not document trash

IDs and passports are local-encrypted records. Removing one moves it to
`trashProvider` so restore is lossless.

Passes are not that. The live list is `GET /v1/passes`. A hide-only client
list comes back on the next refresh; stuffing a `WalletPassItem` into the
ID trash would mix two stores and still leave the row on the server.

So a confirmed remove **deletes** the pass. Mock drops it from the in-memory
catalog. Remote calls `DELETE /v1/passes/{id}`. There is no restore.

## Surfaces

| Where | How |
|---|---|
| Wallet card | Long-press → confirm sheet (same shape as Remove Passport) |
| Detail screen | `⋯` → Copy (when there is something to copy) and **Remove pass** → same confirm. Success pops the detail. |
| Archive row / movie poster | Long-press → same confirm. `HistoryCategoryScreen` already re-derives from `passListProvider`, so the last item in a folder becomes the empty state rather than a frozen snapshot. |

The confirm is a `CupertinoActionSheet`:

- Title: `Remove this pass?`
- Message: `{title} will be removed from your wallet.`
- Destructive `Remove` / `Cancel`

`{title}` is `HistoryPassPresentation.title`, the same line Archive already
uses.

## Data

`PassRepository.deletePass(id)` is the one write.

- **Mock** mutates the fixture list. Recreating the repository (mock toggle)
  reseeds, which is the same as today's reload.
- **Remote** `DELETE /v1/passes/{id}`. `204` and `404` are both success — a
  missing row is already gone. Auth / network failures surface as
  `PassIngestException` the same way ingest does.

`PassListNotifier.removePass` removes the row from the current list first,
then calls the repository. A failure puts the previous list back and the
UI shows `Could not remove pass`. Removes are queued so two confirms cannot
interleave the rollback.

## Out of scope

- Putting passes in the IDs/passports trash
- Server-side soft delete / undelete
- Undo snackbar (would lie once the DELETE has landed)
- Swipe-to-delete on the wallet carousel (vertical pager; long-press matches IDs)
