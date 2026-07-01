# `python-sdist-build` — building a dependency from its sdist, offline

A worked example of **per-dependency sub-builds**: a third-party **pure-Python** dependency that
ships **only an sdist** (no wheel) is fetched and **built from source, offline**, in its own
content-addressed sub-build, then installed alongside the wheel-shipping deps. Demonstrates JOBS's
compositional model — *each dependency is its own build*.

## How it works

1. `uvplugin` reads `uv.lock` and, per dependency, emits **`kind:wheel`** (a prebuilt
   `py3-none-any` wheel) or **`kind:sdist`** (no wheel available).
2. For an `sdist` dep, `build()` makes a `bld(source=imp(sdist), buildJobs=…)` **sub-build**.
3. That sub-build's recipe uses **`pybackendplugin`** — it reads the sdist's
   `pyproject.toml [build-system]`, resolves the declared backend against a **curated
   build-system wheelhouse**, and supplies it offline; then `uv build --wheel --no-build-isolation --offline`
   builds the wheel (the build frontend invokes the backend's `build_wheel`).
4. The built wheel flows into the app's wheelhouse and is installed like any other dep.

No network and no compiler at build time. (This is **Slice 2b-i** — pure-Python sdists;
Rust-extension sdists are the deferred 2b-ii. See
`docs/superpowers/specs/2026-06-26-python-sdist-build-slice2b-i-design.md` and the
`docs/superpowers/research/2026-06-26-offline-sdist-rust-wheel-research.md` note.)

## What's here

```
python-sdist-build/
├── README.md
├── BUILD.jobs     ← plugins() declares the uv plugin; build() routes wheel vs sdist deps to the wheelhouse or sub-builds
├── pyproject.toml ← click + rich + docopt (sdist-only)
├── uv.lock        ← the resolved, pinned dependency set including docopt 0.6.2 (sdist)
└── src/myapp/     ← click CLI; stdlib http.server; imports docopt to prove the sdist build worked
```

The **sdist-only dep** is `docopt` 0.6.2 — a legacy `setup.py` package with no wheel on PyPI.
Its sub-build recipe (GENERIC) calls `pybackendplugin` which detects the setuptools+wheel build backend,
stages those wheels offline, then runs `uv build --wheel --no-build-isolation --offline` to produce the wheel.

## Run it

```bash
scripts/dev-setup.sh                       # registers uvplugin, pybackendplugin (+ reuses tarball+https / hostmusl / shell)
jb run --source python-sdist-build # builds (offline) AND runs the server on :8080
# in another terminal:
curl http://127.0.0.1:8080/                 # → hello world (docopt ok)
```

`jb run` appends trailing args to the entrypoint, so click flags work —
e.g. `jb run --source python-sdist-build -- --addr 0.0.0.0:9090 --log-level debug`.
To debug the build instead of running it, use `jb develop --source python-sdist-build`.

## Notes

- **musl**, not glibc: reuses the `hostmusl` loader and fits the repo's static
  userland. The interpreter + loader are declared **`runtime_deps`** so
  `jobs run`/`jobs image` resolve them from the materialized closure.
- **Pure-Python sdists only (slice 2b-i):** each dependency must ship source buildable with
  setuptools + a standard wheel backend (setuptools, flit, etc.). A Rust-extension sdist
  is a documented hard error — building wheels via pybackendplugin for Rust-backed packages
  is slice 2b-ii (deferred; see the research note).
- The build stages the interpreter + UV into `/build` (sequential copy) rather than
  reading them from the FUSE store, for the same amberfuse-concurrency reason as
  go-build/rust-build.
- The sub-build recipe (GENERIC) is inline Starlark; quoting sdist paths via `jq -r` inside
  triple-quoted strings avoids heredoc nesting collisions. The curated build-system wheelhouse
  is populated by `pybackendplugin` at resolve time.
