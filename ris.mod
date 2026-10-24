module github.com/priit/grant

require github.com/domify/db v0.1.1 as db
require github.com/domify/sqlite v0.1.0 as sqlite
require github.com/domify/pg v0.1.0 as pg

replace github.com/domify/db => ../db
replace github.com/domify/sqlite => ../sqlite
replace github.com/domify/pg => ../pg
