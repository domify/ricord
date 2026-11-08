# Ricord guide

Ricord keeps records of SQLite and Turso databases for ris programs. This guide walks through
the parts in the order a program meets them. Each `ris` example below is a complete test file:
`bin/test` writes each one to `build/guide/<n>_test.ri` and runs it with
`RICORD_DATABASE_URL` set (`sqlite3:<path>` or `turso:<path>`).

The design behind it is [DESIGN.md](DESIGN.md); what changed from Grant is in
[API_CHANGES.md](API_CHANGES.md).

## Opening a database

`Ricord.open(url) do |db| ... end` opens one connection and gives the block a `Session`. The
URL names the engine and the file: `sqlite3:app.db` or `turso:app.db`. The connection closes
when the block ends. `open` returns the block's value, or a `DatabaseError` if the database
cannot be opened.

A model is declared with `model Name do ... end`. `col` declares a column; `id` is added for
you. `Model.create_table(db)` runs the `CREATE TABLE`.

`Model[db]` is the start of every read. It is a query on that session: `where`, `order`,
`limit` and the other query methods chain onto it, and `to_a`, `first`, `find`, `count` and
the like run it.

```ris
import db/db/spec::{describe, it}
import std/env
import std/file
import ricord
import sqlite/sqlite/turso
import ricord/model::{model}
import ricord/failures::{RecordNotFound}

model Court do
  table :courts
  col :name, :string
  col :rank, :integer, null: true
  col :active, :boolean, default: true
end

# The test database from RICORD_DATABASE_URL, removed first.
def fresh_url : String
  url = ENV["RICORD_DATABASE_URL"]? || "sqlite3:/tmp/guide.db"
  skip = url.starts_with?("turso:") ? 6 : 8
  path = url[skip, url.bytesize - skip]
  [path, "#{path}-wal", "#{path}-shm"].each { |p| File.delete(p) if File.exists?(p) }
  url
end

describe "opening" do
  it "opens a database, makes a table and reads it" do
    Ricord.open(fresh_url) do |db|
      Court.create_table(db).or_panic
      Court.create(db, name: "Tartu", rank: 2).or_panic
      Court.create(db, name: "Narva").or_panic

      court = Court[db].find(1).or_panic
      assert court.name == "Tartu"
      assert court.rank == 2_i64
      assert court.active

      assert Court[db].where(rank: nil).count.or_panic == 1_i64
      assert Court[db].where("rank > ?", 1).count.or_panic == 1_i64
      assert Court[db].order(:name).to_a.or_panic.map(&.name) == ["Narva", "Tartu"]
      assert Court[db].find_by(name: "Pärnu").or_panic.nil?
      assert Court[db].find(99).is_a?(RecordNotFound)
      nil
    end.or_panic
  end
end
```

Column types are `:string`, `:integer` (`Int64`), `:float`, `:boolean`, `:datetime`, `:json`
and `:binary`. `null: true` makes the getter nilable. `default:` gives a value for new records.
`index :name, unique: true` adds an index.

## Records

A record is a small handle: its session and an index into the session's store. Its values
live in the store, not in the record. Two copies of a record are the same record, so a change
through one is seen through the other.

Getters and setters are named after the columns. `changed?` tells whether a setter changed a
value since the last save. `persisted?`, `new_record?` and `destroyed?` tell the record's state.
`reload` reads the row again and drops unsaved changes.

A record cannot leave its session's block. The compiler refuses to return one, or to keep one
in a class variable. Take out what you need instead (see "Values leaving a session").

## Writes

`Model.create(db, ...)`, `record.save`, `record.update(...)` and `record.destroy` each run in
their own write. To group several changes, put them in `db.write do |tx| ... end`. The block
runs inside `BEGIN IMMEDIATE`; it commits when the block ends. `tx.roll_back` rolls the write
back. A `write` inside a write is a savepoint.

There is one method per action. `save` returns the record, or an error value; nothing raises.
`.or_panic` stops the program on an error; use it when an error is a bug.

