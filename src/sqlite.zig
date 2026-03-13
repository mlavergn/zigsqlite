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

    /// Binds a 64-bit integer value to parameter at `idx` (1-based).
    pub fn bindInt(self: *Self, idx: u32, val: i64) !void {
        log.debug("{s}:{d} :: {s}", .{ @src().file, @src().line, @src().fn_name });
        const rc = c.sqlite3_bind_int64(self.stmt, @intCast(idx), val);
        if (rc != c.SQLITE_OK) {
            log.err("bindInt failed: {s}", .{c.sqlite3_errmsg(self.db)});
            return mapError(rc);
        }
    }

    /// Binds a text value to parameter at `idx` (1-based). Uses
    /// SQLITE_STATIC — the caller must ensure `val` outlives the
    /// statement execution (until step, reset, or deinit).
    pub fn bindText(self: *Self, idx: u32, val: []const u8) !void {
        log.debug("{s}:{d} :: {s}", .{ @src().file, @src().line, @src().fn_name });
        const rc = c.sqlite3_bind_text(self.stmt, @intCast(idx), val.ptr, @intCast(val.len), null);
        if (rc != c.SQLITE_OK) {
            log.err("bindText failed: {s}", .{c.sqlite3_errmsg(self.db)});
            return mapError(rc);
        }
    }

    /// Binds a 64-bit float value to parameter at `idx` (1-based).
    pub fn bindDouble(self: *Self, idx: u32, val: f64) !void {
        log.debug("{s}:{d} :: {s}", .{ @src().file, @src().line, @src().fn_name });
        const rc = c.sqlite3_bind_double(self.stmt, @intCast(idx), val);
        if (rc != c.SQLITE_OK) {
            log.err("bindDouble failed: {s}", .{c.sqlite3_errmsg(self.db)});
            return mapError(rc);
        }
    }

    /// Binds SQL NULL to parameter at `idx` (1-based).
    pub fn bindNull(self: *Self, idx: u32) !void {
        log.debug("{s}:{d} :: {s}", .{ @src().file, @src().line, @src().fn_name });
        const rc = c.sqlite3_bind_null(self.stmt, @intCast(idx));
        if (rc != c.SQLITE_OK) {
            log.err("bindNull failed: {s}", .{c.sqlite3_errmsg(self.db)});
            return mapError(rc);
        }
    }

    /// Resets the statement so it can be re-executed with new bindings.
    pub fn reset(self: *Self) !void {
        log.debug("{s}:{d} :: {s}", .{ @src().file, @src().line, @src().fn_name });
        const rc = c.sqlite3_reset(self.stmt);
        if (rc != c.SQLITE_OK) {
            log.err("reset failed: {s}", .{c.sqlite3_errmsg(self.db)});
            return mapError(rc);
        }
    }

    /// Clears all parameter bindings, setting them to NULL.
    /// Call after `reset` to avoid stale bindings when reusing a statement.
    pub fn clearBindings(self: *Self) !void {
        log.debug("{s}:{d} :: {s}", .{ @src().file, @src().line, @src().fn_name });
        const rc = c.sqlite3_clear_bindings(self.stmt);
        if (rc != c.SQLITE_OK) {
            log.err("clearBindings failed: {s}", .{c.sqlite3_errmsg(self.db)});
            return mapError(rc);
        }
    }
};

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
    /// Uses `sqlite3_close_v2` which defers closing until all
    /// prepared statements are finalized.
    pub fn deinit(self: *Self) void {
        log.debug("{s}:{d} :: {s}", .{ @src().file, @src().line, @src().fn_name });
        if (self.db) |db| {
            _ = c.sqlite3_close_v2(db);
            self.db = null;
        }
    }

    /// Executes one or more semicolon-separated SQL statements that
    /// return no rows (e.g. CREATE TABLE, INSERT, UPDATE, DELETE,
    /// pragma statements, or DDL scripts).
    pub fn exec(self: *Self, sql: [*:0]const u8) !void {
        log.debug("{s}:{d} :: {s}", .{ @src().file, @src().line, @src().fn_name });
        const db = self.db orelse return error.SQLiteMisuse;
        const rc = c.sqlite3_exec(db, sql, null, null, null);
        if (rc != c.SQLITE_OK) {
            log.err("exec failed: {s}", .{c.sqlite3_errmsg(db)});
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

// -----------------------------------------------------------------------------
// Unit Tests

test "mapError known codes" {
    try std.testing.expectEqual(error.SQLitePerm, mapError(c.SQLITE_PERM));
    try std.testing.expectEqual(error.SQLiteBusy, mapError(c.SQLITE_BUSY));
    try std.testing.expectEqual(error.SQLiteConstraint, mapError(c.SQLITE_CONSTRAINT));
}

test "mapError unknown code" {
    try std.testing.expectEqual(error.SQLiteError, mapError(999));
}

test "init and deinit" {
    var db = try SQLite.init(":memory:");
    db.deinit();
}

test "exec create table and insert" {
    var db = try SQLite.init(":memory:");
    defer db.deinit();
    try db.exec("CREATE TABLE t(id INTEGER PRIMARY KEY, name TEXT)");
    try db.exec("INSERT INTO t VALUES(1, 'hello')");
}

test "exec multiple semicolon-separated statements" {
    var db = try SQLite.init(":memory:");
    defer db.deinit();
    try db.exec("CREATE TABLE t(id INTEGER); INSERT INTO t VALUES(1); INSERT INTO t VALUES(2)");
    var stmt = try db.prepare("SELECT count(*) FROM t");
    defer stmt.deinit();
    try std.testing.expect(try stmt.step());
    try std.testing.expectEqual(@as(i64, 2), stmt.columnInt(0));
}

test "prepare and columnCount" {
    var db = try SQLite.init(":memory:");
    defer db.deinit();
    try db.exec("CREATE TABLE t(a INTEGER, b TEXT, c REAL)");
    var stmt = try db.prepare("SELECT a, b, c FROM t");
    defer stmt.deinit();
    try std.testing.expectEqual(@as(u32, 3), stmt.columnCount());
}

test "step returns false on empty result" {
    var db = try SQLite.init(":memory:");
    defer db.deinit();
    try db.exec("CREATE TABLE t(id INTEGER)");
    var stmt = try db.prepare("SELECT * FROM t");
    defer stmt.deinit();
    try std.testing.expectEqual(false, try stmt.step());
}

test "columnInt" {
    var db = try SQLite.init(":memory:");
    defer db.deinit();
    try db.exec("CREATE TABLE t(val INTEGER)");
    try db.exec("INSERT INTO t VALUES(42)");
    var stmt = try db.prepare("SELECT val FROM t");
    defer stmt.deinit();
    try std.testing.expect(try stmt.step());
    try std.testing.expectEqual(@as(i64, 42), stmt.columnInt(0));
    try std.testing.expectEqual(false, try stmt.step());
}

test "columnText" {
    var db = try SQLite.init(":memory:");
    defer db.deinit();
    try db.exec("CREATE TABLE t(val TEXT)");
    try db.exec("INSERT INTO t VALUES('hello')");
    var stmt = try db.prepare("SELECT val FROM t");
    defer stmt.deinit();
    try std.testing.expect(try stmt.step());
    try std.testing.expectEqualStrings("hello", stmt.columnText(0).?);
}

test "columnText returns null for SQL NULL" {
    var db = try SQLite.init(":memory:");
    defer db.deinit();
    try db.exec("CREATE TABLE t(val TEXT)");
    try db.exec("INSERT INTO t VALUES(NULL)");
    var stmt = try db.prepare("SELECT val FROM t");
    defer stmt.deinit();
    try std.testing.expect(try stmt.step());
    try std.testing.expectEqual(@as(?[]const u8, null), stmt.columnText(0));
}

test "columnDouble" {
    var db = try SQLite.init(":memory:");
    defer db.deinit();
    try db.exec("CREATE TABLE t(val REAL)");
    try db.exec("INSERT INTO t VALUES(3.14)");
    var stmt = try db.prepare("SELECT val FROM t");
    defer stmt.deinit();
    try std.testing.expect(try stmt.step());
    try std.testing.expectApproxEqAbs(@as(f64, 3.14), stmt.columnDouble(0), 0.001);
}

test "bindInt" {
    var db = try SQLite.init(":memory:");
    defer db.deinit();
    try db.exec("CREATE TABLE t(id INTEGER, val TEXT)");
    try db.exec("INSERT INTO t VALUES(1, 'a'); INSERT INTO t VALUES(2, 'b')");
    var stmt = try db.prepare("SELECT val FROM t WHERE id = ?");
    defer stmt.deinit();
    try stmt.bindInt(1, 2);
    try std.testing.expect(try stmt.step());
    try std.testing.expectEqualStrings("b", stmt.columnText(0).?);
    try std.testing.expectEqual(false, try stmt.step());
}

test "bindText" {
    var db = try SQLite.init(":memory:");
    defer db.deinit();
    try db.exec("CREATE TABLE t(id INTEGER, name TEXT)");
    try db.exec("INSERT INTO t VALUES(1, 'alice'); INSERT INTO t VALUES(2, 'bob')");
    var stmt = try db.prepare("SELECT id FROM t WHERE name = ?");
    defer stmt.deinit();
    try stmt.bindText(1, "bob");
    try std.testing.expect(try stmt.step());
    try std.testing.expectEqual(@as(i64, 2), stmt.columnInt(0));
}

test "bindDouble" {
    var db = try SQLite.init(":memory:");
    defer db.deinit();
    try db.exec("CREATE TABLE t(val REAL)");
    try db.exec("INSERT INTO t VALUES(1.5); INSERT INTO t VALUES(2.5); INSERT INTO t VALUES(3.5)");
    var stmt = try db.prepare("SELECT val FROM t WHERE val > ? ORDER BY val");
    defer stmt.deinit();
    try stmt.bindDouble(1, 2.0);
    try std.testing.expect(try stmt.step());
    try std.testing.expectApproxEqAbs(@as(f64, 2.5), stmt.columnDouble(0), 0.001);
    try std.testing.expect(try stmt.step());
    try std.testing.expectApproxEqAbs(@as(f64, 3.5), stmt.columnDouble(0), 0.001);
    try std.testing.expectEqual(false, try stmt.step());
}

test "bindNull" {
    var db = try SQLite.init(":memory:");
    defer db.deinit();
    try db.exec("CREATE TABLE t(val TEXT)");
    var ins = try db.prepare("INSERT INTO t VALUES(?)");
    try ins.bindNull(1);
    try std.testing.expectEqual(false, try ins.step());
    ins.deinit();
    var sel = try db.prepare("SELECT val FROM t");
    defer sel.deinit();
    try std.testing.expect(try sel.step());
    try std.testing.expectEqual(@as(?[]const u8, null), sel.columnText(0));
}

test "reset and clearBindings" {
    var db = try SQLite.init(":memory:");
    defer db.deinit();
    try db.exec("CREATE TABLE t(id INTEGER, name TEXT)");
    try db.exec("INSERT INTO t VALUES(1, 'a'); INSERT INTO t VALUES(2, 'b')");
    var stmt = try db.prepare("SELECT name FROM t WHERE id = ?");
    defer stmt.deinit();

    // First execution
    try stmt.bindInt(1, 1);
    try std.testing.expect(try stmt.step());
    try std.testing.expectEqualStrings("a", stmt.columnText(0).?);

    // Reset, clear, re-bind
    try stmt.reset();
    try stmt.clearBindings();
    try stmt.bindInt(1, 2);
    try std.testing.expect(try stmt.step());
    try std.testing.expectEqualStrings("b", stmt.columnText(0).?);
}
