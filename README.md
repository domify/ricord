# Ricord

Records over SQLite and Turso for ris: one session per block, records in a flat store, writes
in `db.write`. Work in progress; the design is [doc/DESIGN.md](doc/DESIGN.md), and M5 writes
the real introduction and `doc/GUIDE.md`.

Ricord grew out of Grant for ris (the old `Grant::Base` code is at the tag `grant-base-final`),
which was grown from Crystal Grant. Its shape follows Rails' Active Record, and its
one-database-file-per-account model follows 37signals' Campfire.

## Development

* `bin/build-turso` builds libturso for the `turso:` engine (needs Rust; see
  [vendor/turso.md](vendor/turso.md)).
* `bin/test` runs the checks on SQLite; `RICORD_ENGINE=turso bin/test` on Turso.
* The compiler is pinned in `.ris-version`.
