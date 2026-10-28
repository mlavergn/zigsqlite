# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

zigsqlite — a Zig wrapper module embedding SQLite (amalgamation) with a Zig-friendly API. Can be used as a Zig package dependency to build SQLite with custom statically linked extensions. Targets aarch64 macOS (Apple Silicon). The SQLite amalgamation is downloaded from sqlite.org by zigbuildx (not committed).

## Build Commands

```bash
zig build --verbose       # Build all artifacts (or: make build)
make cli                  # Build, then open the sqlite3 shell
make format               # zig fmt over build.zig, src/, cli/, build.zig.zon
make lint                 # zlintpre + zlint -c ../styleguide over build.zig, src/, cli/ (warnings fail)
make validate             # clean, format, lint, build, test
make clean                # Remove zig-out/
```

Build produces three artifacts:
- `zig-out/lib/libzigsqlite.a` — static library
- `zig-out/bin/sqlite3` — standard SQLite CLI (from shell.c)
- `zig-out/bin/demo` — demo CLI using the Zig API

Tests: `zig build test`

## Dependency Usage (Static Extensions)

Downstream projects can use zigsqlite as a Zig dependency to build SQLite with custom C extensions statically linked in:

```zig
// consumer's build.zig
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

At runtime, register extensions before opening any database:

```zig
extern fn sqlite3_myext_init() callconv(.c) void;
try sqlite.SQLite.registerExtension(@ptrCast(&sqlite3_myext_init));
var db = try sqlite.SQLite.init(":memory:");
```

## Code Style

All Zig code must follow `../styleguide/ZIGSTYLE.md` (the shared sibling checkout of `mlavergn/styleguide`, its own repo — never edit it from here; `format`, `lint` and `validate` come from its `Makefile.in`). Key points: init/deinit lifecycle, `const Self = @This()`, scoped logger per file, barrel re-exports via module.zig, no shorthand aliases (the C API is always `mod.c.…`, never a local `c`), `std.Io` (not `std.io`).

Deliberate departures:

- **build.zig** has no scoped logger or `@src()` tracing: the build runner is compiled in Debug, so `log.debug` would print on every `zig build`. `build` and `createModule` stay free functions (Zig's build system and the downstream `zigsqlite.createModule(dep, …)` API require them); private helpers live on the `Amalgamation` struct.
- **`Extension.SQLITE_*`** constants keep SQLite's C names rather than snake_case, so callback code reads like the C API they mirror.

## Architecture

Module layout:

```
src/errors.zig      — Error set and error mapping (Errors struct, SQLiteError)
src/sqlite.zig      — C FFI + Zig API (SQLite struct)
src/statement.zig   — Prepared statement wrapper (Statement struct)
src/extension.zig   — Scalar function / auto-extension support (Extension struct)
src/module.zig      — Barrel re-export, translated C API (`c`), `is_debug` (library artifact root)
cli/main.zig        — CLI entry point (accepts db path and SQL args)
cli/demo.zig        — Built-in EMP/DEPT demo (Demo struct)
cli/module.zig      — CLI barrel
```

- **deps/sqlite/** — SQLite amalgamation (`sqlite3.c`, `sqlite3.h`, `sqlite3ext.h`, `shell.c`). **Immutable and git-ignored** — never modify or commit it. It is the `sqlite` dependency in `build.zig.zon` (`.path = "deps/sqlite"` + `.archive = <zip URL>`), unpacked by `zigbuildx.Deps.cloneMissing` at the start of `build()`; zigbuildx adds a stub `build.zig` and a `.zigbuildx-archive` URL stamp. build.zig resolves the files via `Amalgamation.path()`. Upgrade by changing the `.archive` URL (and the `-sqlite-XXXYYZZ` suffix of `.version`); the next build replaces `deps/sqlite/` and carries on (no re-run).
- **src/errors.zig** — Error handling. Defines `SQLiteError` (error set mapping common SQLite result codes) and `Errors` (namespace struct with `mapError` for converting C result codes to Zig errors).
- **src/sqlite.zig** — Database connection wrapper. Defines `SQLite` (database connection with init/deinit, registerExtension/resetExtensions, exec, prepare). Tests for the connection itself.
- **src/statement.zig** — Prepared statement wrapper. Defines `Statement` (step, column accessors, bind parameters, reset/clearBindings), with its tests.
- **src/extension.zig** — Extension function support. Defines `Extension` (type aliases for the C callback API, value accessors, result setters, and `register` for scalar SQL functions).
- **src/module.zig** — Barrel re-export of all source files (`Errors`, `SQLiteError`, `SQLite`, `Statement`, `Extension`), plus `c` (the SQLite C API, translated from `sqlite3.h` by build.zig's `addTranslateC` and imported as `sqlite3_h`; every file reaches it as `mod.c`) and `is_debug`. Root of the static library artifact (`libzigsqlite.a`).
- **cli/main.zig** — Demo CLI entry point. Usage: `demo [db_path] [sql]`. Auto-detects queries (SELECT) vs statements via column count; with no SQL it runs `cli.Demo`. Declares `std_options` (log level `.debug` in Debug, `.info` otherwise). Imports the library as `mod` and the CLI barrel as `cli`.
- **cli/demo.zig** — `Demo`: seeds the EMP/DEPT schema into a borrowed `*SQLite` and prints sample queries.
- **cli/module.zig** — CLI barrel (`Demo`).

In build.zig, the module import graph is:
- `Amalgamation.createModule()` — shared helper that creates the core SQLite module (root: `src/module.zig`, translates `sqlite3.h` into the `sqlite3_h` import, compiles `sqlite3.c`, links libc). Also accepts optional extension C sources and include paths. Exposed publicly as `createModule(dep, options)` for downstream dependencies.
- `sqlite_mod` — library module created by `Amalgamation.createModule()`, used as the library artifact root
- `demo_mod` (root: `cli/main.zig`) imports `sqlite_mod` as `"sqlite"` — demo CLI binary

The sqlite3 CLI is a separate build target compiling shell.c + sqlite3.c directly (pure C, no Zig modules).

## Build Notes

- Requires Zig >= 0.17.0
- SQLite compiled with `-fno-sanitize=undefined`
- Optimization: Debug by default; `--release` picks the preferred `fast`; `make dist` builds `--release=safe`
