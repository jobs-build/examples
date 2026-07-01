# `python-rust-sdist-build` — building a Rust-extension dependency from its sdist, offline

A worked example of **per-dependency sub-builds for Rust extensions**: a third-party **Rust
(maturin/PyO3) extension** that ships **only an sdist** (no prebuilt wheel) is fetched and
**built from source, offline**, in its own content-addressed sub-build, then installed alongside
other deps. Demonstrates JOBS's compositional model — *each dependency is its own build* — and
proves that the **same uniform recipe** (GENERIC) can build both pure-Python sdists (Slice 2b-i)
and Rust extensions (Slice 2b-ii).

## How it works

1. `uvplugin` reads `uv.lock` and, per dependency, emits **`kind:wheel`** (a prebuilt wheel) or
   **`kind:sdist`** (no wheel available). For `nh3` (a Rust HTML sanitizer), it emits `sdist`.
2. For an `sdist` dep, `build()` makes a `bld(source=imp(sdist), buildJobs=…)` **sub-build**.
3. That sub-build's recipe uses **`pybackendplugin`** — it reads the sdist's `pyproject.toml
   [build-system]`, resolves the declared backend (`maturin`) from a **curated build-system
   wheelhouse**, and supplies it offline.
4. If the sdist's source has a `Cargo.lock`, the recipe conditionally stages the **musl Rust
   toolchain** (1.96.0), vendors all crates via **`cargoplugin`** into `/build/vendor`, writes
   **`.cargo/config.toml`** (vendor source replacement + rust-lld linker flags + musl rustflags),
   and exports `CARGO_NET_OFFLINE=true` + Python environment variables.
5. Then **`uv build --wheel --no-build-isolation --offline`** invokes the maturin PEP-517 backend,
   which runs `cargo --offline` against the vendored crates to produce an **abi3 wheel** (no
   libpython link — compatible across Python patch versions).
6. The built wheel flows into the app's wheelhouse and is installed like any other dep.

No network and no C compiler at build time. (This is **Slice 2b-ii** — Rust-extension sdists; see
`docs/superpowers/specs/2026-06-26-python-rust-sdist-build-slice2b-ii-design.md`.)

## What's here

```
python-rust-sdist-build/
├── README.md
├── BUILD.jobs     ← plugins() declares uv + cargo plugins; build() routes wheel vs sdist deps to the
│                    wheelhouse or sub-builds; GENERIC recipe builds Rust sdists via pybackendplugin +
│                    conditional cargo vendoring
├── pyproject.toml ← click + rich + nh3 (sdist-only Rust extension)
├── uv.lock        ← the resolved, pinned dependency set including nh3 0.3.6 (sdist, no prebuilt wheel)
└── src/myapp/     ← click CLI; stdlib http.server; imports nh3 to prove the Rust extension built + loaded
```

The **sdist-only dep** is **`nh3` 0.3.6** — an HTML sanitizer wrapping the Rust `ammonia` crate.
Its sdist includes a `pyproject.toml` with `build-backend = "maturin"` and a `Cargo.lock` pinning
all ~90 Rust crates. The sub-build recipe:
- Calls `pybackendplugin` → resolves maturin from the curated set
- Stages maturin offline
- Because `Cargo.lock` exists: stages the musl Rust 1.96.0 toolchain, vendors crates
- Writes `.cargo/config.toml` (source replacement for vendored crates, rust-lld, musl linker flags)
- Exports `CARGO_NET_OFFLINE=true`, `PYO3_PYTHON`, `LIBRARY_PATH`
- Runs `uv build --wheel --no-build-isolation --offline --python /build/python/bin/python3`
- maturin backend invokes `cargo --offline`, links against musl libc, produces an abi3 wheel

## Run it

```bash
scripts/dev-setup.sh                         # registers uvplugin, cargoplugin, pybackendplugin
jb run --source python-rust-sdist-build # builds (offline, Rust toolchain vendored) AND runs
# in another terminal:
curl http://127.0.0.1:8080/                 # → hello world (nh3 ok)
```

`jb run` appends trailing args to the entrypoint, so click flags work —
e.g. `jb run --source python-rust-sdist-build -- --addr 0.0.0.0:9090 --log-level debug`.
To debug the build instead of running it, use `jb develop --source python-rust-sdist-build`.

## Notes

- **musl**, not glibc: reuses the `hostmusl` loader and fits the repo's static userland. The
  interpreter and musl loader are declared **`runtime_deps`** so `jobs run`/`jobs image` resolve
  them from the materialized closure. The Rust toolchain is a **build-time input only** (of the nh3
  sub-build) — the built abi3 `.so` links musl, not Rust, at runtime.
- **Rust-extension sdists (slice 2b-ii)**: each dependency must ship a `Cargo.lock` (offline
  resolution) and a `pyproject.toml` naming `build-backend = "maturin"`. Pure-Python sdists use the
  same GENERIC recipe without the Rust block (Slice 2b-i; see `python-sdist-build`). C
  extensions or non-abi3 wheels are out of scope.
- **Uniform recipe via PEP-517 frontend**: unlike Slice 1's direct `maturin build --offline` call
  (`python-rust-build`), the GENERIC recipe uses `uv build` (PEP-517) and treats maturin as
  just another curated backend wheel, identical to the pure-Python path. This keeps the build
  invocation uniform and the recipe a single branch-safe template across all sdists.
- The recipe stages the interpreter + UV + Rust toolchain into `/build` (sequential copy) rather
  than reading them from the FUSE store, for the same amberfuse-concurrency reason as go-build
  examples.
- The sub-build recipe (GENERIC) is inline Starlark; quoting paths via `jq -r` inside triple-quoted
  strings avoids heredoc nesting collisions. The maturin backend is populated by `pybackendplugin`
  at resolve time. Rust crates are vendored by `cargoplugin` from the sdist's `Cargo.lock`.
- The app's `__main__.py` calls `nh3.clean(...)`, proving the native extension built, linked, and
  loaded at runtime.
