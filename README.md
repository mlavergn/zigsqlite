# zigsqlite

A Zig module that embeds SQLite and exposes a Zig-friendly database interface. Can be used as a Zig package dependency to build SQLite with custom statically linked extensions.

SQLite is compiled from the amalgamation sources and statically linked, so consumers get a self-contained binary with no runtime dependencies. The amalgamation is downloaded from sqlite.org at build time by [zigbuildx](https://github.com/mlavergn/zigbuildx).

## Project Structure

```
src/errors.zig      — Error set and error mapping (Errors, SQLiteError)
src/sqlite.zig      — C FFI bindings and Zig API (SQLite)
src/statement.zig   — Prepared statement wrapper (Statement)
src/extension.zig   — Scalar function / auto-extension support (Extension)
src/module.zig      — Barrel re-export (library artifact root)
cli/main.zig        — Demo CLI entry point
cli/demo.zig        — Built-in EMP/DEPT demo (Demo)
cli/module.zig      — CLI barrel
```

The SQLite amalgamation (`sqlite3.c`, `sqlite3.h`, `sqlite3ext.h`, `shell.c`) is not committed. The `sqlite` dependency in `build.zig.zon` names its zip by `.archive`, and zigbuildx's `Deps.cloneMissing` (first in `build()`) unpacks it into `deps/sqlite/` (git-ignored) when it is missing or the URL changed, then the build carries on. Treat `deps/sqlite/` as immutable. All Zig-side API work belongs in `src/`.

## Requirements

- Zig >= 0.17.0
- macOS (aarch64)

## Build

```bash
zig build              # build all artifacts (downloads SQLite on first run)
zig build test         # run unit tests
make cli               # build, then open the sqlite3 shell
make clean             # remove build output
```

### Artifacts

| Artifact | Description |
|---|---|
| `zig-out/lib/libzigsqlite.a` | Static library |
| `zig-out/bin/sqlite3` | Standard SQLite CLI (from upstream shell.c) |
| `zig-out/bin/demo` | Demo CLI using the Zig API |

## Demo CLI Usage

```bash
demo [db_path] [sql]
```

- Defaults to `:memory:` if no path given
- Queries (SELECT) print pipe-delimited rows
- Statements (CREATE, INSERT, etc.) execute and report ok

```bash
demo my.db "CREATE TABLE t (id INTEGER PRIMARY KEY, name TEXT)"
demo my.db "INSERT INTO t VALUES (1, 'hello')"
demo my.db "SELECT * FROM t"
```

## Using as a Dependency (Static Extensions)

Downstream projects can add zigsqlite as a Zig dependency to build SQLite with custom C extensions statically linked in.

### build.zig.zon

```zon
.dependencies = .{
    .zigsqlite = .{
        .url = "...",
        .hash = "...",
    },
},
```

### build.zig

```zig
const zigsqlite = @import("zigsqlite");
const dep = b.dependency("zigsqlite", .{});
const sqlite_mod = zigsqlite.createModule(dep, .{
    .target = target,
    .optimize = optimize,
    .extension_c_source_files = &.{
        .{ .file = b.path("ext/my_extension.c"), .flags = &.{"-DSQLITE_CORE"} },
    },
});
my_mod.addImport("sqlite", sqlite_mod);
```

### Runtime registration

Register extension entry points before opening any database:

```zig
const sqlite = @import("sqlite");

extern fn sqlite3_myext_init() callconv(.c) void;
try sqlite.SQLite.registerExtension(@ptrCast(&sqlite3_myext_init));
var db = try sqlite.SQLite.init(":memory:");
```

## Updating SQLite

Change the `.archive` URL of the `sqlite` dependency in `build.zig.zon` to the new amalgamation zip (the [download page](https://www.sqlite.org/download.html) gives the release year and version number), and the `-sqlite-XXXYYZZ` suffix of `.version` to match:

```zig
.sqlite = .{
    .path = "deps/sqlite",
    .archive = "https://www.sqlite.org/<YEAR>/sqlite-amalgamation-<VERSION>.zip",
},
```

The next `zig build` replaces `deps/sqlite/` with the new release and builds against it. No changes to `build.zig`, `src/` or `cli/` should be required for a standard SQLite update.
