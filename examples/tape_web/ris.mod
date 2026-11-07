# A request against a Ricord model; run `ris test app_test.ri` here.
module tape_web

require github.com/domify/web v0.1.0 as web
require github.com/priit/ricord v0.0.0 as ricord

replace github.com/domify/web => ../../../web
replace github.com/priit/ricord => ../..
replace github.com/domify/db => ../../../db
replace github.com/domify/sqlite => ../../../sqlite
