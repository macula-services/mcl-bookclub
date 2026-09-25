# Changelog

All notable changes to this project are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and
this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- The readable status strings now live with their flags: each aggregate's
  `{aggregate}_status` module owns a flag map and `to_string/1` (rendered
  through `evoq_bit_flags:to_string/2`), and the projections take each
  status string from there instead of spelling SQL literals -- Demon 68
  in the corpus. The PRJ boundary test now refuses a quoted status literal
  in any projection source, and `project_bookclub` deliberately does NOT
  declare the CMD app as an application dependency: reading a flag map is
  a pure call (a loaded module, not a booted app -- declaring the dep
  boots the mesh emitters into the projection test env and stalls the
  `$all` delivery).

### Added

- The LAN admin UI: a task-based operator console (static page + JSON API)
  on `MCL_ADMIN_PORT` (8488), served by the facade through cowboy. Every
  task is one POST to the desk's own `{command}_api` entry point -- the
  corpus's HOPE-side command entry point, pure and mesh-free -- and every
  lookup is a GET against the QRY division. The aggregate's guards are the
  last word whatever the UI sends.
- The mesh face: three emitters (`emit_member_registered_v1_to_mesh`,
  `emit_book_procured_v1_to_mesh`, `emit_book_retired_v1_to_mesh`) translate
  domain events into facts on `<realm>/mcl-bookclub/bookclub/...` through
  `mcl_bookclub_facts`, with `replay_policy() -> skip` and evoq-retried
  publishes; the first mesh capability, `mcl-bookclub/get_bookclub_by_id`,
  answers from the read model through `mcl_bookclub_get_bookclub_by_id`; the
  identity spec now names the procedure and the three fact topics.
- The full domain: `start_reading_v1`/`finish_reading_v1` (the reading fold,
  self-contained finished event), `procure_book_v1`/`retire_book_v1`,
  `register_member_v1`/`unregister_member_v1`, `plan_party_v1` and the
  `on_member_registered_v1_maybe_plan_party` policy -- each aggregate with a
  blanket lifecycle guard over evoq bit flags, each soft-delete event
  self-contained, each projection an idempotent write carrying the applied
  position.
- `archive_bookclub_v1` soft-deletes a club: the aggregate's blanket lifecycle
  guard refuses every command on an archived stream, the desk refuses a second
  archive and an archive of an unborn club, and `bookclub_archived_v1` is a
  self-contained fact (it echoes the birth details) so its projection stays an
  absolute, idempotent write.
- The walking skeleton: `initiate_bookclub_v1` dispatches to `bookclub_aggregate`
  on its own reckon-db stream, `bookclub_initiated_v1` is projected into a
  sqlite `clubs` table, and `get_bookclub_by_id` answers from it.
- The four-app division shape: `mcl_bookclub` (the mcl_om service facade),
  `host_bookclub` (CMD), `project_bookclub` (PRJ), `query_bookclub` (QRY).
- `guides/event_delivery.md`: what the `$all` subscription guarantees, and what
  projections must do for themselves.
