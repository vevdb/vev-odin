# VevDB for Odin

An Odin package for the [VevDB](https://github.com/vevdb/vev) embedded
database.

The package loads VevDB's stable C ABI dynamically, verifies its ABI version,
and gives native handles explicit Odin lifetimes. VevDB's native library
includes SQLite with FTS5, so applications do not install SQLite separately or
manage SQL schemas.

## Install

Odin deliberately has no official package manager. The simplest installation
is the platform bundle from the
[VevDB for Odin releases](https://github.com/vevdb/vev-odin/releases). Each
bundle contains the Odin package and matching VevDB native library:

```text
vev/
  doc.odin
  vev.odin
  LICENSE
  lib/
    libvev.dylib | libvev.so | vev.dll
```

Unpack that `vev` directory under `vendor/` and import it:

```odin
import vev "vendor/vev"
```

The package owns native discovery:

```odin
library, ok := vev.load_bundled("vendor/vev")
assert(ok)
defer vev.unload(&library)
```

The package and engine are therefore pinned and vendored as one dependency.
The shared library must remain under `vendor/vev/lib` while developing, and
must be copied beside the same package-relative layout when distributing the
application.

Developers who prefer Git can pin this repository as a submodule:

```sh
git submodule add https://github.com/vevdb/vev-odin vendor/vev
```

Import the vendored directory directly:

```odin
import vev "vendor/vev"
```

For a shared dependency directory, expose an Odin collection:

```sh
odin build . -collection:deps=vendor
```

and use:

```odin
import vev "deps:vev"
```

Source-only Git checkouts do not commit large platform binaries. Run
`scripts/package_vendor_bundle.sh` or download the matching native SDK from the
[VevDB releases](https://github.com/vevdb/vev/releases) when developing this
repository itself.

## Example

```odin
library, ok := vev.load_bundled("vendor/vev")
assert(ok)
defer vev.unload(&library)

connection, ok := vev.open_memory(&library)
assert(ok)
defer vev.close(&connection)

tx, ok := vev.transact(&connection, `[{:db/id 1 :user/name "Ada"}]`)
assert(ok)
defer delete(tx)

result, ok := vev.query(
	&connection,
	`[:find ?name :where [?e :user/name ?name]]`,
)
assert(ok)
defer vev.close(&result)
```

`query` returns owned `Data`. Its value has the same shape requested by
Datomic's `:find`: relation, collection, tuple, or scalar. Close the `Data`
after use; any `Value` views borrowed from it remain valid until then.

Durable stores use the same `transact` and `query` API:

```odin
connection, ok := vev.connect(&library, "app.vev")
assert(ok)
defer vev.close(&connection)

tx, ok := vev.transact(
	&connection,
	`[{:db/id 1 :user/name "Ada"}]`,
)
assert(ok)
defer delete(tx)

result, ok := vev.query(
	&connection,
	`[:find ?name . :where [?e :user/name ?name]]`,
)
assert(ok)
defer vev.close(&result)

value, ok := vev.value(&result)
assert(ok)
name, ok := vev.as_string(value)
assert(ok)
defer delete(name)
```

Use `value`, `kind`, `item`, `get`, and the `as_*` procedures for typed
traversal, or `edn` when rendered EDN is the desired boundary. Each durable
query captures an immutable database basis.

The complete runnable program is in [`examples/basic`](examples/basic):

```sh
odin run examples/basic -- vendor/vev
```

## Compatibility

- Bundled VevDB release: `0.2.0-rc.3` (not yet published)
- VevDB C ABI version: `1`
- Tested Odin baseline: `dev-2026-05`
- CI: macOS ARM64/x64, Linux ARM64/x64, and Windows x64

The package surface covers loading, in-memory and durable connections, EDN
transactions, storage-neutral Datalog queries, and typed query-value traversal.
Prepared-query reuse, pull, entity views, and typed transaction builders are
the next API layers; the underlying VevDB C ABI already supports them.

## Development

```sh
odin check . -no-entry-point
scripts/smoke_release.sh
```

`smoke_release.sh` downloads a published native SDK into a temporary directory,
verifies its release checksum, builds the consumer example, and runs it with no
local VevDB checkout.

Licensed under the Eclipse Public License 2.0.
