# `jobs-build` — JOBS builds JOBS

Dogfooding: JOBS compiling its own three production binaries — `jobs`,
`jobs-server`, `jobs-runner` — **fully offline and CGO-free**, over the real
~100-module dependency graph (`amber-store` + its transitive deps,
`cockroachdb/pebble`, `hanwen/go-fuse`, `google/go-containerregistry`,
`go.starlark.net`, …).

This is [`go-build`](../go-build) scaled from a toy program to the real
project. It builds **one** binary per invocation, selected by the `cmd` build
param, so the three binaries are **three separate builds** (distinct `params` →
distinct definition key `K` → independent cache entries) that share **one**
recipe — the recipe runtime has no `load()`, so `params` is how the recipe stays
DRY.

## What's here

```
jobs-build/
├── README.md
└── BUILD.jobs    ← plugins() declares the go plugin; build() reads the repo's
                     root go.sum, fetches the toolchain + every module, and
                     compiles ./cmd/<params.cmd> into $out/bin/<cmd>
```

Unlike `go-build`, there are no `go.mod`/`go.sum`/`*.go` files here: the **source
is the whole repository**, and the recipe reads the repo's own root `go.sum`.

## How it works

1. **`plugins()`** declares the `goplugin` (a static, CGO-free Go binary that runs
   in the hermetic plugin sandbox).
2. **`build()`**:
   - reads `cmd = params["cmd"]` (`jobs` | `jobs-server` | `jobs-runner`);
   - fetches the Go toolchain via **`tarball+https`** (`go1.26.4.linux-<goarch>`,
     pinned by sha256, arch-selected — builds on `linux/amd64` and `linux/arm64`);
   - calls the plugin with the repo's root `go.sum`; the plugin emits one
     **`gomod`** import per module (the full ~100-module jobs graph);
   - stages the toolchain + module cache into the writable `/build` tree (a
     sequential copy — the Go toolchain's high-concurrency stdlib reads are not
     well served by the on-demand FUSE store) and runs
     `go build -o $out/bin/<cmd> ./cmd/<cmd>` with
     `GOPROXY=off GOSUMDB=off CGO_ENABLED=0`;
   - writes `$out/JOBS.entrypoint` (`{"command":"bin/<cmd>"}`).

No network and no GCC are used at build time — the toolchain and every module are
pre-fetched, content-addressed inputs.

## Build it

The source is the **repository root** (the recipe reads the root `go.sum` and
compiles `./cmd/<cmd>`). Point `--source` straight at the working tree — ingest
honors the repo-root **`.amberignore`** (gitignore semantics, see
[import.md](https://github.com/draganm/jobs/blob/main/architecture/import.md) §5 step 6), which excludes `.git/`,
`.jobsdev/`, the built `jobs` binary and the rest of the ~1 GB of junk, so only
the actual source is ingested. **Uncommitted edits are included.**

The recipe lives in *this* repo, but `--build-file` resolves inside the ingested
*source* tree — so copy it into the JOBS checkout first (it's untracked there;
ingest includes uncommitted files). Each `--param cmd=` is its own cached build:

```bash
# from a JOBS repo checkout, with this examples repo cloned as a sibling:
cp ../examples/jobs-build/BUILD.jobs ./BUILD.jobs   # root BUILD.jobs = the default recipe path

# Client — build AND smoke-run it (run appends trailing args to the entrypoint):
jb run   --source . --param cmd=jobs -- --help

# Daemons — build (and package as a loadable OCI image) without running them:
jb image --source . --param cmd=jobs-server -o /tmp/jobs-server.oci.tar
jb image --source . --param cmd=jobs-runner -o /tmp/jobs-runner.oci.tar
```

To debug a build interactively instead, use
`jb develop --source . --param cmd=jobs`. (Remove the copied `BUILD.jobs`
afterwards so it doesn't leak into unrelated ingests.)

> The repo-root [`.amberignore`](https://github.com/draganm/jobs/blob/main/.amberignore) mirrors `.gitignore`'s
> heavy/generated entries plus `.git/` (which gitignore omits implicitly); keep
> the two in sync. It's verified against tracked files, so `--source .` yields
> the same source tree — and the same cached build `F` — as a `git ls-files`
> clean export. (Before `.amberignore` was honored, you had to export a clean
> tree manually with `git ls-files … | tar`.)

## Notes

- **`--param cmd=` is required** — the recipe indexes `params["cmd"]` with no
  default; omitting it is an error (by design, so a build always names its target).
- The plugin enumerates modules from `go.sum`'s `h1:` (zip) lines — the standard
  "what to fetch" set. `amber-store`'s GitHub pseudo-version resolves through
  `gomod` like any other module.
- CGO is disabled; the whole jobs graph builds CGO-free (`go build ./...` needs no
  CGO).
- The three binaries are separate builds, so each runs its own `go build`; they
  share the fetched toolchain + module artifacts (content-addressed) but not the
  Go build cache.

## Deferred: reproducible pinned showcase

A fully reproducible-from-an-empty-store variant (`jobs-build-pinned/`)
that imports the jobs source at a fixed commit via `tarball+https` and sub-builds
it with this recipe is sketched in
[`docs/superpowers/specs/2026-06-30-jobs-self-build-dogfood-design.md`](in the JOBS repo).
