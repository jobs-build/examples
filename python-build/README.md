# `python-build` — building a pure-Python app with JOBS + UV

A worked example of the **uv-build plugin**: a tiny CLI + HTTP "hello world"
(`src/myapp/__main__.py`, `GET /` → "hello world") built **fully offline** by
JOBS on a relocatable **musl** Python. Flags use **click**, logging uses
**rich**, so it exercises **multi-package** wheel fetching (rich pulls
markdown-it-py + pygments + mdurl).

## What's here

```
python-build/
├── README.md
├── BUILD.jobs     ← plugins() declares the uv plugin; build() fetches uv + Python + wheels and installs offline
├── pyproject.toml ← click + rich; hatchling build-system (used only by `uv lock`, not by the JOBS build)
├── uv.lock        ← the resolved, pinned wheel set the plugin reads
└── src/myapp/     ← click CLI (--addr/--log-level); stdlib http.server; rich logging
```

## How it works

1. **`plugins()`** declares a `uvplugin` plugin (a static, CGO-free Go binary).
2. **`build()`**:
   - fetches the **UV** static-musl binary and a relocatable **musl** CPython
     (`python-build-standalone`, `install_only`) via `tarball+https`, both sha256-pinned;
   - fetches the **musl loader** via `hostmusl` (the interpreter is musl-dynamic);
   - calls the plugin with `uv.lock`; the plugin emits one **`pypi`** import per
     `py3-none-any` dependency (downloaded, sha256-verified into a wheelhouse);
   - stages UV + the interpreter into `/build`, builds the wheelhouse, and runs
     `uv pip install --no-index --offline --find-links … --target $out/site-packages`
     for the locked deps; copies the pure-Python app onto `site-packages`;
   - writes a launcher `bin/myapp` that invokes the musl loader explicitly on the
     interpreter (so its fixed `/lib/ld-musl` PT_INTERP needs no run-sandbox symlink).

No network and no C/Rust toolchain are used at build time — UV, the interpreter,
and every wheel are pre-fetched content-addressed inputs.

## Run it

```bash
scripts/dev-setup.sh                    # registers pypi / uvplugin (+ reuses tarball+https / hostmusl / shell)
jb run --source python-build   # builds (offline) AND runs the server on :8080
# in another terminal:
curl http://127.0.0.1:8080/             # → hello world
```

`jb run` appends trailing args to the entrypoint, so click flags work —
e.g. `jb run --source python-build -- --addr 0.0.0.0:9090 --log-level debug`.
To debug the build instead of running it, use `jb develop --source python-build`.

## Notes

- **musl**, not glibc: reuses the `hostmusl` loader and fits the repo's static
  userland. The interpreter + loader are declared **`runtime_deps`** so
  `jobs run`/`jobs image` resolve them from the materialized closure.
- **Pure-Python only (slice 0):** every dependency must ship a `py3-none-any`
  wheel. A native/Rust extension dep is a documented hard error — building wheels
  (PyO3/maturin) and per-dependency sub-builds are slices 1 & 2 (see
  `docs/superpowers/specs/2026-06-25-python-uv-build-slice0-design.md`).
- The build **stages** the interpreter + UV into `/build` (sequential copy)
  rather than reading them from the FUSE store, for the same amberfuse-concurrency
  reason as go-build/rust-build.
