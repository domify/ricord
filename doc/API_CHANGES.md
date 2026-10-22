# API changes from Crystal Grant

What a Grant user changes when moving an app to ris Grant. Each entry says what changed, why,
and how to update, with a before/after example. Newest first.

## Tape models: records on the request's tape

**What changed.** `Grant::TapeModel` (`grant/tape_model.ri`) is a model whose records live on the
running fiber's tape, the request's in a web app. It takes Grant's declarations and answers
Grant's API; [doc/TAPE_MODEL.md](TAPE_MODEL.md) lists both. `Grant::Base` is unchanged; a tape
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
::Grant::TapeModel.model User do
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
| `class User < Grant::Base ... end` | `::Grant::TapeModel.model User do ... end` |
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
