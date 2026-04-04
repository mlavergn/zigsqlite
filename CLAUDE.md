# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

insqlite — a Zig wrapper module embedding SQLite (amalgamation) with a Zig-friendly API. Can be used as a Zig package dependency to build SQLite with custom statically linked extensions. Targets aarch64 macOS (Apple Silicon). No external dependencies.

## Build Commands

```bash
zig build --verbose       # Build all artifacts (or: make build)
make download             # Download SQLite amalgamation sources
make clean                # Remove zig-out/
```

Build produces three artifacts:
- `zig-out/lib/libinsqlite.a` — static library
- `zig-out/bin/sqlite3` — standard SQLite CLI (from shell.c)
- `zig-out/bin/demo` — demo CLI using the Zig API

Tests: `zig build test`

## Dependency Usage (Static Extensions)

Downstream projects can use insqlite as a Zig dependency to build SQLite with custom C extensions statically linked in:

```zig
// consumer's build.zig
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

At runtime, register extensions before opening any database:

```zig
extern fn sqlite3_myext_init() callconv(.c) void;
try sqlite.SQLite.registerExtension(@ptrCast(&sqlite3_myext_init));
var db = try sqlite.SQLite.init(":memory:");
```

## Code Style

All Zig code must follow `ZIGSTYLE.md`. Key points: init/deinit lifecycle, `const Self = @This()`, scoped logger per file, barrel re-exports via module.zig, no shorthand aliases, `std.Io` (not `std.io`).

## Architecture

Module layout:

```
src/errors.zig      — Error set and error mapping (Errors struct, SQLiteError)
src/sqlite.zig      — C FFI + Zig API (SQLite struct)
src/statement.zig   — Prepared statement wrapper (Statement struct)
src/module.zig      — Barrel re-export (library artifact root)
cli/main.zig        — CLI entry point (accepts db path and SQL args)
sqlite/             — Amalgamation sources (immutable)
```

- **sqlite/** — Raw SQLite C amalgamation sources (sqlite3.c, sqlite3.h, sqlite3ext.h, shell.c). **Immutable** — never modify these files. They are replaced wholesale when upgrading SQLite via `make download`.
- **src/errors.zig** — Error handling. Defines `SQLiteError` (error set mapping common SQLite result codes) and `Errors` (namespace struct with `mapError` for converting C result codes to Zig errors).
- **src/sqlite.zig** — Database connection wrapper. Imports `sqlite3.h` via `@cImport`, compiles `sqlite3.c`. Defines `SQLite` (database connection with init/deinit, exec, prepare, registerExtension/resetExtensions).
- **src/statement.zig** — Prepared statement wrapper. Defines `Statement` (step, column accessors, bind parameters, reset/clearBindings). Uses the shared `@cImport` from sqlite.zig via the module barrel.
- **src/module.zig** — Barrel re-export of all source files (`Errors`, `SQLiteError`, `SQLite`, `Statement`). Root of the static library artifact (`libinsqlite.a`).
- **cli/main.zig** — Demo CLI entry point. Usage: `demo [db_path] [sql]`. Auto-detects queries (SELECT) vs statements via column count.

In build.zig, the module import graph is:
- `createSqliteModule()` — shared helper that creates the core SQLite module (root: `src/module.zig`, compiles `sqlite3.c`, links libc). Also accepts optional extension C sources and include paths. Exposed publicly as `createModule(dep, options)` for downstream dependencies.
- `sqlite_mod` — library module created by `createSqliteModule()`, used as the library artifact root
- `demo_mod` (root: `cli/main.zig`) imports `sqlite_mod` as `"sqlite"` — demo CLI binary

The sqlite3 CLI is a separate build target compiling shell.c + sqlite3.c directly (pure C, no Zig modules).

## Build Notes

- Requires Zig >= 0.15.2
- SQLite compiled with `-fno-sanitize=undefined`
- Optimization: ReleaseFast
