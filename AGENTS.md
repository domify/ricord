# Ricord for ris

Do not pollute commit messages with co authored by Agents.

Wrap documentation lines at 100 characters maximum.

* The design is `doc/DESIGN.md`; work follows its milestones (M0-M5). Read `doc/NAMING.md`.
* SQLite and Turso are supported, chosen per URI: `sqlite3:` and `turso:` (the sqlite driver's
  `sqlite/turso` module). One program may use both. PostgreSQL is out of scope.
* No `_strict` methods and no `!` in method names: one method per action, with failures
  returned as error values, not raised.
* The compiler is pinned in `.ris-version` (`ris_path`, `ris_commit`); never use
  `~/contribute/ris`. `bin/test` reads it. libturso comes from `bin/build-turso`.
* Old `Grant::Base` scenarios are ported per `doc/TEST_PORT.md`; the old code is at the tag
  `grant-base-final`.
* Format with `ris fmt`, check with `ris check` (CI runs `ris fmt --check`).
* Long builds and test runs go to minitest.
* No attribution trailers in commits. `crystal-upstream/` is reference only; never edit it.
