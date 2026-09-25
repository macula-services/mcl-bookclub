# Event delivery: what the `$all` subscription guarantees

This guide is the answer to the questions this service exists to make
answerable: *how do events reach handlers, process managers and projections,
and what does each of them have to do to be correct on restart?* Everything
below describes **released evoq 1.24.x on reckon-db**, which is what this
service builds against, and points at the code in this repository that
demonstrates it.

## The delivery pipeline

```
reckon-db store
     │  one `$all` subscription per store (evoq_store_subscription)
     ▼
evoq_event_router  ── per event type ──▶  evoq_event_type_registry
     │                                          │ (pg scope)
     │                                    handlers, PMs, projections,
     ▼                                    emitters (this service's PRJ)
each registered process, one at a time
```

- One subscription per store, not per subscriber. `mcl_om_store` starts it
  when the service boots (it is the `store_id/0` + `data_dir/0` wiring in
  `mcl_bookclub_service`).
- The subscription reads the store's **global log** and, on a fresh boot,
  replays it from its persisted position ("catch-up"). Subscribers register
  interest **by event type**; the router delivers each event to every process
  that registered that type.

## What order does `$all` guarantee?

The global log is totally ordered by `{epoch_us, stream_id, version}`.
`epoch_us` is stamped before the append is committed, and version numbers are
**per stream** — a version alone cannot order events across streams. Within a
stream, version order is strict; across streams, the store's global index is
the order, and `read_all_global/3` reads exactly that index. `read/5` on one
stream folds it in version order.

Because `epoch_us` is read before commit, a slow append can commit after a
faster one it sorts below. Two consequences, both real:

1. **Live delivery order can differ from a later `read_all_global` order** —
   the router hands out events as they arrive, not in the store's final sort.
2. **The persisted position is a durable resume position, and "replayed" does
   not mean "delivered before".** On restart, the subscription resumes at its
   acked position and marks everything below it `replaying => true` in the
   metadata it routes. An event that was appended but never delivered is
   delivered now — with the marker. What a subscriber does with the marker is
   its own declared choice:

   - `replay_policy() -> skip` — side-effect handlers (an emitter publishing
     to the mesh, for example) must not repeat their side effect.
   - `replay_policy() -> deliver` — idempotent consumers re-apply and stay
     complete. This service's projections declare `deliver` (see
     `bookclub_initiated_v1_to_sqlite_clubs`), because their writes are
     idempotent by construction.
   - Not declaring it delivers, exactly as before 1.24, and logs a warning
     once per boot — the warning is the mechanism that makes the choice
     deliberate.

## Delivery guarantees: at-least-once, and synchronous in 1.24

Events are delivered **at least once**. There is no exactly-once, anywhere.
The router's fan-out in released 1.24 is a synchronous call per subscriber,
serially — a slow handler delays the ones behind it (non-blocking delivery is
being worked on upstream in evoq, but this service only builds on released
code). Two rules follow:

1. **Handlers must be fast.** No network calls inside `handle_event/4` unless
   they are short and bounded.
2. **Every consumer must be idempotent.** Because redelivery happens on
   restart, on retry, and after any replay.

## How this service's projections stay correct

`bookclub_initiated_v1_to_sqlite_clubs` writes one row per club with an
`INSERT OR REPLACE` keyed on the stream id — applying the same event twice is
the same write twice. The row also carries the two fields that make the
position explicit, the pattern every read model here follows:

| column | carries | why |
|---|---|---|
| `club_id` | the stream id | the row's identity — PK, idempotent upsert |
| `event_id` | which event last wrote this row | replay and debugging |
| `version` | the stream version that event had | the applied position, saved **with** the row |

So the read model stores the per-stream version it has applied *in the same
row* as the projected data — a single sqlite statement per event, atomic by
itself. The durable position that survives a restart is the subscription's own
ack (persisted in the store), not the row: the row's `version` is the honest
answer to "how far did I get on this stream", and the ack is "where does the
subscription resume".

An idempotent write per event is what makes those two positions able to
disagree safely: the subscription resumes *earlier* than the last applied
event, the projection re-applies the overlap, and nothing changes because the
writes are absolute (`INSERT OR REPLACE`), never relative (`UPDATE ... SET
count = count + 1`). A projection that needs relative accumulation must track
applied event ids instead — out of scope for this slice, and called out here
so it is a choice, not an accident.

**Events are self-contained facts.** `bookclub_archived_v1` echoes the club's
name and birth details from the aggregate state, so its projection can
rebuild the whole row from that event alone — it never needs the initiated
event to have arrived first, in this process's history or at all. The
alternative, a relative `UPDATE` that assumes the earlier event arrived, is
the shape of the cardinal sin: it breaks silently the day a projection is
added after history exists. When an event is too poor for its consumers,
enrich it at the source — the aggregate has the state.

## The two checkpoint systems, and which is which

| Checkpoint | Owner | Type | Meaning |
|---|---|---|---|
| the subscription's ack | `evoq_store_subscription` | offset into the global log | where catch-up resumes after a restart |
| `evoq_projection`'s checkpoint | the projection process | a per-stream `version` integer | a single-stream resume hint (see below) |
| the read model's `version` column | this service's rows | per-stream version | the applied position, for humans and rebuilds |

`evoq_projection`'s checkpoint is one integer — the per-stream version of the
last event — so it is only meaningful for projections that consume **one**
stream. For a table built from many streams (this service's `clubs`, later
`members`, `books`, `readings`), a single integer cannot order across streams.
That is why this service's projections are `evoq_event_handler`s writing
idempotent sqlite rows, the shape the house rules recommend, rather than
`evoq_projection`s: the idempotency lives in the write itself, not in a
checkpoint arithmetic.

## The answer to "is the offset durable, or a hint?"

Durable, with a caveat: it is the subscription's resume position, persisted in
the store, and the `replaying` marker makes whatever it re-reads explicit to
every consumer. It does **not** mean "everything above this was delivered":
an append that committed late can sit below a position that was already
delivered past. Treat the position as *where to start reading again*, and make
every consumer idempotent, and the two properties compose into correctness.
