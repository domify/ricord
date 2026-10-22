# Tape models

A web request is the unit of work: it comes in, finds a few records, renders them and answers,
and then everything it made is garbage. ris gives each request a tape (the server opens one per
request, `web/web/server.ri`), and `Grant::TapeModel` puts the request's records on it. A row
goes from the database driver onto the tape, its text is a `Tape::String` the view writes into
the response, `env.response.send` puts the response on the socket from the tape, and the
request's end frees all of it at once. No record, cell or page is collected or copied on the
way.

`grant/tape_model.ri` holds the model; `test/grant_tape_model_test.ri` plays one request through
all of it under SQLite and PostgreSQL; `examples/tape_web` is a Rails-style users resource on
web.

## Declaring a model

A tape model is declared with Grant's own declarations, in `model ... do` instead of
`class ... < Grant::Base` (`import grant/tape_model::{model}`, or call it as
`::Grant::TapeModel.model`):

```ris
model User do
  connection sqlite
  table users
  column id : Int64, primary: true
  column name : String
  column email : String?
  timestamps
  belongs_to team : Team, optional: true
  has_many posts : Post, dependent: :destroy
  validates_presence_of :name
  validates_format_of :email, with: /@/
  before_save :strip_name

  def strip_name : Nil
    ...
  end
end
```

| Declaration | Forms |
|---|---|
| `connection`, `table` | a name, as in Grant |
| `column` | `Int64`, `Int32`, `Float64`, `Bool`, `String`, `Time`, `UUID`, nilable or not; `primary: true` |
| `timestamps` | `created_at` and `updated_at`, set on save |
| `belongs_to` | `team : Team`, `foreign_key:`, `class_name:`, `optional: true`; adds the key column |
| `has_many`, `has_one` | `posts : Post` or `:posts, class_name: Post`; `foreign_key:`, `dependent: :destroy / :delete_all / :nullify` |
| validations | `validates_presence_of`, `validates_length_of` (`minimum:`, `maximum:`, `is:`), `validates_format_of` (`with:`), `validates_inclusion_of` (`in:`), `validate :method` |
| callbacks | `before_`/`after_` `validation`, `save`, `create`, `update`, `destroy`, naming methods |
| `def` | becomes a method of the model |

## Using it

The model answers Grant's API: `User.find`, `find_strict`, `find_by`, `find_by_strict`, `all`,
`where` (equality, `nil`, arrays as `IN`, ranges, raw SQL with binds), `or_where`, `order`,
`limit`, `offset`, `includes`, `first`, `first_strict`, `count`, `exists?`, `pluck`,
`update_all`, `delete_all`, `destroy_all`, `create`, `create_strict`, `transaction`; records
answer the column getters and setters, `save`, `save_strict`, `update`, `update_strict`,
`destroy`, `destroy_strict`, `delete`, `reload`, `errors` (Grant's `Errors`), `valid?`,
`persisted?`, `new_record?`, `destroyed?`, `changed?`, `<column>_changed?`,
`changed_attributes`, `to_param` and `to_json`.

```ris
router.get "/users" do |env|
  tape do
    env.response.send(index_page(User.includes(:team).order(:name).to_a.or_panic))
  end
  ""
end
```

Each call runs inside a `tape` block. A web handler is already in one, and a nested `tape`
shares it at no cost; a job, a console or a test opens its own.

## What is different from a Grant::Base model

* **A record is a tape value, and the compiler keeps it on the tape.** It cannot be stored in a
  class variable, a heap container (`Array(User)`, `Hash`), a proc's captures or a fiber's
  message; it is refused at compile time. What has to outlive the request crosses the line on
  purpose: `user.to_heap` answers a `User::Data` (a heap struct with the same getters, text as
  `String`) to keep in a cache or a job's arguments, and `User.from_heap(data)` brings it back.
  Most often the id is enough.
* **Text columns are `Tape::String`.** They compare with `==` against a `String`, write into a
  tape writer or an `IO` as they are, and become a `String` with `to_heap` where a heap API needs
  one (a `Regex`, most of the standard library).
* **A record is a handle.** Its values, change marks and preloaded associations are shared by
  every copy, so `same = user; same.update(name: "x")` changes `user` too. There is no identity
  map: the same row read twice is two handles.
* **Results are `Tape::Array(User)`**, not `Array(User)`. Relations chain into new relations as
  Grant's do.
* **No `after_commit`.** Work deferred past a commit would have to hold the record past the
  statement that saved it; callbacks run where they are declared.
* **Callbacks name methods**, as `before_save :method`; blocks and procs are not taken.
* **A record outside a `tape` block stops the program** (`a tape value made outside a tape
  block`), at run time.

## Where the tape ends

A request answers best when everything it sends is already on the tape: write the page with a
`Tape::String::Writer` and `env.response.send` it. `router.get` still wants a `String` back, so
a handler that sent its page answers `""`. Binds for SQL are copied to the heap (`Array(Value)`)
because the drivers take one; they are small. `validates_format_of` copies the value for its
`Regex`. A `Time` column on SQLite parses straight off the tape.
