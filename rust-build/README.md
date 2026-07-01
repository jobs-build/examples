# `rust-build` — building a Rust program with JOBS

A worked example of the **cargo-build plugin**: a tiny `tiny_http` HTTP server
(`src/main.rs`, returns "hello world") built **fully offline and C-toolchain-free**
by JOBS. Flags use **clap (derive)** and logging uses **log + env_logger**, so it
also exercises **proc-macros** and **multi-crate** vendoring.

## What's here

```
rust-build/
├── README.md
├── BUILD.jobs    ← plugins() declares the cargo plugin; build() fetches the toolchain + crates and compiles
├── Cargo.toml    ← tiny_http + clap(derive) + log + env_logger
├── Cargo.lock    ← the resolved, pinned crate set the plugin reads
└── src/main.rs   ← clap CLI (--addr/--log-level); tiny_http server (GET / → "hello world"); env_logger logging
```

## How it works

1. **`plugins()`** declares a `cargoplugin` plugin (a static, CGO-free Go binary).
2. **`build()`**:
   - fetches the **musl** Rust toolchain via `tarball+https` (`rust-1.96.0-<arch>-unknown-linux-musl`,
     pinned by sha256; the recipe selects the URL + hash for the target `platform`,
     so it builds on both `linux/amd64` and `linux/arm64`);
   - fetches the **musl dynamic loader** via `hostmusl` (the toolchain and the
     output binary are dynamically linked against `ld-musl-<arch>.so.1`);
   - calls the plugin with `Cargo.lock`; the plugin emits one **`cargocrate`** import
     per crates.io crate (downloaded, checksum-verified, unpacked into a vendored
     source tree with a `.cargo-checksum.json`);
   - the build script plants the loader at `/lib/ld-musl-<arch>.so.1` for the
     toolchain, stages everything into `/build`, writes a `.cargo/config.toml` with
     source replacement → the vendor dir, and runs `cargo build --frozen` offline.

The output is a **musl-dynamic** binary, linked by Rust's bundled `rust-lld` (no C
compiler). Because `rust-lld` is invoked directly — not through a `cc` driver — the
link args are passed **bare** (`--dynamic-linker=…`, `-rpath`, not `-Wl,`-wrapped).
Its ELF interpreter and RUNPATH point at the loader's content-addressed
`/jobs/store/<BOK>` path, and the `hostmusl` artifact (the loader + `libgcc_s.so.1` +
the `-lc`/`-lgcc_s`/SONAME symlinks) is declared a `runtime_dep`, so `jobs run`/`jobs
image` resolve it from the materialized runtime closure.

## Run it

```bash
scripts/dev-setup.sh                  # registers tarball+https / hostmusl / cargocrate / cargoplugin
jb run --source rust-build   # builds (offline) AND runs the server on :8080
# in another terminal:
curl http://127.0.0.1:8080/           # → hello world
```

`jb run` appends trailing args to the entrypoint, so the clap flags work too —
e.g. `jb run --source rust-build -- --addr 0.0.0.0:9090 --log-level debug`.
To debug the build instead of running it, use `jb develop --source rust-build`.

## Notes

- **Why musl-dynamic, not static?** With a musl host, `host == target`, so a static
  (`+crt-static`) final binary and proc-macros (which need dynamic `dylib`s) collide.
  Building everything dynamic resolves that and keeps proc-macros working; the single
  `ld-musl-<arch>.so.1` loader rides along as a content-addressed runtime dep.
- The build **stages** the toolchain into `/build` (sequential copy) rather than
  reading it from the FUSE store, for the same amberfuse-concurrency reason as
  go-build (see `docs/superpowers/specs/2026-06-24-rust-build-design.md`).
- Crates with C build scripts (`*-sys`, `ring`, …) are out of scope for now — the
  example's dependency tree is deliberately pure-Rust.