```ris
import db/db/spec::{describe, it}
import std/env
import std/file
import ricord
import sqlite/sqlite/turso
import ricord/model::{model}

model Court do
  table :courts
  col :name, :string
end

def fresh_url : String
  url = ENV["RICORD_DATABASE_URL"]? || "sqlite3:/tmp/guide.db"
  skip = url.starts_with?("turso:") ? 6 : 8
  path = url[skip, url.bytesize - skip]
  [path, "#{path}-wal", "#{path}-shm"].each { |p| File.delete(p) if File.exists?(p) }
  url
end

describe "writes" do
  it "saves, groups writes and rolls back" do
    Ricord.open(fresh_url) do |db|
      Court.create_table(db).or_panic
      court = Court.create(db, name: "Old").or_panic
      court.name = "New"
      assert court.changed?
      court.save.or_panic
      assert !court.changed?
      court.update(name: "Newer").or_panic
      assert Court[db].find(court.id).or_panic.name == "Newer"

      db.write do |tx|
        Court.create(tx, name: "a").or_panic
        Court.create(tx, name: "b").or_panic
      end.or_panic
      assert Court[db].count.or_panic == 3_i64

      db.write do |tx|
        Court.create(tx, name: "gone").or_panic
        tx.roll_back
      end
      assert Court[db].count.or_panic == 3_i64

      court.destroy.or_panic
      assert court.destroyed?
      assert Court[db].count.or_panic == 2_i64
      nil
    end.or_panic
  end
end
```

## Validations and callbacks

`validates :col, presence: true` (also `length:`, `format:`, `inclusion:`) and
`validate :method` check a record before it is saved. A record that fails does not reach the
database: `save` returns `RecordInvalid`, and `record.errors` holds the messages.

`before_save`, `after_create` and the other callbacks name a method of the model. They run
inside the write that saves the record.

## After commit

`after_commit :method` names work that must run only when the data is really written, such as
sending a mail. Each save or destroy adds an item to the session's queue. The items run after
the outermost write commits, each in its own write. If the write rolls back, the queue drops
them and runs the `after_rollback` items instead. The queue holds ids, not records.

The method's form depends on the kind:

| Declaration | Method |
|---|---|
| `after_create_commit`, `after_update_commit`, `after_save_commit`, `after_commit on: [:create, :update]` | `def m : Nil \| Ricord::Failures::Error`, on the record read again by id |
| `after_destroy_commit` | `def self.m(tx : Ricord::Sessions::Tx, id : Int64) : Nil \| Ricord::Failures::Error` |
| `after_commit` (all kinds) | both of the above |
| `after_rollback` | `def self.m(session : Ricord::Sessions::Session, id : Int64 \| Nil) : Nil` |

When an item fails, the others still run, and `write` returns an `AfterCommitError` after the
data is committed.

```ris
import db/db/spec::{describe, it}
import std/env
import std/file
import ricord
import sqlite/sqlite/turso
import ricord/model::{model}

class Mailer
  @@sent = 0

  def self.deliver : Nil
    @@sent += 1
    nil
  end

  def self.sent : Int32
    @@sent
  end
end

model Signup do
  table :signups
  col :email, :string
  validates :email, presence: true
  after_create_commit :welcome

  def welcome : Nil | ::Ricord::Failures::Error
    Mailer.deliver
  end
end

def fresh_url : String
  url = ENV["RICORD_DATABASE_URL"]? || "sqlite3:/tmp/guide.db"
  skip = url.starts_with?("turso:") ? 6 : 8
  path = url[skip, url.bytesize - skip]
  [path, "#{path}-wal", "#{path}-shm"].each { |p| File.delete(p) if File.exists?(p) }
  url
end

describe "after commit" do
  it "runs after the commit, not after a rollback" do
    Ricord.open(fresh_url) do |db|
      Signup.create_table(db).or_panic
      db.write do |tx|
        Signup.create(tx, email: "ann@example.com").or_panic
        assert Mailer.sent == 0, "not yet: the write is still open"
      end.or_panic
      assert Mailer.sent == 1

      db.write do |tx|
        Signup.create(tx, email: "bob@example.com").or_panic
        tx.roll_back
      end
      assert Mailer.sent == 1

      blank = Signup.new(db, email: "")
      assert blank.save.is_a?(::Ricord::Failures::RecordInvalid)
      assert blank.errors.full_messages == ["Email can't be blank"]
      assert Mailer.sent == 1
      nil
    end.or_panic
  end
end
```

