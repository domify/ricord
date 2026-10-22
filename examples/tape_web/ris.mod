# A request against a tape-backed model; run `ris test app_test.ri` here.
module tape_web

require github.com/domify/web v0.1.0 as web
require github.com/domify/grant v0.0.0 as grant

replace github.com/domify/web => ../../../web
replace github.com/domify/grant => ../..
replace github.com/domify/db => ../../../db
replace github.com/domify/sqlite => ../../../sqlite
replace github.com/domify/pg => ../../../pg
