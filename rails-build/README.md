# rails-build — a Ruby on Rails 8 app built hermetically by JOBS

This example builds a real **Rails 8** application fully **offline** (`net=none`)
in the JOBS hermetic sandbox, with **no `/nix` and no glibc**. It exercises the
two hard things a Rails build needs:

- **Compiling C in a gem.** `bcrypt`'s C extension (and `json`/`puma`/`bootsnap`/
  `msgpack`) is compiled *from source inside the sandbox* by **`zig cc`** — JOBS's
  first in-sandbox C compiler. The build boots Rails in `production`, migrates
  SQLite, and verifies `User.has_secure_password`, which loads the freshly
  compiled `bcrypt` `.so`.
- **Depending on Node.** `assets:precompile` runs `jsbundling-rails` → `yarn build`
  → **esbuild**, driven by a **musl Node**, with `yarn install` served entirely
  from a pre-fetched offline mirror. Propshaft digests the result into
  `public/assets`.

## How it works

There is no relocatable musl Ruby distribution (à la `python-build-standalone`),
so the toolchain is **assembled from Alpine `apk` packages** — a musl Ruby
(`ruby` + `ruby-libs` + `ruby-dev` + its `.so` closure) staged into the sandbox
root so Ruby runs natively at its `/usr` prefix — and gems are compiled with
**`zig`** (a single relocatable tarball whose `zig cc` targets `x86_64-linux-musl`).
Alpine supplies the interpreter, headers, and runtime libraries; zig supplies the
compiler; we never build Ruby or OpenSSL ourselves and never need Alpine's
(non-relocatable) gcc.

`BUILD.jobs` declares two build plugins — `bundlerplugin` (turns `Gemfile.lock`
into per-gem `rubygems` imports, pinned by the lockfile `CHECKSUMS` sha256) and
`nodeplugin` (turns `yarn.lock` into `npm` imports, pinned by SRI) — plus the
toolchain imports (`alpineapk`, `tarballxz` for zig, `tarball+https` for Node +
Yarn). Every input is content-addressed; the build itself touches no network.

## Build it & run it

```bash
scripts/dev-setup.sh                       # one-time: local amber daemon + signing key
jb run --source rails-build       # build offline, then serve on :3000
# or: jb develop --source rails-build   # drop into the build sandbox
```

`jb run` builds the app entirely from the committed `fetchers.toml` manifest
(provisioning the alpineapk/tarballxz/rubygems/npm/bundler/node fetchers from the
`jobs-build/*` repos on first use — cached afterwards), boots Rails to migrate
SQLite + verify `has_secure_password`, precompiles assets, then **runs puma**:

```
$ curl http://localhost:3000/
rails-build OK — Rails 8.1.3, users=1, bcrypt-cost=12
```

That one line proves the whole stack at runtime: Rails boots, ActiveRecord reads
SQLite, and the zig-compiled `bcrypt` C extension loads. The artifact also carries
the digested `public/assets` (including the esbuild-bundled `application-<hash>.js`).

## Regenerating the committed lockfiles (one-time, online)

`Gemfile.lock` and `yarn.lock` are committed so the build is offline and
deterministic. To regenerate them on a connected machine (any Ruby/Node works —
the lockfiles are platform data + checksums):

```bash
# Gemfile.lock — musl-only, with checksums (content addresses for the gem fetches)
bundle config set --local lockfile_checksums true
bundle lock
for p in aarch64-linux aarch64-linux-gnu aarch64-linux-musl arm-linux-gnu \
         arm-linux-musl arm64-darwin x86_64-darwin x86_64-linux-gnu x86_64-linux java; do
  bundle lock --remove-platform "$p" || true
done
bundle lock --add-platform x86_64-linux-musl

# yarn.lock — generate, then prune to esbuild + @esbuild/linux-x64 (the musl x64
# target) so the build fetches only the binary it actually uses.
yarn install
```

## Notes / pins

- Alpine **v3.22** (Ruby **3.4.4**, gcc **14.2.0**); zig **0.16.0**; Node
  **v22.23.1** (musl, from nodejs unofficial-builds) + Alpine `libstdc++`.
- `json` is pinned to **2.9.1**: json ≥ 2.10 uses `__builtin_cpu_supports`
  (`__cpu_model`), which zig's linker rejects in a shared object.
- `tzdata` is mounted for TZInfo; `config/database.yml`'s production path is set;
  the app boots with `SECRET_KEY_BASE_DUMMY=1` (no credentials/`master.key`).
- **x86_64 only** for now; arm64 needs the aarch64 toolchain pins (and arm64 musl
  Node statically links libstdc++, so it needs no separate `libstdc++` apk).
