# Ricord

Ricord keeps records of SQLite and Turso databases for ris programs. A session is one block:
it owns one connection and a flat store of the records read through it. Writes run in
`db.write`. Its shape follows Rails' Active Record; its one database file per account follows
37signals' Campfire. Ricord grew out of Grant for ris (the old code is at the tag
`grant-base-final`).

## Installation

Add Ricord and its drivers to your `ris.mod`:

```text
require github.com/domify/ricord v0.0.0 as ricord
require github.com/domify/db v0.3.1 as db
require github.com/domify/sqlite v0.2.0 as sqlite
```

The compiler is pinned in `.ris-version`. The `turso:` engine needs libturso: run
`bin/build-turso` (needs Rust; see [vendor/turso.md](vendor/turso.md)) and set
`IYI_LIBRARY_PATH=vendor/turso/lib`.

## A model and a session

```text
import ricord
import sqlite/sqlite/turso
import ricord/model::{model}

model Team do
  table :teams
  col :title, :string
  has_many :users
end

model User do
  table :users
  col :name, :string
  col :team_id, belongs_to: :team, null: true
  validates :name, presence: true
end

Ricord.open("sqlite3:app.db") do |db|
  team = Team[db].find_by(title: "Core").or_panic
  if team
    team.users.create(name: "Ann").or_panic          # a write, with team_id set
    team.users.order(:name).to_a.or_panic.each { |u| puts u.name }
  end
  db.write do |tx|                                   # one transaction
    User.create(tx, name: "Bob").or_panic
    User.create(tx, name: "Cy").or_panic
  end.or_panic
  puts User[db].where(team_id: nil).count.or_panic
  nil
end.or_panic
```

Every read starts at `Model[db]` or at an association. Every call that can fail returns its
value or an error; `.or_panic` stops the program on one. Records cannot leave the block.

## Read on

* [doc/GUIDE.md](doc/GUIDE.md): the guide, with complete examples.
* [doc/DESIGN.md](doc/DESIGN.md): the design.
* [RICORD_SPEC.md](RICORD_SPEC.md): the contract, by rule number.
* [doc/API_CHANGES.md](doc/API_CHANGES.md): moving from Grant.
* [examples/tape_web](examples/tape_web): a users resource on the `web` package.

## Development

* `bin/test` runs the checks on SQLite; `RICORD_ENGINE=turso bin/test` on Turso.
* `bin/build-turso` builds libturso.
