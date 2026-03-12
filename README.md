# insqlite3

A Zig module that embeds SQLite and exposes a Zig-friendly database interface.

SQLite is compiled from the amalgamation sources and statically linked, so consumers get a self-contained binary with no external dependencies.

## Project Structure

```
sqlite/          — SQLite amalgamation sources (immutable, do not modify)
src/sqlite.zig   — C FFI bindings and Zig API (implementation)
src/module.zig   — Barrel re-export (library artifact root)
cli/main.zig     — CLI application entry point
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
| `zig-out/lib/libinsqlite3.a` | Static library |
| `zig-out/bin/sqlite3` | Standard SQLite CLI (from upstream shell.c) |
| `zig-out/bin/insqlite3` | Zig-based CLI |

## Updating SQLite

Run `make download` to fetch the latest amalgamation, then replace the contents of `sqlite/`. No changes to `src/` or `cli/` should be required for a standard SQLite update.
