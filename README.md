# mcl-bookclub

**A book club kept as a reckon-db event store, with projections into sqlite,
on the macula mesh through mcl_om. The teaching service.**

This repository is the worked example for building a `macula-services/mcl-*`
service on [reckon-db](https://github.com/reckon-db-org/reckon-db) +
[evoq](https://github.com/reckon-db-org/evoq), following the house rules:
CMD / PRJ / QRY divisions, business-verb event names, bit-flag statuses,
idempotent projections, and a mesh facade that stays out of the domain code.
Read it end to end; every convention it follows is explained where it is used,
and every rule that protects a decision is a test.

## The divisions

| App | Division | Responsibility |
|---|---|---|
| `apps/mcl_bookclub` | the facade | the `mcl_om_service` contract: identity, `/health`, capabilities, and the store wiring. The only app that touches the mesh. |
| `apps/host_bookclub` | CMD | commands, events, aggregates, policies. Depends on evoq and reckon, nothing else. |
| `apps/project_bookclub` | PRJ | events → sqlite. One projection module per event, idempotent by construction. |
| `apps/query_bookclub` | QRY | sqlite → answers. Pure query modules; no evoq, no mesh. |

A command dispatched in CMD lands as an event in the store; the `$all`
subscription delivers it to the PRJ projections, which write the sqlite read
model; QRY answers questions from it. The facade advertises QRY's answers as
mesh capabilities — that wiring is the only place the mesh meets the domain.

## Status: walking skeleton

The first vertical slice is complete end to end:

    initiate_bookclub_v1 ──▶ bookclub_aggregate ──▶ bookclub_initiated_v1
        (CMD dispatch)                               ──▶ bookclub_initiated_v1_to_sqlite_clubs
                                                          ──▶ get_bookclub_by_id (QRY)

Everything a new slice adds — `archive_bookclub`, `register_member`,
`procure_book`, `retire_book`, `start_reading`, `finish_reading`, the
`plan_party` policy, and the mesh emitters — follows the shape this slice
established. The service announces no capability yet, deliberately: a
capability is advertised only when the thing it names exists and answers.

## Reading order

1. [`guides/event_delivery.md`](guides/event_delivery.md) — what the `$all`
   subscription guarantees, and what projections must do for themselves.
2. `apps/host_bookclub/` — the write side: command → aggregate → event.
3. `apps/project_bookclub/` — the read side: event → sqlite, idempotently.
4. `apps/query_bookclub/` — the answers, and the division-boundary test.
5. `apps/mcl_bookclub/` — the mesh facade and the service-contract tests.

## Running it

    rebar3 compile
    rebar3 eunit
    rebar3 lint
    rebar3 dialyzer

    scripts/health.sh                      # against a running node

The runtime is pinned to OTP 28.4.3 in `.tool-versions`, the `Containerfile`
and the lint workflow — the service-contract suite refuses anything else, so
`mise x erlang@28.4.3 -- rebar3 eunit` if your shell is on another release.

Building the image needs a Rust toolchain, because macula ships a QUIC NIF and
the alpine build compiles it from source rather than fetching one linked
against a different libc.

    podman build -t mcl-bookclub -f Containerfile .

## Configuration

`config/sys.config.src` carries everything the node refuses to boot without:
the realm and its trust anchor, the PQ crypto profile, and the evoq adapter
block that names `mcl_bookclub_store`. `deploy/docker-compose.yml` is runnable
as-is; set `MCL_REALM`, `MCL_REALM_KEY`, `MACULA_STATION_SEEDS` and
`MACULA_STATION_NODE_IDS` and it dials out to a station and answers `/health`.
