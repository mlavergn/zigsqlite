# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

insqlite3 — a Zig wrapper module embedding SQLite (amalgamation) with a Zig-friendly API. Targets aarch64 macOS (Apple Silicon). No external dependencies.

## Build Commands

```bash
zig build --verbose       # Build all artifacts (or: make build)
make download             # Download SQLite amalgamation sources
make clean                # Remove zig-out/
```

Build produces three artifacts:
- `zig-out/lib/libinsqlite3.a` — static library
- `zig-out/bin/sqlite3` — standard SQLite CLI (from shell.c)
- `zig-out/bin/insqlite3` — Zig-based CLI

There are no tests yet.

## Code Style

All Zig code must follow `ZIGSTYLE.md`. Key points: init/deinit lifecycle, `const Self = @This()`, scoped logger per file, barrel re-exports via module.zig, no shorthand aliases, `std.Io` (not `std.io`).

## Architecture

Module layout:

```
src/sqlite.zig   — C FFI + Zig API (SQLite, Statement, SQLiteError)
src/module.zig   — Barrel re-export of sqlite.zig (library artifact root)
cli/main.zig     — CLI entry point (accepts db path and SQL args)
sqlite/          — Amalgamation sources (immutable)
```

- **sqlite/** — Raw SQLite C amalgamation sources (sqlite3.c, sqlite3.h, sqlite3ext.h, shell.c). **Immutable** — never modify these files. They are replaced wholesale when upgrading SQLite via `make download`.
- **src/sqlite.zig** — Implementation layer. Imports `sqlite3.h` via `@cImport`, compiles `sqlite3.c`. Defines `SQLiteError` (error set), `Statement` (prepared statement wrapper), and `SQLite` (database connection wrapper with init/deinit, exec/execScript, prepare).
- **src/module.zig** — Barrel re-export of sqlite.zig (`SQLiteError`, `Statement`, `SQLite`). Root of the static library artifact (`libinsqlite3.a`).
- **cli/main.zig** — CLI entry point. Usage: `insqlite3 [db_path] [sql]`. Auto-detects queries (SELECT) vs statements via column count.

In build.zig, the module import graph is:
- `src_mod` (root: `src/sqlite.zig`, compiles `sqlite3.c`, links libc) — the core module
- `sqlite_mod` (root: `src/module.zig`) imports `src_mod` as `"sqlite"` — library artifact root
- `cli_mod` (root: `cli/main.zig`) imports `src_mod` as `"sqlite"` — CLI binary

The sqlite3 CLI is a separate build target compiling shell.c + sqlite3.c directly (pure C, no Zig modules).

## Build Notes

- Requires Zig >= 0.15.2
- SQLite compiled with `-fPIC -fno-sanitize=undefined`
- Optimization: ReleaseFast