## Associations

`col :court_id, belongs_to: :court` declares the key column and a `belongs_to`. `has_many` and
`has_one` read the other side. An association reads through the record's session.

`owner.cases` is a query: chain onto it, `to_a` it, or `build` and `create` through it with the
key set. (`build`, not `new`: in ris an instance method named `new` means in-place
construction.)

Reading `belongs_to` or `has_one` on one record of a loaded group loads it for the whole group
in one query. `includes(:cases)` does the same for a `has_many`. So a list of N records never
takes N extra queries. The example counts queries in `db.statements`, the SQL log that
`Ricord.open(url, log: true)` keeps.

```ris
import db/db/spec::{describe, it}
import std/env
import std/file
import ricord
import sqlite/sqlite/turso
import ricord/model::{model}

model Court do
  table :courts
  col :name, :string
  has_many :cases
end

model Case do
  table :cases
  col :court_id, belongs_to: :court
  col :title, :string
end

def fresh_url : String
  url = ENV["RICORD_DATABASE_URL"]? || "sqlite3:/tmp/guide.db"
  skip = url.starts_with?("turso:") ? 6 : 8
  path = url[skip, url.bytesize - skip]
  [path, "#{path}-wal", "#{path}-shm"].each { |p| File.delete(p) if File.exists?(p) }
  url
end

def selects_since(db : ::Ricord::Sessions::Session, start : Int32) : Int32
  n = 0
  (start...db.statements.size).each { |i| n += 1 if db.statements[i].starts_with?("SELECT") }
  n
end

describe "associations" do
  it "builds, creates and loads a group in one query" do
    Ricord.open(fresh_url, log: true) do |db|
      Court.create_table(db).or_panic
      Case.create_table(db).or_panic
      tartu = Court.create(db, name: "Tartu").or_panic
      narva = Court.create(db, name: "Narva").or_panic
      draft = tartu.cases.build(title: "draft")
      assert draft.court_id == tartu.id && draft.new_record?
      draft.save.or_panic
      narva.cases.create(title: "appeal").or_panic

      start = db.statements.size
      cases = Case[db].order(:id).to_a.or_panic
      names = cases.map do |c|
        court = c.court.or_panic
        court ? court.name : "none"
      end
      assert names == ["Tartu", "Narva"]
      assert selects_since(db, start) == 2, "one for the cases, one for all their courts"

      start = db.statements.size
      courts = Court[db].order(:id).includes(:cases).to_a.or_panic
      assert courts.map { |c| c.cases.to_a.or_panic.size } == [1, 1]
      assert selects_since(db, start) == 2
      nil
    end.or_panic
  end
end
```

`dependent: :destroy`, `:delete_all` or `:nullify` on a `has_many` or `has_one` acts on the
children inside the parent's destroy write.

## Scope

A query read through an association carries that association's key as its scope. Every query,
`create` and `update_all` through it is limited by the key, and the records it reads carry
the scope too. Through a chain such as `account.courts` then `court.cases`, the scope holds all
the keys whose columns the child has. Saving a scoped record with a changed scope column
returns `ScopeError`, with no SQL sent.

`Model[db]` reads have no scope. So an app that serves accounts reads through the account:
`account.courts`, not `Court[db]`.

```ris
import db/db/spec::{describe, it}
import std/env
import std/file
import ricord
import sqlite/sqlite/turso
import ricord/model::{model}
import ricord/failures::{ScopeError}

model Account do
  table :accounts
  col :name, :string
  has_many :courts
end

model Court do
  table :courts
  col :account_id, belongs_to: :account
  col :name, :string
end

def fresh_url : String
  url = ENV["RICORD_DATABASE_URL"]? || "sqlite3:/tmp/guide.db"
  skip = url.starts_with?("turso:") ? 6 : 8
  path = url[skip, url.bytesize - skip]
  [path, "#{path}-wal", "#{path}-shm"].each { |p| File.delete(p) if File.exists?(p) }
  url
end

describe "scope" do
  it "limits reads and writes through the owner" do
    Ricord.open(fresh_url) do |db|
      Account.create_table(db).or_panic
      Court.create_table(db).or_panic
      ann = Account.create(db, name: "ann").or_panic
      bob = Account.create(db, name: "bob").or_panic
      ann.courts.create(name: "a1").or_panic
      bob.courts.create(name: "b1").or_panic

      assert ann.courts.count.or_panic == 1_i64
      assert ann.courts.where(name: "b1").first.or_panic.nil?
      assert Court[db].count.or_panic == 2_i64, "Model[db] has no scope"

      court = ann.courts.first.or_panic
      assert !court.nil?
      if court
        court.account_id = bob.id
        assert court.save.is_a?(ScopeError)
      end
      nil
    end.or_panic
  end
end
```

