# Specification

A 3-part specification document that guides code generation agents.

## 1. Vision

The module's purpose and direction. Aligns high-level decisions and tradeoffs.

- insqlite is a Zig module that wraps sqlite3 to abstract the C-API and provide Zig APIs such as  SQLite, Statement, etc.
- insqlite uses Zig 0.15.2 for cross-platform compilation and performance.
- insqlite will run on various hardware, initially targeting Apple Silicon on macOS, and eventually Linux on Qualcomm Snapdragon and possibly containerized Linux deployments.

## 2. Structure

Architectural and technical design of the module.

- The project is laid out in a src/ directory. The module is defined by src/module.zig.
- The project has no other external dependencies.
- Circular dependencies are forbidden.
- External dependencies must not be added by agents. Only dependencies already declared in `build.zig.zon` may be used.

## 3. Instructions

Constraints and conventions the agent must follow during generation.

- One struct per file. The filename must match the struct name in lowercase (e.g., `Base` → `base.zig`).
- All files must use `std.log.scoped` with a meaningful scope name for logging.
- Tests are placed at the bottom of source files.
- Every struct must have a `const Self = @This()` member.
- Nested structs are forbidden.
- Structs are used as namespaces. Global functions are forbidden.
- Every struct must have `init` and `deinit` methods. If the struct performs heap allocations, it must capture an allocator via `init`. Heap allocations in `init` are discouraged; prefer lazy allocation.
- Prefer passing structs over extensive parameter lists. Structs that act as data containers are expected where it makes sense. Exceptions exist for parameter lists of 4 or fewer.
- Methods must default to private. Only mark methods `pub` if they are part of the struct's external API.
- Every method must have `///` doc comments describing its expectations and purpose.
- Methods must be designed with testability in mind.
