# The users resource on Ricord; run `ris test app_test.ri` here with DATABASE_URL set.
module tape_web

require github.com/domify/web v0.1.0 as web
require github.com/domify/ricord v0.0.0 as ricord
require github.com/domify/db v0.3.1 as db
require github.com/domify/sqlite v0.2.0 as sqlite

replace github.com/domify/web => ../../../web
replace github.com/domify/ricord => ../..
replace github.com/domify/db => ../../../db
replace github.com/domify/sqlite => ../../../sqlite
