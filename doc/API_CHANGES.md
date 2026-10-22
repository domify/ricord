# API changes from Crystal Grant

What a Grant user changes when moving an app to ris Grant. Each entry says what changed, why,
and how to update, with a before/after example. Newest first.

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
