# libturso

Ricord's `turso:` engine links libturso v0.8.3 (the `turso_sqlite3` C bindings) as a static
library whose C symbols are renamed `sqlite3_*` to `turso_*`, so it links next to libsqlite3
in one binary. `bin/build-turso` makes it:

1. clones tag v0.8.3 into `vendor/turso/src` (ignored by git);
2. `cargo build -p turso_sqlite3 --release` (Rust 1.88 from the checkout's
   `rust-toolchain.toml`; the crate already builds a `staticlib`);
3. writes the rename map from `nm --defined-only` (116 functions and one data symbol);
4. `objcopy --redefine-syms` into `vendor/turso/lib/libturso.a` and checks that no `sqlite3_`
   symbol is left;
5. writes `turso_version` and `turso_commit` to `.ris-version`.

`bin/test` prepends `vendor/turso/lib` to `IYI_LIBRARY_PATH`. The sqlite driver's
`sqlite/turso` module binds it with `@[Link("turso")]` and
`@[Link(ldflags: "-lpthread -ldl -lm")]`, which the Rust standard library needs; the link
line comes out as `-lturso -lpthread -ldl -lm -lsqlite3`.

Found by M0 probe 11 (`test/probe/turso_driver_test.ri`): libturso reports SQLite 3.50.4;
`RETURNING`, BLOBs, `ROLLBACK TO` after a failed nested write, `foreign_keys` with
`CASCADE`/`RESTRICT`, and REGEXP all match libsqlite3, and libsqlite3 reads a Turso-written
file. `numeric(P,S)` in a `STRICT` table and `BEGIN CONCURRENT` are refused (not used in v1).
