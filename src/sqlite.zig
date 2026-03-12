const std = @import("std");
const log = std.log.scoped(.insqlite3_sqlite);

const c = @cImport({
    @cInclude("sqlite3.h");
});

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

/// A prepared SQL statement. Created by `SQLite.prepare` and must be
/// released with `deinit`. Holds a reference to the parent database
/// connection for error reporting.
pub const Statement = struct {
    const Self = @This();

    stmt: *c.sqlite3_stmt,
    db: *c.sqlite3,

    /// Releases the prepared statement resources via `sqlite3_finalize`.
    pub fn deinit(self: *Self) void {
        log.debug("{s}:{d} :: {s}", .{ @src().file, @src().line, @src().fn_name });
        _ = c.sqlite3_finalize(self.stmt);
    }

    /// Advances to the next row. Returns `true` if a row is available
    /// for reading, `false` when execution is complete.
    pub fn step(self: *Self) !bool {
        log.debug("{s}:{d} :: {s}", .{ @src().file, @src().line, @src().fn_name });
        const rc = c.sqlite3_step(self.stmt);
        if (rc == c.SQLITE_ROW) return true;
        if (rc == c.SQLITE_DONE) return false;
        log.err("step failed: {s}", .{c.sqlite3_errmsg(self.db)});
        return mapError(rc);
    }

    /// Returns the number of columns in the result set.
    pub fn columnCount(self: *const Self) u32 {
        return @intCast(c.sqlite3_column_count(self.stmt));
    }

    /// Returns the value of column `col` as a 64-bit integer.
    pub fn columnInt(self: *const Self, col: u32) i64 {
        return c.sqlite3_column_int64(self.stmt, @intCast(col));
    }

    /// Returns the value of column `col` as a Zig slice, or `null`
    /// if the column is SQL NULL.
    pub fn columnText(self: *const Self, col: u32) ?[]const u8 {
        const idx: c_int = @intCast(col);
        const raw = c.sqlite3_column_text(self.stmt, idx);
        if (raw == null) return null;
        const len: usize = @intCast(c.sqlite3_column_bytes(self.stmt, idx));
        const ptr: [*]const u8 = @ptrCast(raw);
        return ptr[0..len];
    }

    /// Returns the value of column `col` as a 64-bit float.
    pub fn columnDouble(self: *const Self, col: u32) f64 {
        return c.sqlite3_column_double(self.stmt, @intCast(col));
    }
};

/// Maps a SQLite C result code to a Zig error.
fn mapError(rc: c_int) SQLiteError {
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

/// Zig wrapper around a SQLite database connection. Manages the
/// lifecycle of the underlying `sqlite3*` handle and provides
/// methods for executing SQL and preparing statements.
pub const SQLite = struct {
    const Self = @This();

    db: ?*c.sqlite3 = null,

    /// Opens a database file at `path`. Use ":memory:" for an
    /// in-memory database. The connection must be released with `deinit`.
    pub fn init(path: [*:0]const u8) !Self {
        log.debug("{s}:{d} :: {s}", .{ @src().file, @src().line, @src().fn_name });
        var db: ?*c.sqlite3 = null;
        const rc = c.sqlite3_open(path, &db);
        if (rc != c.SQLITE_OK) {
            if (db) |d| _ = c.sqlite3_close(d);
            return mapError(rc);
        }
        return Self{ .db = db };
    }

    /// Closes the database connection and releases all resources.
    pub fn deinit(self: *Self) void {
        log.debug("{s}:{d} :: {s}", .{ @src().file, @src().line, @src().fn_name });
        if (self.db) |db| {
            _ = c.sqlite3_close(db);
            self.db = null;
        }
    }

    /// Executes a single SQL statement that returns no rows
    /// (e.g. CREATE TABLE, INSERT, UPDATE, DELETE).
    pub fn exec(self: *Self, sql: [*:0]const u8) !void {
        log.debug("{s}:{d} :: {s}", .{ @src().file, @src().line, @src().fn_name });
        const db = self.db orelse return error.SQLiteMisuse;
        const rc = c.sqlite3_exec(db, sql, null, null, null);
        if (rc != c.SQLITE_OK) {
            log.err("exec failed: {s}", .{c.sqlite3_errmsg(db)});
            return mapError(rc);
        }
    }

    /// Executes one or more semicolon-separated SQL statements that
    /// return no rows. Useful for running DDL scripts or batch inserts.
    pub fn execScript(self: *Self, sql: [*:0]const u8) !void {
        log.debug("{s}:{d} :: {s}", .{ @src().file, @src().line, @src().fn_name });
        const db = self.db orelse return error.SQLiteMisuse;
        const rc = c.sqlite3_exec(db, sql, null, null, null);
        if (rc != c.SQLITE_OK) {
            log.err("execScript failed: {s}", .{c.sqlite3_errmsg(db)});
            return mapError(rc);
        }
    }

    /// Compiles a SQL statement and returns a `Statement` that can be
    /// stepped through to read result rows. The caller must call
    /// `Statement.deinit` when finished.
    pub fn prepare(self: *Self, sql: [*:0]const u8) !Statement {
        log.debug("{s}:{d} :: {s}", .{ @src().file, @src().line, @src().fn_name });
        const db = self.db orelse return error.SQLiteMisuse;
        var stmt: ?*c.sqlite3_stmt = null;
        const rc = c.sqlite3_prepare_v2(db, sql, -1, &stmt, null);
        if (rc != c.SQLITE_OK) {
            log.err("prepare failed: {s}", .{c.sqlite3_errmsg(db)});
            return mapError(rc);
        }
        return Statement{
            .stmt = stmt orelse return error.SQLiteError,
            .db = db,
        };
    }
};
