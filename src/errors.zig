const std = @import("std");
const log = std.log.scoped(.zigsqlite_errors);
const mod = @import("module.zig");

/// Zig error set mapping common SQLite result codes.
pub const SQLiteError = error{
    SQLiteError,
    SQLitePerm,
    SQLiteBusy,
    SQLiteLocked,
    SQLiteNoMem,
    SQLiteReadOnly,
    SQLiteIOErr,
    SQLiteCorrupt,
    SQLiteFull,
    SQLiteCantOpen,
    SQLiteConstraint,
    SQLiteMismatch,
    SQLiteMisuse,
    SQLiteAuth,
    SQLiteRange,
    SQLiteNotADB,
};

/// Namespace for SQLite error mapping utilities.
pub const Errors = struct {
    const Self = @This();

    /// Maps a SQLite C result code to a Zig error.
    pub fn mapError(rc: c_int) SQLiteError {
        log.debug("{s}:{d} :: {s}", .{ @src().file, @src().line, @src().fn_name });
        return switch (rc) {
            mod.c.SQLITE_ERROR => error.SQLiteError,
            mod.c.SQLITE_PERM => error.SQLitePerm,
            mod.c.SQLITE_BUSY => error.SQLiteBusy,
            mod.c.SQLITE_LOCKED => error.SQLiteLocked,
            mod.c.SQLITE_NOMEM => error.SQLiteNoMem,
            mod.c.SQLITE_READONLY => error.SQLiteReadOnly,
            mod.c.SQLITE_IOERR => error.SQLiteIOErr,
            mod.c.SQLITE_CORRUPT => error.SQLiteCorrupt,
            mod.c.SQLITE_FULL => error.SQLiteFull,
            mod.c.SQLITE_CANTOPEN => error.SQLiteCantOpen,
            mod.c.SQLITE_CONSTRAINT => error.SQLiteConstraint,
            mod.c.SQLITE_MISMATCH => error.SQLiteMismatch,
            mod.c.SQLITE_MISUSE => error.SQLiteMisuse,
            mod.c.SQLITE_AUTH => error.SQLiteAuth,
            mod.c.SQLITE_RANGE => error.SQLiteRange,
            mod.c.SQLITE_NOTADB => error.SQLiteNotADB,
            else => error.SQLiteError,
        };
    }
};

// -----------------------------------------------------------------------------
// Unit Tests

test "mapError known codes" {
    try std.testing.expectEqual(error.SQLitePerm, Errors.mapError(mod.c.SQLITE_PERM));
    try std.testing.expectEqual(error.SQLiteBusy, Errors.mapError(mod.c.SQLITE_BUSY));
    try std.testing.expectEqual(error.SQLiteConstraint, Errors.mapError(mod.c.SQLITE_CONSTRAINT));
}

test "mapError unknown code" {
    try std.testing.expectEqual(error.SQLiteError, Errors.mapError(999));
}
