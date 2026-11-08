# API changes

What a user changes when moving an app forward. Each entry says what changed, why, and how to
update, with a before/after example. Newest first. The examples here are excerpts, not
complete programs; [GUIDE.md](GUIDE.md) has complete ones.

## From Grant to Ricord

**What changed.** Grant is now Ricord. `Grant::Base` and `Grant::TapeModel` are gone; the old
code is at the git tag `grant-base-final`. A model is declared with `model ... do` from
`ricord/model`. There are no connection names: a program opens a database with
`Ricord.open(url)`, and every read starts at `Model[db]`. Records live in the session's store
and cannot leave its block. One method does each action and returns an error value on
failure. The engines are SQLite and Turso.

**Why.** Grant carried the whole Rails surface: pools, registries, class-level caches,
`after_commit` blocks holding records. On ris these need a heap and a collector, and they hide
which connection a query uses. A session per block makes the connection, the transaction and
the memory of a unit of work one visible thing. See [DESIGN.md](DESIGN.md).

**How to update.**

A model. Before:

```text
class User < Grant::Base
  connection sqlite
  table users
  column id : Int64, primary: true
  column name : String
  column team_id : Int64?
  belongs_to team : Team, optional: true
  validates_presence_of :name
end
```

Now (`id` is added for you; `null: true` makes a column nilable):

```text
import ricord
import ricord/model::{model}

model User do
  table :users
  col :name, :string
  col :team_id, belongs_to: :team, null: true
  validates :name, presence: true
end
```

Connections. Before, a model named its connection and found it in a registry:

```text
user = User.find_strict(1).or_panic
```

Now the program opens the database, and the query names the session:

```text
Ricord.open("sqlite3:app.db") do |db|
  user = User[db].find(1).or_panic
end.or_panic
```

`find!` and `find_strict` to `find`. `find` returns the record or `RecordNotFound`;
`find_by` and `first` return the record or `nil`:

```text
# before
user = User.find_strict(id).or_panic
maybe = User.find(id)                  # User?
# now
user = User[db].find(id).or_panic
missing = User[db].find(id).is_a?(::Ricord::Failures::RecordNotFound)
```

`save!`, `save_strict` and `save` to one `save`. Before, `save` answered `false` on a
validation failure and `save_strict` returned an error. Now `save` returns the record, or
`RecordInvalid` (messages on `record.errors`), or another error:

```text
# before
if user.save
  ...
end
user.save_strict.or_panic
# now
result = user.save
if result.is_a?(::Ricord::Failures::RecordInvalid)
  puts user.errors.full_messages.join(", ")
end
```

The same holds for `create`, `update` and `destroy`.

Transactions. `User.transaction do ... end` becomes `db.write do |tx| ... end`. Inside it,
use `tx` (`User[tx]`, `User.create(tx, ...)`). `tx.roll_back` rolls back; a nested `write` is
a savepoint.

`after_commit` blocks to method names. Before:

```text
after_commit { Mailer.welcome(self) }
```

Now the declaration names a method. The queue keeps the id, and the method runs on the
record read again after the commit:

```text
after_create_commit :welcome

def welcome : Nil | ::Ricord::Failures::Error
  Mailer.welcome(email)
  nil
end
```

Associations. `owner.cases.new(...)` is `owner.cases.build(...)`: in ris an instance method
named `new` means in-place construction. `pluck(:col)` returns `Array(Ricord::Plucked)`;
`pluck(:col, into: typed_array)` fills an array of your type.

Removed APIs (all at the tag `grant-base-final`, `grant/`):

| Removed | Use instead |
|---|---|
| `class X < Grant::Base`, `Grant::TapeModel` (`base.ri`, `tape_model.ri`) | `model X do ... end` |
| `connection name`, connection registry, pools, reaper, health monitor (`connection*.ri`, `pool_*.ri`, `health_monitor.ri`) | `Ricord.open(url)`; a session owns one connection |
| `find!`, `find_strict`, `save!`, `save_strict`, `create_strict`, `update_strict`, `destroy_strict`, `first!`, `find_by!` | `find`, `save`, `create`, `update`, `destroy`, `first`, `find_by` returning error values |
| `where!`, `order!` and other `_in_place` query mutators | chaining; every query method returns a new query |
| `transaction` (`transaction*.ri`) | `db.write do \|tx\| ... end` |
| `after_commit` and callback blocks or procs | callbacks naming methods |
| `column x : T, primary: true`, `validates_presence_of` and the `validates_*_of` forms | `col :x, :type`, `validates :x, presence: true` |
| `to_heap`, `from_heap`, `Tape::String`, `Tape::Array` | values leave a session as numbers, `String`s, tuples or ids |
| `ids` | `pluck(:id, into: ids)` |
| record copy, dup (`record_copy.ri`) | none |
| PostgreSQL and MySQL adapters (`adapter/`) | SQLite and Turso |
| migrations, schema tasks, seeds (`migrator.ri`, `schema/`, `tasks/`, `seeds.ri`) | `Model.create_table(db)`; migrations are planned |
| sharding, replicas, async queries, query cache, query logs (`scale/`, `replica_load_balancer.ri`, `async/`, `query_cache.ri`, `query_logs.ri`) | none |
| encryption, counter caches, STI, polymorphic, enums, store accessors, value objects, normalization, secure tokens, locking, advisory locks | none |
| `has_many :through`, nested attributes, autosave | none |
| `group_records`, `import_records`, `and_where` | none; `or_where` stays |

