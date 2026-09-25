# The LAN admin UI

The bookclub's operator console: a task-based UI on the box's LAN, served
by the service itself on `MCL_ADMIN_PORT` (default 8488, all interfaces).
It is **not** mesh-facing and carries **no auth layer of its own** — it is
an operator tool on the same box the service runs on, and the fleet places
it accordingly.

## The doctrine: one entry point per desk

Every task the UI offers is one command dispatch, and every command has
exactly one HTTP entry point — the `{command}_api` module in the command's
own desk (the corpus's HOPE-side command entry point). The api module is
**pure**: it turns the UI's params into a command and dispatches, and the
facade (`mcl_bookclub_admin`) owns the wire (cowboy routes, JSON codec,
static files). Three consequences worth noticing:

1. **The UI can never do what the domain refuses.** The api module calls
   the same `maybe_*:dispatch/1` the tests and the mesh use; the
   aggregate's guards (already initiated, archived, retired, ...) are the
   last word, whatever the UI sent.
2. **The api module is the boundary for ids.** A missing `club_id`
   (or member/book/reading id) is minted there and echoed back in the
   event, so the UI's task log always shows the operator the id the task
   created.
3. **The divisions stay pure.** The api modules import no cowboy and no
   mesh SDK — the CMD boundary test keeps it that way.

## Routes

Writes follow the corpus's route shapes, `POST /api/{plural}/{verb}`:

| Task | Route |
|---|---|
| Initiate a club | `POST /api/clubs/initiate` |
| Plan a party | `POST /api/clubs/plan_party` |
| Archive a club | `POST /api/clubs/archive` |
| Register a member | `POST /api/members/register` |
| Unregister a member | `POST /api/members/unregister` |
| Procure a book | `POST /api/books/procure` |
| Retire a book | `POST /api/books/retire` |
| Start a reading | `POST /api/readings/start` |
| Finish a reading | `POST /api/readings/finish` |

Reads answer from the QRY division, `GET /api/{plural}/:id` — plus
`GET /api/members/:id/readings`. A successful write answers
`{ok: true, version, events}` with the minted ids in the events; a refused
one answers `400 {ok: false, error}` — the aggregate's own reason.

## What the UI proves

The UI is the first human-facing consumer of the whole pipeline: a task
appends an event, the projection writes the sqlite row, and the by-id
lookups read it back — the same event-delivery story as the mesh, over
HTTP, and the same correctness: idempotent writes, self-contained events,
absolute folds.