## Reading many rows with `each`

`to_a` reads every row into the session's store, which then holds them all until the block
ends. For many rows use `each`. It reads in batches (`batch_size:`, 1,000 by default) with a
fresh store per batch, keyed on the order columns plus `id`, so memory stays flat. A row
inserted during the walk is neither repeated nor skipped.

The block gets a record that is valid for that batch only; the compiler refuses to keep it.
The block returns `nil`. An order column that allows NULL is refused with a `DatabaseError`.
`offset` returns an `OffsetQuery`, which has no `each`.

```ris
import db/db/spec::{describe, it}
import std/env
import std/file
import ricord
import sqlite/sqlite/turso
import ricord/model::{model}

model Court do
  table :courts
  col :name, :string
end

def fresh_url : String
  url = ENV["RICORD_DATABASE_URL"]? || "sqlite3:/tmp/guide.db"
  skip = url.starts_with?("turso:") ? 6 : 8
  path = url[skip, url.bytesize - skip]
  [path, "#{path}-wal", "#{path}-shm"].each { |p| File.delete(p) if File.exists?(p) }
  url
end

describe "each" do
  it "walks the rows in batches" do
    Ricord.open(fresh_url) do |db|
      Court.create_table(db).or_panic
      db.write { |tx| 25.times { |i| Court.create(tx, name: "c#{i + 10}").or_panic } }.or_panic
      seen = 0
      longest = 0
      Court[db].order(:name).each(batch_size: 10) do |court|
        seen += 1
        longest = court.name.bytesize if court.name.bytesize > longest
        nil
      end.or_panic
      assert seen == 25
      assert longest == 3
      nil
    end.or_panic
  end
end
```

## Errors

Nothing in Ricord raises. Every call that can fail returns its value or an error struct:
`RecordNotFound`, `RecordInvalid`, `ScopeError`, `CallbackError`, `DatabaseError` and
`AfterCommitError` (all in `ricord/failures`; `Error` is their union). Check with `is_a?` or
`case`, or stop with `.or_panic` where an error is a bug.

Each error has a `message`. Only numbers are extra fields, such as `RecordNotFound#id`.

```ris
import db/db/spec::{describe, it}
import std/env
import std/file
import ricord
import sqlite/sqlite/turso
import ricord/model::{model}
import ricord/failures::{RecordNotFound, RecordInvalid}

model Court do
  table :courts
  col :name, :string
  validates :name, presence: true
end

def fresh_url : String
  url = ENV["RICORD_DATABASE_URL"]? || "sqlite3:/tmp/guide.db"
  skip = url.starts_with?("turso:") ? 6 : 8
  path = url[skip, url.bytesize - skip]
  [path, "#{path}-wal", "#{path}-shm"].each { |p| File.delete(p) if File.exists?(p) }
  url
end

describe "errors" do
  it "returns errors as values" do
    Ricord.open(fresh_url) do |db|
      Court.create_table(db).or_panic
      found = Court[db].find(7)
      case found
      when RecordNotFound
        assert found.id == 7_i64
      else
        assert false, "no court 7"
      end
      made = Court.create(db, name: "")
      assert made.is_a?(RecordInvalid)
      nil
    end.or_panic
  end
end
```

## Values leaving a session

Records, and arrays made inside the block, stay in the block. What may leave is a value the
caller owns: a number, a `String`, a tuple of those, or ids appended to the caller's array
with `pluck(:id, into: ids)`. A tuple with a nilable member cannot leave; give it a value
first.