## Tape models: records on the request's tape

**What changed.** `Grant::TapeModel` (`grant/tape_model.ri`) is a model whose records live on the
running fiber's tape, the request's in a web app. It takes Grant's declarations and answers
Grant's API; `doc/TAPE_MODEL.md` listed both (removed in M5; see the git history). `Grant::Base` is unchanged; a tape
model is what an app moves a model to.

**Why.** A request finds a few records, renders them and is done. On the tape the rows go from
the driver to the view to the socket without a heap copy, and the request's end frees them all
at once.

**How to update.** Declare the model in `model ... do`, and keep what outlives a request as
`to_heap` data or its id.

Before:

```ris
class User < Grant::Base
  connection sqlite
  table users
  column id : Int64, primary: true
  column name : String
  validates_presence_of :name
end

user = User.find_strict(1).or_panic
@@current = user                   # kept between requests
puts user.name.upcase              # a String
```

Now:

```ris
import grant/tape_model::{model}

model User do
  connection sqlite
  table users
  column id : Int64, primary: true
  column name : String
  validates_presence_of :name
end

tape do
  user = User.find_strict(1).or_panic
  io << user.name                  # a Tape::String, written as it is
  cached = user.to_heap            # a User::Data, to keep past the request
end
```

What else changes for code that used a `Base` model:

| Was | Now |
|---|---|
| `class User < Grant::Base ... end` | `model User do ... end`, with `import grant/tape_model::{model}` |
| `user.name : String` | `Tape::String`; `to_heap` for a `String` |
| a record kept in a class variable, cache or job | refused by the compiler; keep `to_heap` data or the id |
| results `Array(User)` | `Tape::Array(User)` |
| `after_commit`, callback blocks | not taken; callbacks name methods |
| a record read with no `tape` open | the program stops: open `tape do` (a web request already has one) |

## `pluck` and `pick` read onto the tape

**What changed.** `pluck` and `pick` (on a model, a relation and an association collection)
return their rows on the running fiber's tape:

| Method | Before | Now |
|---|---|---|
| `pluck(*fields)` | `Array(Array(Value)) \| Error` | `Tape::Array(Tape::Array(TapeValue)) \| Error` |
| `pick(*fields)` | `Array(Value)? \| Error` | `Tape::Array(TapeValue)? \| Error` |

`TapeValue` is `Tape::String | Value`: text and bytes columns are `Tape::String`s, every other
column is the same `Value` as before (`Int64`, `Float64`, `Bool`, `nil`, ...).

The call must run inside a `tape do ... end` block (a web request handler usually is one). Outside
one the program stops with `a tape value made outside a tape block`. The rows are freed when the
block ends; `to_heap` copies what has to outlive it.

**Why.** Reading rows straight onto the tape skips a heap `String` and `Array` per row and cell,
and the tape frees them all at once when the block ends. Plucked values are read, used and
dropped, which is the case the tape is for.

**How to update.** Use the rows inside a `tape` block; call `to_heap` on what you keep.

Before:

```ris
names = User.order(:name).pluck(:name).or_panic
puts names.map(&.first).join(", ")
```

Now, using the rows in place:

```ris
tape do
  User.order(:name).pluck(:name).or_panic.each { |row| io << row[0] << "\n" }
end
```

Now, keeping them on the heap:

```ris
names = [] of Array(Grant::Adapter::Driver::Value)
tape do
  names = User.order(:name).pluck(:name).or_panic.to_heap
end
```

`pick` may answer `nil`, so check it before `to_heap`
(`row = User.pick(:name).or_panic; kept = row.to_heap unless row.nil?`).

`ids` is unchanged: it still returns `Array(Value)` on the heap.
