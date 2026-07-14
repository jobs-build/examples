# JOBS examples

Worked example projects for [JOBS](https://github.com/draganm/jobs), a
Nix/Bazel-inspired distributed build system built on content-addressing and
hermetic, reproducible builds. Each directory is a self-contained project with
a `BUILD.jobs` Starlark recipe that builds **fully offline** inside the JOBS
sandbox — no network, no host toolchain; every input (compiler, modules,
wheels, gems, apks, …) is a pinned, content-addressed import.

Extracted from the JOBS repo (`draganm/jobs` @ `8b51f91`); the fetchers and
plugins the recipes name are pinned in the JOBS repo's `fetchers.toml` and
built from the other `jobs-build/*` repos.

## The examples

| Example | What it shows |
|---|---|
| [`develop/`](develop/) | `jobs develop` — the interactive hermetic dev shell (`myapp` + the demo `greeting` fetcher) |
| [`go-build/`](go-build/) | A Go HTTP server: `goplugin` turns `go.sum` into `gomod` imports; offline, CGO-free `go build` |
| [`rust-build/`](rust-build/) | A Rust server: `cargoplugin` + `cargocrate`, musl toolchain, GCC-free linking via bundled `rust-lld` |
| [`python-build/`](python-build/) | A Python app: `uvplugin` turns `uv.lock` into `pypi` wheel imports on a musl CPython |
| [`python-rust-build/`](python-rust-build/) | A PyO3 abi3 extension wheel built with maturin, then installed with UV — two plugins in one recipe |
| [`python-sdist-build/`](python-sdist-build/) | A pure-Python dependency built **from its sdist** as a sub-build (PEP-517 via `pybackendplugin`) |
| [`python-rust-sdist-build/`](python-rust-sdist-build/) | A third-party Rust extension (`nh3`, ~90 crates) built from its sdist with maturin as a curated PEP-517 backend |
| [`rails-build/`](rails-build/) | A Rails 8 app: bundler + node/esbuild assets, bcrypt's C extension compiled in-sandbox with `zig cc` |
| [`phoenix-build/`](phoenix-build/) | A Phoenix 1.8 + LiveView app: `mixplugin` turns `mix.lock` into `hexpm` imports, exqlite's SQLite NIF compiled with `zig cc`, offline Tailwind/esbuild assets, `mix release` output |
| [`subbuild/`](subbuild/) | `subbuild()` — a build input that is a build of a descendant directory |

All recipes are platform-parameterized and build on `linux/amd64` and
`linux/arm64`.

## Building them

**Locally** (Linux, from a JOBS repo checkout after `scripts/dev-setup.sh`):

```bash
jb run --source ../examples/go-build          # build offline, then run it
jb develop --source ../examples/rust-build    # drop into the hermetic build sandbox
```

**Against a JOBS engine** — submit a build whose source is this repo:

```bash
jobs submit-build \
  --source-fetcher github \
  --source-param owner=jobs-build --source-param repo=examples --source-param ref=<commit-sha> \
  --dir go-build --platform linux/amd64
```

Use a commit SHA as `ref` (a branch name caches as one import and won't
re-fetch). The former `jobs-build/` self-build showcase moved into the JOBS
repo itself (root `BUILD.jobs` — build a checkout with
`jobs remote-build --source-dir . --param cmd=<binary>`).

References to `architecture/*.md`, `docs/superpowers/*`, and
`scripts/dev-setup.sh` in the per-example READMEs point into the JOBS repo.
