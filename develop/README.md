# `jobs develop` — a worked example

This directory is a self-contained, **offline** demonstration of
[`jobs develop`](https://github.com/draganm/jobs/blob/main/architecture/develop.md): the local command that builds a
target's missing dependencies into your local amber store and then drops you into
an interactive shell inside the target's hermetic build sandbox.

The example deliberately exercises the headline feature — **`develop` building an
imported dependency for you** — while staying fully local (no network, no engine).

## What's here

```
develop/
├── README.md                  ← this recipe
├── myapp/                      ← the "source" you run `jobs develop` against
│   ├── BUILD.jobs              ← build() imports a dependency + a script using it
│   └── message.txt             ← a file the build reads from $SRC
└── greeting-fetcher/
    └── fetch                   ← a trivial fetcher that produces the dependency
```

`myapp/BUILD.jobs`'s `build()` declares one imported input (fetched by `greeting`)
and a script that combines `$SRC/message.txt` with the dependency's
`greeting.txt`. When you run `jobs develop`, it runs the `greeting` fetcher to
produce that import, mounts it read-only, and hands you a shell with `$SRC`,
`$out`, and `$JOBS_DEPS` set up (the dependency's path is `JOBS_DEPS.greeting`).

## Prerequisites

- **Linux** with unprivileged **user namespaces** and **`/dev/fuse`** (the rootless
  build sandbox needs both). `jobs develop` is Linux-only.
- **Nix** — the repo's Go toolchain *and* the `amber-store` daemon binary are
  provided by its dev shell, so Go commands run as `nix develop -c go …` (`go` is
  not otherwise on `PATH`). amber-store is a normal pinned `go.mod` dependency, so
  no sibling checkout is needed.

`jobs develop` talks only to a **local amber daemon**; it never contacts a JOBS
engine. The shell artifact and the fetcher are operator-published prerequisites
(steps 4–5 below) — `develop` auto-builds imports and builds, but not those.

## Quick start (scripted)

To skip the manual steps below, run the prep script from the repo root — it
ensures the amber daemon, a signing key, the `shell:` artifact, and the example
`greeting` fetcher (all idempotent, state in a gitignored `.jobsdev/`), then
writes a `./dev` wrapper:

```bash
scripts/dev-setup.sh
./dev --source develop/myapp     # drops you into the dev shell
```

`scripts/dev-setup.sh clean` stops the daemon and removes `.jobsdev/` + `./dev`.
The rest of this page is the manual version, for understanding what that does.

## The recipe

Run everything from the repository root. A scratch directory holds the binaries,
the daemon's store, and the keys:

```bash
export WORK=/tmp/jobs-develop-demo
mkdir -p "$WORK"
```

**1. Build the `jobs` CLI** (the `amber-store` daemon binary comes from the nix
dev shell's `PATH`):

```bash
nix develop -c go build -o "$WORK/jobs" ./cmd/jobs
```

**2. Start a local amber daemon.** Run it in its own terminal, or background it as
here (run inside `nix develop` so `amber-store` is on `PATH`):

```bash
amber-store daemon --store "$WORK/store" --socket "$WORK/amber.sock" --log-level error &
```

**3. Make an operator signing key.** Any passwordless ed25519 key works — it signs
the `shell:` and `fetcher:` refs you publish below. (`jobs develop` itself signs
its dependency outputs with a throwaway key by default; the local daemon does no
key authorization.)

```bash
ssh-keygen -t ed25519 -f "$WORK/op-key" -N "" -q
```

**4. Vendor the host shell and publish it as `shell:<platform>`.** The build sandbox
runs the recipe script under this vendored bash + coreutils:

```bash
mkdir -p "$WORK/shell"
nix develop -c bash -c "JOBS_OUTPUT_DIR='$WORK/shell' ./fetchers/hostshell/fetch"
"$WORK/jobs" register-shell --amber-socket "$WORK/amber.sock" --signing-key "$WORK/op-key" --dir "$WORK/shell"
# → shell:linux/amd64 -> <key>
```

**5. Publish the example's `greeting` fetcher** (the dependency `myapp` imports):

```bash
"$WORK/jobs" register-fetcher --amber-socket "$WORK/amber.sock" --signing-key "$WORK/op-key" \
    --name greeting --dir develop/greeting-fetcher
# → fetcher:greeting:linux/amd64 -> <key>
```

**6. Develop.** This ingests `myapp`, evaluates `build()`, runs the `greeting`
fetcher to build the imported dependency, assembles the build sandbox, prints the
script, and drops you into an interactive shell:

```bash
"$WORK/jobs" develop --amber-socket "$WORK/amber.sock" --cache-dir "$WORK/cache" \
    --source develop/myapp
```

## What you'll see

`develop` prints a summary and the build script, then gives you a prompt:

```
=== jobs develop ===
SRC=/build/src  out=/build/out
deps (JOBS_DEPS — name → /jobs/store/<BOK>, read-only):
  greeting=/jobs/store/2070d6cca4e8…
--- build script (runner would execute; saved at /build/build.sh) ---
    GREETING="$(jq -r .greeting <<<"$JOBS_DEPS")"
    cat "$SRC/message.txt" "$GREETING/greeting.txt" > "$out/combined.txt"
----------------------------------------------------------------------
jobs develop: $SRC is the source copy, $out is the (empty) output dir.
The runner build script is printed above and saved at /build/build.sh (run: bash -e /build/build.sh).
(jobs develop) / #
```

Each dependency is mounted at its **content-addressed** path `/jobs/store/<BOK>`
(BOK = the artifact's content key), and the recipe resolves names → paths from the
`JOBS_DEPS` JSON env var (here with `jq`, which the vendored shell provides).

At that prompt, poke around the exact environment the build would run in:

```bash
cat "$SRC/message.txt"                              # hello from the local source   (your local dir, copied in)
cat "$(jq -r .greeting <<<"$JOBS_DEPS")/greeting.txt"  # greetings from the imported dependency! (develop built this import)
bash -e /build/build.sh                            # run the real build script by hand
cat "$out/combined.txt"                            # → both lines, the build's output
exit                                               # leave; the sandbox + work tree are torn down
```

`$SRC` is a throwaway **copy** of your source (edits are discarded on exit), exactly
as the real build sees it. `$GREETING` points at the dependency `develop` imported
for you — proof it walked the build's graph and ran the fetcher.

The first run builds the dependency; thanks to incremental skipping, a second
`jobs develop` reuses `import-output:K` from the store and reaches the shell
immediately.

## How it works (short version)

`jobs develop` is a local, depth-first stand-in for engine + runner that ends in a
shell instead of building the target:

1. It ingests `--source` into amber (a faithful, content-addressed source tree).
2. It evaluates `BUILD.jobs` and, for every dependency the recipe needs, runs the
   **real** runner stage drivers (`RunImport` here; `RunPluginResolve`/`RunPin`/
   `RunBuild` for build dependencies) to make it present — recursively, skipping
   anything already built.
3. It reproduces the target's hermetic build sandbox (same FUSE-mounted inputs,
   `$SRC`/`$out`, env, cgroup) and runs an interactive `bash` in it — adding a
   develop-only host `/dev` bind for job control — instead of the build script.

See [architecture/develop.md](https://github.com/draganm/jobs/blob/main/architecture/develop.md) for the full design.

## Cleanup

```bash
kill %1 2>/dev/null            # stop the backgrounded daemon (or Ctrl-C its terminal)
rm -rf "$WORK"                 # remove the scratch store, binaries, and keys
```

## Notes & variations

- **No dependencies at all?** Delete the `greeting` import from `myapp/BUILD.jobs`
  (return `inputs = {}` and a script that only uses `$SRC`/`$out`). Then you can skip
  step 5 — `develop` needs only the daemon and the shell artifact.
- **Plugins** (`go2nix`-style helpers a recipe calls during evaluation) are built
  the same way: declare them in a `plugins()` function and register their fetcher;
  `develop` builds and calls them hermetically before evaluating `build()`.
- **A real identity:** pass `--signing-key <path>` (and `--user`) to attribute the
  dependency outputs `develop` builds to a real key instead of the default ephemeral
  one — useful if you want them to survive a later remote-sync.
