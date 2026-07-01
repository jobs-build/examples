# `python-rust-build` — a PyO3 Rust wheel built offline with maturin + UV

A worked example uniting the **Rust** (cargo) and **Python/UV** toolchains: a click + rich
CLI/HTTP "hello world" whose response is **computed by a PyO3 Rust extension**
(`src/lib.rs`'s `greeting()`), built **fully offline** by JOBS. maturin compiles the native
**abi3** wheel; UV installs it next to the pure-Python deps. A successful `curl` proves the
wheel built **and** the `.so` loaded + ran in the sandbox.

## What's here

```
python-rust-build/
├── BUILD.jobs       ← plugins(): cargo + uv ; build(): maturin build --offline + uv install
├── pyproject.toml   ← [build-system] maturin ; [tool.maturin] python-source/module-name ; deps click+rich
├── Cargo.toml / Cargo.lock  ← pyo3 (extension-module, abi3-py312) + deps
├── uv.lock          ← click + rich + transitive (pure-Python universal wheels)
├── src/lib.rs       ← PyO3 module `myapp._native` exposing greeting()
└── python/myapp/    ← __init__ re-exports greeting ; __main__ = click CLI + HTTP server (response via _native)
```

## How it works

1. **`plugins()`** declares **two** plugins: `cargoplugin` (Cargo.lock → crate fetches) and
   `uvplugin` (uv.lock → wheel fetches).
2. **`build()`** fetches the musl Rust toolchain, a musl **maturin** binary, the musl CPython,
   and uv (all `tarball+https`, sha256-pinned) plus the `hostmusl` loader; vendors the crates
   and wheels; writes rust-build's offline `.cargo/config.toml` (vendor source-replacement +
   `rust-lld` musl linker); runs **`maturin build --release --offline`** to compile the abi3
   wheel; then **`uv pip install --no-index --offline`** installs the built wheel + its
   click/rich deps into `$out/site-packages`. A musl-loader launcher (`bin/myapp`) runs it.

No network and no C compiler at build time — the Rust toolchain, maturin, the interpreter, the
crates, and the wheels are all pre-fetched content-addressed inputs; the extension links via
Rust's bundled `rust-lld`.

## Run it

```bash
scripts/dev-setup.sh                          # all fetchers/plugins already registered (idempotent)
jb run --source python-rust-build    # builds (offline) AND runs the server on :8080
# in another terminal:
curl http://127.0.0.1:8080/                   # → hello world  (built by the Rust extension)
```

`jb run` appends trailing args, so `-- --addr 0.0.0.0:9090 --log-level debug` works. Debug the
build with `jb develop --source python-rust-build`.

## Notes

- **abi3** (`abi3-py312`): one wheel works across Python ≥ 3.12; the `.so` resolves Python
  symbols via the interpreter at import (no `libpython` link) and links `libgcc_s` (covered by
  `hostmusl`), so `runtime_deps = [python, musl]` — no extra runtime dep.
- **musl** throughout; reuses rust-build's toolchain pin + Slice 0's CPython/uv pins.
- This is **Slice 1** of the Python+UV effort: it builds the project's OWN Rust wheel.
  Per-dependency sub-builds (building third-party Rust wheels) are Slice 2 — see
  `docs/superpowers/specs/2026-06-25-python-rust-build-slice1-design.md`.
