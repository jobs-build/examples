# `go-build` — building a Go program with JOBS

A worked example of the **go-build plugin**: a tiny HTTP server (`main.go`,
returns "hello world") built **fully offline and CGO-free** by JOBS. It uses
**gorilla/mux** for routing, **urfave/cli/v2** for flags, and **slog** for
structured logging — so it also exercises **multi-module** fetching (urfave/cli/v2
pulls in go-md2man, blackfriday, smetrics).

## What's here

```
go-build/
├── README.md
├── BUILD.jobs    ← plugins() declares the go plugin; build() fetches the toolchain + modules and compiles
├── go.mod        ← requires gorilla/mux + urfave/cli/v2
├── go.sum
└── main.go       ← urfave/cli app; mux router (GET / → "hello world"); slog request logging
```

## How it works

1. **`plugins()`** declares a `goplugin` plugin (a static, CGO-free Go binary that
   runs in the hermetic plugin sandbox).
2. **`build()`**:
   - fetches the Go toolchain via the **`tarball+https`** fetcher
     (`go1.26.4.linux-<goarch>`, pinned by sha256; the recipe selects the URL +
     hash for the target `platform`, so it builds on both `linux/amd64` and
     `linux/arm64`);
   - calls the plugin with `go.sum`; the plugin emits one **`gomod`** import per
     module (here: gorilla/mux + urfave/cli/v2 and its deps — several modules);
   - the engine/develop driver fetches each module into a `cache/download` tree;
   - the build script stages the toolchain + module cache into the writable build
     tree and runs `go build` with `GOPROXY=off GOSUMDB=off CGO_ENABLED=0` →
     `$out/bin/app`.

No network and no GCC are used at build time — the toolchain and every module are
pre-fetched content-addressed inputs.

## Run it

```bash
scripts/dev-setup.sh                 # registers tarball+https / gomod / goplugin (+ the daemon, shell)
./run --source go-build     # builds (offline) AND runs $out/bin/app → HTTP server on :8080
                                     # (slog request logs print to the terminal)
# in another terminal:
curl http://127.0.0.1:8080/          # → hello world
# Ctrl-C to stop the server.
```

The build writes a `JOBS.entrypoint` (`{"command":"bin/app"}`); `jobs run` reads it and
executes the static binary in a run sandbox (the toolchain/modules are build-time only).
`jobs run` appends trailing args to the entrypoint, so the urfave/cli flags work too —
e.g. `./run --source go-build -- --addr :9090 --log-level debug`.
To debug the build instead of running it, use `./dev --source go-build`.

## Notes

- The plugin enumerates modules from `go.sum`'s `h1:` (zip) lines — the standard
  "what to fetch" set.
- The build **stages** GOROOT + the module cache into `/build` (a sequential copy)
  rather than reading them directly from the FUSE store; see the design doc
  (`docs/superpowers/specs/2026-06-23-go-build-plugin-design.md`) for why.
- CGO is disabled, so cgo-requiring modules are out of scope for now.
