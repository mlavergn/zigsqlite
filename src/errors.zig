const std = @import("std");
const log = std.log.scoped(.insqlite_errors);

const mod = @import("module.zig");
const c = mod.c;

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
    /// Maps a SQLite C result code to a Zig error.
    pub fn mapError(rc: c_int) SQLiteError {
        return switch (rc) {
            c.SQLITE_ERROR => error.SQLiteError,
            c.SQLITE_PERM => error.SQLitePerm,
            c.SQLITE_BUSY => error.SQLiteBusy,
            c.SQLITE_LOCKED => error.SQLiteLocked,
            c.SQLITE_NOMEM => error.SQLiteNoMem,
            c.SQLITE_READONLY => error.SQLiteReadOnly,
            c.SQLITE_IOERR => error.SQLiteIOErr,
            c.SQLITE_CORRUPT => error.SQLiteCorrupt,
            c.SQLITE_FULL => error.SQLiteFull,
            c.SQLITE_CANTOPEN => error.SQLiteCantOpen,
            c.SQLITE_CONSTRAINT => error.SQLiteConstraint,
            c.SQLITE_MISMATCH => error.SQLiteMismatch,
            c.SQLITE_MISUSE => error.SQLiteMisuse,
            c.SQLITE_AUTH => error.SQLiteAuth,
            c.SQLITE_RANGE => error.SQLiteRange,
            c.SQLITE_NOTADB => error.SQLiteNotADB,
            else => error.SQLiteError,
        };
    }
};

// -----------------------------------------------------------------------------
// Unit Tests

test "mapError known codes" {
    try std.testing.expectEqual(error.SQLitePerm, Errors.mapError(c.SQLITE_PERM));
    try std.testing.expectEqual(error.SQLiteBusy, Errors.mapError(c.SQLITE_BUSY));
    try std.testing.expectEqual(error.SQLiteConstraint, Errors.mapError(c.SQLITE_CONSTRAINT));
}

test "mapError unknown code" {
    try std.testing.expectEqual(error.SQLiteError, Errors.mapError(999));
}
