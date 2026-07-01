// Entry point for the esbuild bundle. JOBS bundles this offline at
// assets:precompile time with esbuild, driven by a musl Node — the "depends on
// Node" half of the example. Kept import-free so the only npm dependency is
// esbuild itself.
console.log("rails-build: esbuild-bundled JavaScript loaded");
