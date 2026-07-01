# subbuild — sub-build of a descendant directory

Demonstrates `subbuild(dir)`: a build that declares, as an input, a build of a
**strict descendant** of its own source tree. The motivating real-world shape is
a Python package whose `build()` needs a Rust wheel compiled from a `rust/`
subdirectory; here `sub/` stands in for that wheel build and emits a sentinel
artifact (`value`) that the parent reads via `JOBS_DEPS`.

The sub-build shares the parent's source *content* (resolved by the `build-from`
stage as a `tree` source) and is narrowed to `sub/`. Because `subbuild` only
descends, the dependency graph is acyclic.

Run locally (Linux, after `scripts/dev-setup.sh`):

    ./dev --source subbuild

Design: `docs/superpowers/specs/2026-06-25-subbuild-descendant-inputs-design.md`.
