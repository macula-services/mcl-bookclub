# Changelog

All notable changes to this project are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and
this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

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