`pluck(:col)` returns `Array(Ricord::Plucked)`, where `Plucked` is
`String | Int64 | Float64 | Bool | Time | Nil`. Its text is a view into the store, so it too
stays in the block.

```ris
import db/db/spec::{describe, it}
import std/env
import std/file
import ricord
import sqlite/sqlite/turso
import ricord/model::{model}

model Court do
  table :courts
  col :name, :string
  col :rank, :integer, null: true
end

def fresh_url : String
  url = ENV["RICORD_DATABASE_URL"]? || "sqlite3:/tmp/guide.db"
  skip = url.starts_with?("turso:") ? 6 : 8
  path = url[skip, url.bytesize - skip]
  [path, "#{path}-wal", "#{path}-shm"].each { |p| File.delete(p) if File.exists?(p) }
  url
end

describe "values leaving a session" do
  it "keeps numbers, strings, tuples and ids" do
    url = fresh_url
    Ricord.open(url) do |db|
      Court.create_table(db).or_panic
      Court.create(db, name: "Tartu", rank: 2).or_panic
      Court.create(db, name: "Pärnu").or_panic
      nil
    end.or_panic

    count = Ricord.open(url) { |db| Court[db].count.or_panic }.or_panic
    name = Ricord.open(url) { |db| Court[db].find(1).or_panic.name }.or_panic
    pair = Ricord.open(url) do |db|
      court = Court[db].find(2).or_panic
      {court.name, court.rank || 0_i64}
    end.or_panic
    ids = [] of Int64
    Ricord.open(url) { |db| Court[db].order(:id).pluck(:id, into: ids).or_panic }.or_panic

    assert count == 2_i64
    assert name == "Tartu"
    assert pair == {"Pärnu", 0_i64}
    assert ids == [1_i64, 2_i64]
  end
end
```

In a long session, such as a web worker's, `db.request do |r| ... end` gives each request a
child session with a fresh store, and `db.release` ends the read transaction before a slow
step such as writing the response. `examples/tape_web/app.ri` shows both.

## Isolation

Ricord keeps one account's data apart from another's in two ways.

**One file per account.** The strongest wall is a separate database file. Open the account's
file for the request: `Ricord.open("sqlite3:accounts/#{account_id}.db")`. A query cannot reach
a file that is not open, so no missing `where` can leak another account's rows. This is the
model 37signals' Campfire uses.

**Scope, inside one file.** Read through the owner (`account.courts`), as in "Scope" above.

**Raw SQL has no scope.** `db.exec`, `db.query` and `db.scalar` send SQL as written, with
`?` binds. Ricord adds no conditions to them, so they see every row in the file. Pass values
as binds, never by string interpolation.

```ris
import db/db/spec::{describe, it}
import std/env
import std/file
import ricord
import sqlite/sqlite/turso
import ricord/model::{model}
import db/db/value::{DBValue}

model Court do
  table :courts
  col :name, :string
end

# The file for one account, next to the test database, removed first.
def account_url(id : Int32) : String
  url = ENV["RICORD_DATABASE_URL"]? || "sqlite3:/tmp/guide.db"
  skip = url.starts_with?("turso:") ? 6 : 8
  path = "#{url[skip, url.bytesize - skip]}.account#{id}"
  [path, "#{path}-wal", "#{path}-shm"].each { |p| File.delete(p) if File.exists?(p) }
  "#{url[0, skip]}#{path}"
end

describe "isolation" do
  it "keeps each account in its own file" do
    one = account_url(1)
    two = account_url(2)
    Ricord.open(one) do |db|
      Court.create_table(db).or_panic
      Court.create(db, name: "Tartu").or_panic
      nil
    end.or_panic
    Ricord.open(two) do |db|
      Court.create_table(db).or_panic
      Court.create(db, name: "Narva").or_panic
      Court.create(db, name: "Pärnu").or_panic
      nil
    end.or_panic

    count = Ricord.open(one) { |db| Court[db].count.or_panic }.or_panic
    assert count == 1_i64
    raw = Ricord.open(two) do |db|
      db.scalar("SELECT count(*) FROM `courts` WHERE `name` != ?", Int64, ["Tartu"] of DBValue).or_panic
    end.or_panic
    assert raw == 2_i64
  end
end
```
