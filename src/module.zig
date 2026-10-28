const std = @import("std");
const builtin = @import("builtin");

pub const is_debug = builtin.mode == .debug;

/// The SQLite C API, translated from `sqlite3.h` by build.zig.
pub const c = @import("sqlite3_h");

pub const Errors = @import("errors.zig").Errors;
pub const SQLiteError = @import("errors.zig").SQLiteError;
pub const SQLite = @import("sqlite.zig").SQLite;
pub const Statement = @import("statement.zig").Statement;
pub const Extension = @import("extension.zig").Extension;

// -----------------------------------------------------------------------------
// Unit Tests

test {
    std.testing.refAllDecls(@This());
}
