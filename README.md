# insqlite

A Zig module that embeds SQLite and exposes a Zig-friendly database interface. Can be used as a Zig package dependency to build SQLite with custom statically linked extensions.

SQLite is compiled from the amalgamation sources and statically linked, so consumers get a self-contained binary with no external dependencies.

## Project Structure

```
sqlite/             — SQLite amalgamation sources (immutable, do not modify)
src/errors.zig      — Error set and error mapping (Errors, SQLiteError)
src/sqlite.zig      — C FFI bindings and Zig API (SQLite)
src/statement.zig   — Prepared statement wrapper (Statement)
src/module.zig      — Barrel re-export (library artifact root)
cli/main.zig        — Demo CLI entry point
```

The `sqlite/` directory contains unmodified upstream SQLite sources. Treat these files as immutable — they are replaced wholesale when upgrading to a new SQLite release. All Zig-side API work belongs in `src/`.

## Requirements

- Zig >= 0.15.2
- macOS (aarch64)

## Build

```bash
zig build              # build all artifacts
make download          # download SQLite amalgamation sources
make clean             # remove build output
```

### Artifacts

| Artifact | Description |
|---|---|
| `zig-out/lib/libinsqlite.a` | Static library |
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

Downstream projects can add insqlite as a Zig dependency to build SQLite with custom C extensions statically linked in.

### build.zig.zon

```zon
.dependencies = .{
    .insqlite = .{
        .url = "...",
        .hash = "...",
    },
},
```

### build.zig

```zig
const insqlite = @import("insqlite");
const dep = b.dependency("insqlite", .{});
const sqlite_mod = insqlite.createModule(dep, .{
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

Run `make download` to fetch the latest amalgamation, then replace the contents of `sqlite/`. No changes to `src/` or `cli/` should be required for a standard SQLite update.
